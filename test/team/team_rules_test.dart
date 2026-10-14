import 'dart:io';

import 'package:bottles_up_vendor/features/team/logic/team_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2031, 10, 24, 12);

InviteForm good({String? email, String? role, String? venue, bool? temporary, DateTime? start, DateTime? end, String? shift}) => InviteForm(
      email: email ?? 'new@club.example', role: role ?? 'door', venueId: venue ?? 'v1', temporary: temporary ?? false, start: start, end: end, shiftId: shift ?? '',
    );

void main() {
  group('states', () {
    test('a person\'s access, in the words a person would use', () {
      expect([for (final s in MemberState.values) s.label], ['Active', 'Starts later', 'Access ended', 'Removed']);
      expect([for (final s in MemberState.values) s.tone], [Tone.success, Tone.info, Tone.neutral, Tone.neutral]);
    });

    test('an invitation, in the words a person would use', () {
      expect([for (final s in InvitationState.values) s.label], ['Waiting', 'Accepted', 'Expired', 'Cancelled']);
      expect([for (final s in InvitationState.values) s.tone], [Tone.info, Tone.success, Tone.warning, Tone.neutral]);
    });

    test('only active and not-yet-started people are on the team; ended and removed are history', () {
      expect([for (final s in MemberState.values) s.isCurrent], [true, true, false, false]);
    });

    test('a new link and cancelling are offered for a waiting or expired invitation, never a used or cancelled one', () {
      expect([for (final s in InvitationState.values) s.canSendNewLink], [true, false, true, false]);
      expect([for (final s in InvitationState.values) s.canCancel], [true, false, true, false]);
    });

    test('an owner or organizer is never removed from here; nobody already removed is offered it again', () {
      for (final state in MemberState.values) {
        expect(canRemoveMember('owner', state), isFalse, reason: 'owner $state');
        expect(canRemoveMember('organizer', state), isFalse, reason: 'organizer $state');
      }
      for (final role in ['manager', 'server', 'door', 'security', 'verifier']) {
        expect(canRemoveMember(role, MemberState.active), isTrue, reason: role);
        expect(canRemoveMember(role, MemberState.scheduled), isTrue, reason: role);
        expect(canRemoveMember(role, MemberState.expired), isTrue, reason: role);
        expect(canRemoveMember(role, MemberState.revoked), isFalse, reason: role);
      }
    });

    test('an unknown state is not guessed at', () {
      expect(MemberState.fromDb('suspended'), isNull);
      expect(MemberState.fromDb(null), isNull);
      expect(InvitationState.fromDb('declined'), isNull);
      expect(MemberState.fromDb('active'), MemberState.active);
    });

    test('a role is shown by name, and an unknown one as it came', () {
      expect(roleLabel('door'), 'Door staff');
      expect(roleLabel('manager'), 'Manager');
      expect(roleLabel('astronaut'), 'astronaut');
    });
  });

  group('the invite form says what is wrong in plain words', () {
    test('a good form has no problems', () => expect(validateInvite(good(), now: now), isEmpty));

    test('each thing that is missing', () {
      expect(validateInvite(const InviteForm(), now: now), [
        'Enter the email address of the person you are inviting.',
        'Choose the club they will work at.',
        'Choose a role.',
      ]);
    });

    test('emails: spaces are trimmed; what is not an address is refused', () {
      expect(validateInvite(good(email: '  a@b.co  '), now: now), isEmpty);
      for (final bad in ['', 'a', 'a@b', 'a b@c.de', '@c.de', 'a@.de ', 'a@b@c.de']) {
        expect(validateInvite(good(email: bad), now: now), contains('Enter the email address of the person you are inviting.'), reason: '"$bad"');
      }
    });

    test('temporary access needs both ends, in order, and not already over', () {
      final start = DateTime(2031, 10, 24, 21);
      final end = DateTime(2031, 10, 25, 3);
      expect(validateInvite(good(temporary: true, start: start, end: end), now: now), isEmpty);
      expect(validateInvite(good(temporary: true), now: now), ['Temporary access needs a start and an end.']);
      expect(validateInvite(good(temporary: true, start: start), now: now), ['Temporary access needs a start and an end.']);
      expect(validateInvite(good(temporary: true, end: end), now: now), ['Temporary access needs a start and an end.']);
      expect(validateInvite(good(temporary: true, start: end, end: start), now: now), ['The end must be after the start.']);
      expect(validateInvite(good(temporary: true, start: start, end: start), now: now), ['The end must be after the start.']);
      expect(validateInvite(good(temporary: true, start: DateTime(2031, 10, 1), end: DateTime(2031, 10, 2)), now: now), ['The end is already in the past.']);
      expect(validateInvite(good(temporary: true, start: DateTime(2031, 10, 24, 11), end: now), now: now), ['The end is already in the past.']);
    });

    test('ongoing access ignores whatever is left in the time boxes', () {
      expect(validateInvite(good(temporary: false, start: DateTime(2031, 1, 1), end: DateTime(2030, 1, 1)), now: now), isEmpty);
    });
  });

  group('what is sent', () {
    test('the email is trimmed and lower-cased; ongoing access sends no window; an empty shift is none', () {
      final p = buildInvitePayload(good(email: '  New@Club.Example ', start: DateTime(2031), end: DateTime(2032)));
      expect([p.email, p.role, p.venueId, p.shiftId, p.accessStartAt, p.accessEndAt], ['new@club.example', 'door', 'v1', null, null, null]);
    });

    test('temporary access sends its window, and a chosen shift is sent', () {
      final start = DateTime(2031, 10, 24, 21);
      final end = DateTime(2031, 10, 25, 3);
      final p = buildInvitePayload(good(temporary: true, start: start, end: end, shift: 's1'));
      expect([p.shiftId, p.accessStartAt, p.accessEndAt], ['s1', start, end]);
    });

    test('the parameters are exactly the ones invite_member declares; an event is never sent; times go as UTC instants', () {
      final p = buildInvitePayload(good(temporary: true, start: DateTime.utc(2031, 10, 25, 1), end: DateTime.utc(2031, 10, 25, 7)));
      final params = inviteParams('o1', p);
      expect(params.keys.toSet(), {'p_org', 'p_email', 'p_role', 'p_venue', 'p_event', 'p_shift', 'p_access_start', 'p_access_end'});
      expect(params['p_event'], isNull);
      expect(params['p_access_start'], '2031-10-25T01:00:00.000Z');
      expect(params['p_access_end'], '2031-10-25T07:00:00.000Z');
      expect(inviteParams('o1', buildInvitePayload(good()))['p_access_start'], isNull);
    });
  });

  group('the link and the email', () {
    test('the link carries the token, encoded, and tolerates a trailing slash on the site', () {
      expect(invitationLink('https://www.bottlesupapp.com', 'abc'), 'https://www.bottlesupapp.com/accept-invite?token=abc');
      expect(invitationLink('https://x.example///', 'a b+c/d=='), 'https://x.example/accept-invite?token=a%20b%2Bc%2Fd%3D%3D');
    });

    test('the mail message names the business, the role and the link, and cannot grow a header from a typed name', () {
      final uri = mailtoLink('new@club.example', 'Club\r\nBcc: evil@x.example', 'Door\nstaff', 'https://s.example/accept-invite?token=t');
      expect(uri.scheme, 'mailto');
      final text = Uri.decodeComponent(uri.toString());
      expect(text, contains('You are invited to join Club Bcc: evil@x.example on BottlesUp'));
      expect(text, contains('as Door staff.'));
      expect(text, contains('https://s.example/accept-invite?token=t'));
      expect(text, contains('Sign in or create an account with new@club.example to accept.'));
      final subject = Uri.decodeComponent(RegExp(r'subject=([^&]*)').firstMatch(uri.toString())!.group(1)!);
      expect(subject.contains('\n'), isFalse);
    });

    test('what to tell the person after trying to email the link', () {
      expect(emailOutcomeMessage(const EmailOutcome(sent: true), 'a@b.co').text, 'We emailed the invitation to a@b.co.');
      expect(emailOutcomeMessage(const EmailOutcome(sent: true), 'a@b.co').tone, Tone.success);
      expect(emailOutcomeMessage(const EmailOutcome(sent: false, reason: 'not_configured'), 'a@b.co').text, 'Email is not set up yet, so nothing was sent. Copy the link below and send it yourself.');
      expect(emailOutcomeMessage(const EmailOutcome(sent: false, reason: 'rate_limited'), 'a@b.co').text, 'This invitation was emailed recently. Copy the link below if you need to send it again.');
      expect(emailOutcomeMessage(const EmailOutcome(sent: false, reason: 'send_failed'), 'a@b.co').text, 'We could not send the email. Copy the link below and send it yourself.');
      expect(emailOutcomeMessage(const EmailOutcome(sent: false), 'a@b.co').tone, Tone.warning);
    });

    test('what the email function answered', () {
      expect(emailOutcomeFromResponse({'sent': true}).sent, isTrue);
      expect(emailOutcomeFromResponse({'sent': false, 'reason': 'not_configured'}).reason, 'not_configured');
      for (final odd in [null, 'ok', {'sent': 'yes'}, {'sent': false}, 7]) {
        final o = emailOutcomeFromResponse(odd);
        expect([o.sent, o.reason], [false, 'send_failed'], reason: '$odd');
      }
      expect(emailOutcomeFromStatus(429).reason, 'rate_limited');
      expect(emailOutcomeFromStatus(500).reason, 'send_failed');
      expect(emailOutcomeFromStatus(null).reason, 'send_failed');
    });
  });

  group('wording', () {
    test('access', () {
      final a = DateTime(2031, 10, 10, 21);
      final b = DateTime(2031, 10, 11, 3);
      expect(describeAccess(null, null), 'Ongoing');
      expect(describeAccess(a, b), 'Oct 10, 9:00 PM to Oct 11, 3:00 AM');
      expect(describeAccess(a, null), 'From Oct 10, 9:00 PM');
      expect(describeAccess(null, b), 'Until Oct 11, 3:00 AM');
    });

    test('a person is named, or shown by email, or as unknown', () {
      expect(displayName('Dana Reyes', 'd@x.co'), 'Dana Reyes');
      expect(displayName('  ', 'd@x.co'), 'd@x.co');
      expect(displayName(null, 'd@x.co'), 'd@x.co');
      expect(displayName(null, null), 'Unknown');
    });

    test('where someone works', () {
      expect(describeScope('Club A', null, null), 'Club A');
      expect(describeScope('Club A', 'Friday Night', 'Late shift'), 'Club A · Friday Night · Late shift');
      expect(describeScope(null, null, null), 'Whole business');
    });
  });

  group('reading what the database returns', () {
    final row = {
      'membership_id': 'm1', 'user_id': 'u1', 'email': 'd@x.co', 'name': 'Dana', 'role': 'manager', 'venue_id': 'v1', 'venue_name': 'Club A',
      'access_start_at': '2031-10-10T21:00:00Z', 'access_end_at': null, 'state': 'scheduled',
    };

    test('a member keeps what it needs', () {
      final m = parseTeamMember(row)!;
      expect([m.membershipId, m.name, m.email, m.role, m.venueName, m.state, m.accessEndAt], ['m1', 'Dana', 'd@x.co', 'manager', 'Club A', MemberState.scheduled, null]);
      expect(m.accessStartAt, DateTime.utc(2031, 10, 10, 21));
    });

    test('a member whose state is unknown, or with no id, user or role, is dropped rather than mislabelled', () {
      expect(parseTeamMember({...row, 'state': 'on_leave'}), isNull);
      for (final key in ['membership_id', 'user_id', 'role']) {
        expect(parseTeamMember({...row, key: null}), isNull, reason: key);
      }
    });

    test('an invitation keeps what it needs, with 0 emails when the count is missing', () {
      final i = parseTeamInvitation({'invitation_id': 'i1', 'email': 'n@x.co', 'role': 'door', 'state': 'pending', 'expires_at': '2031-01-08T12:00:00Z'})!;
      expect([i.invitationId, i.email, i.role, i.state, i.emailsSent], ['i1', 'n@x.co', 'door', InvitationState.pending, 0]);
      expect(parseTeamInvitation({'invitation_id': 'i1', 'email': 'n@x.co', 'role': 'door', 'state': 'declined'}), isNull);
      expect(parseTeamInvitation({'email': 'n@x.co', 'role': 'door', 'state': 'pending'}), isNull);
      expect(parseTeamInvitation({'invitation_id': 'i1', 'email': 'n@x.co', 'role': 'door', 'state': 'pending', 'emails_sent': 3})!.emailsSent, 3);
    });

    test('a shift needs an id and both times; a missing name is "Shift"', () {
      expect(parseShift({'shift_id': 's1', 'starts_at': '2031-01-02T20:00:00Z', 'ends_at': '2031-01-03T04:00:00Z'})!.name, 'Shift');
      expect(parseShift({'shift_id': 's1', 'name': 'Late', 'starts_at': 'soon', 'ends_at': '2031-01-03T04:00:00Z'}), isNull);
      expect(parseShift({'name': 'Late', 'starts_at': '2031-01-02T20:00:00Z', 'ends_at': '2031-01-03T04:00:00Z'}), isNull);
    });

    test('the team is split into who is on it and history, each in the order given', () {
      final all = [for (final (id, st) in [('a', 'active'), ('b', 'revoked'), ('c', 'scheduled'), ('d', 'expired')]) parseTeamMember({...row, 'membership_id': id, 'state': st})!];
      final s = splitTeam(all);
      expect(s.current.map((m) => m.membershipId), ['a', 'c']);
      expect(s.history.map((m) => m.membershipId), ['b', 'd']);
    });
  });

  // The website decides every one of these words and rules; the app must not drift from them. These read the website's source when
  // it is checked out beside this app (the monorepo) and are skipped otherwise.
  group('agrees with the website', () {
    final ts = File('../bottles-up-website-main/src/lib/team.ts');
    final tenancy = File('../bottles-up-website-main/supabase/migrations/20261006120000_tenancy_foundation.sql');
    final team = File('../bottles-up-website-main/supabase/migrations/20261008100000_team_invitations.sql');
    const why = 'website repo is not checked out next to this app';
    final present = ts.existsSync() && tenancy.existsSync() && team.existsSync();

    test('the labels of every state are the website\'s', () {
      final src = ts.readAsStringSync();
      for (final s in MemberState.values) {
        expect(src, contains("${s.name}: { label: '${s.label}'"), reason: s.name);
      }
      for (final s in InvitationState.values) {
        expect(src, contains("${s.name}: { label: '${s.label}'"), reason: s.name);
      }
    }, skip: present ? false : why);

    test('the wording of the email outcomes, the problems and the scope is the website\'s, word for word', () {
      final src = ts.readAsStringSync();
      for (final text in [
        'Enter the email address of the person you are inviting.', 'Choose the club they will work at.', 'Choose a role.',
        'Temporary access needs a start and an end.', 'The end must be after the start.', 'The end is already in the past.',
        'Email is not set up yet, so nothing was sent. Copy the link below and send it yourself.',
        'This invitation was emailed recently. Copy the link below if you need to send it again.',
        'We could not send the email. Copy the link below and send it yourself.',
        'Whole business', 'Ongoing', 'You are invited to join', 'Sign in or create an account with',
      ]) {
        expect(src, contains(text), reason: text);
      }
    }, skip: present ? false : why);

    test('who may not be removed, and which states can send a new link, are the website\'s rules', () {
      final src = ts.readAsStringSync();
      expect(src, contains("if (role === 'owner' || role === 'organizer') return false;"));
      expect(src, contains("return state === 'pending' || state === 'expired';"));
      expect(src, contains("return state === 'active' || state === 'scheduled';"));
    }, skip: present ? false : why);

    test('invite_member takes exactly the parameters the app sends, and every one without a default is sent', () {
      final sql = tenancy.readAsStringSync();
      final m = RegExp(r'create function public\.invite_member\(([\s\S]*?)\)\s*returns').firstMatch(sql)!.group(1)!;
      final declared = {for (final part in m.split(RegExp(r',\s*(?=p_)'))) RegExp(r'p_\w+').firstMatch(part)!.group(0)!: !part.contains('default')};
      final sent = inviteParams('o', buildInvitePayload(good())).keys.toSet();
      expect(declared.keys.toSet().containsAll(sent), isTrue, reason: 'declared ${declared.keys}, sent $sent');
      expect(declared.entries.where((e) => e.value).map((e) => e.key).toSet().difference(sent), isEmpty, reason: 'a required parameter is not sent');
    }, skip: present ? false : why);

    test('the other functions and their argument names are the ones the database defines', () {
      final all = tenancy.readAsStringSync() + team.readAsStringSync();
      for (final signature in [
        'list_team(p_org uuid)', 'list_team_invitations(p_org uuid)', 'list_shifts(p_venue uuid)', 'invitable_roles(p_org uuid, p_venue uuid)',
        'resend_invitation(p_invitation uuid', 'revoke_invitation(p_invitation uuid)', 'revoke_membership(p_membership uuid)',
      ]) {
        expect(all, contains('create function public.$signature'), reason: signature);
      }
    }, skip: present ? false : why);

    test('the columns a row is read from are the ones list_team and list_team_invitations return', () {
      final sql = team.readAsStringSync();
      for (final column in ['membership_id', 'user_id', 'email', 'name', 'role', 'venue_id', 'venue_name', 'event_id', 'event_title', 'shift_id', 'shift_name', 'access_start_at', 'access_end_at', 'state']) {
        expect(sql, contains(column), reason: column);
      }
      for (final column in ['invitation_id', 'expires_at', 'emails_sent']) {
        expect(sql, contains(column), reason: column);
      }
    }, skip: present ? false : why);
  });
}
