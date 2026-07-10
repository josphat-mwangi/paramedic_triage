import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repository/triage_repository.dart';
import '../domain/triage_record.dart';
import '../sync/sync_engine.dart';

/// Provided by an override in main() after async init (Hive box, deps).
final triageRepositoryProvider = Provider<TriageRepository>(
    (ref) => throw UnimplementedError('override in ProviderScope'));

final syncEngineProvider = Provider<SyncEngine>(
    (ref) => throw UnimplementedError('override in ProviderScope'));

/// Immutable UI state — the view is a pure function of this.
class TriageUiState {
  final List<TriageRecord> records;
  final bool isSyncing;

  const TriageUiState({this.records = const [], this.isSyncing = false});

  int get pendingCount => records
      .where((r) =>
          r.syncStatus == SyncStatus.pending ||
          r.syncStatus == SyncStatus.syncing)
      .length;

  TriageUiState copyWith({List<TriageRecord>? records, bool? isSyncing}) =>
      TriageUiState(
        records: records ?? this.records,
        isSyncing: isSyncing ?? this.isSyncing,
      );
}

class TriageNotifier extends StateNotifier<TriageUiState> {
  final TriageRepository _repository;
  final SyncEngine _syncEngine;
  final _uuid = const Uuid();
  StreamSubscription<List<TriageRecord>>? _sub;

  TriageNotifier(this._repository, this._syncEngine)
      : super(const TriageUiState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(records: await _repository.getAll());
    _sub = _repository.watch().listen((records) {
      state = state.copyWith(
        records: records,
        isSyncing: records.any((r) => r.syncStatus == SyncStatus.syncing),
      );
    });
  }

  /// Capture a new triage record. Writes locally (optimistic, always succeeds)
  /// then nudges the engine — which quietly no-ops if we happen to be offline.
  Future<void> submit({
    required String patientName,
    required String conditionDescription,
    required int priority,
    required TriageStatus status,
  }) async {
    final record = TriageRecord(
      id: _uuid.v4(),
      patientName: patientName.trim(),
      conditionDescription: conditionDescription.trim(),
      priority: priority,
      status: status,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repository.save(record);
    unawaited(_syncEngine.syncPending());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final triageNotifierProvider =
    StateNotifierProvider<TriageNotifier, TriageUiState>((ref) {
  return TriageNotifier(
    ref.watch(triageRepositoryProvider),
    ref.watch(syncEngineProvider),
  );
});
