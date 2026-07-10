import 'dart:async';

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

  final _onlineController = StreamController<void>.broadcast();

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<void> get onOnline => _onlineController.stream;

  /// Test helper mirroring a real device coming back online: flips the flag
  /// and emits on [onOnline], which is exactly what [SyncEngine.start]'s
  /// listener reacts to. Used to reproduce "toggle airplane mode off".
  void goOnline() {
    online = true;
    _onlineController.add(null);
  }

  void dispose() => _onlineController.close();
}

/// A remote data source whose `create()` blocks on an explicit [Completer]
/// per record id, instead of a real or fake timer. This lets a test pause a
/// drain "mid-flight" and resume it deterministically — no reliance on wall
/// clock margins, so there is zero timing luck involved.
///
/// A record id may be [release]d *before* it is ever pushed (a "pre-release"),
/// in which case the eventual `create()` call resolves immediately — this is
/// what lets a dirty-flag-triggered re-drain finish without deadlocking a
/// test that wants to assert on the *first* drain's future.
class GatedRemoteDataSource implements RemoteDataSource {
  final _pending = <String, Completer<void>>{};
  final _preReleased = <String>{};

  /// Every id `create()` was called with, in call order — used to assert
  /// "pushed exactly once" / "no duplicate sends".
  final List<String> attempts = [];

  @override
  Future<void> create(TriageRecord record) {
    attempts.add(record.id);
    if (_preReleased.remove(record.id)) return Future.value();
    return (_pending[record.id] = Completer<void>()).future;
  }

  /// Lets a blocked (or not-yet-started) `create()` call for [id] resolve.
  void release(String id) {
    final completer = _pending.remove(id);
    if (completer != null) {
      completer.complete();
    } else {
      _preReleased.add(id);
    }
  }
}

/// Wraps any [RemoteDataSource] and records every id `create()` was called
/// with, so a test can assert "no duplicate sends" precisely instead of only
/// checking end state.
class RecordingRemoteDataSource implements RemoteDataSource {
  final RemoteDataSource _inner;
  final List<String> pushedIds = [];
  RecordingRemoteDataSource(this._inner);

  @override
  Future<void> create(TriageRecord record) async {
    pushedIds.add(record.id);
    await _inner.create(record);
  }
}

/// Always fails for a chosen set of ids ("poison" records) and succeeds
/// instantly for everything else — MockRemoteDataSource only supports a
/// global forceFailure switch, so this fills a real gap for the
/// "poison record among healthy ones" scenario.
class SelectiveFailureRemoteDataSource implements RemoteDataSource {
  final Set<String> failIds;
  SelectiveFailureRemoteDataSource(this.failIds);

  @override
  Future<void> create(TriageRecord record) async {
    if (failIds.contains(record.id)) {
      throw NetworkException('poison record ${record.id}');
    }
  }
}

/// Simulates a *real* connectivity drop happening partway through a batch:
/// the first push succeeds, and immediately after it flips the shared
/// [FakeConnectivity] offline and starts failing every subsequent push —
/// exactly what a genuine HTTP client would do once the network is gone,
/// even though [SyncEngine.syncPending] only checks connectivity once up
/// front and therefore keeps working through the batch it already fetched.
class FlappingRemoteDataSource implements RemoteDataSource {
  final FakeConnectivity connectivity;
  int pushCount = 0;
  FlappingRemoteDataSource(this.connectivity);

  @override
  Future<void> create(TriageRecord record) async {
    pushCount++;
    if (pushCount == 1) {
      connectivity.online = false;
      return;
    }
    throw NetworkException('offline mid-drain');
  }
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

  group('demo scenario reproduction', () {
    test(
        'save while offline (airplane mode), then reconnect auto-syncs via '
        'the onOnline listener — the exact mechanism start() wires up',
        () async {
      final connectivity = FakeConnectivity(false);
      await repository.save(_record('a')); // "save in airplane mode"
      final engine =
          SyncEngine(repository: repository, connectivity: connectivity);

      // start() subscribes to onOnline and runs an initial pass, which is a
      // no-op here because we're still offline.
      engine.start();
      await pumpEventQueue();
      expect((await local.getById('a'))!.syncStatus, SyncStatus.pending);

      // "Toggle airplane mode off" — this is the real trigger the demo
      // relies on, not a manual syncPending() call.
      connectivity.goOnline();
      await pumpEventQueue();

      expect((await local.getById('a'))!.syncStatus, SyncStatus.synced);
      engine.dispose();
      connectivity.dispose();
    });
  });

