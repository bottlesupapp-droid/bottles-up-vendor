import 'dart:async';

import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/register_screen.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/no_workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_auth.dart';

const token = '0f8fad5bd9cb469fa16570867728950e3a1c4b7e9d2f4a6c8b0e1d3f5a7c9e2b';

class Harness {
  Harness({this.opens = true, this.opener, this.snapshot = const WorkspaceSnapshot.ready([]), this.gate});

  final bool opens;
  final Future<bool> Function(Uri)? opener;
  final WorkspaceSnapshot snapshot;

  /// When given, the workspaces are not known until this completes (the "being asked" state).
  final Completer<WorkspaceSnapshot>? gate;
  final auth = FakeAuthNotifier(SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true));
  final opened = <Uri>[];
  var asked = 0;

  Widget build({String start = WorkspaceRoutes.noWorkspace}) {
    final router = GoRouter(initialLocation: start, routes: [
      GoRoute(path: WorkspaceRoutes.noWorkspace, builder: (_, __) => const NoWorkspaceScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login page'))),
      GoRoute(
        path: WorkspaceRoutes.acceptInvite,
        builder: (_, s) => Scaffold(body: Text('accepting ${s.uri.queryParameters['token']}')),
      ),
    ]);
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        workspaceSnapshotProvider.overrideWith((ref) async {
          asked++;
          return gate == null ? snapshot : gate!.future;
        }),
        siteUrlProvider.overrideWithValue('https://example.test'),
        urlOpenerProvider.overrideWithValue(opener ??
            (uri) async {
              opened.add(uri);
              return opens;
            }),
        fakeAuth(auth),
      ],
      child: MaterialApp.router(routerConfig: router, theme: ThemeData.dark()),
    );
  }
}

/// The page is a scrolling list; a tall screen keeps all of it built, so a test can see and press the bottom button.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('NoWorkspaceScreen', () {
    testWidgets('says what to do: set up a business on the website, or use an invitation', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      expect(find.text('Set up your business'), findsOneWidget);
      expect(find.byKey(const Key('no-workspace-title')), findsOneWidget);
      expect(find.text('Starting a business?'), findsOneWidget);
      expect(find.text('Joining a team?'), findsOneWidget);
      expect(find.byKey(const Key('no-workspace-error')), findsNothing);
      // Nothing here creates an account: no password, name or role fields.
      expect(find.byType(TextField), findsOneWidget); // the invitation link, and nothing else
    });

    testWidgets('"Create a business account" opens the website\'s business signup, outside the app', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('business-signup-button')));
      await tester.pumpAndSettle();

      expect(h.opened.map((u) => u.toString()), ['https://example.test/signup/business']);
      expect(find.byType(SnackBar), findsNothing); // it opened: nothing to apologise for
    });

    testWidgets('when the website cannot be opened it says where to go', (tester) async {
      tallScreen(tester);
      final h = Harness(opens: false);
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('business-signup-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('https://example.test/signup/business'), findsOneWidget);
    });

    testWidgets('...also when opening it throws', (tester) async {
      tallScreen(tester);
      final h = Harness(opener: (_) async => throw Exception('no browser'));
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('business-signup-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not open the website'), findsOneWidget);
    });

    testWidgets('a pasted invitation link goes to the accept screen with its token', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('invitation-field')), 'https://www.bottlesupapp.com/accept-invite?token=$token');
      await tester.tap(find.byKey(const Key('use-invitation-button')));
      await tester.pumpAndSettle();

      expect(find.text('accepting $token'), findsOneWidget);
    });

    testWidgets('the bare token works too, and so does the keyboard\'s done key', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('invitation-field')), token);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('accepting $token'), findsOneWidget);
    });

    testWidgets('something that is not an invitation says so, goes nowhere, and clears when they type again', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('invitation-field')), 'hello');
      await tester.tap(find.byKey(const Key('use-invitation-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('does not look like an invitation link'), findsOneWidget);
      expect(find.textContaining('accepting'), findsNothing);

      await tester.enterText(find.byKey(const Key('invitation-field')), 'hello again');
      await tester.pump();
      expect(find.textContaining('does not look like an invitation link'), findsNothing);
    });

    testWidgets('an empty field is not an invitation either', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('use-invitation-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('does not look like an invitation link'), findsOneWidget);
    });

    testWidgets('"Check again" asks for the workspaces again', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();
      final before = h.asked;

      await tester.tap(find.byKey(const Key('check-again-button')));
      await tester.pumpAndSettle();

      expect(h.asked, before + 1);
    });

    testWidgets('while it is being asked the button says so and cannot be pressed twice', (tester) async {
      tallScreen(tester);
      final gate = Completer<WorkspaceSnapshot>();
      final h = Harness(gate: gate);
      await tester.pumpWidget(h.build());
      await tester.pump(); // the answer has not arrived: loading

      expect(find.text('Checking...'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(find.byKey(const Key('check-again-button')));
      expect(button.onPressed, isNull);

      gate.complete(const WorkspaceSnapshot.ready([]));
      await tester.pumpAndSettle();
      expect(find.text('Check again'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('check-again-button'))).onPressed, isNotNull);
    });

    testWidgets('Sign out signs out', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sign-out-button')));
      await tester.pump();

      expect(h.auth.signOuts, 1);
    });
  });

  group('RegisterScreen (the old "Create account")', () {
    testWidgets('creates nothing: it explains and opens the website', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build(start: '/register'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('register-title')), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // no name, email, password or role to fill in
      expect(find.text('Joining a team?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('business-signup-button')));
      await tester.pumpAndSettle();
      expect(h.opened.map((u) => u.toString()), ['https://example.test/signup/business']);
    });

    testWidgets('"I already have an account" goes back to sign in', (tester) async {
      tallScreen(tester);
      final h = Harness();
      await tester.pumpWidget(h.build(start: '/register'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('back-to-sign-in')));
      await tester.pumpAndSettle();

      expect(find.text('login page'), findsOneWidget);
    });
  });

  group('classicVendorStatusProvider', () {
    ClassicVendorStatus statusOf(SupabaseAuthState state) {
      final container = ProviderContainer(overrides: [fakeAuth(FakeAuthNotifier(state))]);
      addTearDown(container.dispose);
      return container.read(classicVendorStatusProvider);
    }

    test('signed out, or signed in but the row not looked up yet: undecided', () {
      expect(statusOf(const SupabaseAuthState()), ClassicVendorStatus.loading);
      expect(statusOf(SupabaseAuthState(supabaseUser: supabaseUser())), ClassicVendorStatus.loading);
    });

    test('looked up and there is no row: not a classic vendor', () {
      expect(statusOf(SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true)), ClassicVendorStatus.none);
    });

    test('a row that never finished the classic onboarding (the app used to create these for every account): not a classic vendor', () {
      final state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorUser: vendorRow(onboardingCompleted: false), vendorChecked: true);
      expect(statusOf(state), ClassicVendorStatus.none);
    });

    test('a row that finished it: a classic vendor', () {
      final state = SupabaseAuthState(supabaseUser: supabaseUser(), vendorUser: vendorRow(onboardingCompleted: true), vendorChecked: true);
      expect(statusOf(state), ClassicVendorStatus.classic);
    });
  });
}
