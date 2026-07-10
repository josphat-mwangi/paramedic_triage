/// Core domain entity for a single triage submission.
///
/// Note the two independent status fields — conflating them is the most common
/// modelling mistake here:
///   * [status]     -> the PATIENT's triage status, set by the paramedic (their enum).
///   * [syncStatus] -> the RECORD's delivery lifecycle, owned by the sync engine.
library;

/// The paramedic-facing triage status (part of the intake form).
enum TriageStatus { pending, inTransit }

extension TriageStatusX on TriageStatus {
  String get label => switch (this) {
        TriageStatus.pending => 'Pending',
        TriageStatus.inTransit => 'In-Transit',
      };

  String get wire => name; // 'pending' | 'inTransit'

  static TriageStatus fromWire(String v) =>
      TriageStatus.values.firstWhere((e) => e.name == v,
          orElse: () => TriageStatus.pending);
}

/// The record's delivery lifecycle, owned entirely by the sync engine.
enum SyncStatus { pending, syncing, synced, failed }

extension SyncStatusX on SyncStatus {
  String get wire => name;

  static SyncStatus fromWire(String v) =>
      SyncStatus.values.firstWhere((e) => e.name == v,
          orElse: () => SyncStatus.pending);
}

class TriageRecord {
  /// Client-generated UUID. Doubles as the server idempotency key so that a
  /// retry after a lost ack does not create a duplicate patient record.
  final String id;
  final String patientName;
  final String conditionDescription;

  /// 1..5, where 1 is absolute critical / life-threatening.
  final int priority;

  final TriageStatus status;
  final SyncStatus syncStatus;
  final int createdAt; // epoch millis
  final int retryCount;
  final String? lastError;

  const TriageRecord({
    required this.id,
    required this.patientName,
    required this.conditionDescription,
    required this.priority,
    required this.status,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  bool get isCritical => priority <= 2;

  TriageRecord copyWith({
    SyncStatus? syncStatus,
    int? retryCount,
    String? lastError,
    bool clearError = false,
  }) {
    return TriageRecord(
      id: id,
      patientName: patientName,
      conditionDescription: conditionDescription,
      priority: priority,
      status: status,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientName': patientName,
        'conditionDescription': conditionDescription,
        'priority': priority,
        'status': status.wire,
        'syncStatus': syncStatus.wire,
        'createdAt': createdAt,
        'retryCount': retryCount,
        'lastError': lastError,
      };

  factory TriageRecord.fromJson(Map<String, dynamic> j) => TriageRecord(
        id: j['id'] as String,
        patientName: j['patientName'] as String,
        conditionDescription: j['conditionDescription'] as String,
        priority: j['priority'] as int,
        status: TriageStatusX.fromWire(j['status'] as String),
        syncStatus: SyncStatusX.fromWire(j['syncStatus'] as String),
        createdAt: j['createdAt'] as int,
        retryCount: j['retryCount'] as int? ?? 0,
        lastError: j['lastError'] as String?,
      );

  /// The payload actually sent to the server (drops local sync bookkeeping).
  Map<String, dynamic> toWirePayload() => {
        'id': id,
        'patientName': patientName,
        'conditionDescription': conditionDescription,
        'priority': priority,
        'status': status.wire,
        'createdAt': createdAt,
      };
}
