import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/workspace_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_auth.dart';

const server = Workspace(
  membershipId: 'm1', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner',
  role: WorkspaceRole.server, venueId: 'v1', venueName: 'Club A',
);
const owner = Workspace(
  membershipId: 'm2', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner,
);

Widget app(List<Workspace> workspaces, FakeAuthNotifier auth, {String start = '/w/m1/tables'}) {
  final router = GoRouter(initialLocation: start, routes: [
    GoRoute(path: '/workspaces', builder: (_, __) => const Scaffold(body: Text('workspace list'))),
    workspaceShellRoute(),
  ]);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      workspaceSnapshotProvider.overrideWith((ref) async => WorkspaceSnapshot.ready(workspaces)),
      fakeAuth(auth),
    ],
    child: MaterialApp.router(routerConfig: router, theme: ThemeData.dark()),
  );
}

FakeAuthNotifier signedIn() => FakeAuthNotifier(SupabaseAuthState(supabaseUser: supabaseUser(), vendorChecked: true));

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('account-menu')));
  await tester.pumpAndSettle();
}

void main() {
  group('signing out from inside a workspace', () {
    testWidgets('a person with ONE workspace (who never sees the workspace list) can sign out', (tester) async {
      final auth = signedIn();
      await tester.pumpWidget(app([server], auth));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switch-workspace')), findsNothing); // nothing to switch to...
      expect(find.byKey(const Key('account-menu')), findsOneWidget); // ...but they can still sign out
    });

    testWidgets('it asks first, and Cancel keeps them signed in', (tester) async {
      final auth = signedIn();
      await tester.pumpWidget(app([server], auth));
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-sign-out')));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      expect(auth.signOuts, 0); // asking is not signing out

      await tester.tap(find.byKey(const Key('cancel-sign-out')));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsNothing);
      expect(auth.signOuts, 0);
    });

    testWidgets('confirming signs out, once', (tester) async {
      final auth = signedIn();
      await tester.pumpWidget(app([server], auth));
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-sign-out')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-sign-out')));
      await tester.pumpAndSettle();

      expect(auth.signOuts, 1);
    });

    testWidgets('people with several workspaces get both the switch button and the menu', (tester) async {
      final auth = signedIn();
      await tester.pumpWidget(app([server, owner], auth));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('switch-workspace')), findsOneWidget);
      expect(find.byKey(const Key('account-menu')), findsOneWidget);
    });

    testWidgets('the menu is there on every tab, not just the first', (tester) async {
      final auth = signedIn();
      await tester.pumpWidget(app([server], auth, start: '/w/m1/orders'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-menu')), findsOneWidget);
    });
  });
}
