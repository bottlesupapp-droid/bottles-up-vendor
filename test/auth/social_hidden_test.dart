import 'package:bottles_up_vendor/core/config/google_sign_in_config.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/login_screen.dart';
import 'package:bottles_up_vendor/features/auth/screens/otp_verification_screen.dart';
import 'package:bottles_up_vendor/features/auth/screens/register_screen.dart';
import 'package:bottles_up_vendor/features/auth/widgets/social_sign_in_buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../workspace/fake_auth.dart';

// The client asked for no "Continue with Google / Apple" anywhere in the vendor app (2 Nov 2026). These keep every page free of them while the one switch is off, and keep the switch off.
Future<void> _show(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/page', routes: [
    GoRoute(path: '/page', builder: (_, __) => page),
    GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login page'))),
    GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('dashboard page'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [fakeAuth(FakeAuthNotifier(const SupabaseAuthState()))],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Future<void> _as(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void _expectNoSocial() {
  expect(find.byKey(const Key('social-google')), findsNothing);
  expect(find.byKey(const Key('social-apple')), findsNothing);
  expect(find.byKey(const Key('register-social-title')), findsNothing);
  expect(find.textContaining('Continue with'), findsNothing);
  expect(find.textContaining('Google'), findsNothing);
  expect(find.textContaining('Apple'), findsNothing);
  expect(find.text('or'), findsNothing);
  expect(find.text('or continue with'), findsNothing);
}

void main() {
  test('the switch is off, so nobody turns the buttons back on by accident', () {
    expect(SocialSignInConfig.offered, isFalse);
  });

  test('with the switch off no phone is offered either sign-in', () {
    for (final platform in TargetPlatform.values) {
      expect(socialProvidersFor(platform), isEmpty, reason: '$platform');
    }
  });

  test('turning the switch on brings them back (the code is kept, only hidden)', () {
    SocialSignInConfig.offered = true;
    addTearDown(() => SocialSignInConfig.offered = false);
    expect(socialProvidersFor(TargetPlatform.android), isNotEmpty);
    expect(socialProvidersFor(TargetPlatform.iOS), isNotEmpty);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('on $platform', () {
      testWidgets('the sign-in page has the e-mail and phone forms and no Google or Apple', (tester) => _as(platform, () async {
            await _show(tester, const LoginScreen());
            expect(find.byType(TabBar), findsOneWidget);
            expect(find.text("Don't have an account? "), findsOneWidget);
            _expectNoSocial();
          }));

      testWidgets('the create-account page has no social heading and no buttons, and still lets a person sign in instead', (tester) => _as(platform, () async {
            await _show(tester, const RegisterScreen());
            expect(find.byKey(const Key('back-to-sign-in')), findsOneWidget);
            _expectNoSocial();
          }));

      testWidgets('the phone-code page no longer has the two Google and Apple buttons that did nothing', (tester) => _as(platform, () async {
            await _show(tester, const OtpVerificationScreen(phoneNumber: '+14165550100'));
            expect(find.byType(OutlinedButton), findsNothing);
            _expectNoSocial();
          }));
    });
  }
}
