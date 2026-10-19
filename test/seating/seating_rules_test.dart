import 'package:bottles_up_vendor/features/seating/logic/seating_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading what the database sends', () {
    test('a match needs a booking id and has safe fallbacks', () {
      expect(parseBookingMatch({'customer_name': 'Ada'}), isNull);
      final m = parseBookingMatch({'booking_id': 'b1'})!;
      expect([m.customerName, m.tableName, m.guestCount, m.seated, m.isMine, m.canSeat], ['Guest', 'Table', 0, false, false, false]);
      final full = parseBookingMatch({
        'booking_id': 'b1', 'confirmation_code': 'ADA111', 'customer_name': 'Ada', 'table_name': 'VIP booth', 'guest_count': 4,
        'start_time': '21:00:00', 'seated': true, 'server_name': 'Sam', 'is_mine': true, 'can_seat': true,
      })!;
      expect([full.code, full.guestCount, full.startTime, full.seated, full.serverName, full.isMine, full.canSeat], ['ADA111', 4, '21:00:00', true, 'Sam', true, true]);
    });

    test('the seating state keeps "no estimate" apart from an estimate', () {
      final none = parseSeatingState({'seated': false})!;
      expect(none.seated, isFalse);
      expect(none.estimateMinutes, isNull);
      final s = parseSeatingState({'seated': true, 'seated_at': '2026-10-09T21:42:00Z', 'method': 'scan', 'estimate_minutes': 25, 'seated_by_name': 'Sam'})!;
      expect([s.seated, s.method, s.estimateMinutes, s.seatedByName], [true, 'scan', 25, 'Sam']);
      expect(s.seatedAt, isNotNull);
    });

    test('the outcome of seating, from the json the database returns', () {
      expect(parseSeatOutcome({'already': true, 'estimate_minutes': 20}).already, isTrue);
      expect(parseSeatOutcome({'already': false}).estimateMinutes, isNull);
      expect(parseSeatOutcome(null).already, isFalse);
      expect(parseSeatOutcome('junk').already, isFalse);
    });

    test('a guest message never claims more than happened', () {
      final queued = parseGuestMessage({'kind': 'seated_ack', 'status': 'queued'})!;
      expect(queued.kindLabel, 'Arrival confirmation');
      expect(queued.statusLabel, 'Queued, not sent yet');
      expect(parseGuestMessage({'kind': 'estimate_updated', 'status': 'sent'})!.statusLabel, 'Sent');
      expect(parseGuestMessage({'kind': 'estimate_updated', 'status': 'sent'})!.kindLabel, 'Service estimate update');
      expect(parseGuestMessage({'kind': 'seated_ack', 'status': 'failed', 'last_error': 'mailbox full'})!.statusLabel, 'Failed: mailbox full');
      expect(parseGuestMessage({'kind': 'seated_ack', 'status': 'failed'})!.statusLabel, 'Failed');
      expect(parseGuestMessage({'kind': 'seated_ack'})!.statusLabel, 'Queued, not sent yet', reason: 'no status is queued, never sent');
      expect(parseGuestMessage({'kind': 'mystery', 'status': 'queued'})!.kindLabel, 'mystery');
      expect(parseGuestMessage({'status': 'sent'}), isNull);
    });
  });

  group('the code the camera read', () {
    test('a plain code stays as it is', () {
      expect(normalizeBookingCode('ADA111'), 'ADA111');
      expect(normalizeBookingCode('  ada111 \n'), 'ada111');
    });

    test('a link carrying the code gives the code', () {
      expect(normalizeBookingCode('https://www.bottlesupapp.com/booking?code=ADA111'), 'ADA111');
      expect(normalizeBookingCode('https://www.bottlesupapp.com/booking/ADA111'), 'ADA111');
      expect(normalizeBookingCode('https://www.bottlesupapp.com/booking/ADA111/'), 'ADA111');
    });

    test('something enormous is cut, not sent whole', () {
      expect(normalizeBookingCode('x' * 500).length, 60);
    });
  });

  group('what a person types', () {
    test('the search needs a code or 3 letters, and not an essay', () {
      expect(checkSearch(''), contains('at least 3'));
      expect(checkSearch('ab'), contains('at least 3'));
      expect(checkSearch('  ab  '), contains('at least 3'));
      expect(checkSearch('abc'), isNull);
      expect(checkSearch('x' * 60), isNull);
      expect(checkSearch('x' * 61), contains('too long'));
    });

    test('an estimate is empty (none) or whole minutes from 1 to 480', () {
      expect(checkEstimate(''), (minutes: null, error: null));
      expect(checkEstimate('  '), (minutes: null, error: null));
      expect(checkEstimate('25'), (minutes: 25, error: null));
      expect(checkEstimate('1').minutes, 1);
      expect(checkEstimate('480').minutes, 480);
      for (final bad in ['0', '481', '-5', 'soon', '2.5', '1e3']) {
        expect(checkEstimate(bad).error, contains('between 1 and 480'), reason: bad);
        expect(checkEstimate(bad).minutes, isNull, reason: bad);
      }
    });

    test('the detail checked by hand needs real words', () {
      expect(checkManualDetail(''), contains('Say what you checked'));
      expect(checkManualDetail('ok'), contains('Say what you checked'));
      expect(checkManualDetail('email'), isNull);
      expect(checkManualDetail('x' * 300), isNull);
      expect(checkManualDetail('x' * 301), contains('300'));
    });
  });

  group('words for times', () {
    test('an estimate', () {
      expect(estimateLabel(1), '1 min');
      expect(estimateLabel(59), '59 min');
      expect(estimateLabel(60), '1 h');
      expect(estimateLabel(65), '1 h 5 min');
      expect(estimateLabel(480), '8 h');
    });

    test('an arrival time from the database\'s "21:00:00"', () {
      expect(startLabel('21:00:00'), '9:00 PM');
      expect(startLabel('01:30:00'), '1:30 AM');
      expect(startLabel('12:00:00'), '12:00 PM');
      expect(startLabel(null), '');
      expect(startLabel('x'), '');
      expect(startLabel('ab:cd:00'), '');
    });
  });
}
