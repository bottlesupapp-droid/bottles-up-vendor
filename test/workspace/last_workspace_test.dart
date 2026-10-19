import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/workspace/logic/last_workspace.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_selector_screen.dart';
import 'package:bottles_up_vendor/features/workspace/services/last_workspace_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Workspace ws(String id, WorkspaceRole role, {String? venue}) =>
    Workspace(membershipId: id, orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: role, venueId: venue, venueName: venue == null ? null : 'Club $venue');

final a = ws('m1', WorkspaceRole.manager, venue: 'A');
final b = ws('m2', WorkspaceRole.owner);
final c = ws('m3', WorkspaceRole.door, venue: 'C');

User user(String id) => User(id: id, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-10-19T00:00:00Z');

List<String> ids(List<Workspace> l) => [for (final w in l) w.membershipId];

void main() {
  group('the order', () {
    test('nothing remembered: the list keeps its order', () {
      expect(ids(withLastUsedFirst([a, b, c], null)), ['m1', 'm2', 'm3']);
    });

    test('the remembered one goes first and the others keep their order', () {
      expect(ids(withLastUsedFirst([a, b, c], 'm3')), ['m3', 'm1', 'm2']);
      expect(ids(withLastUsedFirst([a, b, c], 'm2')), ['m2', 'm1', 'm3']);
      expect(ids(withLastUsedFirst([a, b, c], 'm1')), ['m1', 'm2', 'm3']);
    });

    test('a remembered one that is no longer in the list (revoked, expired, another person) is ignored', () {
      expect(ids(withLastUsedFirst([a, b], 'm3')), ['m1', 'm2']);
      expect(isLastUsed(a, [a, b], 'm3'), isFalse);
      expect(isLastUsed(c, [a, b], 'm3'), isFalse, reason: 'even asked directly about the stale one');
    });

    test('only the remembered one says so', () {
      expect(isLastUsed(b, [a, b, c], 'm2'), isTrue);
      expect(isLastUsed(a, [a, b, c], 'm2'), isFalse);
      expect(isLastUsed(a, [a, b, c], null), isFalse);
    });

    test('the list given is not changed', () {
      final original = [a, b, c];
      withLastUsedFirst(original, 'm3');
      expect(ids(original), ['m1', 'm2', 'm3']);
    });
  });

  group('the store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('remembers per person', () async {
      const store = LastWorkspaceStore();
      expect(await store.read('u1'), isNull);
      await store.write('u1', 'm2');
      await store.write('u2', 'm3');
      expect(await store.read('u1'), 'm2');
      expect(await store.read('u2'), 'm3');
    });

    test('the latest choice wins', () async {
      const store = LastWorkspaceStore();
      await store.write('u1', 'm2');
      await store.write('u1', 'm1');
      expect(await store.read('u1'), 'm1');
    });

    test('an empty stored value is nothing', () async {
      SharedPreferences.setMockInitialValues({'last_workspace_u1': ''});
      expect(await const LastWorkspaceStore().read('u1'), isNull);
    });
  });

  group('the list on screen', () {
    Widget app({String userId = 'u1', List<Workspace>? list}) {
      final router = GoRouter(initialLocation: '/workspaces', routes: [
        GoRoute(path: '/workspaces', builder: (_, __) => const WorkspaceSelectorScreen()),
        GoRoute(path: '/w/:id/:tab', builder: (_, s) => Scaffold(body: Text('opened ${s.pathParameters['id']}'))),
      ]);
      return ProviderScope(
        key: UniqueKey(),
        overrides: [
          currentUserProvider.overrideWithValue(user(userId)),
          workspaceSnapshotProvider.overrideWith((ref) async => WorkspaceSnapshot.ready(list ?? [a, b, c])),
        ],
        child: MaterialApp.router(routerConfig: router, theme: ThemeData.dark()),
      );
    }

    double top(WidgetTester t, String id) => t.getTopLeft(find.byKey(Key('workspace-$id'))).dy;

    testWidgets('the one opened last is first, and says "Last used"', (tester) async {
      SharedPreferences.setMockInitialValues({'last_workspace_u1': 'm3'});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(top(tester, 'm3'), lessThan(top(tester, 'm1')));
      expect(top(tester, 'm1'), lessThan(top(tester, 'm2')));
      expect(find.text('Last used'), findsNothing, reason: 'the label sits inside the card text');
      expect(find.textContaining('Last used'), findsOneWidget);
    });

    testWidgets('opening one remembers it, for this person only', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.textContaining('Last used'), findsNothing);

      await tester.tap(find.byKey(const Key('workspace-m2')));
      await tester.pumpAndSettle();
      expect(find.text('opened m2'), findsOneWidget);
      expect(await const LastWorkspaceStore().read('u1'), 'm2');
      expect(await const LastWorkspaceStore().read('u2'), isNull);
    });

    testWidgets('a remembered workspace the person no longer has is not shown or favoured', (tester) async {
      SharedPreferences.setMockInitialValues({'last_workspace_u1': 'revoked-one'});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.textContaining('Last used'), findsNothing);
      expect(top(tester, 'm1'), lessThan(top(tester, 'm2')));
    });

    testWidgets('somebody else signing in on the same phone does not inherit the choice', (tester) async {
      SharedPreferences.setMockInitialValues({'last_workspace_u1': 'm3'});
      await tester.pumpWidget(app(userId: 'u2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Last used'), findsNothing);
      expect(top(tester, 'm1'), lessThan(top(tester, 'm3')));
    });
  });
}
