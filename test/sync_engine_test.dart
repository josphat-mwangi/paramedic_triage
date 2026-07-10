import 'package:flutter_test/flutter_test.dart';
import 'package:paramedic_triage/data/local/local_data_source.dart';
import 'package:paramedic_triage/data/remote/remote_data_source.dart';
import 'package:paramedic_triage/data/repository/triage_repository_impl.dart';
import 'package:paramedic_triage/domain/triage_record.dart';
import 'package:paramedic_triage/sync/backoff.dart';
import 'package:paramedic_triage/sync/connectivity_monitor.dart';
import 'package:paramedic_triage/sync/sync_engine.dart';

/// In-memory local store — no Hive, so tests run fast and pure.
class InMemoryLocalDataSource implements LocalDataSource {
  final _store = <String, TriageRecord>{};

  @override
  Future<void> upsert(TriageRecord record) async => _store[record.id] = record;

  @override
  Future<TriageRecord?> getById(String id) async => _store[id];

  @override
  Future<List<TriageRecord>> getAll() async => _store.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

class FakeConnectivity implements ConnectivityMonitor {
  bool online;
  FakeConnectivity(this.online);

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<void> get onOnline => const Stream.empty();
}

TriageRecord _record(String id, {int retry = 0}) => TriageRecord(
      id: id,
      patientName: 'Patient $id',
      conditionDescription: 'condition',
      priority: 1,
      status: TriageStatus.pending,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      retryCount: retry,
    );

void main() {
  late InMemoryLocalDataSource local;
  late MockRemoteDataSource remote;
  late TriageRepositoryImpl repository;

  setUp(() {
    local = InMemoryLocalDataSource();
    // Zero latency so tests are instant and deterministic.
    remote = MockRemoteDataSource(latency: Duration.zero, failureRate: 0);
    repository =
        TriageRepositoryImpl(local: local, remote: remote, maxRetries: 3);
  });

  tearDown(() => repository.dispose());

  test('offline: syncPending is a no-op, record stays pending', () async {
    await repository.save(_record('a'));
    final engine = SyncEngine(
        repository: repository, connectivity: FakeConnectivity(false));

    await engine.syncPending();

    expect((await local.getById('a'))!.syncStatus, SyncStatus.pending);
    engine.dispose();
  });

  test('online + healthy server: record is delivered and marked synced',
      () async {
    await repository.save(_record('a'));
    final engine = SyncEngine(
        repository: repository, connectivity: FakeConnectivity(true));

    await engine.syncPending();

    expect((await local.getById('a'))!.syncStatus, SyncStatus.synced);
    engine.dispose();
  });

  test('failure increments retry count and keeps record pending', () async {
    await repository.save(_record('a'));
    remote.forceFailure = true;
    final engine = SyncEngine(
      repository: repository,
      connectivity: FakeConnectivity(true),
      backoff: BackoffPolicy(maxRetries: 3, base: Duration.zero),
    );

    await engine.syncPending();
    // Cancel the auto-scheduled retry timer before asserting so the count is
    // stable and no timer leaks into the next test.
    engine.dispose();

    final saved = await local.getById('a');
    expect(saved!.syncStatus, SyncStatus.pending);
    expect(saved.retryCount, 1);
  });

  test('a record over the retry cap is parked as failed', () async {
    await repository.save(_record('a', retry: 2));
    remote.forceFailure = true;
    final engine = SyncEngine(
      repository: repository,
      connectivity: FakeConnectivity(true),
      backoff: BackoffPolicy(maxRetries: 3, base: Duration.zero),
    );

    await engine.syncPending();
    engine.dispose();

    final saved = await local.getById('a');
    expect(saved!.syncStatus, SyncStatus.failed);
    expect(saved.retryCount, 3);
    expect(saved.lastError, isNotNull);
  });

  test('drains multiple queued records in one pass', () async {
    await repository.save(_record('a'));
    await repository.save(_record('b'));
    await repository.save(_record('c'));
    final engine = SyncEngine(
        repository: repository, connectivity: FakeConnectivity(true));

    await engine.syncPending();

    for (final id in ['a', 'b', 'c']) {
      expect((await local.getById(id))!.syncStatus, SyncStatus.synced);
    }
    engine.dispose();
  });
}
