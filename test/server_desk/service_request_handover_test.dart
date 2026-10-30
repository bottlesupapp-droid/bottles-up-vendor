import 'dart:async';

import 'package:bottles_up_vendor/features/server_desk/logic/server_desk_rules.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/service_requests_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/services/server_desk_service.dart';
import 'package:bottles_up_vendor/features/server_desk/widgets/assign_server_row.dart';
import 'package:bottles_up_vendor/features/team/logic/team_rules.dart' show MemberState, TeamMember;
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:bottles_up_vendor/features/team/services/team_service.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_desk_backend.dart';

// A manager hands a service request to a server of the club (the database's `reassign` move, which the screen did not offer before).

late FakeDeskBackend db;
late List<Map<String, dynamic>> team;
Object? teamFailure;
int teamReads = 0;

Map<String, dynamic> person(String id, String name, {String role = 'server', String venue = 'v1', String state = 'active', String? email}) => {
      'membership_id': id,
      'user_id': 'u-$id',
      'email': email ?? '${name.toLowerCase().replaceAll(' ', '')}@club.example',
      'name': name,
      'role': role,
      'venue_id': venue,
      'venue_name': 'Club',
      'state': state,
    };

Workspace workspace(WorkspaceRole role) => Workspace(
      membershipId: 'w1',
      orgId: 'o1',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: role,
      venueId: 'v1',
      venueName: 'Club A',
    );

DateTime nineThirty() => DateTime(2026, 10, 9, 21, 30);

/// What the picker was shown, so a test can say who was offered.
List<ServerOption>? offered;
String? offeredCurrent;

Widget host({WorkspaceRole role = WorkspaceRole.manager, ServerPicker? pick}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        serverDeskServiceProvider.overrideWithValue(db.service),
        teamServiceProvider.overrideWithValue(TeamService(rpc: (f, {params}) async {
          teamReads++;
          if (teamFailure != null) throw teamFailure!;
          return team;
        })),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ServiceRequestsScreen(
            workspace: workspace(role),
            clock: nineThirty,
            pickReason: (c, a) async => 'because',
            pickHolder: pick ?? (c, options, current) async => null,
          ),
        ),
      ),
    );

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

ServerPicker choose(String? membershipId) => (c, options, current) async {
      offered = options;
      offeredCurrent = current;
      return membershipId == null ? null : ServerChoice(membershipId);
    };

List<(String, Map<String, dynamic>?)> reassigns() => [for (final c in db.calls) if (c.$1 == 'update_service_request' && c.$2?['p_action'] == 'reassign') c];

ServiceRequestRow row({String status = 'new', String? assigned, bool mine = false}) => ServiceRequestRow(
      requestId: 'r1',
      bookingId: 'b1',
      confirmationCode: null,
      customerName: 'Ada',
      tableName: 'Booth',
      guestCount: 2,
      kind: ServiceKind.values.first,
      note: null,
      status: RequestStatus.fromDb(status)!,
      assignedMembershipId: assigned,
      assignedToMe: mine,
      createdAt: DateTime(2026, 10, 9, 21),
      acknowledgedAt: null,
      closedAt: null,
      statusNote: null,
    );

TeamMember member(String id, String name, {String? email}) => TeamMember(
      membershipId: id,
      userId: 'u-$id',
      email: email,
      name: name,
      role: 'server',
      venueId: 'v1',
      venueName: 'Club',
      state: MemberState.active,
    );

