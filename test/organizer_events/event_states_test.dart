import 'dart:io';

import 'package:bottles_up_vendor/features/organizer_events/logic/event_states.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row({String state = 'draft', Object? blockers, String? venue, String? agreement, String id = 'e1'}) => {
      'event_id': id, 'state': state, 'blockers': blockers ?? <String>[], 'agreement_id': null, 'agreement_status': agreement, 'venue_name': venue,
    };

void main() {
  group('reading what the database says', () {
    test('every state the database can send', () {
      for (final s in EventState.values) {
        expect(parseEventState(row(state: s.db))!.state, s);
      }
    });

    test('a state this app does not know, or a row without an id, is not shown as anything', () {
      expect(parseEventState(row(state: 'cancelled')), isNull);
      expect(parseEventState(row(state: '')), isNull);
      expect(parseEventState({...row(), 'event_id': null}), isNull);
      expect(parseEventState({...row(), 'event_id': ''}), isNull);
    });

    test('blockers are read in order; one this version does not know is counted, not dropped', () {
      final i = parseEventState(row(blockers: ['business_verification', 'venue_request', 'something_new', 'another']))!;
      expect(i.blockers, [PublishBlocker.businessVerification, PublishBlocker.venueRequest]);
      expect(i.unknownBlockers, 2);
      expect(parseEventState(row(blockers: 'nope'))!.blockers, isEmpty);
    });

    test('the club behind the connection, when there is one', () {
      expect(parseEventState(row(venue: 'Club A', agreement: 'requested'))!.venueName, 'Club A');
      expect(parseEventState(row(venue: ''))!.venueName, isNull);
    });

    test('states are found by event', () {
      final m = statesByEvent([parseEventState(row(id: 'a'))!, parseEventState(row(id: 'b', state: 'live'))!]);
      expect(m['b']!.state, EventState.live);
      expect(m['c'], isNull);
    });
  });

  group('what it says', () {
    test('labels are the brief\'s words', () {
      expect([for (final s in EventState.values) s.label], ['Draft', 'Awaiting venue approval', 'Ready to publish', 'Live', 'Ended']);
    });

    test('only drafts, waiting drafts and ready drafts are still the organizer\'s to change', () {
      expect([for (final s in EventState.values) s.isDraftLike], [true, true, true, false, false]);
    });

    test('each blocker is a sentence naming the club when there is one', () {
      EventStateInfo info(List<PublishBlocker> b, {String? venue, String? agreement}) =>
          EventStateInfo(eventId: 'e', state: EventState.draft, blockers: b, venueName: venue, agreementStatus: agreement);
      expect(blockerSentences(info([PublishBlocker.businessVerification])), ['Your business is not verified yet. Publishing waits for verification.']);
      expect(blockerSentences(info([PublishBlocker.venueRequest])), ['No club has been asked to host this event yet.']);
      expect(blockerSentences(info([PublishBlocker.venueApproval], venue: 'Club A')), ['Waiting for Club A to agree the terms.']);
      expect(blockerSentences(info([PublishBlocker.venueApproval])), ['Waiting for the club to agree the terms.']);
      expect(blockerSentences(info([PublishBlocker.venueDeclined], venue: 'Club A', agreement: 'declined')), ['Club A declined. Ask another club to host this event.']);
      expect(blockerSentences(info([PublishBlocker.venueDeclined], venue: 'Club A', agreement: 'cancelled')), ['The request to Club A was cancelled. Ask a club to host this event.']);
    });

    test('blockers that are not known are still said', () {
      const one = EventStateInfo(eventId: 'e', state: EventState.draft, blockers: [], unknownBlockers: 1);
      const many = EventStateInfo(eventId: 'e', state: EventState.draft, blockers: [PublishBlocker.venueRequest], unknownBlockers: 3);
      expect(blockerSentences(one), ['Something else needs the BottlesUp team.']);
      expect(blockerSentences(many).last, '3 other things need the BottlesUp team.');
    });

    test('the button goes with the first blocker the person can act on', () {
      EventStateInfo info(List<PublishBlocker> b) => EventStateInfo(eventId: 'e', state: EventState.draft, blockers: b);
      expect(blockerAction(info([PublishBlocker.venueRequest]))!.label, 'Ask a club to host it');
      expect(blockerAction(info([PublishBlocker.venueDeclined]))!.label, 'Ask a club to host it');
      expect(blockerAction(info([PublishBlocker.venueApproval]))!.label, 'See the agreement');
      expect(blockerAction(info([PublishBlocker.businessVerification, PublishBlocker.venueRequest]))!.label, 'Ask a club to host it', reason: 'verification is shown elsewhere; the next one gets the button');
      expect(blockerAction(info([PublishBlocker.businessVerification])), isNull);
      expect(blockerAction(info([])), isNull);
    });
  });

  group('the same states and blockers as the database (checked when the website is beside this app)', () {
    final sql = File('../bottles-up-website-main/supabase/migrations/20261020120000_org_event_states.sql');

    test('every state and blocker the app knows is one the database sends', () {
      if (!sql.existsSync()) return;
      final text = sql.readAsStringSync();
      for (final s in EventState.values) {
        expect(text, contains("'${s.db}'"), reason: s.db);
      }
      for (final b in PublishBlocker.values) {
        expect(text, contains("'${b.db}'"), reason: b.db);
      }
      expect(text, contains('list_org_event_states(p_org uuid)'));
    });
  });
}
