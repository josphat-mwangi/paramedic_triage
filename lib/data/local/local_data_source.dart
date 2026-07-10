import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/triage_record.dart';

/// Dumb persistence contract — no business logic lives here. Keeping it minimal
/// makes it trivial to swap Hive for SQLite/Drift and to fake in unit tests.
abstract class LocalDataSource {
  Future<void> upsert(TriageRecord record);
  Future<TriageRecord?> getById(String id);
  Future<List<TriageRecord>> getAll();
}

/// Hive-backed outbox. Each record is stored as a JSON string keyed by its
/// UUID, which avoids TypeAdapter code-gen and keeps setup friction near zero.
/// For a high-volume production outbox you'd move to SQLite/Drift for indexed
/// `WHERE syncStatus = 'pending'` queries — see README "Production next steps".
class HiveLocalDataSource implements LocalDataSource {
  final Box<String> _box;

  HiveLocalDataSource(this._box);

  static const boxName = 'triage_outbox';

  @override
  Future<void> upsert(TriageRecord record) async {
    await _box.put(record.id, jsonEncode(record.toJson()));
  }

  @override
  Future<TriageRecord?> getById(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    return TriageRecord.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<List<TriageRecord>> getAll() async {
    final records = _box.values
        .map((raw) =>
            TriageRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList();
    // Newest first for the UI.
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }
}
