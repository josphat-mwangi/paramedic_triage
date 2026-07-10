import 'dart:math';

/// Pure exponential-backoff-with-jitter policy. Kept free of side effects and
/// wall-clock time so the delay math is directly unit-testable.
class BackoffPolicy {
  final Duration base;
  final Duration max;
  final int maxRetries;
  final Random _rng;

  BackoffPolicy({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
    this.maxRetries = 5,
    Random? rng,
  }) : _rng = rng ?? Random();

  /// The deterministic (jitter-free) backoff for a given attempt: base * 2^n,
  /// clamped to [max]. attempt 0 -> base, 1 -> 2×base, 2 -> 4×base ...
  Duration baseDelayFor(int attempt) {
    final ms = base.inMilliseconds * pow(2, attempt).toInt();
    return Duration(milliseconds: min(ms, max.inMilliseconds));
  }

  /// Full-jitter delay: a random point in [0, baseDelayFor(attempt)], which
  /// avoids the thundering-herd problem when many clients reconnect at once.
  Duration jitteredDelayFor(int attempt) {
    final ceiling = baseDelayFor(attempt).inMilliseconds;
    return Duration(milliseconds: _rng.nextInt(ceiling + 1));
  }

  bool hasAttemptsLeft(int retryCount) => retryCount < maxRetries;
}