  group('adversarial: reentrancy / dirty-flag regression', () {
    test(
        'a syncPending() call that lands mid-drain does not strand a record '
        'saved during the drain (regression for the _dirty fix)', () async {
      final gated = GatedRemoteDataSource();
      final repo = TriageRepositoryImpl(local: local, remote: gated, maxRetries: 3);
      await repo.save(_record('a'));
      final engine =
          SyncEngine(repository: repo, connectivity: FakeConnectivity(true));

      // Start draining 'a'. Because GatedRemoteDataSource blocks on a
      // Completer we control (not a timer), this is genuinely paused
      // mid-flight with zero reliance on wall-clock timing.
      final firstDrain = engine.syncPending();
      await pumpEventQueue();
      expect(gated.attempts, ['a'], reason: "a's push is now genuinely in flight");

      // A second record is saved and a racing sync trigger fires while the
      // first drain is still in flight — exactly the TriageNotifier.submit()
      // vs. connectivity-listener race this fix addresses.
      await repo.save(_record('b'));
      await engine.syncPending(); // must not no-op silently: sets _dirty.

      // Pre-release 'b' so that whenever the dirty-triggered re-drain pushes
      // it, it resolves immediately (this test intentionally never blocks on
      // 'b' — it exists purely to prove 'b' isn't stranded).
      gated.release('b');
      gated.release('a');
      await firstDrain;
      await pumpEventQueue();

      expect((await local.getById('a'))!.syncStatus, SyncStatus.synced);
      expect((await local.getById('b'))!.syncStatus, SyncStatus.synced);
      // Exactly one push per record — the dirty re-drain must not resend 'a'.
      expect(gated.attempts, ['a', 'b']);
      engine.dispose();
    });

    test('onAppResumed() while a drain is in flight is safe and does not double-send',
        () async {
      final gated = GatedRemoteDataSource();
      final repo = TriageRepositoryImpl(local: local, remote: gated, maxRetries: 3);
      await repo.save(_record('a'));
      final engine =
          SyncEngine(repository: repo, connectivity: FakeConnectivity(true));

      final firstDrain = engine.syncPending();
      await pumpEventQueue();
      expect(gated.attempts, ['a']);

      // App is backgrounded/resumed mid-drain.
      expect(() => engine.onAppResumed(), returnsNormally);
      await pumpEventQueue();
      expect(gated.attempts, ['a'],
          reason: 'resume must not trigger a second concurrent push for a');

      gated.release('a');
      await firstDrain;
      await pumpEventQueue();

      expect((await local.getById('a'))!.syncStatus, SyncStatus.synced);
      expect(gated.attempts, ['a']); // still exactly one push, end to end.
      engine.dispose();
    });
  });

  group('adversarial: connectivity flapping', () {
    test(
        'connectivity dropping mid-batch does not throw and leaves '
        'undelivered records pending (not corrupted, not force-failed)',
        () async {
      final connectivity = FakeConnectivity(true);
      final flapping = FlappingRemoteDataSource(connectivity);
      final repo = TriageRepositoryImpl(local: local, remote: flapping, maxRetries: 3);
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      await repo.save(_record('c'));

      final engine = SyncEngine(
        repository: repo,
        connectivity: connectivity,
        backoff: BackoffPolicy(maxRetries: 3, base: Duration.zero),
      );

      // Must complete without throwing even though 'b' and 'c' hit a
      // simulated connectivity drop mid-pass.
      await engine.syncPending();
      // Cancel the auto-scheduled retry timer before asserting, same pattern
      // as the existing single-failure test.
      engine.dispose();

      final a = await local.getById('a');
      final b = await local.getById('b');
      final c = await local.getById('c');
      expect(a!.syncStatus, SyncStatus.synced);
      expect(b!.syncStatus, SyncStatus.pending);
      expect(b.retryCount, 1);
      expect(c!.syncStatus, SyncStatus.pending);
      expect(c.retryCount, 1);

      // Connectivity toggles back on (online -> offline -> online) and the
      // next drain (e.g. the reconnect listener firing) finishes the job
      // without resending the already-synced 'a'.
      connectivity.online = true;
      final recovered = RecordingRemoteDataSource(
          MockRemoteDataSource(latency: Duration.zero, failureRate: 0));
      final repo2 = TriageRepositoryImpl(local: local, remote: recovered, maxRetries: 3);
      final engine2 =
          SyncEngine(repository: repo2, connectivity: connectivity);
      await engine2.syncPending();
      engine2.dispose();

      expect((await local.getById('b'))!.syncStatus, SyncStatus.synced);
      expect((await local.getById('c'))!.syncStatus, SyncStatus.synced);
      expect(recovered.pushedIds, isNot(contains('a')),
          reason: 'already-synced record must not be resent after a flap');
    });
  });

