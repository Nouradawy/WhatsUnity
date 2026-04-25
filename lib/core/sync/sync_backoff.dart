/// Exponential-ish backoff in seconds: 2, 5, 15, 30, 60, then cap at 120.
int syncBackoffSecondsForAttempt(int zeroBasedAttemptIndex) {
  const steps = <int>[2, 5, 15, 30, 60, 120];
  if (zeroBasedAttemptIndex < 0) return steps.first;
  if (zeroBasedAttemptIndex >= steps.length) return steps.last;
  return steps[zeroBasedAttemptIndex];
}

Duration syncBackoffDurationForAttempt(int attemptCount) {
  final idx = attemptCount <= 0 ? 0 : attemptCount - 1;
  return Duration(seconds: syncBackoffSecondsForAttempt(idx));
}
