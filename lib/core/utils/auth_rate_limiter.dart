/// In-memory rate limiter for login / signup attempts.
/// Locks out an email address after [maxAttempts] failures within a session.
///
/// Usage:
///   if (AuthRateLimiter.isLocked(email)) return;
///   try {
///     await signIn(...);
///     AuthRateLimiter.reset(email);
///   } catch (_) {
///     AuthRateLimiter.recordFailure(email);
///   }
class AuthRateLimiter {
  AuthRateLimiter._();

  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);

  static final Map<String, _AttemptRecord> _records = {};

  static bool isLocked(String key) {
    final r = _records[key];
    if (r == null || r.attempts < maxAttempts) return false;
    if (DateTime.now().isBefore(r.lockedUntil!)) return true;
    // Lockout expired — clear it
    _records.remove(key);
    return false;
  }

  static Duration? lockoutRemaining(String key) {
    if (!isLocked(key)) return null;
    final remaining = _records[key]!.lockedUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  static void recordFailure(String key) {
    final existing = _records[key];
    final attempts = (existing?.attempts ?? 0) + 1;
    _records[key] = _AttemptRecord(
      attempts: attempts,
      lockedUntil: attempts >= maxAttempts
          ? DateTime.now().add(lockoutDuration)
          : existing?.lockedUntil,
    );
  }

  static int attemptsRemaining(String key) {
    final attempts = _records[key]?.attempts ?? 0;
    final remaining = maxAttempts - attempts;
    return remaining < 0 ? 0 : remaining;
  }

  static void reset(String key) => _records.remove(key);
}

class _AttemptRecord {
  final int attempts;
  final DateTime? lockedUntil;

  const _AttemptRecord({required this.attempts, this.lockedUntil});
}
