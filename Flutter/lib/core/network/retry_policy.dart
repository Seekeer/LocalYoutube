class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 2,
    this.baseDelayMs = 300,
  });

  final int maxRetries;
  final int baseDelayMs;

  Duration delayForAttempt(int attempt) {
    final int multiplier = 1 << attempt;
    return Duration(milliseconds: baseDelayMs * multiplier);
  }
}
