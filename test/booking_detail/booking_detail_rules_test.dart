import 'dart:io';

import 'package:bottles_up_vendor/features/booking_detail/logic/booking_detail_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> guestsRow({Object? guests, int left = 2, String holder = 'Hana Holder', Object? holderIn}) => {
      'holder_name': holder,
      'holder_checked_in_at': holderIn,
      'party_size': 4,
      'max_guests': 6,
      'table_name': 'VIP booth',
      'guests': guests ?? <Map<String, dynamic>>[],
      'guests_issued': 3,
      'guests_in': 1,
      'guests_left': left,
    };

ActivityEntry entry(String action, {Map<String, dynamic> details = const {}, String actor = 'Sam Server', String kind = 'audit'}) =>
    ActivityEntry(at: DateTime(2026, 10, 9, 22), kind: kind, action: action, actor: actor, details: details);

void main() {
  group('reading the guests', () {
    test('the holder, the party, the limit and each guest', () {
      final g = parseBookingGuests(guestsRow(holderIn: '2026-10-09T22:00:00Z', guests: [
        {'id': 'g1', 'name': 'Gia', 'ticket_sent': false, 'checked_in_at': null},
        {'id': 'g2', 'name': 'Gus', 'ticket_sent': true, 'checked_in_at': '2026-10-09T22:30:00Z'},
      ]))!;
      expect(g.holderName, 'Hana Holder');
      expect(g.holderIsIn, isTrue);
      expect(g.partySize, 4);
      expect(g.maxGuests, 6);
      expect(g.tableName, 'VIP booth');
      expect(g.guests.map((x) => x.name), ['Gia', 'Gus']);
      expect(g.guests.map((x) => x.isIn), [false, true]);
      expect(g.guests.map((x) => x.ticketSent), [false, true]);
      expect(g.guestsIn, 1);
    });

    test('a row with no holder is not a row; a guest without an id or a name is dropped', () {
      expect(parseBookingGuests({'party_size': 2}), isNull);
      final g = parseBookingGuests(guestsRow(guests: [
        {'id': null, 'name': 'No id'},
        {'id': 'g9'},
        'junk',
        {'id': 'g1', 'name': 'Gia'},
      ]))!;
      expect(g.guests.map((x) => x.id), ['g1']);
    });

    test('counts that arrive as text, and a list that is missing, still read', () {
      final g = parseBookingGuests({...guestsRow(), 'party_size': '5', 'max_guests': '8', 'guests': null, 'guests_left': '3'})!;
      expect(g.partySize, 5);
      expect(g.maxGuests, 8);
      expect(g.guests, isEmpty);
      expect(g.guestsLeft, 3);
    });

    test('the allowance is said in words, including when nobody more can be invited', () {
      expect(allowanceLine(parseBookingGuests(guestsRow(left: 2))!), 'Party of 4 · table limit 6 · 2 more guests can be invited');
      expect(allowanceLine(parseBookingGuests(guestsRow(left: 1))!), 'Party of 4 · table limit 6 · 1 more guest can be invited');
      expect(allowanceLine(parseBookingGuests(guestsRow(left: 0))!), 'Party of 4 · table limit 6 · no more guests can be invited');
    });

    test('who is in', () {
      expect(guestsInLine(parseBookingGuests(guestsRow())!), 'No guests invited yet.');
      final g = parseBookingGuests(guestsRow(guests: [
        {'id': 'g1', 'name': 'Gia', 'checked_in_at': '2026-10-09T22:30:00Z'},
        {'id': 'g2', 'name': 'Gus'},
      ]))!;
      expect(guestsInLine(g), '1 of 2 guests in');
      expect(guestsInLine(parseBookingGuests(guestsRow(guests: [{'id': 'g1', 'name': 'Gia'}]))!), '0 of 1 guest in');
    });

    test('the admission note does not promise unlimited entry', () {
      expect(admissionNote, contains('own code'));
      expect(admissionNote.toLowerCase(), isNot(contains('unlimited')));
    });
  });

  group('reading the activity', () {
    test('a row is read; a row without a time or an action is dropped; the actor is never blank', () {
      final e = parseActivityEntry({'at': '2026-10-09T22:00:00Z', 'kind': 'scan', 'action': 'scan.ok', 'actor': ' Sam Server ', 'details': {'guest': true}})!;
      expect(e.actor, 'Sam Server');
      expect(e.kind, 'scan');
      expect(e.details['guest'], true);
      expect(parseActivityEntry({'at': null, 'action': 'x'}), isNull);
      expect(parseActivityEntry({'at': '2026-10-09T22:00:00Z', 'action': ''}), isNull);
      expect(parseActivityEntry({'at': 'nonsense', 'action': 'x'}), isNull);
      expect(parseActivityEntry({'at': '2026-10-09T22:00:00Z', 'action': 'x', 'actor': '  '})!.actor, 'Staff member');
      expect(parseActivityEntry({'at': '2026-10-09T22:00:00Z', 'action': 'x', 'details': 'not a map'})!.details, isEmpty);
    });
  });

  group('what each action says', () {
    test('payments', () {
      expect(activitySentence(entry('table_booking.club_payment_recorded', details: {'amount_paid_cents': 10000, 'payment_method': 'cash'})), '\$100.00 recorded as cash');
      expect(activitySentence(entry('table_booking.club_payment_recorded', details: {'amount_paid_cents': 2550, 'payment_method': 'split'})), '\$25.50 recorded as a split payment');
      expect(activitySentence(entry('table_booking.club_payment_recorded')), 'A payment was recorded');
      expect(activitySentence(entry('table_booking.club_payment_manager_verified')), 'A payment was verified by a manager');
      expect(activitySentence(entry('payment.flagged')), 'A payment was flagged for a second look');
      expect(activitySentence(entry('payment.flag_resolved', details: {'resolution': 'written_off'})), 'A flagged payment was resolved (written off)');
      expect(activitySentence(entry('payment.flag_resolved')), 'A flagged payment was resolved');
    });

    test('bottle service moves use the same words as the orders', () {
      expect(activitySentence(entry('table_booking.bottle_service_status_updated', details: {'old_status': 'awaiting_prep', 'new_status': 'preparing'})), 'A bottle order moved from New to Preparing');
      expect(activitySentence(entry('table_booking.bottle_service_status_updated', details: {'old_status': 'picked_up', 'new_status': 'served'})), 'A bottle order moved from On the way to Delivered');
      expect(activitySentence(entry('table_booking.bottle_service_status_updated', details: {'old_status': 'x', 'new_status': 'served'})), 'A bottle order moved from another step to Delivered');
    });

    test('seating and staff', () {
      expect(activitySentence(entry('booking.seated')), 'The guest was seated');
      expect(activitySentence(entry('booking.seated', details: {'estimate_minutes': 20})), 'The guest was seated. Estimate: 20 minutes');
      expect(activitySentence(entry('booking.estimate_set', details: {'to_minutes': 90})), 'The service estimate was set to 1 h 30 min');
      expect(activitySentence(entry('booking.estimate_set', details: {'to_minutes': 60})), 'The service estimate was set to 1 hour');
      expect(activitySentence(entry('booking.estimate_set', details: {'to_minutes': 1})), 'The service estimate was set to 1 minute');
      expect(activitySentence(entry('booking.estimate_set')), 'The service estimate was changed');
      expect(activitySentence(entry('booking.unseated', details: {'reason': 'wrong table'})), 'Seating was undone: wrong table');
      expect(activitySentence(entry('booking.unseated')), 'Seating was undone');
      expect(activitySentence(entry('booking.server_assigned')), 'The table was given to a server');
      expect(activitySentence(entry('booking.server_reassigned')), 'The table was given to a different server');
      expect(activitySentence(entry('booking.server_removed')), 'The table was taken off its server');
      expect(activitySentence(entry('table_booking.resent')), 'The confirmation e-mail was sent again');
    });

    test('door scans say who was scanned', () {
      expect(activitySentence(entry('scan.ok', kind: 'scan', details: {'guest': false})), 'The booking holder was scanned in at the door');
      expect(activitySentence(entry('scan.ok', kind: 'scan', details: {'guest': true})), 'A guest was scanned in at the door');
      expect(activitySentence(entry('scan.already_checked_in', kind: 'scan', details: {'guest': true})), 'A guest\'s code was scanned again (already in)');
      expect(activitySentence(entry('scan.already_checked_in', kind: 'scan', details: {'guest': false})), 'The holder\'s code was scanned again (already in)');
      expect(activitySentence(entry('scan.not_paid', kind: 'scan')), 'A scan was refused: the booking is not paid');
      expect(activitySentence(entry('scan.expired', kind: 'scan')), 'A scan was refused: the booking has expired');
      expect(activitySentence(entry('scan.not_found', kind: 'scan')), 'A code that does not match was scanned');
      expect(activitySentence(entry('scan.code_required', kind: 'scan')), 'A scan was held: the entry code is needed');
    });

    test('an action this version does not know is still shown, in plain words, never hidden', () {
      expect(activitySentence(entry('table_booking.refund_issued')), 'Table booking refund issued');
      expect(activitySentence(entry('x')), 'X');
      expect(activitySentence(entry('..')), 'Something happened');
    });

    test('every action the website records for a booking has a sentence of its own', () {
      final sql = File('../bottles-up-website-main/supabase/migrations/20261020110000_booking_guests_and_activity.sql');
      if (!sql.existsSync()) return;
      // The actions the earlier migrations log with desk_log() against a booking, its bottle lines, payments or flags.
      for (final action in [
        'table_booking.club_payment_recorded', 'table_booking.club_payment_manager_verified', 'table_booking.bottle_service_status_updated',
        'booking.seated', 'booking.estimate_set', 'booking.unseated', 'booking.server_assigned', 'booking.server_reassigned', 'booking.server_removed',
        'payment.flagged', 'payment.flag_resolved',
      ]) {
        final words = action.replaceAll(RegExp(r'[._]+'), ' ');
        expect(activitySentence(entry(action)), isNot(equals(words[0].toUpperCase() + words.substring(1))), reason: '$action falls back to the generic wording');
      }
    });
  });

  group('the same functions and fields as the database (checked when the website is beside this app)', () {
    final sql = File('../bottles-up-website-main/supabase/migrations/20261020110000_booking_guests_and_activity.sql');

    test('the function and argument names the service sends', () {
      if (!sql.existsSync()) return;
      final text = sql.readAsStringSync();
      expect(text, contains('create function public.desk_booking_guests(p_booking uuid)'));
      expect(text, contains('create function public.desk_booking_activity(p_booking uuid, p_limit int default 100)'));
    });

    test('the fields the app reads are the fields the database sends', () {
      if (!sql.existsSync()) return;
      final text = sql.readAsStringSync();
      for (final k in ['holder_name', 'holder_checked_in_at', 'party_size', 'max_guests', 'table_name', 'guests_left', 'ticket_sent', 'checked_in_at', 'guests']) {
        expect(text, contains("'$k'"), reason: k);
      }
      expect(text, contains('returns table (at timestamptz, kind text, action text, actor text, details jsonb)'));
    });

    test('the detail fields the sentences use are in the database\'s list', () {
      if (!sql.existsSync()) return;
      final text = sql.readAsStringSync();
      for (final k in ['amount_paid_cents', 'payment_method', 'old_status', 'new_status', 'estimate_minutes', 'to_minutes', 'reason', 'resolution']) {
        expect(text, contains("'$k'"), reason: k);
      }
    });
  });
}
