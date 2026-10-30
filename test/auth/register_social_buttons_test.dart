import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/register_screen.dart';
import 'package:bottles_up_vendor/features/auth/services/social_sign_in_service.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart' show pendingInviteToken;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../workspace/fake_auth.dart';

class _Recording extends FakeAuthNotifier {
  _Recording([super.state = const SupabaseAuthState()]);

  final calls = <(SocialProvider, bool)>[];
  int errorsCleared = 0;

  @override
  Future<void> signInWithSocial(SocialProvider provider, {bool allowNewAccount = false}) async => calls.add((provider, allowNewAccount));

  @override
  void clearError() => errorsCleared++;
}

Future<_Recording> _open(WidgetTester tester, {SupabaseAuthState? state}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final notifier = _Recording(state ?? const SupabaseAuthState());
  final router = GoRouter(initialLocation: '/register', routes: [
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login page'))),
    GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('dashboard page'))),
  ]);
  await tester.pumpWidget(ProviderScope(overrides: [fakeAuth(notifier)], child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  return notifier;
}

/// Runs [body] as [platform] and puts the real platform back before the test ends.
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

  group('the Create an account page', () {
    testWidgets('on Android it offers Google, under its own heading and without the "or" line', (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('register-social-title')), findsOneWidget);
      expect(find.byKey(const Key('social-google')), findsOneWidget);
      expect(find.byKey(const Key('social-apple')), findsNothing);
      expect(find.text('or'), findsNothing);
    });

    testWidgets('on iPhone it offers Apple', (tester) => _as(TargetPlatform.iOS, () async {
          final notifier = await _open(tester);
          expect(find.byKey(const Key('social-apple')), findsOneWidget);
          await tester.ensureVisible(find.byKey(const Key('social-apple')));
          await tester.tap(find.byKey(const Key('social-apple')));
          expect(notifier.calls, [(SocialProvider.apple, false)]);
        }));

    testWidgets('Google signs in to an existing account only', (tester) async {
      final notifier = await _open(tester);
      await tester.ensureVisible(find.byKey(const Key('social-google')));
      await tester.tap(find.byKey(const Key('social-google')));
      expect(notifier.calls, [(SocialProvider.google, false)]);
    });

    testWidgets('a person who came by an invitation link may make the account on their first sign-in', (tester) async {
      pendingInviteToken.value = 'invite-token';
      final notifier = await _open(tester);
      await tester.ensureVisible(find.byKey(const Key('social-google')));
      await tester.tap(find.byKey(const Key('social-google')));
      expect(notifier.calls, [(SocialProvider.google, true)]);
    });

    testWidgets('while a sign-in runs the buttons are off', (tester) async {
      final notifier = await _open(tester, state: const SupabaseAuthState(isLoading: true));
      await tester.ensureVisible(find.byKey(const Key('social-google')));
      await tester.tap(find.byKey(const Key('social-google')), warnIfMissed: false);
      expect(notifier.calls, isEmpty);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('social-google'))).onPressed, isNull);
    });

    testWidgets('a phone that can offer neither shows no heading and no button', (tester) => _as(TargetPlatform.windows, () async {
          await _open(tester);
          expect(find.byKey(const Key('register-social-title')), findsNothing);
          expect(find.byType(OutlinedButton), findsNothing);
        }));

    testWidgets('someone already signed in (no workspace yet) is not offered another sign-in', (tester) async {
      await _open(tester, state: SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true));
      expect(find.byKey(const Key('register-social-title')), findsNothing);
      expect(find.byKey(const Key('social-google')), findsNothing);
    });

    testWidgets('it still creates nothing: no form, the website button and the way back are there', (tester) async {
      await _open(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('business-signup-button')), findsOneWidget);
      expect(find.byKey(const Key('back-to-sign-in')), findsOneWidget);
    });

    testWidgets('a refused sign-in shows its message once and clears it', (tester) async {
      final notifier = await _open(tester);
      notifier.state = const SupabaseAuthState(error: 'No BottlesUp Business account was found for this Google sign-in.');
      await tester.pump();
      expect(find.text('No BottlesUp Business account was found for this Google sign-in.'), findsOneWidget);
      expect(notifier.errorsCleared, 1);
    });

    testWidgets('a sign-in that works opens the dashboard', (tester) async {
      final notifier = await _open(tester);
      notifier.state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true);
      await tester.pumpAndSettle();
      expect(find.text('dashboard page'), findsOneWidget);
    });
  });
}
