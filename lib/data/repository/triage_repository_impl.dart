import 'dart:async';

import '../../domain/triage_record.dart';
import '../local/local_data_source.dart';
import '../remote/remote_data_source.dart';
import 'triage_repository.dart';

class TriageRepositoryImpl implements TriageRepository {
  final LocalDataSource _local;
  final RemoteDataSource _remote;

  /// Max attempts before a record is parked as permanently `failed`, so a
  /// poison record can't loop forever.
  final int maxRetries;

  final _controller = StreamController<List<TriageRecord>>.broadcast();

  TriageRepositoryImpl({
    required LocalDataSource local,
    required RemoteDataSource remote,
    this.maxRetries = 5,
  })  : _local = local,
        _remote = remote;

  @override
  Stream<List<TriageRecord>> watch() => _controller.stream;

  Future<void> _emit() async {
    if (!_controller.isClosed) _controller.add(await _local.getAll());
  }

  @override
  Future<List<TriageRecord>> getAll() => _local.getAll();

  @override
  Future<List<TriageRecord>> getSyncable() async {
    final all = await _local.getAll();
    return all
        .where((r) =>
            r.syncStatus == SyncStatus.pending ||
            r.syncStatus == SyncStatus.syncing)
        .toList()
      // Oldest first so records leave in the order they were captured.
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> save(TriageRecord record) async {
    await _local.upsert(record.copyWith(syncStatus: SyncStatus.pending));
    await _emit();
  }

  Future<void> _mutate(String id, TriageRecord Function(TriageRecord) f) async {
    final current = await _local.getById(id);
    if (current == null) return;
    await _local.upsert(f(current));
    await _emit();
  }

  @override
  Future<void> markSyncing(String id) =>
      _mutate(id, (r) => r.copyWith(syncStatus: SyncStatus.syncing));

  @override
  Future<void> markSynced(String id) => _mutate(
      id, (r) => r.copyWith(syncStatus: SyncStatus.synced, clearError: true));

  @override
  Future<void> markPendingRetry(String id, int retryCount) => _mutate(id,
      (r) => r.copyWith(syncStatus: SyncStatus.pending, retryCount: retryCount));

  @override
  Future<void> markFailed(String id, String error, int retryCount) => _mutate(
      id,
      (r) => r.copyWith(
          syncStatus: SyncStatus.failed,
          retryCount: retryCount,
          lastError: error));

  @override
  Future<void> pushToRemote(TriageRecord record) => _remote.create(record);

  @override
  void dispose() {
    _controller.close();
  }
}
