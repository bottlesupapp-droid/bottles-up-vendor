import 'package:bottles_up_vendor/features/door_staff/providers/door_staff_providers.dart';
import 'package:bottles_up_vendor/features/door_staff/screens/organizer_team_screen.dart';
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../team/fake_team_backend.dart';
import 'fake_door_staff_backend.dart';

late FakeDoorStaffBackend db;
late List<DateTime?> picks;

const orgWs = Workspace(membershipId: 'm-g', orgId: 'o1', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);
final fixedNow = DateTime(2031, 10, 20, 12);

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        doorStaffServiceProvider.overrideWithValue(db.doorService),
        teamServiceProvider.overrideWithValue(db.teamService),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: OrganizerTeamScreen(workspace: orgWs, clock: () => fixedNow, pickDateTime: (context, initial) async => picks.isEmpty ? null : picks.removeAt(0), openUri: (_) async => true)),
      ),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeKey(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Map<String, dynamic> doorMember(String id, String event, {String name = 'Dan Door', String state = 'active', String role = 'door'}) =>
    {...memberRow(id, name: name, role: role, state: state, venue: null), 'event_id': event, 'event_title': 'Event'};

Map<String, dynamic> doorInvite(String id, String event, {String email = 'new@x.example', String state = 'pending'}) =>
    {...invitationRow(id, email: email, state: state), 'event_id': event, 'event_title': 'Event', 'venue_id': null, 'venue_name': null};

void main() {
  setUp(() {
    db = FakeDoorStaffBackend();
    picks = [];
    db.statuses.addAll([
      statusRow('e1', 'Rooftop Sessions', 'own_event'),
      statusRow('e2', 'Club Night', 'allowed', club: 'Club A', agreement: 'a2'),
      statusRow('e3', 'Harbour Party', 'not_allowed', club: 'Club B', agreement: 'a3'),
      statusRow('e4', 'Summer Closing', 'awaiting_approval', club: 'Club C', agreement: 'a4'),
    ]);
  });

  testWidgets('each event says whether door staff may be invited, and Invite is offered only where the database would accept it', (tester) async {
    await open(tester);
    expect(find.descendant(of: find.byKey(const Key('team-state-e1')), matching: find.text('Your own event')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('team-state-e2')), matching: find.text('Allowed')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('team-state-e3')), matching: find.text('Not allowed yet')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('team-state-e4')), matching: find.text('Awaiting the club')), findsOneWidget);
    expect(find.byKey(const Key('team-invite-e1')), findsOneWidget);
    expect(find.byKey(const Key('team-invite-e2')), findsOneWidget);
    expect(find.byKey(const Key('team-invite-e3')), findsNothing);
    expect(find.byKey(const Key('team-invite-e4')), findsNothing);
    expect(find.text('Club B has not allowed door staff for this event. Ask Club B to allow it.'), findsOneWidget);
    expect(find.textContaining('cannot change prices'), findsOneWidget);
  });

  testWidgets('door staff and waiting invitations sit under their own event; other roles and removed people are not listed', (tester) async {
    db.team.members.addAll([
      doorMember('m1', 'e1'),
      doorMember('m2', 'e2', name: 'Ella Entry'),
      doorMember('m3', 'e1', name: 'Gone Gary', state: 'revoked'),
      doorMember('m4', 'e1', name: 'Sec Sam', role: 'security'),
    ]);
    db.team.invitations.addAll([doorInvite('i1', 'e1', email: 'wait@x.example'), doorInvite('i2', 'e1', email: 'old@x.example', state: 'expired'), doorInvite('i3', 'e2', email: 'done@x.example', state: 'accepted')]);
    await open(tester);
    expect(find.descendant(of: find.byKey(const Key('team-event-e1')), matching: find.text('Dan Door')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('team-event-e2')), matching: find.text('Ella Entry')), findsOneWidget);
    expect(find.text('Gone Gary'), findsNothing);
    expect(find.text('Sec Sam'), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('team-event-e1')), matching: find.text('wait@x.example')), findsOneWidget);
    expect(find.text('Invited, not accepted yet'), findsOneWidget);
    expect(find.text('Invitation expired'), findsOneWidget);
    expect(find.text('done@x.example'), findsNothing, reason: 'an accepted invitation is the person above');
    expect(find.byKey(const Key('team-none-e3')), findsOneWidget);
  });

  testWidgets('inviting: the email goes to the database for THIS event as door staff, and the link is shown once', (tester) async {
    await open(tester);
    await tapKey(tester, 'team-invite-e2');
    expect(find.text('Club Night'), findsOneWidget);
    await typeKey(tester, 'invite-door-email', '  Ella@Gate.example ');
    await tapKey(tester, 'invite-door-submit');
    final p = db.paramsOf('invite_member').single!;
    expect(p['p_org'], 'o1');
    expect(p['p_email'], 'ella@gate.example');
    expect(p['p_role'], 'door');
    expect(p['p_event'], 'e2');
    expect(p['p_venue'], isNull);
    expect(p['p_access_start'], isNull);
    expect(db.team.emailed, hasLength(1));
    expect(find.byKey(const Key('invite-result')), findsOneWidget);
    expect(find.byKey(const Key('team-invitation-i1')), findsOneWidget, reason: 'the list was read again');
  });

  testWidgets('a time window is sent in UTC, and only when asked for', (tester) async {
    await open(tester);
    await tapKey(tester, 'team-invite-e1');
    await typeKey(tester, 'invite-door-email', 'ella@gate.example');
    await tapKey(tester, 'invite-door-limit');
    picks = [DateTime(2031, 10, 24, 20), DateTime(2031, 10, 25, 4)];
    await tapKey(tester, 'invite-door-start');
    await tapKey(tester, 'invite-door-end');
    await tapKey(tester, 'invite-door-submit');
    final p = db.paramsOf('invite_member').single!;
    expect(p['p_access_start'], DateTime(2031, 10, 24, 20).toUtc().toIso8601String());
    expect(p['p_access_end'], DateTime(2031, 10, 25, 4).toUtc().toIso8601String());
  });

  testWidgets('a window that was picked and then switched off is not sent', (tester) async {
    await open(tester);
    await tapKey(tester, 'team-invite-e1');
    await typeKey(tester, 'invite-door-email', 'ella@gate.example');
    await tapKey(tester, 'invite-door-limit');
    picks = [DateTime(2031, 10, 24, 20), DateTime(2031, 10, 25, 4)];
    await tapKey(tester, 'invite-door-start');
    await tapKey(tester, 'invite-door-end');
    await tapKey(tester, 'invite-door-limit');
    await tapKey(tester, 'invite-door-submit');
    final p = db.paramsOf('invite_member').single!;
    expect(p['p_access_start'], isNull);
    expect(p['p_access_end'], isNull);
  });

  group('the form checks before anything is sent', () {
    Future<void> openForm(WidgetTester tester) async {
      await open(tester);
      await tapKey(tester, 'team-invite-e1');
    }

    testWidgets('a bad email', (tester) async {
      await openForm(tester);
      await typeKey(tester, 'invite-door-email', 'not an email');
      await tapKey(tester, 'invite-door-submit');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(db.count('invite_member'), 0);
    });

    testWidgets('a time limit needs both ends, in the right order, in the future', (tester) async {
      await openForm(tester);
      await typeKey(tester, 'invite-door-email', 'ella@gate.example');
      await tapKey(tester, 'invite-door-limit');
      await tapKey(tester, 'invite-door-submit');
      expect(find.textContaining('Choose when the access starts and ends'), findsOneWidget);
      picks = [DateTime(2031, 10, 25, 4), DateTime(2031, 10, 24, 20)];
      await tapKey(tester, 'invite-door-start');
      await tapKey(tester, 'invite-door-end');
      await tapKey(tester, 'invite-door-submit');
      expect(find.text('The access must end after it starts.'), findsOneWidget);
      picks = [DateTime(2031, 10, 1, 4), DateTime(2031, 10, 2, 4)];
      await tapKey(tester, 'invite-door-start');
      await tapKey(tester, 'invite-door-end');
      await tapKey(tester, 'invite-door-submit');
      expect(find.text('The access must end in the future.'), findsOneWidget);
      expect(db.count('invite_member'), 0);
    });
  });

  testWidgets('if the club turned the permission off in the meantime the database\'s sentence is shown and what was typed is kept', (tester) async {
    await open(tester);
    await tapKey(tester, 'team-invite-e2');
    await typeKey(tester, 'invite-door-email', 'ella@gate.example');
    db.statuses[1]['state'] = 'not_allowed';
    await tapKey(tester, 'invite-door-submit');
    expect(find.byKey(const Key('invite-door-problem')), findsOneWidget);
    expect(find.text('The club has not allowed door staff for this event.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('invite-door-email'))).controller!.text, 'ella@gate.example');
    expect(find.byKey(const Key('invite-result')), findsNothing);
  });

  testWidgets('a second tap while sending does not send twice', (tester) async {
    await open(tester);
    await tapKey(tester, 'team-invite-e1');
    await typeKey(tester, 'invite-door-email', 'ella@gate.example');
    db.team.hold = Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('invite-door-submit')));
    await tester.pump();
    expect(find.text('Sending...'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('invite-door-submit'))).onPressed, isNull);
    await tester.pumpAndSettle();
    expect(db.count('invite_member'), 1);
  });

  testWidgets('removing a door staff member asks first and then removes their access', (tester) async {
    db.team.members.add(doorMember('m1', 'e1'));
    await open(tester);
    await tapKey(tester, 'team-remove-m1');
    expect(find.text('Remove Dan Door?'), findsOneWidget);
    await tapKey(tester, 'keep');
    expect(db.count('revoke_membership'), 0);
    await tapKey(tester, 'team-remove-m1');
    await tapKey(tester, 'confirm-remove');
    expect(db.paramsOf('revoke_membership').single, {'p_membership': 'm1'});
    expect(find.byKey(const Key('team-member-m1')), findsNothing);
  });

  testWidgets('cancelling a waiting invitation', (tester) async {
    db.team.invitations.add(doorInvite('i1', 'e1', email: 'wait@x.example'));
    await open(tester);
    await tapKey(tester, 'team-cancel-i1');
    expect(db.paramsOf('revoke_invitation').single, {'p_invitation': 'i1'});
    expect(find.byKey(const Key('team-invitation-i1')), findsNothing);
  });

  testWidgets('an organizer with no events is told what to do', (tester) async {
    db.statuses.clear();
    await open(tester);
    expect(find.byKey(const Key('team-no-events')), findsOneWidget);
  });

  testWidgets('a failed read is plain with Try again, and is not shown as "no events"', (tester) async {
    db.failAll = StateError('relation "site_agreements" does not exist');
    await open(tester);
    expect(find.byKey(const Key('team-error')), findsOneWidget);
    expect(find.textContaining('relation'), findsNothing);
    expect(find.byKey(const Key('team-no-events')), findsNothing);
    db.failAll = null;
    await tapKey(tester, 'team-retry');
    expect(find.byKey(const Key('team-event-e1')), findsOneWidget);
  });

  testWidgets('if the people cannot be read the events still show with their state', (tester) async {
    db.failTeam = StateError('x');
    await open(tester);
    expect(find.byKey(const Key('team-event-e2')), findsOneWidget);
    expect(find.byKey(const Key('team-invite-e2')), findsOneWidget);
  });
}
