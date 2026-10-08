import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/screens/accept_invitation_screen.dart';
import 'package:bottles_up_vendor/features/workspace/workspace_routes.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_selector_screen.dart';
import 'package:bottles_up_vendor/features/workspace/services/workspace_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const manager = Workspace(
  membershipId: 'm1', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner',
  role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A',
);
const owner = Workspace(
  membershipId: 'm2', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner,
);
final door = Workspace(
  membershipId: 'm3', orgId: 'p', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.door,
  eventId: 'e1', eventTitle: 'Promoter Night', accessEndAt: DateTime(2026, 10, 7, 4),
);

/// The same routes the app registers, without the sign-in machinery.
Widget harness(WorkspaceSnapshot snapshot, {String start = '/workspaces', WorkspaceService? service}) {
  final router = GoRouter(initialLocation: start, routes: [
    GoRoute(path: '/workspaces', builder: (_, __) => const WorkspaceSelectorScreen()),
    GoRoute(path: '/accept-invite', builder: (_, s) => AcceptInvitationScreen(token: s.uri.queryParameters['token'])),
    GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('classic dashboard'))),
    workspaceShellRoute(),
  ]);
  // A new key each time: pumping a second harness into the same scope would reuse the first one's cached providers.
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      workspaceSnapshotProvider.overrideWith((ref) async => snapshot),
      if (service != null) workspaceServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp.router(routerConfig: router, theme: ThemeData.dark()),
  );
}

