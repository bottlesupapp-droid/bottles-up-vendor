import 'package:bottles_up_vendor/features/booking_conflicts/logic/conflict_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row({Map<String, dynamic> over = const {}}) => {
      'conflict_id': 'k1',
      'booking_id': 'b1',
      'confirmation_code': 'CF0002',
      'customer_name': 'Late Payer',
      'customer_email': 'late@example.com',
      'customer_phone': '+1 555 0122',
      'table_name': 'Last booth',
      'arrival_date': '2026-11-14',
      'arrival_time': '21:00:00',
      'guest_count': 2,
      'amount_paid_cents': 10000,
      'currency': 'cad',
      'tables_counted': 2,
      'tables_available': 1,
      'status': 'open',
      'resolution': null,
      'resolution_note': null,
      'created_at': '2026-11-14T21:40:00Z',
      'resolved_at': null,
      ...over,
    };

void main() {
  group('parseConflict', () {
    test('reads a whole row', () {
      final c = parseConflict(row())!;
      expect([c.conflictId, c.bookingId, c.confirmationCode, c.customerName, c.customerEmail, c.customerPhone], ['k1', 'b1', 'CF0002', 'Late Payer', 'late@example.com', '+1 555 0122']);
      expect([c.tableName, c.arrivalDate, c.arrivalTime, c.guestCount, c.amountPaidCents, c.tablesCounted, c.tablesAvailable], ['Last booth', '2026-11-14', '21:00', 2, 10000, 2, 1]);
      expect(c.isOpen, isTrue);
      expect(c.resolution, isNull);
      expect(c.createdAt, DateTime.utc(2026, 11, 14, 21, 40));
      expect(c.hasContact, isTrue);
    });

    test('a settled one carries how and the words', () {
      final c = parseConflict(row(over: {'status': 'resolved', 'resolution': 'moved', 'resolution_note': 'Moved to table 4', 'resolved_at': '2026-11-14T22:00:00Z'}))!;
      expect([c.isOpen, c.resolution, c.resolutionNote, c.resolvedAt], [false, ConflictResolution.moved, 'Moved to table 4', DateTime.utc(2026, 11, 14, 22)]);
    });

    test('missing words fall back to plain ones, and no contact is no contact', () {
      final c = parseConflict(row(over: {'customer_name': null, 'table_name': '', 'customer_email': null, 'customer_phone': '', 'confirmation_code': null, 'arrival_time': null}))!;
      expect([c.customerName, c.tableName, c.customerEmail, c.customerPhone, c.confirmationCode, c.arrivalTime], ['A guest', 'A table', null, null, null, '']);
      expect(c.hasContact, isFalse);
    });

    test('only an e-mail, or only a phone, still counts as a way to reach them', () {
      expect(parseConflict(row(over: {'customer_phone': null}))!.hasContact, isTrue);
      expect(parseConflict(row(over: {'customer_email': null}))!.hasContact, isTrue);
    });

    test('a row that cannot be identified, or has an unknown state, is dropped: never shown as open or as settled', () {
      expect(parseConflict({...row(), 'conflict_id': null}), isNull);
      expect(parseConflict({...row(), 'conflict_id': ''}), isNull);
      expect(parseConflict({...row(), 'booking_id': null}), isNull);
      expect(parseConflict({...row(), 'status': 'maybe'}), isNull);
      expect(parseConflict({...row(), 'status': null}), isNull);
    });

    test('an unknown way of settling is ignored, not guessed', () {
      expect(parseConflict(row(over: {'status': 'resolved', 'resolution': 'ignored'}))!.resolution, isNull);
    });

    test('the amounts are read even when they arrive as numbers with decimals or text', () {
      final c = parseConflict(row(over: {'amount_paid_cents': 10000.0, 'guest_count': '3'}))!;
      expect([c.amountPaidCents, c.guestCount], [10000, 3]);
    });
  });

  group('the words', () {
    test('where and when', () {
      expect(conflictWhere(parseConflict(row())!), 'Saturday Nov 14 · 21:00 · Last booth');
      expect(conflictWhere(parseConflict(row(over: {'arrival_date': null, 'arrival_time': null}))!), 'Last booth');
    });

    test('what is wrong, in one sentence, with the right plural', () {
      expect(conflictSentence(parseConflict(row())!), 'Paid after the table had gone to another guest: 2 bookings and holds for 1 table. No confirmation has been sent to them.');
      expect(conflictSentence(parseConflict(row(over: {'tables_counted': 4, 'tables_available': 3}))!), contains('4 bookings and holds for 3 tables'));
      expect(conflictSentence(parseConflict(row(over: {'tables_counted': 1, 'tables_available': 0}))!), contains('1 booking or hold for 0 tables'));
    });

    test('a settled one says how', () {
      expect(conflictSentence(parseConflict(row(over: {'status': 'resolved', 'resolution': 'refunded'}))!), 'Settled: refunded or cancelled.');
      expect(conflictSentence(parseConflict(row(over: {'status': 'resolved'}))!), 'Settled: dealt with.');
    });

    test('what the guest paid', () {
      expect(paidLine(parseConflict(row())!), 'Paid \$100.00 · 2 guests');
      expect(paidLine(parseConflict(row(over: {'guest_count': 1, 'amount_paid_cents': 12550}))!), 'Paid \$125.50 · 1 guest');
    });

    test('the three ways of settling use the database\'s words', () {
      expect([for (final c in ConflictResolution.values) c.db], ['moved', 'refunded', 'kept']);
      for (final c in ConflictResolution.values) {
        expect(c.label.isNotEmpty && c.hint.isNotEmpty, isTrue);
      }
    });
  });

  group('closing one', () {
    test('a way and a few words are needed', () {
      expect(validateResolution(null, 'Moved to table 4'), 'Say how it was settled.');
      expect(validateResolution(ConflictResolution.moved, ''), 'Say what was done, in a few words.');
      expect(validateResolution(ConflictResolution.moved, '   '), 'Say what was done, in a few words.');
      expect(validateResolution(ConflictResolution.moved, 'ok'), 'Say what was done, in a few words.');
      expect(validateResolution(ConflictResolution.moved, ' ok '), 'Say what was done, in a few words.', reason: 'the spaces do not count');
    });

    test('three characters are enough and 500 are the most', () {
      expect(validateResolution(ConflictResolution.kept, 'Yes'), isNull);
      expect(validateResolution(ConflictResolution.kept, 'x' * 500), isNull);
      expect(validateResolution(ConflictResolution.kept, 'x' * 501), 'Keep the note to 500 characters or fewer.');
      expect([conflictNoteMin, conflictNoteMax], [3, 500]);
    });

    test('what is sent: the conflict, the way and the trimmed words', () {
      expect(resolveParams('k1', ConflictResolution.moved, '  Moved to table 4  '), {'p_conflict': 'k1', 'p_resolution': 'moved', 'p_note': 'Moved to table 4'});
    });
  });
}
