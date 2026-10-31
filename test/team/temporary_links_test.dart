import 'dart:io';

import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/team/logic/team_rules.dart';
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:bottles_up_vendor/features/team/screens/team_screen.dart';
import 'package:bottles_up_vendor/features/team/services/team_service.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../owner/fake_owner_backend.dart';
import 'fake_team_backend.dart';

// Temporary staff: inviting them with a secure link, and what the people who manage the team see (website repo, 20261118100000_temporary_staff_links.sql).

late FakeTeamBackend team;
late FakeOwnerBackend owner;
late List<DateTime?> picks;

const ownerWs = Workspace(membershipId: 'm-o', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
final fixedNow = DateTime(2031, 10, 24, 12);

InviteForm form({bool temporary = true, String role = 'door', int hours = 24, DateTime? start, DateTime? end}) =>
    InviteForm(email: 'new@club.example', role: role, venueId: 'v1', temporary: temporary, start: start ?? DateTime(2031, 10, 24, 21), end: end ?? DateTime(2031, 10, 25, 3), validHours: hours);

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [teamServiceProvider.overrideWithValue(team.service), ownerServiceProvider.overrideWithValue(owner.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: TeamScreen(workspace: ownerWs, clock: () => fixedNow, pickDateTime: (context, initial) async => picks.isEmpty ? null : picks.removeAt(0), openUri: (uri) async => true),
        ),
      ),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2600);
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

Finder inProblems(String text) => find.descendant(of: find.byKey(const Key('problems')), matching: find.text(text));

