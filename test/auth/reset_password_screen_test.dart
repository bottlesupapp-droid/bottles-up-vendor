import 'package:bottles_up_vendor/features/auth/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException, AuthRetryableFetchException;

import 'pump_recovery_screen.dart';
import 'recovery_support.dart';

const hash = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c';

void main() {
  late RecoveryHarness h;

  // By default a reset session is already open, the way the code screen leaves it.
  setUp(() => h = RecoveryHarness(session: true));

  Future<void> open(WidgetTester tester, {String? tokenHash, bool expired = false}) =>
      pumpRecoveryScreen(tester, ResetPasswordScreen(tokenHash: tokenHash, expired: expired), harness: h);

  Future<void> fill(WidgetTester tester, {String password = 'new-password-1', String? confirm}) async {
    await tester.enterText(find.byKey(const Key('reset-new-password')), password);
    await tester.enterText(find.byKey(const Key('reset-confirm-password')), confirm ?? password);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('reset-submit')));
    await tester.tap(find.byKey(const Key('reset-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('arriving from the code screen', () {
    testWidgets('with a reset session it shows the two password boxes', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('reset-new-password')), findsOneWidget);
      expect(find.byKey(const Key('reset-confirm-password')), findsOneWidget);
      expect(find.text('This reset has expired'), findsNothing);
    });

    testWidgets('without one it says the reset has expired, instead of a form that can only fail', (tester) async {
      h.auth.session = false;
      await open(tester);
      expect(find.text('This reset has expired'), findsOneWidget);
      expect(find.byKey(const Key('reset-new-password')), findsNothing);
    });
  });

  group('arriving from the link in the email', () {
    testWidgets('spends the token first, then shows the form', (tester) async {
      h.auth.session = false;
      await open(tester, tokenHash: hash);
      expect(find.byKey(const Key('reset-checking')), findsOneWidget, reason: 'while the token is being spent');
      await tester.pump(const Duration(milliseconds: 50));
      expect(h.auth.calls, ['token:$hash']);
      expect(find.byKey(const Key('reset-new-password')), findsOneWidget);
    });

    testWidgets('a token that was already used shows the expired page and no form', (tester) async {
      h.auth.session = false;
      h.auth.tokenError = AuthApiException('used', statusCode: '403', code: 'otp_expired');
      await open(tester, tokenHash: hash);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('This reset has expired'), findsOneWidget);
      expect(find.byKey(const Key('reset-new-password')), findsNothing);
      expect(find.textContaining('work once'), findsOneWidget);
    });

    testWidgets('no connection says so, and does not claim the link expired', (tester) async {
      h.auth.session = false;
      h.auth.tokenError = AuthRetryableFetchException(message: 'offline');
      await open(tester, tokenHash: hash);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('reset-dead-reason')), findsOneWidget);
      expect(find.textContaining('could not reach'), findsOneWidget);
    });

    testWidgets('a link already marked expired is not sent to the server at all', (tester) async {
      await open(tester, expired: true);
      expect(find.text('This reset has expired'), findsOneWidget);
      expect(h.auth.calls, isEmpty);
    });
  });

  group('the expired page', () {
    testWidgets('offers a new email, and the way back to sign-in', (tester) async {
      h.auth.session = false;
      await open(tester);
      await tester.tap(find.byKey(const Key('reset-expired-new')));
      await tester.pumpAndSettle();
      expect(find.text('FORGOT PAGE'), findsOneWidget);
    });

    testWidgets('Back to Login goes to the sign-in', (tester) async {
      h.auth.session = false;
      await open(tester);
      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN PAGE'), findsOneWidget);
    });
  });

  group('choosing the password', () {
    testWidgets('7 characters are refused, and nothing is sent', (tester) async {
      await open(tester);
      await fill(tester, password: 'abcdefg');
      await submit(tester);
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(h.auth.calls, isEmpty);
    });

    testWidgets('two different passwords are refused, and nothing is sent', (tester) async {
      await open(tester);
      await fill(tester, password: 'new-password-1', confirm: 'new-password-2');
      await submit(tester);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(h.auth.calls, isEmpty);
    });

    testWidgets('a good password is set, the reset session is ended, the app is told, and the person is sent to sign in', (tester) async {
      await open(tester);
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(h.auth.calls, ['set:new-password-1', 'signOut']);
      expect(h.events, ['end']);
      expect(find.text('LOGIN PAGE'), findsOneWidget);
      expect(find.text('Password updated. Sign in with your new password.'), findsOneWidget);
    });

    testWidgets('the same password as before is explained, keeps the reset open, and signs nobody out', (tester) async {
      h.auth.setPasswordError = AuthApiException('same', statusCode: '422', code: 'same_password');
      await open(tester);
      await fill(tester, password: 'old-password-1');
      await submit(tester);
      expect(find.text('Your new password must be different from your old one.'), findsOneWidget);
      expect(h.auth.calls, ['set:old-password-1']);
      expect(h.auth.session, isTrue);
      expect(h.events, isEmpty);
      expect(find.byKey(const Key('reset-new-password')), findsOneWidget, reason: 'the form is still there to try another password');
    });

    testWidgets('a weak password is explained', (tester) async {
      h.auth.setPasswordError = AuthApiException('weak', statusCode: '422', code: 'weak_password');
      await open(tester);
      await fill(tester, password: 'password');
      await submit(tester);
      expect(find.textContaining('too easy to guess'), findsOneWidget);
    });

    testWidgets('each password box can be shown and hidden', (tester) async {
      await open(tester);
      bool hidden(String key) => tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).obscureText;
      Finder eye(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(IconButton));

      expect(hidden('reset-new-password'), isTrue);
      expect(hidden('reset-confirm-password'), isTrue);
      await tester.tap(eye('reset-new-password'));
      await tester.pump();
      expect(hidden('reset-new-password'), isFalse);
      expect(hidden('reset-confirm-password'), isTrue, reason: 'the other box is not affected');
      await tester.tap(eye('reset-confirm-password'));
      await tester.pump();
      expect(hidden('reset-confirm-password'), isFalse);
    });

    testWidgets('Back to Login gives up the reset: the session is ended and the app is told', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.byKey(const Key('reset-back')));
      await tester.tap(find.byKey(const Key('reset-back')));
      await tester.pumpAndSettle();
      expect(h.auth.calls, ['signOut']);
      expect(h.events, ['end']);
      expect(find.text('LOGIN PAGE'), findsOneWidget);
    });
  });
}