void main() {
  setUp(() {
    db = FakeDeskBackend()
      ..level = 'manager'
      ..now = DateTime(2026, 10, 9, 21, 30);
    db.addBooking('b1', code: 'AB12CD', name: 'Ada Lovelace');
    db.staff.addAll({'m-sam': 'ok', 'm-zoe': 'ok', 'm-old': 'revoked', 'm-door': 'door', 'm-other': 'other-club'});
    team = [
      person('m-sam', 'Sam'),
      person('m-zoe', 'Zoe'),
      person('m-later', 'Later Lee', state: 'scheduled'),
      person('m-old', 'Old Olga', state: 'revoked'),
      person('m-door', 'Door Dan', role: 'door'),
      person('m-other', 'Other Ola', venue: 'v2'),
      person('m-boss', 'Boss Bea', role: 'manager'),
    ];
    teamFailure = null;
    teamReads = 0;
    offered = null;
    offeredCurrent = null;
  });

  group('the rules', () {
    test('a manager can hand over any request that is still open, and nothing else', () {
      for (final s in ['new', 'acknowledged', 'in_progress', 'escalated']) {
        expect(canHandOver(row(status: s), manager: true), isTrue, reason: s);
      }
      for (final s in ['completed', 'cancelled']) {
        expect(canHandOver(row(status: s), manager: true), isFalse, reason: s);
      }
      expect(canHandOver(row(), manager: false), isFalse, reason: 'a server hands nothing on');
    });

    test('what is sent: the request, the move and the person, nothing else', () {
      expect(reassignParams('r1', 'm-zoe'), {'p_request': 'r1', 'p_action': 'reassign', 'p_assignee': 'm-zoe'});
    });

    test('a manager is told who has it: "You", the name, the e-mail when there is no name, or the plain words', () {
      final people = [member('m-sam', 'Sam'), member('m-lee', '', email: 'lee@club.example')];
      expect(holderLabelFor(row(assigned: 'm-me', mine: true), people), 'You');
      // the manager is on the team list too: it still says "You", not their own name
      expect(holderLabelFor(row(assigned: 'm-me', mine: true), [...people, member('m-me', 'Mia Manager')]), 'You');
      expect(holderLabelFor(row(assigned: 'm-sam'), people), 'Sam');
      expect(holderLabelFor(row(assigned: 'm-lee'), people), 'lee@club.example');
      expect(holderLabelFor(row(assigned: 'm-gone'), people), 'A colleague');
      expect(holderLabelFor(row(), people), 'Nobody yet');
      expect(holderLabelFor(row(assigned: 'm-sam'), const []), 'A colleague');
    });
  });

  group('the service', () {
    test('hands the request on with the database\'s own move', () async {
      db.addRequest('b1', 'assistance', rid: 'r1');
      await db.service.reassign('r1', 'm-zoe');
      expect(reassigns().single.$2, {'p_request': 'r1', 'p_action': 'reassign', 'p_assignee': 'm-zoe'});
      expect(db.requests.single.assigned, 'm-zoe');
      expect(db.requests.single.status, 'new');
    });

    test('each refusal is the database\'s own sentence', () async {
      db.addRequest('b1', 'assistance', rid: 'r1');
      Future<String> refused(String to) async {
        try {
          await db.service.reassign('r1', to);
        } on ServerDeskActionException catch (e) {
          return e.message;
        }
        return 'accepted';
      }

      expect(await refused('m-old'), 'That person no longer has access to this club.');
      expect(await refused('m-door'), 'That person is not staff at this club.');
      expect(await refused('m-other'), 'That person is not staff at this club.');
      expect(await refused('m-nobody'), 'That person is not staff at this club.');
      db.level = 'server';
      expect(await refused('m-zoe'), 'Only a manager can hand a request to someone else.');
      db.requests.single.status = 'completed';
      db.level = 'manager';
      expect(await refused('m-zoe'), 'This request is already closed.');
    });

    test('a dropped connection gets a plain sentence, not the technical one', () async {
      db.addRequest('b1', 'assistance', rid: 'r1');
      db.failAll = Exception('SocketException: Failed host lookup');
      try {
        await db.service.reassign('r1', 'm-zoe');
        fail('should have been refused');
      } on ServerDeskActionException catch (e) {
        expect(e.message, 'The request could not be handed on. Check your connection and try again.');
      }
    });
  });

  group('the screen', () {
    testWidgets('a manager sees who has each request by name, and a way to give it to someone else', (tester) async {
      db.addRequest('b1', 'assistance', assigned: 'm-sam', rid: 'r1', createdAt: DateTime(2026, 10, 9, 21, 25));
      db.addRequest('b1', 'bill_request', rid: 'r2', createdAt: DateTime(2026, 10, 9, 21, 28));
      await open(tester, host());
      expect(find.text('Waiting 5 min · Sam'), findsOneWidget);
      expect(find.text('Waiting 2 min · Nobody yet'), findsOneWidget);
      expect(find.byKey(const Key('handover-r1')), findsOneWidget);
      expect(find.byKey(const Key('handover-r2')), findsOneWidget);
      expect(find.text('Give to someone else'), findsNWidgets(2));
    });

    testWidgets('a server is offered no hand-over, and still sees "You" or "A colleague"', (tester) async {
      db.level = 'server';
      db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
      await open(tester, host(role: WorkspaceRole.server));
      expect(find.byKey(const Key('handover-r1')), findsNothing);
      expect(find.text('Waiting just now · You'), findsOneWidget);
    });

    testWidgets('a finished request has no hand-over', (tester) async {
      db.addRequest('b1', 'assistance', status: 'completed', rid: 'r1').closedAt = DateTime(2026, 10, 9, 21, 25);
      await open(tester, host());
      await tapKey(tester, 'show-closed');
      expect(find.byKey(const Key('request-r1')), findsOneWidget);
      expect(find.byKey(const Key('handover-r1')), findsNothing);
    });

    testWidgets('the picker offers the servers of this club who can serve, marks who has it, and nobody else', (tester) async {
      db.addRequest('b1', 'assistance', assigned: 'm-sam', rid: 'r1');
      await open(tester, host(pick: choose(null)));
      await tapKey(tester, 'handover-r1');
      expect([for (final o in offered!) o.label], ['Later Lee', 'Sam', 'Zoe']);
      expect(offeredCurrent, 'm-sam');
    });

    testWidgets('choosing a person hands the request over; it goes back to New with them, and the manager is told', (tester) async {
      db.addRequest('b1', 'assistance', status: 'acknowledged', assigned: 'm-sam', rid: 'r1', createdAt: DateTime(2026, 10, 9, 21, 25));
      await open(tester, host(pick: choose('m-zoe')));
      expect(find.text('Acknowledged'), findsOneWidget);
      await tapKey(tester, 'handover-r1');
      expect(reassigns().single.$2, {'p_request': 'r1', 'p_action': 'reassign', 'p_assignee': 'm-zoe'});
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Waiting 5 min · Zoe'), findsOneWidget);
      expect(find.text('Handed to Zoe. They need to take it.'), findsOneWidget);
    });

    testWidgets('a manager\'s own request says "You" on the screen, though their name is on the team list', (tester) async {
      team = [...team, person('m-me', 'Mia Manager', role: 'manager')];
      db.addRequest('b1', 'assistance', status: 'escalated', assigned: 'm-me', rid: 'r1', createdAt: DateTime(2026, 10, 9, 21, 25));
      await open(tester, host());
      expect(find.text('Waiting 5 min · You'), findsOneWidget);
    });

    testWidgets('a server never asks for the team list (only a manager may read it)', (tester) async {
      db.level = 'server';
      db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
      await open(tester, host(role: WorkspaceRole.server));
      expect(teamReads, 0);
      await open(tester, host());
      expect(teamReads, 1, reason: 'a manager does');
    });

    testWidgets('if the picker returns someone the list does not hold, the message still reads well', (tester) async {
      db.staff['m-new'] = 'ok';
      db.addRequest('b1', 'assistance', assigned: 'm-sam', rid: 'r1');
      await open(tester, host(pick: (c, options, current) async => const ServerChoice('m-new')));
      await tapKey(tester, 'handover-r1');
      expect(find.text('Handed to them. They need to take it.'), findsOneWidget);
    });

    testWidgets('a request passed up to a manager can be handed back down', (tester) async {
      db.addRequest('b1', 'assistance', status: 'escalated', assigned: 'm-sam', rid: 'r1');
      await open(tester, host(pick: choose('m-zoe')));
      await tapKey(tester, 'handover-r1');
      expect(db.requests.single.status, 'new');
      expect(db.requests.single.assigned, 'm-zoe');
    });

    testWidgets('choosing the person who already has it, or backing out, sends nothing', (tester) async {
      db.addRequest('b1', 'assistance', assigned: 'm-sam', rid: 'r1');
      await open(tester, host(pick: choose('m-sam')));
      await tapKey(tester, 'handover-r1');
      expect(reassigns(), isEmpty);
      await open(tester, host(pick: choose(null)));
      await tapKey(tester, 'handover-r1');
      expect(reassigns(), isEmpty);
    });

    testWidgets('a refusal is shown in the database\'s words, nothing is faked, and the list is read again', (tester) async {
      db.addRequest('b1', 'assistance', assigned: 'm-sam', rid: 'r1');
      db.staff['m-zoe'] = 'revoked'; // her access ended after the team list was read
      await open(tester, host(pick: choose('m-zoe')));
      final reads = db.calls.where((c) => c.$1 == 'list_service_requests').length;
      await tapKey(tester, 'handover-r1');
      expect(find.text('That person no longer has access to this club.'), findsOneWidget);
      expect(find.text('Waiting 2 min · Sam'), findsNothing); // (the clock is fixed; what matters is that Sam still has it)
      expect(db.requests.single.assigned, 'm-sam');
      expect(db.calls.where((c) => c.$1 == 'list_service_requests').length, greaterThan(reads));
      expect(find.byKey(const Key('handover-r1')), findsOneWidget, reason: 'it can be tried again');
    });

    testWidgets('while it goes through the button waits: two quick taps are one hand-over', (tester) async {
      db.addRequest('b1', 'assistance', assigned: 'm-sam', rid: 'r1');
      var picks = 0;
      await open(tester, host(pick: (c, options, current) async {
        picks++;
        return const ServerChoice('m-zoe');
      }));
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.tap(find.byKey(const Key('handover-r1')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('handover-r1')), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(picks, 1);
      expect(reassigns(), hasLength(1));
    });

    testWidgets('until the team is known nobody can be chosen: the button waits, and names fall back to the plain words', (tester) async {
      teamFailure = Exception('offline');
      db.addRequest('b1', 'assistance', assigned: 'm-sam', rid: 'r1');
      await open(tester, host(pick: choose('m-zoe')));
      expect(find.text('Waiting just now · A colleague'), findsOneWidget);
      final button = tester.widget<TextButton>(find.byKey(const Key('handover-r1')));
      expect(button.onPressed, isNull);
      await tester.tap(find.byKey(const Key('handover-r1')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(reassigns(), isEmpty);
    });

    testWidgets('a club with no servers on the team is told so, instead of an empty list (the real sheet)', (tester) async {
      team = [person('m-boss', 'Boss Bea', role: 'manager')];
      db.addRequest('b1', 'assistance', rid: 'r1');
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          serverDeskServiceProvider.overrideWithValue(db.service),
          teamServiceProvider.overrideWithValue(TeamService(rpc: (f, {params}) async => team)),
        ],
        child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: ServiceRequestsScreen(workspace: workspace(WorkspaceRole.manager), clock: nineThirty))),
      ));
      await tester.pumpAndSettle();
      await tapKey(tester, 'handover-r1');
      expect(find.text('Who should take this request?'), findsOneWidget);
      expect(find.byKey(const Key('picker-empty')), findsOneWidget);
      expect(find.byKey(const Key('pick-none')), findsNothing);
    });

    testWidgets('the real sheet lists the servers, ticks the one who has it, and has no "nobody" row', (tester) async {
      db.addRequest('b1', 'assistance', assigned: 'm-sam', rid: 'r1');
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          serverDeskServiceProvider.overrideWithValue(db.service),
          teamServiceProvider.overrideWithValue(TeamService(rpc: (f, {params}) async => team)),
        ],
        child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: ServiceRequestsScreen(workspace: workspace(WorkspaceRole.manager), clock: nineThirty))),
      ));
      await tester.pumpAndSettle();
      await tapKey(tester, 'handover-r1');
      expect(find.text('Who should take this request?'), findsOneWidget);
      expect(find.byKey(const Key('pick-m-sam')), findsOneWidget);
      expect(find.byKey(const Key('pick-m-zoe')), findsOneWidget);
      expect(find.byKey(const Key('pick-m-later')), findsOneWidget);
      expect(find.text('Starts later'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('pick-m-sam')), matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('pick-m-zoe')), matching: find.byIcon(Icons.check)), findsNothing);
      expect(find.byKey(const Key('pick-none')), findsNothing);
      await tapKey(tester, 'pick-m-zoe');
      expect(db.requests.single.assigned, 'm-zoe');
    });
  });
}
