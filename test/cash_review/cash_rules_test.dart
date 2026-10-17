import 'package:bottles_up_vendor/features/cash_review/logic/cash_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading what the database sends', () {
    test('a cash line, with a name when there is none', () {
      final l = parseCashLine({'collector_name': 'Sam', 'is_me': true, 'collected_cents': 7800, 'handed_in_cents': 3000, 'held_cents': 4800})!;
      expect([l.collectorName, l.isMe, l.collectedCents, l.handedInCents, l.heldCents], ['Sam', true, 7800, 3000, 4800]);
      final n = parseCashLine({'collected_cents': '100'})!;
      expect(n.collectorName, 'Staff member');
      expect(n.isMe, isFalse);
      expect(n.collectedCents, 100, reason: 'a number sent as text is still a number');
      expect(n.heldCents, 0);
    });

    test('a handover needs an id, and counted/difference stay empty until it is counted', () {
      expect(parseHandover({'claimed_cents': 100}), isNull);
      final waiting = parseHandover({'handover_id': 'h1', 'collector_name': 'Sam', 'is_mine': false, 'claimed_cents': 3000, 'status': 'submitted', 'counted_cents': null})!;
      expect(waiting.waiting, isTrue);
      expect(waiting.acknowledged, isFalse);
      expect(waiting.countedCents, isNull);
      expect(waiting.differenceCents, isNull);
      final done = parseHandover({
        'handover_id': 'h2', 'claimed_cents': 3000, 'status': 'acknowledged', 'counted_cents': 0, 'difference_cents': -3000,
        'received_by_name': 'Vera', 'receive_note': 'nothing came', 'submitted_at': '2026-10-09T23:30:00Z',
      })!;
      expect(done.acknowledged, isTrue);
      expect(done.countedCents, 0, reason: 'nothing counted is 0, not "not counted"');
      expect(done.differenceCents, -3000);
      expect(done.receivedByName, 'Vera');
      expect(done.submittedAt, isNotNull);
    });

    test('a flag needs both ids', () {
      expect(parseFlag({'flag_id': 'f1'}), isNull);
      expect(parseFlag({'payment_id': 'p1'}), isNull);
      final f = parseFlag({'flag_id': 'f1', 'payment_id': 'p1', 'status': 'resolved', 'resolution': 'corrected'})!;
      expect(f.open, isFalse);
      expect(f.customerName, 'Guest');
      expect(f.tableName, 'Table');
      expect(f.raisedByName, 'Staff member');
      expect(parseFlag({'flag_id': 'f2', 'payment_id': 'p2'})!.open, isTrue);
    });

    test('the summary reads all ten numbers', () {
      final s = parseVerifierSummary({
        'payments_recorded': 6, 'payments_checked': 1, 'payments_to_check': 2, 'payments_disputed': 3, 'checked_by_me': 4,
        'flags_open': 5, 'flags_resolved': 7, 'handovers_waiting': 8, 'handovers_acknowledged': 9, 'cash_difference_cents': -100,
      })!;
      expect([s.paymentsRecorded, s.paymentsChecked, s.paymentsToCheck, s.paymentsDisputed, s.checkedByMe], [6, 1, 2, 3, 4]);
      expect([s.flagsOpen, s.flagsResolved, s.handoversWaiting, s.handoversAcknowledged, s.cashDifferenceCents], [5, 7, 8, 9, -100]);
      expect(parseVerifierSummary({})!.paymentsRecorded, 0);
    });
  });

  group('words for a difference', () {
    test('a shortage, an overage and a match are said in words', () {
      expect(differenceLabel(0), 'Matches');
      expect(differenceLabel(-100), r'Short $1.00');
      expect(differenceLabel(250), r'Over $2.50');
      expect(differenceLabel(-12345), r'Short $123.45');
    });

    test('every way a flag can end has a label, and an unknown one falls back to its own text', () {
      for (final (value, label) in flagResolutions) {
        expect(resolutionLabel(value), label);
      }
      expect(resolutionLabel('mystery'), 'mystery');
      expect(resolutionLabel(null), '');
    });
  });

  group('handing in cash', () {
    test('an amount is needed, above zero, and no more than is held', () {
      expect(checkHandoverAmount('', 5000).error, contains('Enter the amount'));
      expect(checkHandoverAmount('abc', 5000).error, contains('Enter the amount'));
      expect(checkHandoverAmount('0', 5000).error, 'Enter an amount above zero.');
      expect(checkHandoverAmount('0.00', 5000).error, 'Enter an amount above zero.');
      expect(checkHandoverAmount('50.01', 5000).error, r'You only hold $50.00.');
      expect(checkHandoverAmount('50.00', 5000).cents, 5000, reason: 'all of it is allowed');
      expect(checkHandoverAmount('12.5', 5000).cents, 1250);
      expect(checkHandoverAmount(r'$12.50', 5000).cents, 1250);
      expect(checkHandoverAmount('0.01', 5000).cents, 1);
    });

    test('with nothing held no amount is possible', () {
      expect(checkHandoverAmount('1', 0).error, r'You only hold $0.00.');
    });

    test('the note has a limit', () {
      expect(checkCashNote('x' * 300), isNull);
      expect(checkCashNote('x' * 301), contains('300'));
      expect(checkCashNote(''), isNull);
    });

    test('what is sent is trimmed, and an empty note is no note', () {
      expect(submitHandoverParams('v1', '2026-10-09', 1250, '  '), {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_amount_cents': 1250, 'p_note': null});
      expect(submitHandoverParams('v1', '2026-10-09', 1250, ' first part ')['p_note'], 'first part');
    });
  });

  group('counting cash', () {
    test('what was counted can be nothing, but must be a number', () {
      expect(checkCountedAmount('0').cents, 0);
      expect(checkCountedAmount('29').cents, 2900);
      expect(checkCountedAmount('').error, contains('Enter the amount you counted'));
      expect(checkCountedAmount('lots').error, contains('Enter the amount you counted'));
    });

    test('a difference needs a reason, a match does not', () {
      expect(checkCountReason(claimedCents: 3000, countedCents: 3000, note: ''), isNull);
      expect(checkCountReason(claimedCents: 3000, countedCents: 2900, note: ''), contains('say why'));
      expect(checkCountReason(claimedCents: 3000, countedCents: 2900, note: 'x'), contains('say why'));
      expect(checkCountReason(claimedCents: 3000, countedCents: 2900, note: 'abc'), isNull);
      expect(checkCountReason(claimedCents: 3000, countedCents: 3100, note: 'tip jar'), isNull);
      expect(checkCountReason(claimedCents: 3000, countedCents: 3000, note: 'x' * 301), contains('300'));
    });

    test('what is sent', () {
      expect(receiveHandoverParams('h1', 2900, ' torn note '), {'p_handover': 'h1', 'p_counted_cents': 2900, 'p_note': 'torn note'});
      expect(receiveHandoverParams('h1', 3000, '')['p_note'], isNull);
    });
  });

  group('flagging and resolving', () {
    test('a flag needs a real reason', () {
      expect(checkFlagReason(''), contains('Say what is wrong'));
      expect(checkFlagReason('  ab '), contains('Say what is wrong'));
      expect(checkFlagReason('abc'), isNull);
      expect(checkFlagReason('x' * 500), isNull);
      expect(checkFlagReason('x' * 501), contains('500'));
    });

    test('an outcome is needed, and only "the payment is fine" can go without a note', () {
      expect(checkResolution(null, ''), 'Choose how it was resolved.');
      expect(checkResolution('ignored', 'abc'), 'Choose how it was resolved.');
      expect(checkResolution('confirmed_ok', ''), isNull);
      expect(checkResolution('corrected', ''), 'Say what was done.');
      expect(checkResolution('refunded', 'ab'), 'Say what was done.');
      expect(checkResolution('written_off', 'abc'), isNull);
      expect(checkResolution('other', 'x' * 501), contains('500'));
      expect(checkResolution('confirmed_ok', 'x' * 501), contains('500'));
    });
  });
}
