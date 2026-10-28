import 'package:bottles_up_vendor/core/config/google_sign_in_config.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/login_screen.dart';
import 'package:bottles_up_vendor/features/auth/services/social_sign_in_service.dart';
import 'package:bottles_up_vendor/features/auth/widgets/social_sign_in_buttons.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart' show pendingInviteToken;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../workspace/fake_auth.dart';

class _Recording extends FakeAuthNotifier {
  _Recording() : super(const SupabaseAuthState());

  final calls = <(SocialProvider, bool)>[];

  @override
  Future<void> signInWithSocial(SocialProvider provider, {bool allowNewAccount = false}) async => calls.add((provider, allowNewAccount));
}

Future<_Recording> _openLogin(WidgetTester tester, {SupabaseAuthState? state}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final notifier = _Recording();
  if (state != null) notifier.state = state;
  await tester.pumpWidget(ProviderScope(overrides: [fakeAuth(notifier)], child: const MaterialApp(home: LoginScreen())));
  await tester.pump();
  return notifier;
}

/// Runs [body] as [platform] and puts the real platform back before the test ends (Flutter checks that at the end of the test body, before any tear-down).
Future<void> _as(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  tearDown(() => pendingInviteToken.value = null);

  group('which sign-ins a phone can offer', () {
    test('Android: Google, never Apple', () {
      expect(socialProvidersFor(TargetPlatform.android), [SocialProvider.google]);
    });

    test('iPhone: Apple always, Google once its iOS client id is set in GoogleSignInConfig', () {
      final providers = socialProvidersFor(TargetPlatform.iOS);
      expect(providers.contains(SocialProvider.apple), isTrue);
      expect(providers.contains(SocialProvider.google), GoogleSignInConfig.iosClientId.isNotEmpty);
    });

    test('anything else: nothing', () {
      expect(socialProvidersFor(TargetPlatform.macOS), isEmpty);
      expect(socialProvidersFor(TargetPlatform.windows), isEmpty);
    });

    test('Google is set up on Android with the web client id', () {
      expect(GoogleSignInConfig.isConfiguredFor(TargetPlatform.android), GoogleSignInConfig.webClientId.isNotEmpty);
      expect(GoogleSignInConfig.webClientId, endsWith('.apps.googleusercontent.com'));
    });
  });

  group('the buttons', () {
    Future<void> show(WidgetTester tester, {bool enabled = true, List<SocialProvider>? pressed}) => tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SocialSignInButtons(enabled: enabled, onPressed: (p) => pressed?.add(p))),
        ));

    testWidgets('on Android Google shows under an "or" and runs the Google sign-in', (tester) async {
      final pressed = <SocialProvider>[];
      await show(tester, pressed: pressed);
      expect(find.text('or'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byKey(const Key('social-apple')), findsNothing);
      await tester.tap(find.byKey(const Key('social-google')));
      expect(pressed, [SocialProvider.google]);
    });

    testWidgets('on iPhone Apple shows (Apple\'s own button) and runs the Apple sign-in', (tester) => _as(TargetPlatform.iOS, () async {
          final pressed = <SocialProvider>[];
          await show(tester, pressed: pressed);
          expect(find.text('Continue with Apple'), findsOneWidget);
          expect(find.byKey(const Key('social-google')), GoogleSignInConfig.iosClientId.isEmpty ? findsNothing : findsOneWidget);
          await tester.tap(find.byKey(const Key('social-apple')));
          expect(pressed, [SocialProvider.apple]);
        }));

    testWidgets('while a sign-in runs nothing can be pressed', (tester) => _as(TargetPlatform.iOS, () async {
          final pressed = <SocialProvider>[];
          await show(tester, enabled: false, pressed: pressed);
          await tester.tap(find.byKey(const Key('social-apple')), warnIfMissed: false);
          expect(pressed, isEmpty);
        }));

    testWidgets('on a platform with neither, nothing is drawn, not even the "or"', (tester) => _as(TargetPlatform.windows, () async {
          await show(tester);
          expect(find.text('or'), findsNothing);
          expect(find.byType(OutlinedButton), findsNothing);
        }));
  });

  group('on the login screen', () {
    testWidgets('Google is offered and signs in to an existing account only', (tester) async {
      final notifier = await _openLogin(tester);
      await tester.ensureVisible(find.byKey(const Key('social-google')));
      await tester.tap(find.byKey(const Key('social-google')));
      expect(notifier.calls, [(SocialProvider.google, false)]);
    });

    testWidgets('a person who came by an invitation link may make the account on their first sign-in', (tester) async {
      pendingInviteToken.value = 'invite-token';
      final notifier = await _openLogin(tester);
      await tester.ensureVisible(find.byKey(const Key('social-google')));
      await tester.tap(find.byKey(const Key('social-google')));
      expect(notifier.calls, [(SocialProvider.google, true)]);
    });

    testWidgets('while a sign-in runs the buttons are off', (tester) async {
      final notifier = await _openLogin(tester, state: const SupabaseAuthState(isLoading: true));
      await tester.ensureVisible(find.byKey(const Key('social-google')));
      await tester.tap(find.byKey(const Key('social-google')), warnIfMissed: false);
      expect(notifier.calls, isEmpty);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('social-google'))).onPressed, isNull);
    });

    testWidgets('the e-mail and phone sign-in are still there', (tester) async {
      await _openLogin(tester);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
    });
  });
}
