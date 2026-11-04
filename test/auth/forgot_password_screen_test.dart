import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../workspace/fake_auth.dart';
import 'pump_recovery_screen.dart';
import 'recovery_support.dart';

/// Answers "asking for the email" as told, and shows the reason in the state the way the real notifier does when it fails.
class _FakeNotifier extends FakeAuthNotifier {
  _FakeNotifier() : super(const SupabaseAuthState());
  bool succeeds = true;
  final requested = <String>[];

  @override
  void clearError() => state = const SupabaseAuthState();

  @override
  Future<bool> resetPassword(String email) async {
    requested.add(email);
    if (!succeeds) {
      state = const SupabaseAuthState(error: 'Email rate limit exceeded');
    }
    return succeeds;
  }
}

void main() {
  late _FakeNotifier notifier;

  setUp(() => notifier = _FakeNotifier());

  Future<void> open(WidgetTester tester) => pumpRecoveryScreen(tester, const ForgotPasswordScreen(), harness: RecoveryHarness(), overrides: [fakeAuth(notifier)]);

  Future<void> sendFor(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('asks for the email', (tester) async {
    await open(tester);
    expect(find.text('Send Reset Link'), findsOneWidget);
    expect(find.byKey(const Key('forgot-sent-title')), findsNothing);
  });

  testWidgets('an address that is not an email is refused and nothing is requested', (tester) async {
    await open(tester);
    await sendFor(tester, 'not-an-email');
    expect(find.text('Please enter a valid email'), findsOneWidget);
    expect(notifier.requested, isEmpty);
  });

  testWidgets('addresses with a + or a long ending are accepted: they are real addresses', (tester) async {
    for (final email in ['sam+work@example.com', 'sam@club.london', 'first.last@sub.example.co.uk']) {
      notifier.requested.clear();
      await open(tester);
      await sendFor(tester, email);
      expect(notifier.requested, [email], reason: email);
    }
  });

  testWidgets('things that are clearly not addresses are still refused', (tester) async {
    for (final email in ['sam', 'sam@', '@example.com', 'sam@example', 'sam @example.com', 'sam@exa mple.com']) {
      notifier.requested.clear();
      await open(tester);
      await sendFor(tester, email);
      expect(notifier.requested, isEmpty, reason: email);
    }
  });

  testWidgets('after the email is sent it names the address and offers the 6-digit code', (tester) async {
    await open(tester);
    await sendFor(tester, 'sam@example.com');
    expect(notifier.requested, ['sam@example.com']);
    expect(find.byKey(const Key('forgot-sent-title')), findsOneWidget);
    expect(find.textContaining('sam@example.com'), findsOneWidget);
    expect(find.textContaining('a 6-digit code'), findsOneWidget);
    expect(find.byKey(const Key('forgot-enter-code')), findsOneWidget);
  });

  testWidgets('a refused request does NOT say "Email Sent!": the person would wait for an email that never comes', (tester) async {
    notifier.succeeds = false;
    await open(tester);
    await sendFor(tester, 'sam@example.com');
    expect(notifier.requested, ['sam@example.com']);
    expect(find.byKey(const Key('forgot-sent-title')), findsNothing);
    expect(find.text('Send Reset Link'), findsOneWidget, reason: 'still on the form, to try again');
    expect(find.textContaining('Email rate limit exceeded'), findsOneWidget, reason: 'the reason is shown');
  });

  testWidgets('the code button opens the code page, carrying the address', (tester) async {
    await open(tester);
    await sendFor(tester, 'sam+test@example.com');
    await tester.ensureVisible(find.byKey(const Key('forgot-enter-code')));
    await tester.tap(find.byKey(const Key('forgot-enter-code')));
    await tester.pumpAndSettle();
    expect(find.text('CODE PAGE sam+test@example.com'), findsOneWidget);
  });
}
