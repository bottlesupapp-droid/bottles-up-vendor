import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/team/logic/team_rules.dart';
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:bottles_up_vendor/features/team/screens/team_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../owner/fake_owner_backend.dart';
import 'fake_team_backend.dart';

late FakeTeamBackend team;
late FakeOwnerBackend owner;
late List<DateTime?> picks;

const ownerWs = Workspace(membershipId: 'm-o', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const managerWs = Workspace(membershipId: 'm-m', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
final fixedNow = DateTime(2031, 10, 24, 12);

Future<void> open(WidgetTester tester, Workspace ws) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [teamServiceProvider.overrideWithValue(team.service), ownerServiceProvider.overrideWithValue(owner.service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: TeamScreen(workspace: ws, clock: () => fixedNow, pickDateTime: (context, initial) async => picks.isEmpty ? null : picks.removeAt(0))),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void main() {
  setUp(() {
    team = FakeTeamBackend();
    owner = FakeOwnerBackend();
    picks = [];
  });

  group('rules', () {
    test('the shift form', () {
      final a = DateTime(2031, 10, 24, 21);
      expect(checkShiftForm(name: ' ', start: a, end: a.add(const Duration(hours: 6))), 'Name the shift, for example "Friday night".');
      expect(checkShiftForm(name: 'Friday', start: null, end: a), 'Choose when the shift starts.');
      expect(checkShiftForm(name: 'Friday', start: a, end: null), 'Choose when the shift ends.');
      expect(checkShiftForm(name: 'Friday', start: a, end: a), 'The shift has to end after it starts.');
      expect(checkShiftForm(name: 'Friday', start: a, end: a.add(const Duration(hours: 25))), 'A shift can be at most 24 hours long.');
      expect(checkShiftForm(name: 'Friday', start: a, end: a.add(const Duration(hours: 6))), isNull);
      expect(checkShiftForm(name: 'x' * 81, start: a, end: a.add(const Duration(hours: 6))), 'Keep the name to 80 characters or fewer.');
    });

    test('a shift in words, across midnight too', () {
      expect(describeShift(DateTime(2031, 10, 24, 21), DateTime(2031, 10, 24, 23, 30)), 'Fri 24 Oct 21:00 to 23:30');
      expect(describeShift(DateTime(2031, 10, 24, 21), DateTime(2031, 10, 25, 3)), 'Fri 24 Oct 21:00 to Sat 25 Oct 03:00');
    });

    test('which roles can be changed, and to what', () {
      expect(canChangeRole('server', MemberState.active, venueId: 'v1'), isTrue);
      expect(canChangeRole('manager', MemberState.active, venueId: 'v1'), isTrue);
      expect(canChangeRole('owner', MemberState.active, venueId: null), isFalse);
      expect(canChangeRole('organizer', MemberState.active, venueId: null), isFalse);
      expect(canChangeRole('door', MemberState.active, venueId: null), isFalse, reason: 'an event role has nothing to change to');
      expect(canChangeRole('server', MemberState.revoked, venueId: 'v1'), isFalse);
      expect(rolesToChangeTo(['manager', 'server', 'door'], 'server'), ['manager', 'door']);
    });
  });

  group('shifts', () {
    testWidgets('a shift is added from the Team screen: name and times are checked, then it is saved in UTC and listed', (tester) async {
      await open(tester, managerWs);
      await tapKey(tester, 'shifts-button');
      expect(find.byKey(const Key('shifts-empty')), findsOneWidget);
      await tapKey(tester, 'shift-save');
      expect(find.text('Name the shift, for example "Friday night".'), findsOneWidget);
      await typeIn(tester, 'shift-name', 'Friday night');
      await tapKey(tester, 'shift-save');
      expect(find.text('Choose when the shift starts.'), findsOneWidget);
      picks.addAll([DateTime(2031, 10, 24, 21), DateTime(2031, 10, 24, 20)]);
      await tapKey(tester, 'shift-start');
      await tapKey(tester, 'shift-end');
      await tapKey(tester, 'shift-save');
      expect(find.text('The shift has to end after it starts.'), findsOneWidget);
      expect(team.count('create_shift'), 0);
      picks.add(DateTime(2031, 10, 25, 3));
      await tapKey(tester, 'shift-end');
      await tapKey(tester, 'shift-save');
      expect(find.text('Shift added.'), findsOneWidget);
      final sent = team.paramsOf('create_shift').single!;
      expect(sent['p_venue'], 'v1');
      expect(sent['p_name'], 'Friday night');
      expect(sent['p_starts'], DateTime(2031, 10, 24, 21).toUtc().toIso8601String());
      expect(sent['p_ends'], DateTime(2031, 10, 25, 3).toUtc().toIso8601String());
      expect(find.text('Friday night'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('shift-name'))).controller!.text, isEmpty);
    });

    testWidgets('if the database refuses, the reason is shown and the form is kept', (tester) async {
      await open(tester, managerWs);
      await tapKey(tester, 'shifts-button');
      await typeIn(tester, 'shift-name', 'Friday night');
      picks.addAll([DateTime(2031, 10, 24, 21), DateTime(2031, 10, 25, 3)]);
      await tapKey(tester, 'shift-start');
      await tapKey(tester, 'shift-end');
      team.failAll = null;
      team.beforeCall = (f) {
        if (f == 'create_shift') throw refuse('not allowed');
      };
      await tapKey(tester, 'shift-save');
      expect(find.byKey(const Key('shift-problem')), findsOneWidget);
      expect(find.text("You don't have access to do that."), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('shift-name'))).controller!.text, 'Friday night');
    });

    testWidgets('existing shifts are listed with their times', (tester) async {
      team.shifts.add(shiftRow('s1', 'Saturday', starts: '2031-10-25T20:00:00Z', ends: '2031-10-26T02:00:00Z'));
      await open(tester, managerWs);
      await tapKey(tester, 'shifts-button');
      expect(find.text('Saturday'), findsOneWidget);
    });

    testWidgets('an owner of two clubs chooses the club for the shift', (tester) async {
      owner.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A'), myVenue('v2', 'Club B')];
      await open(tester, ownerWs);
      await tapKey(tester, 'shifts-button');
      expect(find.byKey(const Key('shift-venue')), findsOneWidget);
    });

    testWidgets('a person with no club has no Shifts button to press', (tester) async {
      owner.handlers['my_venues'] = (_) => [];
      await open(tester, ownerWs);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('shifts-button'))).onPressed, isNull);
    });
  });

  group('changing a role', () {
    testWidgets('the roles on offer are the ones this person may appoint, without the current one; choosing one asks first, then changes it', (tester) async {
      team.members.add(memberRow('m1', name: 'Sam Lee', role: 'server'));
      team.defaultRoles = ['manager', 'server', 'door', 'verifier'];
      await open(tester, ownerWs);
      await tapKey(tester, 'change-role-m1');
      expect(find.byKey(const Key('role-option-server')), findsNothing);
      expect(find.byKey(const Key('role-option-verifier')), findsOneWidget);
      expect(find.byKey(const Key('role-option-door')), findsOneWidget);
      await tapKey(tester, 'role-option-verifier');
      expect(find.text('Make Sam Lee payment verifier?'), findsOneWidget);
      await tapKey(tester, 'keep');
      expect(team.count('change_member_role'), 0);
      await tapKey(tester, 'change-role-m1');
      await tapKey(tester, 'role-option-verifier');
      await tapKey(tester, 'confirm-remove');
      expect(team.paramsOf('change_member_role').single, {'p_membership': 'm1', 'p_new_role': 'verifier'});
      expect(find.text('Role changed.'), findsOneWidget);
      expect(find.text('Payment verifier · Club A'), findsOneWidget);
      expect(find.text('History (1)'), findsOneWidget, reason: 'the old role is kept in the history');
    });

    testWidgets('owners and event staff have no Change role; a revoked person has none', (tester) async {
      team.members.addAll([
        memberRow('mo', role: 'owner', venue: null),
        memberRow('md', role: 'door', venue: null),
        memberRow('m1', name: 'Sam Lee', role: 'server'),
      ]);
      await open(tester, ownerWs);
      expect(find.byKey(const Key('change-role-mo')), findsNothing);
      expect(find.byKey(const Key('change-role-md')), findsNothing);
      expect(find.byKey(const Key('change-role-m1')), findsOneWidget);
    });

    testWidgets('a refusal from the database is shown in its own words', (tester) async {
      team.members.add(memberRow('m1', name: 'Sam Lee', role: 'server'));
      await open(tester, ownerWs);
      team.beforeCall = (f) {
        if (f == 'change_member_role') throw refuse('you cannot change your own role');
      };
      await tapKey(tester, 'change-role-m1');
      await tapKey(tester, 'role-option-door');
      await tapKey(tester, 'confirm-remove');
      expect(find.text('You cannot change your own role.'), findsOneWidget);
    });

    testWidgets('when there is no other role to give, the person is told', (tester) async {
      team.members.add(memberRow('m1', name: 'Sam Lee', role: 'server'));
      team.defaultRoles = ['server'];
      await open(tester, ownerWs);
      await tapKey(tester, 'change-role-m1');
      expect(find.text('There is no other role you can give Sam Lee here.'), findsOneWidget);
    });
  });
}