  group('adversarial: duplicate submission', () {
    test('the same record submitted twice is deduped by its id (idempotency key)',
        () async {
      final recording = RecordingRemoteDataSource(
          MockRemoteDataSource(latency: Duration.zero, failureRate: 0));
      final repo = TriageRepositoryImpl(local: local, remote: recording, maxRetries: 3);
      final record = _record('dup-1');

      // Simulate a double-tap submit: the exact same record saved twice
      // before any sync has run.
      await repo.save(record);
      await repo.save(record);

      expect((await local.getAll()).length, 1,
          reason: 'the outbox is keyed by id — a duplicate save upserts, not appends');

      final engine =
          SyncEngine(repository: repo, connectivity: FakeConnectivity(true));
      await engine.syncPending();
      engine.dispose();

      expect((await local.getById('dup-1'))!.syncStatus, SyncStatus.synced);
      expect(recording.pushedIds, ['dup-1']);
    });
  });

  group('adversarial: poison record', () {
    test('a record that always fails is parked at the cap without blocking healthy records',
        () async {
      final selective = SelectiveFailureRemoteDataSource({'poison'});
      final repo = TriageRepositoryImpl(local: local, remote: selective, maxRetries: 2);
      await repo.save(_record('poison'));
      await repo.save(_record('healthy-1'));
      await repo.save(_record('healthy-2'));

      final backoff = BackoffPolicy(maxRetries: 2, base: Duration.zero);

      // Pass 1: healthy records sync; the poison record fails once and stays
      // pending (retryCount 0 -> 1, still under the cap of 2).
      final engine1 = SyncEngine(
          repository: repo, connectivity: FakeConnectivity(true), backoff: backoff);
      await engine1.syncPending();
      engine1.dispose();

      expect((await local.getById('healthy-1'))!.syncStatus, SyncStatus.synced);
      expect((await local.getById('healthy-2'))!.syncStatus, SyncStatus.synced);
      var poison = await local.getById('poison');
      expect(poison!.syncStatus, SyncStatus.pending);
      expect(poison.retryCount, 1);

      // Pass 2 (e.g. the scheduled retry firing): poison finally exceeds the
      // cap and is parked as failed — healthy records are untouched since
      // getSyncable() no longer returns them.
      final engine2 = SyncEngine(
          repository: repo, connectivity: FakeConnectivity(true), backoff: backoff);
      await engine2.syncPending();
      engine2.dispose();

      poison = await local.getById('poison');
      expect(poison!.syncStatus, SyncStatus.failed);
      expect(poison.retryCount, 2);
      expect(poison.lastError, isNotNull);
      expect((await local.getById('healthy-1'))!.syncStatus, SyncStatus.synced);
      expect((await local.getById('healthy-2'))!.syncStatus, SyncStatus.synced);
    });
  });

  group('adversarial: large queue', () {
    test('a large queue (100+ records) drains in order, oldest first', () async {
      final recording = RecordingRemoteDataSource(
          MockRemoteDataSource(latency: Duration.zero, failureRate: 0));
      final repo = TriageRepositoryImpl(local: local, remote: recording, maxRetries: 3);

      final ids = List.generate(120, (i) => 'r$i');
      for (var i = 0; i < ids.length; i++) {
        // Strictly increasing createdAt so "oldest first" is unambiguous even
        // though every record is saved within the same test tick.
        await local.upsert(TriageRecord(
          id: ids[i],
          patientName: 'Patient ${ids[i]}',
          conditionDescription: 'condition',
          priority: 1,
          status: TriageStatus.pending,
          syncStatus: SyncStatus.pending,
          createdAt: i,
        ));
      }

      final engine =
          SyncEngine(repository: repo, connectivity: FakeConnectivity(true));
      await engine.syncPending();
      engine.dispose();

      expect(recording.pushedIds, ids,
          reason: 'oldest (lowest createdAt) first, exact order preserved');
      for (final id in ids) {
        expect((await local.getById(id))!.syncStatus, SyncStatus.synced);
      }
    });
  });
}
