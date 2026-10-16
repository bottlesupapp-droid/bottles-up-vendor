import 'package:bottles_up_vendor/features/team/logic/team_rules.dart';
import 'package:bottles_up_vendor/features/team/services/team_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_team_backend.dart';

Matcher refusal(String message) => throwsA(isA<TeamActionException>().having((e) => e.message, 'message', message));

InvitePayload payload({String email = 'new@club.example', String role = 'door', String venue = 'v1', DateTime? start, DateTime? end, String? shift}) =>
    InvitePayload(email: email, role: role, venueId: venue, shiftId: shift, accessStartAt: start, accessEndAt: end);

void main() {
  late FakeTeamBackend db;
  setUp(() => db = FakeTeamBackend());

  group('reading', () {
    test('the team of one business, dropping rows it cannot read', () async {
      db.members.addAll([memberRow('m1', name: 'Dana'), {'user_id': 'x', 'role': 'door', 'state': 'active'}, memberRow('m2', state: 'on_leave'), memberRow('m3')]);
      final list = await db.service.team('o1');
      expect(list.map((m) => m.membershipId), ['m1', 'm3']);
      expect(db.paramsOf('list_team'), [
        {'p_org': 'o1'},
      ]);
    });

    test('the invitations of one business', () async {
      db.invitations.addAll([invitationRow('i1'), invitationRow('i2', state: 'accepted'), invitationRow('i3', state: 'bogus')]);
      expect((await db.service.invitations('o1')).map((i) => i.invitationId), ['i1', 'i2']);
      expect(db.paramsOf('list_team_invitations'), [
        {'p_org': 'o1'},
      ]);
    });

    test('the shifts of a club; a failure is an empty list, because a shift is optional', () async {
      db.shifts.add(shiftRow('s1', 'Late'));
      expect((await db.service.shifts('v1')).map((s) => s.name), ['Late']);
      expect(db.paramsOf('list_shifts'), [
        {'p_venue': 'v1'},
      ]);
      db.failAll = Exception('boom');
      expect(await db.service.shifts('v1'), isEmpty);
    });

    test('the roles the database allows for that club, and only those', () async {
      db.rolesByVenue['v1'] = ['server', 'door'];
      db.rolesByVenue['v2'] = [];
      expect(await db.service.invitableRoles('o1', 'v1'), ['server', 'door']);
      expect(await db.service.invitableRoles('o1', 'v2'), isEmpty);
      expect(db.paramsOf('invitable_roles'), [
        {'p_org': 'o1', 'p_venue': 'v1'},
        {'p_org': 'o1', 'p_venue': 'v2'},
      ]);
    });

    test('only text is a role: anything else in the answer is dropped', () async {
      final odd = TeamService(rpc: (f, {params}) async => [1, 'door', null, 'server', {'role': 'x'}]);
      expect(await odd.invitableRoles('o1', 'v1'), ['door', 'server']);
    });

    test('an answer that is not a list is nothing, never a crash', () async {
      final odd = TeamService(rpc: (f, {params}) async => 'nonsense');
      expect(await odd.team('o1'), isEmpty);
      expect(await odd.invitations('o1'), isEmpty);
      expect(await odd.invitableRoles('o1', 'v1'), isEmpty);
    });

    test('a failure says what is wrong', () async {
      Matcher failure({bool unavailable = false, bool accessEnded = false}) => throwsA(isA<TeamLoadException>()
          .having((e) => e.unavailable, 'unavailable', unavailable)
          .having((e) => e.accessEnded, 'accessEnded', accessEnded));
      for (final load in <Future<Object?> Function()>[() => db.service.team('o1'), () => db.service.invitations('o1'), () => db.service.invitableRoles('o1', 'v1')]) {
        db.failAll = const PostgrestException(message: 'no function', code: '42883');
        await expectLater(load(), failure(unavailable: true));
        db.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
        await expectLater(load(), failure(accessEnded: true));
        db.failAll = Exception('socket closed');
        await expectLater(load(), failure());
      }
    });

    test('the load messages', () {
      expect(const TeamLoadException(unavailable: true, accessEnded: false).message, 'The team is not set up on this server yet.');
      expect(const TeamLoadException(unavailable: false, accessEnded: true).message, 'Your access has ended, or you are signed out.');
      expect(const TeamLoadException(unavailable: false, accessEnded: false).message, startsWith('The team could not be loaded'));
    });
  });

  group('inviting', () {
    test('sends exactly the form\'s payload and returns the link token the database issued', () async {
      final link = await db.service.invite('o1', payload(email: 'New@Club.Example ', role: 'server', shift: 's1'));
      final call = db.paramsOf('invite_member').single!;
      expect([call['p_org'], call['p_email'], call['p_role'], call['p_venue'], call['p_shift'], call['p_event']], ['o1', 'New@Club.Example ', 'server', 'v1', 's1', null]);
      expect(link.token, 'tok-${link.invitationId}');
      expect(db.invitations.single['email'], 'new@club.example');
    });

    test('temporary access is sent as a window', () async {
      await db.service.invite('o1', payload(start: DateTime.utc(2031, 10, 25, 1), end: DateTime.utc(2031, 10, 25, 7)));
      final call = db.paramsOf('invite_member').single!;
      expect([call['p_access_start'], call['p_access_end']], ['2031-10-25T01:00:00.000Z', '2031-10-25T07:00:00.000Z']);
    });

    test('a refusal arrives as the database\'s sentence, made into a sentence', () async {
      await expectLater(db.service.invite('o1', payload(email: 'nope')), refusal('Valid email required.'));
      await expectLater(db.service.invite('o1', payload(start: DateTime.utc(2031, 10, 25, 7), end: DateTime.utc(2031, 10, 25, 1))), refusal('Invalid access window.'));
    });

    test('a role the caller may not appoint is refused in the person\'s words', () async {
      db.rolesByVenue['v1'] = ['door'];
      await expectLater(db.service.invite('o1', payload(role: 'manager')), refusal("You don't have access to do that."));
      expect(db.invitations, isEmpty);
    });

    test('an answer with no token is a failure, not a success', () async {
      for (final answer in [null, <dynamic>[], [{'invitation_id': 'i1'}], [{'token': 't'}], 'nonsense']) {
        final odd = TeamService(rpc: (f, {params}) async => answer);
        await expectLater(odd.invite('o1', payload()), refusal('The invitation could not be created.'), reason: '$answer');
      }
    });

    test('a dropped connection is a generic sentence', () async {
      db.failAll = Exception('socket closed');
      await expectLater(db.service.invite('o1', payload()), refusal('This could not be done. Check your connection and try again.'));
    });
  });

  group('a new link, cancelling, removing', () {
    test('a new link for a waiting invitation returns a new token and the database is asked about that invitation', () async {
      db.invitations.add(invitationRow('i1'));
      final link = await db.service.sendNewLink('i1');
      expect([link.invitationId, link.token], ['i1', 'new-i1']);
      expect(db.paramsOf('resend_invitation'), [
        {'p_invitation': 'i1'},
      ]);
    });

    test('a used or cancelled invitation gets no new link, and says why', () async {
      db.invitations.addAll([invitationRow('i1', state: 'accepted'), invitationRow('i2', state: 'revoked')]);
      await expectLater(db.service.sendNewLink('i1'), refusal('Already accepted.'));
      await expectLater(db.service.sendNewLink('i2'), refusal('Invitation was revoked.'));
    });

    test('cancelling an invitation names it, and a finished one cannot be cancelled', () async {
      db.invitations.addAll([invitationRow('i1'), invitationRow('i2', state: 'accepted')]);
      await db.service.cancelInvitation('i1');
      expect(db.invitations.first['state'], 'revoked');
      expect(db.paramsOf('revoke_invitation').first, {'p_invitation': 'i1'});
      await expectLater(db.service.cancelInvitation('i2'), refusal('Only a pending invitation can be revoked.'));
    });

    test('removing access names the membership; an owner or someone already removed is refused', () async {
      db.members.addAll([memberRow('m1'), memberRow('m2', role: 'owner'), memberRow('m3', state: 'revoked')]);
      await db.service.removeMember('m1');
      expect(db.members.first['state'], 'revoked');
      expect(db.paramsOf('revoke_membership').first, {'p_membership': 'm1'});
      await expectLater(db.service.removeMember('m2'), refusal("You don't have access to do that."));
      await expectLater(db.service.removeMember('m3'), refusal('Membership not found.'));
    });

    test('losing access mid-way is said in the person\'s words; a dropped connection gets the action\'s own sentence', () async {
      db.failAll = const PostgrestException(message: 'not authenticated', code: 'P0001');
      await expectLater(db.service.cancelInvitation('i1'), refusal("You don't have access to do that."));
      db.failAll = Exception('socket closed');
      await expectLater(db.service.cancelInvitation('i1'), refusal('The invitation could not be cancelled. Try again.'));
      await expectLater(db.service.removeMember('m1'), refusal('Access could not be removed. Try again.'));
    });
  });

  group('emailing the link', () {
    test('asks for the invitation and the token it was given, and reports what came back', () async {
      expect((await db.service.emailInvitation('i1', 'tok')).sent, isTrue);
      expect(db.emailed, [('i1', 'tok')]);
      db.emailAnswer = const EmailOutcome(sent: false, reason: 'not_configured');
      expect((await db.service.emailInvitation('i1', 'tok')).reason, 'not_configured');
    });

    test('never throws: whatever goes wrong is a failed send', () async {
      final broken = TeamService(rpc: db.call, emailer: (a, b) async => throw Exception('network'));
      final o = await broken.emailInvitation('i1', 't');
      expect([o.sent, o.reason], [false, 'send_failed']);
    });
  });

  group('sentences', () {
    test('a database message becomes a sentence', () {
      expect(sentence('invalid access window'), 'Invalid access window.');
      expect(sentence('Already a sentence.'), 'Already a sentence.');
      expect(sentence('  shift does not belong to this venue  '), 'Shift does not belong to this venue.');
      expect(sentence(''), 'Please try again.');
    });
  });

  // A stale list of who has access is worse than a slow one: nothing is kept once the screen that asked for it is gone.
  group('lists are read again, never kept', () {
    Future<void> reopened<T>(ProviderContainer container, AutoDisposeFutureProvider<T> provider) async {
      final sub = container.listen(provider, (_, __) {});
      await container.read(provider.future);
      sub.close();
      await Future<void>.delayed(Duration.zero);
    }

    test('the team, the invitations, the roles and the shifts', () async {
      final container = ProviderContainer(overrides: [teamServiceProvider.overrideWithValue(db.service)]);
      addTearDown(container.dispose);
      await reopened(container, teamMembersProvider('o1'));
      await reopened(container, teamInvitationsProvider('o1'));
      await reopened(container, invitableRolesProvider(const RoleQuery('o1', 'v1')));
      await reopened(container, venueShiftsProvider('v1'));
      db.members.add(memberRow('m1'));
      db.invitations.add(invitationRow('i1'));
      db.shifts.add(shiftRow('s1', 'Late'));
      db.rolesByVenue['v1'] = ['door'];
      expect((await container.read(teamMembersProvider('o1').future)).length, 1);
      expect((await container.read(teamInvitationsProvider('o1').future)).length, 1);
      expect(await container.read(invitableRolesProvider(const RoleQuery('o1', 'v1')).future), ['door']);
      expect((await container.read(venueShiftsProvider('v1').future)).length, 1);
    });

    test('a role query is about one business and one club', () {
      expect(const RoleQuery('o1', 'v1') == const RoleQuery('o1', 'v1'), isTrue);
      expect(const RoleQuery('o1', 'v1') == const RoleQuery('o1', 'v2'), isFalse);
      expect(const RoleQuery('o1', 'v1') == const RoleQuery('o2', 'v1'), isFalse);
      expect(const RoleQuery('o1', 'v1').hashCode, const RoleQuery('o1', 'v1').hashCode);
    });
  });
}
