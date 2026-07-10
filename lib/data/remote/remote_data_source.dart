import 'dart:math';

import '../../domain/triage_record.dart';

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

abstract class RemoteDataSource {
  /// Simulates `POST /api/v1/triage`. Idempotent by [TriageRecord.id].
  Future<void> create(TriageRecord record);
}

/// Mock server per the brief: artificial latency + a random-failure toggle to
/// prove the retry/backoff path. Every knob is injectable so tests are
/// deterministic (latency: Duration.zero, forceFailure: true/false) while the
/// running app uses realistic randomness.
class MockRemoteDataSource implements RemoteDataSource {
  final Duration latency;
  final double failureRate; // 0.0..1.0
  final Random _rng;

  /// When true, every call fails regardless of [failureRate]. Wired to a UI
  /// switch so the demo can force offline-style rejections on demand.
  bool forceFailure;

  MockRemoteDataSource({
    this.latency = const Duration(seconds: 2),
    this.failureRate = 0.3,
    this.forceFailure = false,
    Random? rng,
  }) : _rng = rng ?? Random();

  @override
  Future<void> create(TriageRecord record) async {
    await Future.delayed(latency);
    if (forceFailure || _rng.nextDouble() < failureRate) {
      throw NetworkException('Simulated upload failure for ${record.id}');
    }
    // Success: a real server would upsert by record.id (idempotency key),
    // so a duplicate delivery after a lost ack is a no-op.
  }
}
