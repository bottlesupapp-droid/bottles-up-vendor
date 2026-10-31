import 'dart:async';

import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/team/logic/team_rules.dart';
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:bottles_up_vendor/features/team/screens/team_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../owner/fake_owner_backend.dart';
import 'fake_team_backend.dart';

late FakeTeamBackend team;
late FakeOwnerBackend owner;
late List<DateTime?> picks;
late List<Uri> opened;
late List<String?> clipboard;

const ownerWs = Workspace(membershipId: 'm-o', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const managerWs = Workspace(membershipId: 'm-m', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
final fixedNow = DateTime(2031, 10, 24, 12);
const siteLink = 'https://www.bottlesupapp.com/accept-invite?token=';

Widget host(Workspace ws) => ProviderScope(
      key: UniqueKey(),
      overrides: [teamServiceProvider.overrideWithValue(team.service), ownerServiceProvider.overrideWithValue(owner.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: TeamScreen(
            workspace: ws,
            clock: () => fixedNow,
            pickDateTime: (context, initial) async => picks.isEmpty ? null : picks.removeAt(0),
            openUri: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );

Future<void> open(WidgetTester tester, Workspace ws) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(ws));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeKey(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Finder inProblems(String text) => find.descendant(of: find.byKey(const Key('problems')), matching: find.text(text));

void main() {
  setUp(() {
    team = FakeTeamBackend();
    owner = FakeOwnerBackend();
    picks = [];
    opened = [];
    clipboard = [];
    owner.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A'), myVenue('v2', 'Club B')];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String?);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  group('the list', () {
    testWidgets('says plainly when there is nobody and nothing waiting', (tester) async {
      await open(tester, ownerWs);
      expect(find.byKey(const Key('no-waiting')), findsOneWidget);
      expect(find.byKey(const Key('no-team')), findsOneWidget);
      expect(find.text('INVITATIONS WAITING (0)'), findsOneWidget);
      expect(find.text('TEAM (0)'), findsOneWidget);
    });

    testWidgets('shows each person with their role, where they work, how long they have access, and their state', (tester) async {
      team.members.addAll([
        memberRow('mo', name: 'Dana Reyes', email: 'dana@club.example', role: 'owner', venue: null),
        memberRow('m1', name: 'Sam Lee', role: 'manager'),
        memberRow('m2', email: 'door@club.example', role: 'door', state: 'scheduled', start: '2031-10-30T21:00:00Z', end: '2031-10-31T03:00:00Z'),
      ]);
      await open(tester, ownerWs);
      expect(find.text('TEAM (3)'), findsOneWidget);
      final owner0 = find.byKey(const Key('member-mo'));
      expect(find.descendant(of: owner0, matching: find.text('Dana Reyes')), findsOneWidget);
      expect(find.descendant(of: owner0, matching: find.text('Owner · Whole business')), findsOneWidget);
      expect(find.descendant(of: owner0, matching: find.text('Access: Ongoing')), findsOneWidget);
      final sam = find.byKey(const Key('member-m1'));
      expect(find.descendant(of: sam, matching: find.text('sam@club.example')), findsNothing, reason: 'the email is only shown once, as the name\'s subtitle');
      expect(find.descendant(of: sam, matching: find.text('Manager · Club A')), findsOneWidget);
      final door = find.byKey(const Key('member-m2'));
      expect(find.descendant(of: door, matching: find.text('door@club.example')), findsOneWidget, reason: 'no name: the email is the name');
      expect(find.descendant(of: door, matching: find.text('Starts later')), findsOneWidget);
      expect(find.descendant(of: door, matching: find.textContaining('Access: ')), findsOneWidget);
    });

    testWidgets('an owner can never be removed from here; a manager can', (tester) async {
      team.members.addAll([memberRow('mo', role: 'owner', venue: null), memberRow('m1', role: 'manager')]);
      await open(tester, ownerWs);
      expect(find.byKey(const Key('remove-mo')), findsNothing);
      expect(find.byKey(const Key('remove-m1')), findsOneWidget);
    });

    testWidgets('waiting invitations show their state, when the link works until, and how often they were emailed', (tester) async {
      team.invitations.addAll([
        invitationRow('i1', email: 'a@club.example', sent: 2),
        invitationRow('i2', email: 'b@club.example', state: 'expired'),
        invitationRow('i3', email: 'c@club.example', state: 'accepted'),
      ]);
      await open(tester, ownerWs);
      expect(find.text('INVITATIONS WAITING (2)'), findsOneWidget);
      final i1 = find.byKey(const Key('invitation-i1'));
      expect(find.descendant(of: i1, matching: find.text('Waiting')), findsOneWidget);
      expect(find.descendant(of: i1, matching: find.textContaining('Link works until Jan 8, 2031')), findsOneWidget);
      expect(find.descendant(of: i1, matching: find.textContaining('Emailed 2 times')), findsOneWidget);
      final i2 = find.byKey(const Key('invitation-i2'));
      expect(find.descendant(of: i2, matching: find.text('Expired')), findsOneWidget);
      expect(find.descendant(of: i2, matching: find.textContaining('Link expired')), findsOneWidget);
      expect(find.byKey(const Key('invitation-i3')), findsNothing, reason: 'an accepted invitation is history');
      for (final id in ['i1', 'i2']) {
        expect(find.byKey(Key('new-link-$id')), findsOneWidget);
        expect(find.byKey(Key('cancel-$id')), findsOneWidget);
      }
    });

    testWidgets('history is folded away, and holds ended and removed people and finished invitations', (tester) async {
      team.members.addAll([memberRow('m1'), memberRow('m2', name: 'Old Timer', state: 'revoked'), memberRow('m3', name: 'Night Temp', state: 'expired')]);
      team.invitations.addAll([invitationRow('i1', state: 'accepted'), invitationRow('i2', state: 'revoked', email: 'gone@club.example')]);
      await open(tester, ownerWs);
      expect(find.text('History (4)'), findsOneWidget);
      expect(find.byKey(const Key('past-m2')), findsNothing, reason: 'folded');
      await tapKey(tester, 'history');
      expect(find.descendant(of: find.byKey(const Key('past-m2')), matching: find.text('Removed')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('past-m3')), matching: find.text('Access ended')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('past-i2')), matching: find.text('Cancelled')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('past-i1')), matching: find.text('Accepted')), findsOneWidget);
      expect(find.text('TEAM (1)'), findsOneWidget, reason: 'only current people are on the team');
    });

    testWidgets('a server without the migration says so, with no retry; a dropped connection offers one that works', (tester) async {
      team.failAll = const PostgrestException(message: 'no function', code: '42883');
      await open(tester, ownerWs);
      expect(find.text('The team is not set up on this server yet.'), findsOneWidget);
      expect(find.byKey(const Key('team-retry')), findsNothing);

      team.failAll = Exception('socket closed');
      await open(tester, ownerWs);
      expect(find.byKey(const Key('team-retry')), findsOneWidget);
      team.failAll = null;
      team.members.add(memberRow('m1', name: 'Sam Lee'));
      await tapKey(tester, 'team-retry');
      expect(find.text('Sam Lee'), findsOneWidget);
      expect(find.byKey(const Key('team-error')), findsNothing);
    });

    testWidgets('an owner with no venue is told to add one first, and cannot invite', (tester) async {
      owner.handlers['my_venues'] = (_) => [];
      await open(tester, ownerWs);
      expect(find.byKey(const Key('no-venues')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('invite-button'))).onPressed, isNull);
    });
  });

  group('removing access and cancelling invitations', () {
    testWidgets('keeping at the confirmation changes nothing; confirming removes the person and the list moves them to history', (tester) async {
      team.members.add(memberRow('m1', name: 'Sam Lee'));
      await open(tester, ownerWs);
      await tapKey(tester, 'remove-m1');
      expect(find.text('Remove Sam Lee?'), findsOneWidget);
      expect(find.textContaining('They lose access immediately'), findsOneWidget);
      await tapKey(tester, 'keep');
      expect(team.count('revoke_membership'), 0);
      await tapKey(tester, 'remove-m1');
      await tapKey(tester, 'confirm-remove');
      expect(team.paramsOf('revoke_membership'), [
        {'p_membership': 'm1'},
      ]);
      expect(find.text('Access removed.'), findsOneWidget);
      expect(find.text('TEAM (0)'), findsOneWidget);
      expect(find.text('History (1)'), findsOneWidget);
    });

    testWidgets('dismissing the confirmation by tapping outside it removes nothing', (tester) async {
      team.members.add(memberRow('m1', name: 'Sam Lee'));
      await open(tester, ownerWs);
      await tapKey(tester, 'remove-m1');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Remove Sam Lee?'), findsNothing);
      expect(team.count('revoke_membership'), 0);
    });

    testWidgets('a refusal from the database is said, and the person stays', (tester) async {
      team.members.add(memberRow('m1', name: 'Sam Lee'));
      await open(tester, ownerWs);
      team.members[0] = {...team.members[0], 'state': 'revoked'}; // removed by someone else since the list was read
      await tapKey(tester, 'remove-m1');
      await tapKey(tester, 'confirm-remove');
      expect(find.text('Membership not found.'), findsOneWidget);
    });

    testWidgets('cancelling an invitation asks first, then the link stops working and the invitation leaves the waiting list', (tester) async {
      team.invitations.add(invitationRow('i1', email: 'a@club.example'));
      await open(tester, ownerWs);
      await tapKey(tester, 'cancel-i1');
      expect(find.text('Cancel the invitation to a@club.example?'), findsOneWidget);
      expect(find.textContaining('The link stops working'), findsOneWidget);
      await tapKey(tester, 'keep');
      expect(team.count('revoke_invitation'), 0);
      await tapKey(tester, 'cancel-i1');
      await tapKey(tester, 'confirm-remove');
      expect(team.paramsOf('revoke_invitation'), [
        {'p_invitation': 'i1'},
      ]);
      expect(find.text('Invitation cancelled.'), findsOneWidget);
      expect(find.byKey(const Key('invitation-i1')), findsNothing);
      expect(find.text('INVITATIONS WAITING (0)'), findsOneWidget);
    });
  });

  group('a new link', () {
    testWidgets('is asked for, emailed, shown once with its outcome, and the list is read again', (tester) async {
      team.invitations.add(invitationRow('i1', email: 'a@club.example', role: 'door'));
      await open(tester, ownerWs);
      await tapKey(tester, 'new-link-i1');
      expect(team.paramsOf('resend_invitation'), [
        {'p_invitation': 'i1'},
      ]);
      expect(team.emailed, [('i1', 'new-i1')]);
      expect(find.byKey(const Key('invite-result')), findsOneWidget);
      expect(find.text('We emailed the invitation to a@club.example.'), findsOneWidget);
      expect(find.text('$siteLink${'new-i1'}'), findsOneWidget);
      expect(team.count('list_team_invitations'), 2);
      expect(find.text('Send a new link'), findsOneWidget, reason: 'the button is usable again');
      expect(tester.widget<TextButton>(find.byKey(const Key('new-link-i1'))).onPressed, isNotNull);
    });

    testWidgets('when the email could not be sent the link is still shown, with a way to send it yourself', (tester) async {
      team.invitations.add(invitationRow('i1', email: 'a@club.example', state: 'expired'));
      team.emailAnswer = const EmailOutcome(sent: false, reason: 'not_configured');
      await open(tester, ownerWs);
      await tapKey(tester, 'new-link-i1');
      expect(find.textContaining('Email is not set up yet'), findsOneWidget);
      expect(find.text('$siteLink${'new-i1'}'), findsOneWidget);
      await tapKey(tester, 'open-mail');
      expect(opened.single.scheme, 'mailto');
      expect(Uri.decodeComponent(opened.single.path), 'a@club.example', reason: 'the message is addressed to the invited person');
      expect(Uri.decodeComponent(opened.single.toString()), contains('$siteLink${'new-i1'}'));
    });

    testWidgets('a refusal is said and no link is shown', (tester) async {
      team.invitations.add(invitationRow('i1'));
      await open(tester, ownerWs);
      team.invitations[0] = {...team.invitations[0], 'state': 'accepted'}; // accepted since the list was read
      await tapKey(tester, 'new-link-i1');
      expect(find.text('Already accepted.'), findsOneWidget);
      expect(find.byKey(const Key('invite-result')), findsNothing);
    });

    testWidgets('Copy puts the link on the clipboard; closing the card makes it go (it cannot be shown again)', (tester) async {
      team.invitations.add(invitationRow('i1'));
      await open(tester, ownerWs);
      await tapKey(tester, 'new-link-i1');
      await tapKey(tester, 'copy-link');
      expect(clipboard, ['$siteLink${'new-i1'}']);
      expect(find.text('Copied'), findsOneWidget);
      await tapKey(tester, 'close-result');
      expect(find.byKey(const Key('invite-result')), findsNothing);
      expect(find.textContaining(siteLink), findsNothing);
    });

    testWidgets('a second tap while the first is still going does nothing', (tester) async {
      team.invitations.add(invitationRow('i1'));
      await open(tester, ownerWs);
      final gate = Completer<void>();
      team.hold = gate.future;
      await tester.tap(find.byKey(const Key('new-link-i1')));
      await tester.pump();
      expect(find.text('Sending…'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('new-link-i1'))).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(team.count('resend_invitation'), 1);
    });
  });

  group('inviting someone', () {
    testWidgets('the roles come from the database for that club, the first is chosen, and the invitation goes out with its link', (tester) async {
      team.rolesByVenue['v1'] = ['server', 'door'];
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      expect(find.byKey(const Key('role-server')), findsOneWidget);
      expect(find.byKey(const Key('role-door')), findsOneWidget);
      expect(find.byKey(const Key('role-manager')), findsNothing);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('role-server'))).selected, isTrue);
      await typeKey(tester, 'invite-email', '  New.Person@Club.Example ');
      await tapKey(tester, 'role-door');
      await tapKey(tester, 'send-invite');

      final call = team.paramsOf('invite_member').single!;
      expect([call['p_org'], call['p_email'], call['p_role'], call['p_venue'], call['p_shift'], call['p_event'], call['p_access_start']],
          ['o1', 'new.person@club.example', 'door', 'v1', null, null, null]);
      expect(find.byKey(const Key('invite-result')), findsOneWidget);
      expect(find.text('We emailed the invitation to new.person@club.example.'), findsOneWidget);
      expect(find.byKey(const Key('open-mail')), findsNothing, reason: 'it was emailed, so there is nothing to send by hand');
      expect(find.textContaining(siteLink), findsOneWidget);
      expect(team.emailed.single.$1, team.invitations.single['invitation_id']);
      expect(find.text('INVITATIONS WAITING (1)'), findsOneWidget);
      expect(find.text('Door staff · Club A'), findsOneWidget);
    });

    testWidgets('an empty form says what is missing and sends nothing', (tester) async {
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await tapKey(tester, 'send-invite');
      expect(inProblems('Enter the email address of the person you are inviting.'), findsOneWidget);
      expect(team.count('invite_member'), 0);
    });

    testWidgets('a person who may appoint nobody at that club is told so and cannot send', (tester) async {
      team.rolesByVenue['v1'] = [];
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      expect(find.byKey(const Key('no-roles')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('send-invite'))).onPressed, isNull);
    });

    testWidgets('roles that cannot be loaded are said, not shown as empty', (tester) async {
      await open(tester, ownerWs);
      team.beforeCall = (f) {
        if (f == 'invitable_roles') throw Exception('socket closed');
      };
      await tapKey(tester, 'invite-button');
      expect(find.byKey(const Key('roles-error')), findsOneWidget);
      expect(find.byKey(const Key('no-roles')), findsNothing);
    });

    testWidgets('a refusal from the database is shown in the form and nothing typed is lost', (tester) async {
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'new@club.example');
      team.beforeCall = (f) {
        if (f == 'invite_member') throw const PostgrestException(message: 'shift does not belong to this venue', code: 'P0001');
      };
      await tapKey(tester, 'send-invite');
      expect(inProblems('Shift does not belong to this venue.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('invite-email'))).controller!.text, 'new@club.example');
      expect(tester.widget<FilledButton>(find.byKey(const Key('send-invite'))).onPressed, isNotNull);
    });

    testWidgets('a second tap on Send while the first is still going does not invite twice', (tester) async {
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'new@club.example');
      final gate = Completer<void>();
      team.hold = gate.future;
      await tester.tap(find.byKey(const Key('send-invite')));
      await tester.pump();
      expect(find.text('Sending…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('send-invite')), warnIfMissed: false);
      gate.complete();
      await tester.pumpAndSettle();
      expect(team.count('invite_member'), 1);
    });

    testWidgets('temporary access sends its window; an end before the start is refused first; cancelling a picker changes nothing', (tester) async {
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'temp@club.example');
      expect(find.byKey(const Key('pick-start')), findsNothing, reason: 'ongoing access has no window');
      await tapKey(tester, 'invite-temporary');
      await tapKey(tester, 'send-invite');
      expect(inProblems('Temporary access needs a start and an end.'), findsOneWidget);

      final start = DateTime(2031, 10, 24, 21);
      final end = DateTime(2031, 10, 25, 3);
      picks = [null];
      await tapKey(tester, 'pick-start');
      expect(find.text('Choose start'), findsOneWidget);
      picks = [end, start]; // start chosen after end
      await tapKey(tester, 'pick-start');
      await tapKey(tester, 'pick-end');
      await tapKey(tester, 'send-invite');
      expect(inProblems('The end must be after the start.'), findsOneWidget);
      expect(team.count('invite_member'), 0);
      expect(team.count('invite_temporary_staff'), 0);

      picks = [start, end];
      await tapKey(tester, 'pick-start');
      await tapKey(tester, 'pick-end');
      await tapKey(tester, 'send-invite');
      expect(team.count('invite_member'), 0, reason: 'temporary access is a secure link, not an ordinary invitation');
      final call = team.paramsOf('invite_temporary_staff').single!;
      expect([call['p_access_start'], call['p_access_end']], [start.toUtc().toIso8601String(), end.toUtc().toIso8601String()]);
      expect(call['p_valid_hours'], 24);
      expect(find.byKey(const Key('invite-result')), findsOneWidget);
      expect(find.byKey(const Key('invite-code-note')), findsOneWidget);
    });

    testWidgets('with shifts available, none is the default', (tester) async {
      team.shifts.add(shiftRow('s1', 'Late shift'));
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'a@club.example');
      await tapKey(tester, 'send-invite');
      expect(team.paramsOf('invite_member').single!['p_shift'], isNull);
    });

    testWidgets('with a shift chosen it is sent', (tester) async {
      team.shifts.add(shiftRow('s1', 'Late shift'));
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'a@club.example');
      await tapKey(tester, 'invite-shift');
      await tester.tap(find.textContaining('Late shift').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'send-invite');
      expect(team.paramsOf('invite_member').single!['p_shift'], 's1');
    });

    testWidgets('no shift picker when the club has no shifts', (tester) async {
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      expect(find.byKey(const Key('invite-shift')), findsNothing);
    });

    testWidgets('an owner of two clubs chooses the club; the roles are read again for it, and the invitation is for it', (tester) async {
      team.rolesByVenue['v1'] = ['server'];
      team.rolesByVenue['v2'] = ['security'];
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      expect(find.byKey(const Key('role-server')), findsOneWidget);
      await tapKey(tester, 'invite-venue');
      await tester.tap(find.text('Club B').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('role-security')), findsOneWidget);
      expect(find.byKey(const Key('role-server')), findsNothing);
      expect(team.paramsOf('invitable_roles').map((p) => p!['p_venue']), containsAll(['v1', 'v2']));
      await typeKey(tester, 'invite-email', 'b@club.example');
      await tapKey(tester, 'send-invite');
      final call = team.paramsOf('invite_member').single!;
      expect([call['p_venue'], call['p_role']], ['v2', 'security']);
    });

    testWidgets('when the email could not be sent, the new invitation still has its link and a way to send it yourself', (tester) async {
      team.emailAnswer = const EmailOutcome(sent: false, reason: 'send_failed');
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'a@club.example');
      await tapKey(tester, 'send-invite');
      expect(find.text('We could not send the email. Copy the link below and send it yourself.'), findsOneWidget);
      expect(find.byKey(const Key('open-mail')), findsOneWidget);
      expect(find.textContaining(siteLink), findsOneWidget);
    });
  });

  group('shifts belong to a club', () {
    testWidgets('a shift chosen at one club is not sent for another, and is not still chosen when coming back', (tester) async {
      team.shifts.add(shiftRow('s1', 'Late shift'));
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'a@club.example');
      await tapKey(tester, 'invite-shift');
      await tester.tap(find.textContaining('Late shift').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'invite-venue');
      await tester.tap(find.text('Club B').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-shift')), findsNothing, reason: 'Club B has no shifts');
      await tapKey(tester, 'invite-venue');
      await tester.tap(find.text('Club A').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-shift')), findsOneWidget);
      await tapKey(tester, 'send-invite');
      expect(team.paramsOf('invite_member').single!['p_shift'], isNull);
    });

    testWidgets('going to another club and sending sends no shift of the first', (tester) async {
      team.shifts.add(shiftRow('s1', 'Late shift'));
      await open(tester, ownerWs);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'a@club.example');
      await tapKey(tester, 'invite-shift');
      await tester.tap(find.textContaining('Late shift').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'invite-venue');
      await tester.tap(find.text('Club B').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'send-invite');
      final call = team.paramsOf('invite_member').single!;
      expect([call['p_venue'], call['p_shift']], ['v2', null]);
    });
  });

  group('a manager', () {
    testWidgets('with no club on the workspace cannot invite anyone', (tester) async {
      const noClub = Workspace(membershipId: 'm-m', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager);
      await open(tester, noClub);
      expect(find.byKey(const Key('no-venues')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('invite-button'))).onPressed, isNull);
    });

    testWidgets('invites only to their own club: no choice of club, and the owner\'s venue list is never read', (tester) async {
      team.defaultRoles = ['server', 'door'];
      await open(tester, managerWs);
      expect(owner.count('my_venues'), 0);
      await tapKey(tester, 'invite-button');
      expect(find.byKey(const Key('invite-venue')), findsNothing);
      expect(find.text('Club: Club A'), findsOneWidget);
      expect(find.byKey(const Key('role-manager')), findsNothing, reason: 'the database does not offer a manager the manager role');
      await typeKey(tester, 'invite-email', 'a@club.example');
      await tapKey(tester, 'send-invite');
      expect(team.paramsOf('invite_member').single!['p_venue'], 'v1');
      expect(team.paramsOf('list_team'), everyElement({'p_org': 'o1'}), reason: 'the database narrows what a manager sees; the app asks the same question');
    });
  });
}
