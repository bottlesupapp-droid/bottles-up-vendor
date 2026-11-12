import 'package:bottles_up_vendor/features/auth/logic/password_recovery_logic.dart';
import 'package:bottles_up_vendor/features/auth/services/password_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException, AuthRetryableFetchException;

import 'recovery_support.dart';

void main() {
  late RecoveryHarness h;

  setUp(() => h = RecoveryHarness());

  Future<PasswordRecoveryException> failure(Future<void> Function() run) async {
    try {
      await run();
    } on PasswordRecoveryException catch (e) {
      return e;
    }
    fail('expected a PasswordRecoveryException');
  }

  group('asking for the email', () {
    test('trims the address, and does not touch the app\'s sign-in state', () async {
      await h.service.sendEmail('  sam@example.com ');
      expect(h.auth.calls, ['send:sam@example.com']);
      expect(h.events, isEmpty);
    });

    test('a rate limit says to wait; no connection says so', () async {
      h.auth.sendError = AuthApiException('slow', statusCode: '429', code: 'over_email_send_rate_limit');
      expect((await failure(() => h.service.sendEmail('a@b.co'))).problem, RecoveryProblem.tooManyRequests);
      h.auth.sendError = AuthRetryableFetchException(message: 'offline');
      expect((await failure(() => h.service.sendEmail('a@b.co'))).problem, RecoveryProblem.network);
    });
  });

  group('checking the code', () {
    test('tells the app a reset has begun, sends the digits only, and leaves the reset open', () async {
      await h.service.verifyCode(email: ' sam@example.com ', code: '483 920');
      expect(h.auth.calls, ['code:sam@example.com:483920']);
      expect(h.events, ['begin']);
      expect(h.service.hasRecoverySession, isTrue);
    });

    test('a wrong code ends the reset again, so the app goes back to what it was', () async {
      h.auth.codeError = AuthApiException('bad', statusCode: '403', code: 'otp_expired');
      final e = await failure(() => h.service.verifyCode(email: 'sam@example.com', code: '000000'));
      expect(e.problem, RecoveryProblem.codeWrong);
      expect(h.events, ['begin', 'end']);
      expect(h.service.hasRecoverySession, isFalse);
    });

    test('a dropped connection is not called a wrong code', () async {
      h.auth.codeError = AuthRetryableFetchException(message: 'offline');
      expect((await failure(() => h.service.verifyCode(email: 'sam@example.com', code: '483920'))).problem, RecoveryProblem.network);
    });
  });

  group('a link that reached the app', () {
    test('spends the token, once', () async {
      await h.service.verifyLink('abc12345');
      expect(h.auth.calls, ['token:abc12345']);
      expect(h.events, ['begin']);
    });

    test('the same link arriving a second time later does not spend the token again', () async {
      await h.service.verifyLink('abc12345');
      await h.service.verifyLink('abc12345');
      expect(h.auth.calls, ['token:abc12345']);
    });

    test('the same link arriving twice at once is checked once, and both callers get the same answer', () async {
      final first = h.service.verifyLink('abc12345');
      final second = h.service.verifyLink('abc12345');
      await Future.wait([first, second]);
      expect(h.auth.calls, ['token:abc12345']);
    });

    test('a second, different link is its own check', () async {
      await h.service.verifyLink('abc12345');
      await h.service.verifyLink('xyz98765');
      expect(h.auth.calls, ['token:abc12345', 'token:xyz98765']);
    });

    test('a token that was used is refused, ends the reset, and is not remembered as spent', () async {
      h.auth.tokenError = AuthApiException('used', statusCode: '403', code: 'otp_expired');
      expect((await failure(() => h.service.verifyLink('abc12345'))).problem, RecoveryProblem.codeWrong);
      expect(h.events, ['begin', 'end']);
      // A later try with the same token is a real try, not skipped.
      h.auth.tokenError = null;
      await h.service.verifyLink('abc12345');
      expect(h.auth.calls, ['token:abc12345', 'token:abc12345']);
    });

    test('once the reset is finished the same token is not treated as already spent', () async {
      await h.service.verifyLink('abc12345');
      await h.service.finish();
      h.auth.tokenError = AuthApiException('used', statusCode: '403', code: 'otp_expired');
      await failure(() => h.service.verifyLink('abc12345'));
      expect(h.auth.calls.where((c) => c.startsWith('token:')).length, 2);
    });
  });

  group('the new password', () {
    test('needs a reset session, and without one asks nothing of the server', () async {
      final e = await failure(() => h.service.updatePassword('new-password-1'));
      expect(e.problem, RecoveryProblem.linkExpired);
      expect(h.auth.calls, isEmpty);
    });

    test('is set on the session the code opened', () async {
      await h.service.verifyCode(email: 'sam@example.com', code: '483920');
      await h.service.updatePassword('new-password-1');
      expect(h.auth.calls.last, 'set:new-password-1');
    });

    test('the same password and a weak one are told apart, and neither ends the reset', () async {
      h.auth.session = true;
      h.auth.setPasswordError = AuthApiException('x', statusCode: '422', code: 'same_password');
      expect((await failure(() => h.service.updatePassword('old-password'))).problem, RecoveryProblem.sameAsOld);
      h.auth.setPasswordError = AuthApiException('x', statusCode: '422', code: 'weak_password');
      expect((await failure(() => h.service.updatePassword('password'))).problem, RecoveryProblem.tooWeak);
      expect(h.service.hasRecoverySession, isTrue);
      expect(h.events, isEmpty);
    });
  });

  group('finishing and abandoning', () {
    test('finish signs out on this phone only, then tells the app the reset is over', () async {
      h.auth.session = true;
      await h.service.finish();
      expect(h.auth.calls, ['signOut']);
      expect(h.events, ['end']);
      expect(h.service.hasRecoverySession, isFalse);
    });

    test('abandon does the same', () async {
      await h.service.verifyCode(email: 'sam@example.com', code: '483920');
      await h.service.abandon();
      expect(h.auth.calls.last, 'signOut');
      expect(h.events, ['begin', 'end']);
    });

    test('neither throws, even when signing out fails, and the app is still told the reset is over', () async {
      h.auth.signOutError = Exception('storage unavailable');
      await h.service.finish();
      expect(h.events, ['end']);
    });

    test('nor when telling the app fails', () async {
      final auth = FakeRecoveryAuth(session: true);
      final service = PasswordRecoveryService(auth: auth, begin: () {}, end: () async => throw Exception('boom'));
      await service.finish();
      expect(auth.calls, ['signOut']);
    });
  });
}
