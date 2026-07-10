import 'dart:async';

import '../data/repository/triage_repository.dart';
import '../domain/triage_record.dart';
import 'backoff.dart';
import 'connectivity_monitor.dart';

/// The crown jewel: drains the local outbox to the server whenever the network
/// is available, off the UI thread, with bounded retries.
///
/// Design guarantees:
///   * Reentrancy guard — overlapping drains (listener + manual trigger +
///     lifecycle resume) collapse into one in-flight pass.
///   * Offline-safe — [syncPending] is a no-op when offline, so callers never
///     have to check connectivity themselves.
///   * Bounded — records that keep failing are parked as `failed` after
///     [BackoffPolicy.maxRetries] rather than looping forever.
class SyncEngine {
  final TriageRepository repository;
  final ConnectivityMonitor connectivity;
  final BackoffPolicy backoff;

  StreamSubscription<void>? _onlineSub;
  bool _isSyncing = false;
  bool _dirty = false;
  Timer? _retryTimer;

  SyncEngine({
    required this.repository,
    required this.connectivity,
    BackoffPolicy? backoff,
  }) : backoff = backoff ?? BackoffPolicy();

  /// Begin listening for network restoration. Also kicks an initial drain in
  /// case records were captured while the app was closed and offline.
  void start() {
    _onlineSub ??= connectivity.onOnline.listen((_) => syncPending());
    syncPending();
  }

  /// Drain the outbox once. Safe to call from anywhere, any number of times.
  ///
  /// If a call arrives while a drain is already in flight (e.g. a submit
  /// racing the connectivity listener), it doesn't just no-op: it marks the
  /// pass "dirty" so the in-flight drain immediately runs one more pass on
  /// completion. Without this, a record saved mid-drain could sit `pending`
  /// until the next unrelated trigger (reconnect, resume, manual refresh).
  Future<void> syncPending() async {
    if (_isSyncing) {
      _dirty = true;
      return;
    }
    if (!await connectivity.isOnline) return;

    _isSyncing = true;
    try {
      final batch = await repository.getSyncable();
      var scheduleRetry = false;

      for (final record in batch) {
        final ok = await _attempt(record);
        if (!ok) scheduleRetry = true;
      }

      // If anything is still pending after this pass, schedule a jittered
      // retry — the exponential backoff kicks in via each record's retryCount.
      if (scheduleRetry) _scheduleRetry(batch);
    } finally {
      _isSyncing = false;
    }

    if (_dirty) {
      _dirty = false;
      await syncPending();
    }
  }

  /// Returns true if the record was delivered.
  Future<bool> _attempt(TriageRecord record) async {
    await repository.markSyncing(record.id);
    try {
      await repository.pushToRemote(record);
      await repository.markSynced(record.id);
      return true;
    } catch (e) {
      final nextCount = record.retryCount + 1;
      if (backoff.hasAttemptsLeft(nextCount)) {
        await repository.markPendingRetry(record.id, nextCount);
      } else {
        await repository.markFailed(record.id, e.toString(), nextCount);
      }
      return false;
    }
  }

  void _scheduleRetry(List<TriageRecord> batch) {
    final maxAttempt = batch.fold<int>(
        0, (m, r) => r.retryCount > m ? r.retryCount : m);
    final delay = backoff.jitteredDelayFor(maxAttempt);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, syncPending);
  }

  /// Call from `didChangeAppLifecycleState` on resume — a cheap opportunistic
  /// drain when the app returns to the foreground.
  void onAppResumed() => syncPending();

  void dispose() {
    _onlineSub?.cancel();
    _retryTimer?.cancel();
  }
}
