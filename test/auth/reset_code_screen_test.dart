import 'package:bottles_up_vendor/features/auth/screens/reset_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException, AuthRetryableFetchException;

import 'pump_recovery_screen.dart';
import 'recovery_support.dart';

void main() {
  late RecoveryHarness h;

  setUp(() => h = RecoveryHarness());

  Future<void> open(WidgetTester tester, {String email = 'sam@example.com'}) => pumpRecoveryScreen(tester, ResetCodeScreen(email: email), harness: h);

  Future<void> typeCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byKey(const Key('reset-code-field')), code);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('reset-code-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows where the code was sent', (tester) async {
    await open(tester);
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(find.text('sam@example.com'), findsOneWidget);
  });

  testWidgets('with nothing typed it asks for the code and checks nothing', (tester) async {
    await open(tester);
    await submit(tester);
    expect(find.text('Enter the 6-digit code from your email'), findsOneWidget);
    expect(h.auth.calls, isEmpty);
  });

  testWidgets('5 digits are refused before asking the server', (tester) async {
    await open(tester);
    await typeCode(tester, '48392');
    await submit(tester);
    expect(find.text('The code has 6 digits'), findsOneWidget);
    expect(h.auth.calls, isEmpty);
  });

  testWidgets('letters are not accepted into the box', (tester) async {
    await open(tester);
    await typeCode(tester, 'ab12cd');
    expect(tester.widget<TextField>(find.descendant(of: find.byKey(const Key('reset-code-field')), matching: find.byType(TextField))).controller!.text, '12');
  });

  testWidgets('a good code is checked with the digits only, then the new-password page opens', (tester) async {
    await open(tester);
    await typeCode(tester, '483 920');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(h.auth.calls, ['code:sam@example.com:483920']);
    expect(find.text('NEW PASSWORD PAGE'), findsOneWidget);
    expect(h.events, ['begin'], reason: 'the app is told to hold back its sign-in state, and the reset stays open for the next screen');
  });

  testWidgets('a wrong code says so, stays on the page, ends the reset, and can be tried again', (tester) async {
    h.auth.codeError = AuthApiException('Token has expired or is invalid', statusCode: '403', code: 'otp_expired');
    await open(tester);
    await typeCode(tester, '000000');
    await submit(tester);
    expect(find.byKey(const Key('reset-code-problem')), findsOneWidget);
    expect(find.textContaining('not right'), findsOneWidget);
    expect(find.text('NEW PASSWORD PAGE'), findsNothing);
    expect(h.events, ['begin', 'end']);

    h.auth.codeError = null;
    await typeCode(tester, '483920');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('NEW PASSWORD PAGE'), findsOneWidget);
  });

  testWidgets('no connection is not called a wrong code', (tester) async {
    h.auth.codeError = AuthRetryableFetchException(message: 'offline');
    await open(tester);
    await typeCode(tester, '483920');
    await submit(tester);
    expect(find.textContaining('could not reach'), findsOneWidget);
    expect(find.textContaining('not right'), findsNothing);
  });

  testWidgets('a new code cannot be asked for in the first minute, and the button says how long is left', (tester) async {
    await open(tester);
    expect(find.text('Send a new code in 60s'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('reset-code-resend'))).onPressed, isNull);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Send a new code in 30s'), findsOneWidget);
  });

  testWidgets('after a minute a new email can be sent; the box is cleared and the wait starts again', (tester) async {
    await open(tester);
    await typeCode(tester, '123456');
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Send a new code'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reset-code-resend')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(h.auth.calls, ['send:sam@example.com']);
    expect(find.byKey(const Key('reset-code-notice')), findsOneWidget);
    expect(find.text('Send a new code in 60s'), findsOneWidget);
    expect(tester.widget<TextField>(find.descendant(of: find.byKey(const Key('reset-code-field')), matching: find.byType(TextField))).controller!.text, isEmpty);
  });

  testWidgets('a refused new email is explained', (tester) async {
    h.auth.sendError = AuthApiException('slow down', statusCode: '429', code: 'over_email_send_rate_limit');
    await open(tester);
    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.byKey(const Key('reset-code-resend')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('wait a minute'), findsOneWidget);
    expect(find.text('Send a new code'), findsOneWidget);
  });

  testWidgets('opened without an address it sends the person back to Forgot password', (tester) async {
    await open(tester, email: '');
    expect(find.byKey(const Key('reset-code-field')), findsNothing);
    await tester.tap(find.byKey(const Key('reset-code-start-over')));
    await tester.pumpAndSettle();
    expect(find.text('FORGOT PAGE'), findsOneWidget);
  });

  testWidgets('Back to Login goes to the sign-in', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Back to Login'));
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });
}
