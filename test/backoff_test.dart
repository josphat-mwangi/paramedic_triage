import 'package:flutter_test/flutter_test.dart';
import 'package:paramedic_triage/sync/backoff.dart';

void main() {
  group('BackoffPolicy', () {
    final policy = BackoffPolicy(
      base: const Duration(seconds: 1),
      max: const Duration(seconds: 30),
      maxRetries: 5,
    );

    test('base delay grows exponentially', () {
      expect(policy.baseDelayFor(0), const Duration(seconds: 1));
      expect(policy.baseDelayFor(1), const Duration(seconds: 2));
      expect(policy.baseDelayFor(2), const Duration(seconds: 4));
      expect(policy.baseDelayFor(3), const Duration(seconds: 8));
    });

    test('base delay is capped at max', () {
      expect(policy.baseDelayFor(10), const Duration(seconds: 30));
    });

    test('jittered delay never exceeds the exponential ceiling', () {
      for (var attempt = 0; attempt < 6; attempt++) {
        final jittered = policy.jitteredDelayFor(attempt);
        expect(jittered <= policy.baseDelayFor(attempt), isTrue);
        expect(jittered >= Duration.zero, isTrue);
      }
    });

    test('respects the retry cap', () {
      expect(policy.hasAttemptsLeft(4), isTrue);
      expect(policy.hasAttemptsLeft(5), isFalse);
    });
  });
}
