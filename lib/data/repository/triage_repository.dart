import '../../domain/triage_record.dart';

/// The single boundary the UI and sync engine talk to. UI never touches Hive or
/// the network directly — it only calls this. That is the "views decoupled from
/// persistence and sync" requirement, expressed as a contract.
abstract class TriageRepository {
  /// Reactive stream of the full record set. Emits after every mutation so the
  /// UI updates optimistically without polling.
  Stream<List<TriageRecord>> watch();

  Future<List<TriageRecord>> getAll();

  /// Records eligible for a sync attempt (pending, or previously-failed items
  /// still under the retry cap are re-queued as pending).
  Future<List<TriageRecord>> getSyncable();

  /// Persist a brand-new record locally as `pending`. This ALWAYS succeeds and
  /// never touches the network — that is the offline-first guarantee.
  Future<void> save(TriageRecord record);

  Future<void> markSyncing(String id);
  Future<void> markSynced(String id);
  Future<void> markPendingRetry(String id, int retryCount);
  Future<void> markFailed(String id, String error, int retryCount);

  /// Delegates the actual upload to the remote data source. Throws on failure.
  Future<void> pushToRemote(TriageRecord record);

  void dispose();
}