void main() {
  setUp(() {
    team = FakeTeamBackend();
    owner = FakeOwnerBackend();
    picks = [];
    owner.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A'), myVenue('v2', 'Club B')];
    team.defaultRoles = ['manager', 'server', 'door', 'security'];
  });

  group('the form', () {
    test('temporary access is for a server, door staff, security or a verifier, never a manager', () {
      expect(validateInvite(form(role: 'door'), now: fixedNow), isEmpty);
      for (final r in ['server', 'door', 'security', 'verifier']) {
        expect(validateInvite(form(role: r), now: fixedNow), isEmpty, reason: r);
      }
      expect(validateInvite(form(role: 'manager'), now: fixedNow), ['Temporary access is for servers, door staff, security and verifiers.']);
      expect(validateInvite(form(role: 'manager', temporary: false), now: fixedNow), isEmpty, reason: 'an ordinary invitation to a manager is unchanged');
      expect(temporaryRoles, {'server', 'door', 'security', 'verifier'});
    });

    test('the link must stay valid for between one hour and seven days', () {
      expect(validateInvite(form(hours: 1), now: fixedNow), isEmpty);
      expect(validateInvite(form(hours: 168), now: fixedNow), isEmpty);
      expect(validateInvite(form(hours: 0), now: fixedNow), ['The link must stay valid for between 1 hour and 7 days.']);
      expect(validateInvite(form(hours: 169), now: fixedNow), ['The link must stay valid for between 1 hour and 7 days.']);
      expect(validateInvite(form(hours: 169, temporary: false), now: fixedNow), isEmpty, reason: 'an ordinary invitation has no such rule');
    });

    test('the suggestion is a day, and every choice is within the rule', () {
      expect(defaultTemporaryLinkHours, 24);
      expect(temporaryLinkHourChoices, contains(defaultTemporaryLinkHours));
      for (final h in temporaryLinkHourChoices) {
        expect(h >= 1 && h <= 168, isTrue, reason: '$h');
      }
    });

    test('link lengths are said in hours or days', () {
      expect(linkValidityLabel(1), '1 hour');
      expect(linkValidityLabel(6), '6 hours');
      expect(linkValidityLabel(24), '1 day');
      expect(linkValidityLabel(48), '2 days');
      expect(linkValidityLabel(168), '7 days');
      expect(linkValidityLabel(36), '36 hours');
    });

    test('a temporary payload with no length asks for the suggested day', () {
      final params = inviteTemporaryParams('o1', InvitePayload(email: 'a@club.example', role: 'door', venueId: 'v1', accessEndAt: DateTime(2031, 12, 1), temporary: true));
      expect(params['p_valid_hours'], 24);
    });

    test('the payload carries the choice only for a temporary invitation', () {
      final t = buildInvitePayload(form(hours: 48));
      expect([t.temporary, t.validHours], [true, 48]);
      final o = buildInvitePayload(form(temporary: false, hours: 48));
      expect([o.temporary, o.validHours], [false, null]);
    });

    test('invite_temporary_staff gets the ordinary parameters and how long the link lives; invite_member gets no such thing', () {
      final p = buildInvitePayload(form(hours: 48));
      final params = inviteTemporaryParams('o1', p);
      expect(params.keys.toSet(), {'p_org', 'p_email', 'p_role', 'p_venue', 'p_event', 'p_shift', 'p_access_start', 'p_access_end', 'p_valid_hours'});
      expect(params['p_valid_hours'], 48);
      expect(params['p_event'], isNull);
      expect(inviteParams('o1', p).containsKey('p_valid_hours'), isFalse);
    });
  });

  group('the calls', () {
    test('a temporary invitation calls the secure function, an ordinary one the ordinary function', () async {
      await team.service.invite('o1', buildInvitePayload(form(hours: 6)));
      expect(team.count('invite_temporary_staff'), 1);
      expect(team.count('invite_member'), 0);
      expect(team.paramsOf('invite_temporary_staff').single!['p_valid_hours'], 6);
      await team.service.invite('o1', buildInvitePayload(form(temporary: false)));
      expect(team.count('invite_member'), 1);
      expect(team.count('invite_temporary_staff'), 1);
    });

    test('the database\'s sentence is shown when it refuses', () async {
      await expectLater(
        team.service.invite('o1', InvitePayload(email: 'a@club.example', role: 'manager', venueId: 'v1', accessEndAt: DateTime(2031, 12, 1), temporary: true, validHours: 24)),
        throwsA(isA<TeamActionException>().having((e) => e.message, 'message', 'Temporary access is for servers, door staff, security and verifiers.')),
      );
    });

    test('the waiting invitations come with the extras, matched by invitation', () async {
      team.invitations.addAll([
        {...invitationRow('i1', email: 'temp@club.example'), 'kind': 'temporary', 'identity_verified': true},
        {...invitationRow('i2', email: 'asked@club.example', state: 'expired'), 'kind': 'temporary', 'renewal_requested_at': '2031-10-24T10:00:00Z', 'renewal_note': 'late again'},
        invitationRow('i3', email: 'plain@club.example'),
      ]);
      final list = await team.service.invitations('o1');
      final by = {for (final i in list) i.invitationId: i};
      expect([by['i1']!.isTemporary, by['i1']!.identityConfirmed, by['i1']!.renewalRequested], [true, true, false]);
      expect([by['i2']!.isTemporary, by['i2']!.identityConfirmed, by['i2']!.renewalRequested, by['i2']!.renewalNote], [true, false, true, 'late again']);
      expect([by['i3']!.isTemporary, by['i3']!.renewalRequested], [false, false]);
      expect(team.paramsOf('list_invitation_extras').single, {'p_org': 'o1'});
    });

    test('where the server does not have the extras the invitations are still listed', () async {
      team.invitations.add(invitationRow('i1'));
      team.beforeCall = (fn) {
        if (fn == 'list_invitation_extras') throw const PostgrestException(message: 'function list_invitation_extras does not exist', code: '42883');
      };
      final list = await team.service.invitations('o1');
      expect(list.single.invitationId, 'i1');
      expect(list.single.isTemporary, isFalse);
    });

    test('a row of the extras without an invitation is dropped', () {
      expect(parseInvitationExtras({'kind': 'temporary'}), isNull);
      expect(parseInvitationExtras({'invitation_id': 'i1', 'kind': 'permanent'})!.isTemporary, isFalse);
    });
  });

  group('the invite screen', () {
    testWidgets('the link\'s length is only asked for when access is temporary, and a day is suggested', (tester) async {
      await open(tester);
      await tapKey(tester, 'invite-button');
      expect(find.byKey(const Key('invite-valid-hours')), findsNothing);
      await tapKey(tester, 'invite-temporary');
      expect(find.byKey(const Key('invite-valid-hours')), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
    });

    testWidgets('the chosen length is sent, with the window, to the secure function', (tester) async {
      await open(tester);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'temp@club.example');
      await tapKey(tester, 'role-door');
      await tapKey(tester, 'invite-temporary');
      picks = [DateTime(2031, 10, 24, 21), DateTime(2031, 10, 25, 3)];
      await tapKey(tester, 'pick-start');
      await tapKey(tester, 'pick-end');
      await tapKey(tester, 'invite-valid-hours');
      await tester.tap(find.text('6 hours').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'send-invite');
      final call = team.paramsOf('invite_temporary_staff').single!;
      expect([call['p_role'], call['p_valid_hours'], call['p_email']], ['door', 6, 'temp@club.example']);
      expect(team.count('invite_member'), 0);
    });

    testWidgets('a manager is not offered while access is temporary, and comes back when it is not', (tester) async {
      await open(tester);
      await tapKey(tester, 'invite-button');
      expect(find.byKey(const Key('role-manager')), findsOneWidget);
      await tapKey(tester, 'invite-temporary');
      expect(find.byKey(const Key('role-manager')), findsNothing);
      expect(find.byKey(const Key('role-door')), findsOneWidget);
      await tapKey(tester, 'invite-temporary');
      expect(find.byKey(const Key('role-manager')), findsOneWidget);
    });

    testWidgets('a manager chosen first is not sent as temporary staff: the first allowed role is used', (tester) async {
      await open(tester);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'temp@club.example');
      await tapKey(tester, 'role-manager');
      await tapKey(tester, 'invite-temporary');
      picks = [DateTime(2031, 10, 24, 21), DateTime(2031, 10, 25, 3)];
      await tapKey(tester, 'pick-start');
      await tapKey(tester, 'pick-end');
      await tapKey(tester, 'send-invite');
      expect(team.paramsOf('invite_temporary_staff').single!['p_role'], 'server');
    });

    testWidgets('someone who can only appoint managers is told temporary access is not for them, and cannot send', (tester) async {
      team.defaultRoles = ['manager'];
      await open(tester);
      await tapKey(tester, 'invite-button');
      await tapKey(tester, 'invite-temporary');
      expect(find.byKey(const Key('no-temporary-roles')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('send-invite'))).onPressed, isNull);
      await tapKey(tester, 'invite-temporary');
      expect(find.byKey(const Key('no-temporary-roles')), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const Key('send-invite'))).onPressed, isNotNull);
    });

    testWidgets('the result says the person will be asked for a code, where it goes and how long the link works', (tester) async {
      await open(tester);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'temp@club.example');
      await tapKey(tester, 'invite-temporary');
      picks = [DateTime(2031, 10, 24, 21), DateTime(2031, 10, 25, 3)];
      await tapKey(tester, 'pick-start');
      await tapKey(tester, 'pick-end');
      await tapKey(tester, 'send-invite');
      expect(find.byKey(const Key('invite-result')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('invite-code-note'))).data,
          'They will be asked for a 6-digit code sent to temp@club.example before the link works. The link is valid for 1 day.');
    });

    testWidgets('the result says how long the chosen link works', (tester) async {
      await open(tester);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'temp@club.example');
      await tapKey(tester, 'invite-temporary');
      picks = [DateTime(2031, 10, 24, 21), DateTime(2031, 10, 25, 3)];
      await tapKey(tester, 'pick-start');
      await tapKey(tester, 'pick-end');
      await tapKey(tester, 'invite-valid-hours');
      await tester.tap(find.text('3 days').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'send-invite');
      expect(tester.widget<Text>(find.byKey(const Key('invite-code-note'))).data, endsWith('The link is valid for 3 days.'));
      expect(team.paramsOf('invite_temporary_staff').single!['p_valid_hours'], 72);
    });

    testWidgets('an ordinary invitation says nothing about a code', (tester) async {
      await open(tester);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'plain@club.example');
      await tapKey(tester, 'send-invite');
      expect(find.byKey(const Key('invite-result')), findsOneWidget);
      expect(find.byKey(const Key('invite-code-note')), findsNothing);
      expect(team.count('invite_member'), 1);
    });

    testWidgets('a refusal from the database is shown and nothing is claimed to be sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'invite-button');
      await typeKey(tester, 'invite-email', 'temp@club.example');
      await tapKey(tester, 'invite-temporary');
      picks = [DateTime(2031, 10, 24, 21), DateTime(2031, 10, 25, 3)];
      await tapKey(tester, 'pick-start');
      await tapKey(tester, 'pick-end');
      team.beforeCall = (fn) {
        if (fn == 'invite_temporary_staff') throw const PostgrestException(message: 'not allowed', code: 'P0001');
      };
      await tapKey(tester, 'send-invite');
      expect(inProblems("You don't have access to do that."), findsOneWidget);
      expect(find.byKey(const Key('invite-result')), findsNothing);
    });
  });

  group('the team screen', () {
    setUp(() {
      team.invitations.addAll([
        invitationRow('i-plain', email: 'plain@club.example'),
        {...invitationRow('i-temp', email: 'temp@club.example'), 'kind': 'temporary', 'identity_verified': false},
        {...invitationRow('i-ok', email: 'ok@club.example'), 'kind': 'temporary', 'identity_verified': true},
        {...invitationRow('i-ask', email: 'asked@club.example', state: 'expired'), 'kind': 'temporary', 'renewal_requested_at': '2031-10-24T10:00:00Z', 'renewal_note': 'I was running late'},
      ]);
    });

    testWidgets('a temporary invitation says so and whether the address was confirmed; an ordinary one says neither', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('temporary-i-temp')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('confirmed-i-temp')), matching: find.text('Address not confirmed yet')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('confirmed-i-ok')), matching: find.text('Address confirmed')), findsOneWidget);
      expect(find.byKey(const Key('temporary-i-plain')), findsNothing);
      expect(find.byKey(const Key('confirmed-i-plain')), findsNothing);
      expect(find.byKey(const Key('renewal-i-plain')), findsNothing);
    });

    testWidgets('an ordinary invitation that asked for a new link is flagged for that, and is not called temporary', (tester) async {
      team.invitations.add({...invitationRow('i-perm-ask', email: 'perm@club.example', state: 'expired'), 'kind': 'permanent', 'renewal_requested_at': '2031-10-24T09:00:00Z'});
      await open(tester);
      expect(find.byKey(const Key('renewal-i-perm-ask')), findsOneWidget);
      expect(find.byKey(const Key('temporary-i-perm-ask')), findsNothing);
      expect(find.byKey(const Key('confirmed-i-perm-ask')), findsNothing);
    });

    testWidgets('someone who asked for a new link is flagged, with what they wrote, and comes first', (tester) async {
      await open(tester);
      expect(find.descendant(of: find.byKey(const Key('renewal-i-ask')), matching: find.text('Asked for a new link')), findsOneWidget);
      expect(find.text('"I was running late"'), findsOneWidget);
      final asked = tester.getTopLeft(find.byKey(const Key('invitation-i-ask'))).dy;
      for (final other in ['i-plain', 'i-temp', 'i-ok']) {
        expect(asked, lessThan(tester.getTopLeft(find.byKey(Key('invitation-$other'))).dy), reason: other);
      }
    });

    testWidgets('sending a new link answers the request: it is gone from the list afterwards', (tester) async {
      await open(tester);
      await tapKey(tester, 'new-link-i-ask');
      expect(team.count('resend_invitation'), 1);
      expect(find.byKey(const Key('invite-result')), findsOneWidget);
      await tapKey(tester, 'close-result');
      expect(find.byKey(const Key('renewal-i-ask')), findsNothing);
      expect(find.byKey(const Key('renewal-note-i-ask')), findsNothing);
    });

    testWidgets('without the extras the invitations still show, just unmarked', (tester) async {
      team.beforeCall = (fn) {
        if (fn == 'list_invitation_extras') throw const PostgrestException(message: 'function list_invitation_extras does not exist', code: '42883');
      };
      await open(tester);
      expect(find.byKey(const Key('invitation-i-temp')), findsOneWidget);
      expect(find.byKey(const Key('temporary-i-temp')), findsNothing);
    });
  });

  group('agrees with the website', () {
    final migration = File('../bottles-up-website-main/supabase/migrations/20261118100000_temporary_staff_links.sql');
    const why = 'the temporary staff links migration is not in the website checkout beside this app (its branch is not merged yet)';

    test('invite_temporary_staff takes exactly the parameters the app sends, and every one without a default is sent', () {
      final sql = migration.readAsStringSync();
      final m = RegExp(r'create function public\.invite_temporary_staff\(([\s\S]*?)\)\s*returns').firstMatch(sql)!.group(1)!;
      final declared = {for (final part in m.split(RegExp(r',\s*(?=p_)'))) RegExp(r'p_\w+').firstMatch(part)!.group(0)!: !part.contains('default')};
      final sent = inviteTemporaryParams('o', buildInvitePayload(form())).keys.toSet();
      expect(declared.keys.toSet(), sent);
      expect(declared.entries.where((e) => e.value).map((e) => e.key).toSet().difference(sent), isEmpty, reason: 'a required parameter is not sent');
    }, skip: migration.existsSync() ? false : why);

    test('the roles, the limits and the sentences the form words are the database\'s', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains("p_role not in ('server', 'door', 'security', 'verifier')"));
      expect(sql, contains("raise exception 'temporary access is for servers, door staff, security and verifiers'"));
      expect(sql, contains('p_valid_hours < 1 or p_valid_hours > 168'));
      expect(sql, contains("raise exception 'the link must stay valid for between 1 hour and 7 days'"));
      expect(sql, contains("raise exception 'say when the access ends: an end time, or a shift'"));
      expect(sql, contains("raise exception 'the access would already be over'"));
    }, skip: migration.existsSync() ? false : why);

    test('list_invitation_extras returns the columns the app reads', () {
      final sql = migration.readAsStringSync();
      final m = RegExp(r'create function public\.list_invitation_extras\(p_org uuid\)\s*returns table \(([^)]*)\)').firstMatch(sql)!.group(1)!;
      for (final c in ['invitation_id', 'kind', 'identity_verified', 'renewal_requested_at', 'renewal_note']) {
        expect(m, contains(c), reason: c);
      }
    }, skip: migration.existsSync() ? false : why);
  });
}
