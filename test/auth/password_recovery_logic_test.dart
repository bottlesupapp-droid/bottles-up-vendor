import 'package:bottles_up_vendor/features/auth/logic/password_recovery_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException, AuthException, AuthRetryableFetchException;

const hash = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c';

void main() {
  group('the code from the email', () {
    test('keeps only the digits, so a pasted "483 920" or "483-920" works', () {
      expect(normaliseRecoveryCode('483920'), '483920');
      expect(normaliseRecoveryCode('483 920'), '483920');
      expect(normaliseRecoveryCode('483-920'), '483920');
      expect(normaliseRecoveryCode(' 4a8b3 '), '483');
    });

    test('is valid at exactly 6 digits', () {
      expect(validateRecoveryCode('483920'), isNull);
      expect(validateRecoveryCode('483 920'), isNull);
      expect(validateRecoveryCode('48392'), 'The code has 6 digits');
      expect(validateRecoveryCode('4839201'), 'The code has 6 digits');
    });

    test('says what to do when nothing was typed', () {
      expect(validateRecoveryCode(''), 'Enter the 6-digit code from your email');
      expect(validateRecoveryCode(null), 'Enter the 6-digit code from your email');
    });

    test('is 6 digits, and a new email can be asked for after a minute', () {
      expect(recoveryCodeLength, 6);
      expect(recoveryResendCooldown, const Duration(seconds: 60));
    });
  });

  group('the new password', () {
    test('needs 8 characters: 7 is refused, 8 is accepted', () {
      expect(validateNewPassword('abcdefg'), 'Use at least 8 characters');
      expect(validateNewPassword('abcdefgh'), isNull);
    });

    test('is required', () {
      expect(validateNewPassword(''), 'Password is required');
      expect(validateNewPassword(null), 'Password is required');
    });

    test('is limited to 72 bytes, counted in bytes and not characters', () {
      expect(validateNewPassword('a' * 72), isNull);
      expect(validateNewPassword('a' * 73), contains('too long'));
      expect(validateNewPassword('é' * 37), contains('too long'));
      expect(validateNewPassword('é' * 36), isNull);
    });

    test('the confirmation must be there and must match', () {
      expect(validateConfirmPassword('abcdefgh', 'abcdefgh'), isNull);
      expect(validateConfirmPassword('abcdefgH', 'abcdefgh'), 'Passwords do not match');
      expect(validateConfirmPassword('', 'abcdefgh'), 'Please confirm your password');
    });
  });

  group('tokens', () {
    test('a hex token of ours is valid; short, spaced, long or script-like ones are not', () {
      expect(isValidTokenHash(hash), isTrue);
      expect(isValidTokenHash('short'), isFalse);
      expect(isValidTokenHash('a b c d e f g h'), isFalse);
      expect(isValidTokenHash('a' * 300), isFalse);
      expect(isValidTokenHash('<script>alert(1)</script>'), isFalse);
      expect(isValidTokenHash(null), isFalse);
    });

    test('a token only counts together with type=recovery', () {
      expect(recoveryTokenFrom({'token_hash': hash, 'type': 'recovery'}), hash);
      expect(recoveryTokenFrom({'token_hash': hash, 'type': 'signup'}), isNull);
      expect(recoveryTokenFrom({'token_hash': hash}), isNull);
      expect(recoveryTokenFrom({'type': 'recovery'}), isNull);
      expect(recoveryTokenFrom({'token_hash': 'short', 'type': 'recovery'}), isNull);
    });

    test('the in-app address for a token reads back to the same token', () {
      final uri = Uri.parse(recoveryLocationForToken(hash));
      expect(uri.path, '/reset-password');
      expect(recoveryTokenFrom(uri.queryParameters), hash);
    });
  });

  group('what a link on the Business app\'s scheme means', () {
    String? where(String link) => recoveryLocationFor(Uri.parse(link));

    test('a link from the website\'s page opens the new-password screen with its token', () {
      expect(where('bottlesupbusiness://app/reset-password?token_hash=$hash&type=recovery'), '/reset-password?token_hash=$hash&type=recovery');
    });

    test('a link that was refused, or has nothing usable, opens the "expired" screen: the person is waiting for something to happen', () {
      expect(where('bottlesupbusiness://app/reset-password?error=access_denied'), '/reset-password?expired=1');
      expect(where('bottlesupbusiness://app/reset-password?error_code=otp_expired'), '/reset-password?expired=1');
      expect(where('bottlesupbusiness://app/reset-password'), '/reset-password?expired=1');
      expect(where('bottlesupbusiness://app/reset-password?token_hash=short&type=recovery'), '/reset-password?expired=1');
      expect(where('bottlesupbusiness://app/reset-password?token_hash=$hash&type=signup'), '/reset-password?expired=1');
    });

    test('an error wins over a token in the same link', () {
      expect(where('bottlesupbusiness://app/reset-password?token_hash=$hash&type=recovery&error=access_denied'), '/reset-password?expired=1');
    });

    test('anything else is left alone: other paths, other hosts, other schemes, web addresses', () {
      expect(where('bottlesupbusiness://app/login'), isNull);
      expect(where('bottlesupbusiness://other/reset-password?token_hash=$hash&type=recovery'), isNull);
      expect(where('bottlesup://app/reset-password?token_hash=$hash&type=recovery'), isNull);
      expect(where('https://www.bottlesupapp.com/reset-password?token_hash=$hash&type=recovery'), isNull);
      expect(where('https://www.bottlesupapp.com/accept-invite?token=abc'), isNull);
    });
  });

  group('logging a link', () {
    test('hides every secret in it, and nothing else', () {
      expect(redactLink('bottlesupbusiness://app/reset-password?token_hash=$hash&type=recovery'), 'bottlesupbusiness://app/reset-password?token_hash=...&type=recovery');
      expect(redactLink('x://y#access_token=abc.def&refresh_token=xyz&type=recovery'), 'x://y#access_token=...&refresh_token=...&type=recovery');
      expect(redactLink('bottlesupbusiness://app/login'), 'bottlesupbusiness://app/login');
      expect(redactLink('x://y?mytoken=1&tokens=2'), 'x://y?mytoken=1&tokens=2');
    });
  });

  group('what went wrong, in words', () {
    PasswordRecoveryException of(Object e, {bool duringCode = false}) => recoveryExceptionFor(e, duringCode: duringCode);

    test('every problem has a sentence', () {
      for (final problem in RecoveryProblem.values) {
        expect(recoveryProblemMessage(problem), isNotEmpty);
      }
    });

    test('losing the connection is a connection problem, never "expired"', () {
      expect(of(AuthRetryableFetchException(message: 'x')).problem, RecoveryProblem.network);
      expect(of(Exception('SocketException: Failed host lookup')).problem, RecoveryProblem.network);
    });

    test('a wrong or expired code, while checking one', () {
      expect(of(AuthApiException('bad', statusCode: '403', code: 'otp_expired'), duringCode: true).problem, RecoveryProblem.codeWrong);
      expect(of(const AuthException('bad', statusCode: '400'), duringCode: true).problem, RecoveryProblem.codeWrong);
      expect(of(const AuthException('bad', statusCode: '422'), duringCode: true).problem, RecoveryProblem.codeWrong);
    });

    test('an expired reset, when not checking a code, is an expired link', () {
      expect(of(AuthApiException('gone', statusCode: '401', code: 'session_expired')).problem, RecoveryProblem.linkExpired);
      expect(of(AuthApiException('gone', code: 'session_not_found')).problem, RecoveryProblem.linkExpired);
    });

    test('the same password, a weak password, and asking too often', () {
      expect(of(AuthApiException('x', statusCode: '422', code: 'same_password')).problem, RecoveryProblem.sameAsOld);
      expect(of(AuthApiException('x', statusCode: '422', code: 'weak_password')).problem, RecoveryProblem.tooWeak);
      expect(of(AuthApiException('x', statusCode: '429', code: 'over_email_send_rate_limit')).problem, RecoveryProblem.tooManyRequests);
    });

    test('anything else is "something went wrong", and a 400 outside a code check is not "wrong code"', () {
      expect(of(Exception('boom')).problem, RecoveryProblem.other);
      expect(of(const AuthException('bad', statusCode: '400')).problem, RecoveryProblem.other);
    });

    test('an exception of ours passes through, and its message is its text', () {
      const original = PasswordRecoveryException(RecoveryProblem.tooWeak, 'x');
      expect(identical(of(original), original), isTrue);
      expect(of(AuthApiException('x', code: 'same_password')).toString(), recoveryProblemMessage(RecoveryProblem.sameAsOld));
    });
  });
}
