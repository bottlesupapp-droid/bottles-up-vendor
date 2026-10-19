import 'dart:io';

import 'package:bottles_up_vendor/features/door_staff/logic/door_staff_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> status({String state = 'allowed', String? club = 'Club A', String id = 'e1', Object? title = 'Rooftop Sessions'}) =>
    {'event_id': id, 'event_title': title, 'state': state, 'agreement_id': null, 'club_name': club};

void main() {
  group('where the organizer stands on an event', () {
    test('every state the database sends, and only two let the organizer invite', () {
      expect([for (final s in EventDoorState.values) s.db], ['own_event', 'allowed', 'not_allowed', 'awaiting_approval']);
      expect([for (final s in EventDoorState.values) s.canInvite], [true, true, false, false]);
    });

    test('a row is read; a state this app does not know, or a row without an id or title, is dropped', () {
      final s = parseEventDoorStatus(status(state: 'not_allowed'))!;
      expect(s.state, EventDoorState.notAllowed);
      expect(s.clubName, 'Club A');
      expect(parseEventDoorStatus(status(state: 'maybe')), isNull);
      expect(parseEventDoorStatus(status(id: '')), isNull);
      expect(parseEventDoorStatus(status(title: null)), isNull);
      expect(parseEventDoorStatus(status(club: ''))!.clubName, isNull);
    });

    test('each state is said in words, naming the club', () {
      EventDoorStatus of(EventDoorState s, {String? club = 'Club A'}) => EventDoorStatus(eventId: 'e', title: 't', state: s, clubName: club);
      expect(doorStateSentence(of(EventDoorState.ownEvent, club: null)), 'No club is hosting this event, so you can invite door staff yourself.');
      expect(doorStateSentence(of(EventDoorState.allowed)), 'Club A allows you to invite door staff for this event.');
      expect(doorStateSentence(of(EventDoorState.notAllowed)), 'Club A has not allowed door staff for this event. Ask Club A to allow it.');
      expect(doorStateSentence(of(EventDoorState.awaitingApproval)), startsWith('Waiting for Club A to agree the event terms.'));
      expect(doorStateSentence(of(EventDoorState.notAllowed, club: null)), contains('the club'));
      expect([for (final s in EventDoorState.values) doorStateLabel(s)], ['Your own event', 'Allowed', 'Not allowed yet', 'Awaiting the club']);
    });
  });

  group('the club\'s side', () {
    test('a permission is read with the club\'s answer, and the sentence says it counts once terms are agreed', () {
      final p = parseDoorPermission({'agreement_id': 'a1', 'event_id': 'e1', 'event_title': 'Rooftop', 'event_start': '2031-10-24T22:00:00Z', 'organizer_name': 'Night Events', 'approved': true, 'door_staff_allowed': true})!;
      expect(p.allowed, isTrue);
      expect(permissionSentence(p), 'Night Events may invite door staff for this event.');
      final no = parseDoorPermission({'agreement_id': 'a1', 'event_id': 'e1', 'approved': true, 'door_staff_allowed': false})!;
      expect(permissionSentence(no), 'An organizer may not invite door staff for this event.');
      final waiting = parseDoorPermission({'agreement_id': 'a1', 'event_id': 'e1', 'approved': false, 'door_staff_allowed': true})!;
      expect(permissionSentence(waiting), contains('not agreed yet'));
      expect(parseDoorPermission({'event_id': 'e1'}), isNull);
      expect(parseDoorPermission({'agreement_id': 'a1'}), isNull);
    });

    test('door staff are read as people or invitations; a row with neither, or no name, is dropped', () {
      final m = parseClubDoorStaff({'membership_id': 'm1', 'invitation_id': null, 'event_title': 'Rooftop', 'organizer_name': 'Night Events', 'person': 'Dan Door', 'state': 'active'})!;
      expect(m.isInvitation, isFalse);
      expect(m.canRevoke, isTrue);
      final i = parseClubDoorStaff({'membership_id': null, 'invitation_id': 'i1', 'person': 'new@x.example', 'state': 'invited'})!;
      expect(i.isInvitation, isTrue);
      expect(i.canRevoke, isTrue);
      expect(parseClubDoorStaff({'membership_id': null, 'invitation_id': null, 'person': 'x'}), isNull);
      expect(parseClubDoorStaff({'membership_id': 'm1', 'person': ''}), isNull);
    });

    test('only access that can still be taken away offers Remove', () {
      ClubDoorStaff of(String state) => ClubDoorStaff(eventTitle: 't', organizerName: 'o', person: 'p', state: state, membershipId: 'm');
      expect([for (final s in ['active', 'scheduled', 'invited', 'invitation_expired', 'expired', 'revoked']) of(s).canRevoke], [true, true, true, true, false, false]);
    });

    test('states are said in words', () {
      expect(clubStaffStateLabel('active'), 'Has access');
      expect(clubStaffStateLabel('invited'), 'Invited, not accepted yet');
      expect(clubStaffStateLabel('invitation_expired'), 'Invitation expired');
      expect(clubStaffStateLabel('revoked'), 'Removed');
      expect(clubStaffStateLabel('something_new'), 'something new');
    });

    test('door staff are told what they can and cannot do', () {
      expect(doorStaffLimits, contains('cannot change prices'));
      expect(doorStaffLimits, contains('refunds'));
      expect(doorStaffLimits, contains('banking'));
    });
  });

  group('the same functions and states as the database (checked when the website is beside this app)', () {
    final sql = File('../bottles-up-website-main/supabase/migrations/20261020130000_organizer_door_staff.sql');

    test('the function names, arguments and states the service uses', () {
      if (!sql.existsSync()) return;
      final text = sql.readAsStringSync();
      for (final f in ['organizer_event_door_status(p_org uuid)', 'venue_door_permissions(p_venue uuid)', 'set_organizer_door_staff(p_agreement uuid, p_allowed boolean)', 'venue_event_door_staff(p_venue uuid)', 'revoke_event_door_access(p_membership uuid default null, p_invitation uuid default null)']) {
        expect(text, contains(f), reason: f);
      }
      for (final s in EventDoorState.values) {
        expect(text, contains("'${s.db}'"), reason: s.db);
      }
      for (final k in ['door_staff_allowed', 'approved', 'organizer_name', 'person', 'invitation_expired', 'invited']) {
        expect(text, contains(k), reason: k);
      }
    });

    test('the refusal the invite shows is the database\'s own sentence', () {
      if (!sql.existsSync()) return;
      expect(sql.readAsStringSync(), contains('the club has not allowed door staff for this event'));
    });
  });
}