void main() {
  group('choosing a workspace', () {
    testWidgets('several workspaces are listed, and opening one is an explicit tap', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([manager, owner])));
      await tester.pumpAndSettle();

      expect(find.text('Your workspaces'), findsOneWidget);
      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.textContaining('Club Co · Club A'), findsOneWidget);
      expect(find.textContaining('Club Co · All venues'), findsOneWidget);

      await tester.tap(find.byKey(const Key('workspace-m1')));
      await tester.pumpAndSettle();

      expect(find.text('Manager · Club Co'), findsOneWidget); // who you are acting as
      expect(find.text('Club A'), findsWidgets); // and where
      expect(find.textContaining('Prepare, run and close the night'), findsOneWidget);
    });

    testWidgets('one workspace opens straight away, with no list', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([door])));
      await tester.pumpAndSettle();

      expect(find.text('Your workspaces'), findsNothing);
      expect(find.text('Door staff · Night Events'), findsOneWidget);
      expect(find.textContaining('Promoter Night'), findsWidgets);
      expect(find.textContaining('access until Oct 7, 04:00'), findsOneWidget); // temporary access is visible
    });

    testWidgets('no workspace says so and offers a way on', (tester) async {
      await tester.pumpWidget(harness(const WorkspaceSnapshot.ready([])));
      await tester.pumpAndSettle();
      expect(find.textContaining('do not have a workspace yet'), findsOneWidget);
      await tester.tap(find.text('Open the classic dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('classic dashboard'), findsOneWidget);
    });

    testWidgets('a backend without workspaces is explained, not shown as a failure', (tester) async {
      await tester.pumpWidget(harness(const WorkspaceSnapshot.unavailable()));
      await tester.pumpAndSettle();
      expect(find.text('Workspaces are not set up on this server yet.'), findsOneWidget);
    });
  });

  group('inside a workspace', () {
    testWidgets('each role sees exactly its own tabs', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([manager, owner]), start: '/w/m1/tonight'));
      await tester.pumpAndSettle();
      for (final label in ['Tonight', 'Floor', 'Orders', 'Team', 'More']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Venues'), findsNothing); // an owner tab, not a manager tab
      expect(find.text('Money'), findsNothing);
    });

    testWidgets('door staff get the door tabs', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([door, manager]), start: '/w/m3/scan'));
      await tester.pumpAndSettle();
      for (final label in ['Scan', 'Guests', 'Door Sales', 'Chat']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Floor'), findsNothing);
    });

    testWidgets('tapping a tab opens that section', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([manager, owner]), start: '/w/m1/tonight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Staff, invitations, shifts and role limits'), findsOneWidget);
    });

    testWidgets('a section that is not built says so plainly', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([manager]), start: '/w/m1/orders'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('not-built-yet')), findsOneWidget);
      expect(find.textContaining('Not built yet'), findsOneWidget);
    });

    testWidgets('the switch button only exists when there is something to switch to', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([manager, owner]), start: '/w/m1/tonight'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('switch-workspace')), findsOneWidget);

      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([manager]), start: '/w/m1/tonight'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('switch-workspace')), findsNothing);
    });

    testWidgets('switching goes back to the list', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([manager, owner]), start: '/w/m1/tonight'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('switch-workspace')));
      await tester.pumpAndSettle();
      expect(find.text('Your workspaces'), findsOneWidget);
    });

    testWidgets('a workspace that is no longer yours shows a clear message, never a blank or raw error', (tester) async {
      await tester.pumpWidget(harness(WorkspaceSnapshot.ready([owner]), start: '/w/m1/tonight'));
      await tester.pumpAndSettle();
      expect(find.text('This workspace is no longer available to you'), findsOneWidget);
      expect(find.text('Tonight'), findsNothing); // none of its tabs
      await tester.tap(find.text('Back to my workspaces'));
      await tester.pumpAndSettle();
      expect(find.text('Owner · Club Co'), findsOneWidget); // their one remaining workspace
    });
  });

  group('opening an invitation link', () {
    WorkspaceService answering(String outcome, {List<String>? calls}) => WorkspaceService(rpc: (fn, {params}) async {
          calls?.add(fn);
          return [
            {'outcome': outcome}
          ];
        });

    for (final outcome in InvitationOutcome.values.where((o) => o != InvitationOutcome.failed)) {
      final dbValue = {
        InvitationOutcome.ok: 'ok',
        InvitationOutcome.alreadyAccepted: 'already_accepted',
        InvitationOutcome.invalid: 'invalid',
        InvitationOutcome.revoked: 'revoked',
        InvitationOutcome.expired: 'expired',
        InvitationOutcome.emailMismatch: 'email_mismatch',
      }[outcome]!;
      testWidgets('says the right thing for "$dbValue"', (tester) async {
        await tester.pumpWidget(harness(const WorkspaceSnapshot.ready([]), start: '/accept-invite?token=t', service: answering(dbValue)));
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.byKey(const Key('invitation-message'))).data;
        expect(text, invitationMessage(outcome));
        expect(find.text('Open my workspace'), outcome.grantedAccess ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('an expired link tells the person what to do next', (tester) async {
      await tester.pumpWidget(harness(const WorkspaceSnapshot.ready([]), start: '/accept-invite?token=t', service: answering('expired')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ask the person who invited you to send a new one'), findsOneWidget);
    });

    testWidgets('the wrong account is offered a way to switch accounts', (tester) async {
      await tester.pumpWidget(harness(const WorkspaceSnapshot.ready([]), start: '/accept-invite?token=t', service: answering('email_mismatch')));
      await tester.pumpAndSettle();
      expect(find.text('Sign out and use the invited email'), findsOneWidget);
    });

    testWidgets('a link with no token is invalid and never calls the server', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(harness(const WorkspaceSnapshot.ready([]), start: '/accept-invite', service: answering('ok', calls: calls)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invitation-message')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('invitation-message'))).data, invitationMessage(InvitationOutcome.invalid));
      expect(calls, isEmpty);
    });

    testWidgets('the remembered token is cleared once it has been used, but kept if the server could not be reached', (tester) async {
      pendingInviteToken.value = 'tok';
      await tester.pumpWidget(harness(const WorkspaceSnapshot.ready([]), start: '/accept-invite?token=tok', service: answering('ok')));
      await tester.pumpAndSettle();
      expect(pendingInviteToken.value, isNull);

      pendingInviteToken.value = 'tok';
      final failing = WorkspaceService(rpc: (fn, {params}) async => throw Exception('offline'));
      await tester.pumpWidget(harness(const WorkspaceSnapshot.ready([]), start: '/accept-invite?token=tok', service: failing));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(pendingInviteToken.value, 'tok'); // still there for the retry
      pendingInviteToken.value = null;
    });
  });
}
