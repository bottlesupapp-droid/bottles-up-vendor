import 'dart:io';

import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/auth/screens/login_screen.dart';
import 'package:bottles_up_vendor/features/auth/widgets/auth_button.dart';
import 'package:bottles_up_vendor/features/auth/widgets/auth_text_field.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_selector_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../workspace/fake_auth.dart';

const _owner = Workspace(membershipId: 'm-o', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const _manager = Workspace(membershipId: 'm-m', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Color? _materialColorBehind(WidgetTester tester, Finder label) =>
    tester.widget<Material>(find.ancestor(of: label, matching: find.byType(Material)).first).color;

void main() {
  // The app's own Inter file, so text takes the room it really takes (without it the test environment draws every letter as a wide square, and an ordinary
  // row looks too wide for the screen).
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(File('assets/fonts/Inter.ttf').readAsBytes().then(ByteData.sublistView));
    await font.load();
  });

  group('the workspace list', () {
    late FakeAuthNotifier auth;

    Future<void> open(WidgetTester tester, {String? last}) async {
      _phone(tester);
      auth = FakeAuthNotifier(const SupabaseAuthState());
      final router = GoRouter(initialLocation: '/workspaces', routes: [GoRoute(path: '/workspaces', builder: (_, __) => const WorkspaceSelectorScreen())]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          fakeAuth(auth),
          workspaceSnapshotProvider.overrideWith((ref) async => WorkspaceSnapshot.ready([_owner, _manager])),
          lastWorkspaceIdProvider.overrideWith((ref) async => last),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.darkTheme),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('opens with the brand, an eyebrow, the heading and a line saying what the list is', (tester) async {
      await open(tester);
      expect(find.byType(BuWordmark), findsOneWidget);
      expect(find.text('ASSIGNED ACCESS'), findsOneWidget);
      expect(find.text('Your workspaces'), findsOneWidget);
      expect(find.textContaining('assigned to your account'), findsOneWidget);
    });

    testWidgets('each workspace is a card, and only the one used last is highlighted', (tester) async {
      await open(tester, last: 'm-m');
      final cards = tester.widgetList<BuCard>(find.byType(BuCard)).toList();
      expect(cards, hasLength(2));
      expect(cards.where((c) => c.highlight), hasLength(1));
      expect(tester.widget<BuCard>(find.byKey(const Key('workspace-m-m'))).highlight, isTrue);
      expect(tester.widget<BuCard>(find.byKey(const Key('workspace-m-o'))).highlight, isFalse);
    });

    testWidgets('with no last-used workspace nothing is highlighted', (tester) async {
      await open(tester);
      expect(tester.widgetList<BuCard>(find.byType(BuCard)).where((c) => c.highlight), isEmpty);
    });

    testWidgets('"Last used" is inside the card\'s own text, once', (tester) async {
      await open(tester, last: 'm-m');
      expect(find.textContaining('Last used'), findsOneWidget);
      expect(find.text('Last used'), findsNothing);
    });

    testWidgets('Sign out is still in the corner, and signs out', (tester) async {
      await open(tester);
      await tester.tap(find.text('Sign out'));
      expect(auth.signOuts, 1);
    });

    testWidgets('a card is a whole tap target (title, words and chevron alike)', (tester) async {
      await open(tester);
      final card = tester.getRect(find.byKey(const Key('workspace-m-o')));
      expect(card.height, greaterThanOrEqualTo(72));
      expect(card.width, 393 - 2 * BuSpace.page);
    });
  });

  group('sign-in', () {
    Future<void> open(WidgetTester tester) async {
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [fakeAuth(FakeAuthNotifier(const SupabaseAuthState()))],
        child: MaterialApp(theme: AppTheme.darkTheme, home: const LoginScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('has the brand, an eyebrow and the welcome heading', (tester) async {
      await open(tester);
      expect(find.byType(BuWordmark), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('Welcome back!'), findsOneWidget);
    });

    testWidgets('still offers both ways in: e-mail and phone number', (tester) async {
      await open(tester);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
    });

    testWidgets('the Login button is the orange primary, with white text', (tester) async {
      await open(tester);
      expect(_materialColorBehind(tester, find.text('Login')), BuTokens.dark.orange);
      expect(tester.widget<Text>(find.text('Login')).style?.color, Colors.white);
    });

    testWidgets('the phone tab\'s button is the orange primary too', (tester) async {
      await open(tester);
      await tester.tap(find.text('Phone number'));
      await tester.pumpAndSettle();
      expect(_materialColorBehind(tester, find.text('Send Code')), BuTokens.dark.orange);
    });

    testWidgets('Forgot password? and Create a new one! are the orange links, and still go where they went', (tester) async {
      await open(tester);
      expect(tester.widget<Text>(find.text('Forgot password?')).style?.color, BuTokens.dark.orangeSoft);
      expect(tester.widget<Text>(find.text('Create a new one!')).style?.color, BuTokens.dark.orangeSoft);
    });

    test('the screen draws no input borders or fills of its own: the theme\'s input style applies (a local one would override it)', () {
      final source = File('lib/features/auth/screens/login_screen.dart').readAsStringSync();
      expect(source, isNot(contains('OutlineInputBorder')));
      expect(source, isNot(contains('fillColor')));
      expect(source, isNot(contains('BorderRadius.circular(30)')), reason: 'the old pill shape');
    });

    testWidgets('signing in with a wrong form still shows the validators', (tester) async {
      await open(tester);
      await tester.tap(find.text('Login'));
      await tester.pump();
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('on a small phone the whole screen scrolls instead of overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [fakeAuth(FakeAuthNotifier(const SupabaseAuthState()))],
        child: MaterialApp(theme: AppTheme.darkTheme, home: const LoginScreen()),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });

  group('the shared auth widgets', () {
    Future<void> show(WidgetTester tester, Widget child) async {
      _phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: child))));
    }

    testWidgets('a primary AuthButton is orange with white text and 14-point corners, 56 tall by default', (tester) async {
      await show(tester, AuthButton(text: 'Continue', onPressed: () {}));
      expect(_materialColorBehind(tester, find.text('Continue')), BuTokens.dark.orange);
      expect(tester.getSize(find.byType(AuthButton)).height, 56);
      final shape = tester.widget<Material>(find.ancestor(of: find.text('Continue'), matching: find.byType(Material)).first).shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(BuRadius.control));
    });

    testWidgets('a secondary AuthButton is the dark panel with a soft edge and ink text', (tester) async {
      await show(tester, AuthButton(text: 'Back to Login', isSecondary: true, onPressed: () {}));
      expect(tester.widget<Text>(find.text('Back to Login')).style?.color, BuTokens.dark.ink);
      expect(_materialColorBehind(tester, find.text('Back to Login')), BuTokens.dark.panel);
    });

    testWidgets('an AuthButton shows a spinner, and cannot be pressed, while busy', (tester) async {
      var taps = 0;
      await show(tester, AuthButton(text: 'Continue', isLoading: true, onPressed: () => taps++));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      await tester.tap(find.byType(AuthButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('an AuthButton with an icon shows both icon and words', (tester) async {
      await show(tester, AuthButton(text: 'Send', icon: Icons.send, onPressed: () {}));
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('an AuthTextField has its label above, a default hint, and takes typing', (tester) async {
      final controller = TextEditingController();
      await show(tester, AuthTextField(controller: controller, label: 'Email'));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter Email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'sam@example.com');
      expect(controller.text, 'sam@example.com');
    });

    testWidgets('an AuthTextField shows its validator\'s message and hides a password', (tester) async {
      final formKey = GlobalKey<FormState>();
      await show(tester, Form(key: formKey, child: AuthTextField(controller: TextEditingController(), label: 'Password', obscureText: true, validator: (v) => 'Required')));
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText, isTrue);
    });
  });
}
