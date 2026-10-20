import 'package:bottles_up_vendor/features/payouts/logic/payout_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_payout_backend.dart';

PayoutItem item({String status = 'paid', int adjustment = 0, String? note, String? reference = 'TRF-1', String? failure, String? expected}) =>
    parsePayoutItem(FakePayoutBackend.item('i1', status: status, adjustment: adjustment, note: note, reference: reference, failure: failure, expected: expected))!;

void main() {
  group('reading what the business is paid', () {
    Map<String, dynamic> answer() => {
          'org_kind': 'venue_owner',
          'account': {'status': 'under_review', 'account_holder': ' Club Co ', 'masked_account': '•••• 9876', 'note': ''},
          'settings': {'payout_method': 'manual_transfer', 'commission_set': true, 'commission_bps': 1000, 'payout_weekday': 5, 'hold_days': 3, 'next_payout_on': '2026-10-30', 'own_arrangement': true},
          'waiting': {'bookings': 2, 'gross_cents': 20000},
          'items': [FakePayoutBackend.item('i1'), 'junk', {'id': 'bad'}],
        };

    test('the account, the arrangement, what is waiting and the payouts are read; a payout that cannot be read is dropped', () {
      final p = parseMyPayouts(answer())!;
      expect([p.isVenueBusiness, p.account.status, p.account.holder, p.account.maskedAccount, p.account.note], [true, PayoutAccountStatus.underReview, 'Club Co', '•••• 9876', null]);
      expect([p.settings.weekday, p.settings.holdDays, p.settings.commissionSet, p.settings.commissionBps, p.settings.nextPayoutOn, p.settings.ownArrangement], [5, 3, true, 1000, '2026-10-30', true]);
      expect([p.waiting!.bookings, p.waiting!.grossCents], [2, 20000]);
      expect(p.items.map((i) => i.id), ['i1']);
    });

    test('an organizer has nothing waiting and is not a venue business', () {
      final p = parseMyPayouts({...answer(), 'org_kind': 'organizer', 'waiting': null})!;
      expect([p.isVenueBusiness, p.waiting], [false, null]);
    });

    test('an answer that is not the payouts, or has a weekday that is not one, is not trusted', () {
      expect(parseMyPayouts(null), isNull);
      expect(parseMyPayouts('ok'), isNull);
      expect(parseMyPayouts({'org_kind': 'venue_owner'}), isNull);
      expect(parseMyPayouts({...answer(), 'account': {'status': 'mystery'}}), isNull);
      final s = (answer()['settings'] as Map<String, dynamic>);
      expect(parseMyPayouts({...answer(), 'settings': {...s, 'payout_weekday': 7}}), isNull);
      expect(parseMyPayouts({...answer(), 'settings': {...s, 'payout_weekday': -1}}), isNull);
      expect(parseMyPayouts({...answer(), 'settings': {...s}..remove('hold_days')}), isNull);
    });

    test('the percentage is only known once BottlesUp has set it', () {
      final p = parseMyPayouts({...answer(), 'settings': {...(answer()['settings'] as Map<String, dynamic>), 'commission_set': false, 'commission_bps': null}})!;
      expect([p.settings.commissionSet, p.settings.commissionBps], [false, null]);
    });

    test('a payout without what it needs is dropped', () {
      final base = FakePayoutBackend.item('i1');
      expect(parsePayoutItem(base), isNotNull);
      for (final k in ['id', 'period_start', 'period_end', 'gross_cents', 'commission_cents', 'net_cents']) {
        expect(parsePayoutItem({...base}..remove(k)), isNull, reason: k);
      }
      expect(parsePayoutItem({...base, 'status': 'cancelled'}), isNull, reason: 'a cancelled payout is never shown');
    });
  });

  group('words', () {
    test('the account statuses say what they mean', () {
      expect([for (final s in PayoutAccountStatus.values) s.label], ['Not set up yet', 'Under review', 'Ready', 'Action needed']);
      expect(PayoutAccountStatus.incomplete.explanation, contains('Nothing can be paid out'));
      expect(PayoutAccountStatus.actionRequired.explanation, contains('needs something from you'));
    });

    test('the payout statuses are in plain words', () {
      expect([for (final s in PayoutItemStatus.values) s.label], ['Being prepared', 'On its way', 'Paid', 'Did not go through']);
    });

    test('a percentage from basis points', () {
      expect(percentFromBps(0), '0%');
      expect(percentFromBps(1000), '10%');
      expect(percentFromBps(1250), '12.5%');
      expect(percentFromBps(1205), '12.05%');
      expect(percentFromBps(5), '0.05%');
      expect(percentFromBps(10000), '100%');
    });

    test('dates read with their weekday', () {
      expect(payoutDate('2026-10-28'), 'Wednesday 28 October 2026');
      expect(payoutDate('2026-11-01'), 'Sunday 1 November 2026');
      expect(payoutDate('2026-10-28T10:00:00Z'), 'Wednesday 28 October 2026');
      expect(payoutDate('soon'), 'soon');
      expect(payoutDate('2026-13-01'), '2026-13-01');
    });

    test('the arrangement in words', () {
      final p = parseMyPayouts({
        'org_kind': 'venue_owner',
        'account': {'status': 'ready'},
        'settings': {'commission_set': true, 'commission_bps': 1250, 'payout_weekday': 3, 'hold_days': 2, 'own_arrangement': true},
        'items': [],
      })!;
      expect(settingsLines(p.settings), [
        'BottlesUp pays out every Wednesday, by bank transfer.',
        'Money waits 2 days after the night before it is included.',
        'BottlesUp keeps 12.5% of what it pays out.',
        'This is an arrangement made for your business.',
      ]);
    });

    test('no hold, one day of hold, and a percentage not yet decided', () {
      PayoutSettings s({int hold = 2, bool set = true, int? bps = 1000, bool own = false}) =>
          PayoutSettings(method: 'manual_transfer', commissionSet: set, commissionBps: bps, weekday: 0, holdDays: hold, ownArrangement: own);
      expect(settingsLines(s(hold: 0))[1], 'Money is included as soon as the night is over.');
      expect(settingsLines(s(hold: 1))[1], 'Money waits 1 day after the night before it is included.');
      expect(settingsLines(s(set: false, bps: null))[2], 'BottlesUp has not set its percentage yet.');
      expect(settingsLines(s(set: true, bps: null))[2], 'BottlesUp has not set its percentage yet.', reason: 'a percentage without a number is not shown as one');
      expect(settingsLines(s()), hasLength(3), reason: 'no line about an own arrangement');
      expect(settingsLines(s())[0], 'BottlesUp pays out every Sunday, by bank transfer.');
    });

    test('what is waiting', () {
      expect(waitingLine(const PayoutWaiting(bookings: 0, grossCents: 0)), 'Nothing is waiting for the next payout.');
      expect(waitingLine(const PayoutWaiting(bookings: 1, grossCents: 15000)), '1 booking with \$150.00 collected online is waiting for the next payout. This is an estimate, before BottlesUp\'s percentage.');
      expect(waitingLine(const PayoutWaiting(bookings: 3, grossCents: 45000)), '3 bookings with \$450.00 collected online are waiting for the next payout. This is an estimate, before BottlesUp\'s percentage.');
      expect(clubCashNote, contains('never paid to you again'));
    });

    test('a payout in words: the period, the money, the adjustment, and where it stands', () {
      expect(itemHeadline(item()), 'Monday 5 October 2026 to Sunday 11 October 2026');
      expect(itemMoneyLine(item()), '\$1,000.00 collected · \$125.00 BottlesUp');
      expect(itemMoneyLine(item(adjustment: 2500, note: 'Bonus')), '\$1,000.00 collected · \$125.00 BottlesUp · +\$25.00 adjustment');
      expect(itemMoneyLine(item(adjustment: -2500, note: 'Refund taken off')), '\$1,000.00 collected · \$125.00 BottlesUp · -\$25.00 adjustment');
      expect(itemStatusLine(item(status: 'pending', reference: null)), 'Being prepared');
      expect(itemStatusLine(item(status: 'pending', reference: null, expected: '2026-10-28')), 'Being prepared: expected Wednesday 28 October 2026');
      expect(itemStatusLine(item(status: 'processing', reference: null, expected: '2026-10-28')), 'On its way: expected Wednesday 28 October 2026');
      expect(itemStatusLine(item(status: 'processing', reference: null)), 'On its way');
      expect(itemStatusLine(item()), allOf(startsWith('Paid on '), endsWith(' · reference TRF-1')));
      expect(itemStatusLine(item(status: 'failed', reference: null, failure: 'Bank rejected it')), 'Did not go through: Bank rejected it. BottlesUp will be in touch.');
      expect(itemStatusLine(item(status: 'failed', reference: null)), 'Did not go through. BottlesUp will be in touch.');
    });

    test('the net is what is paid: gross less BottlesUp\'s share plus the adjustment', () {
      final i = item(adjustment: 2500, note: 'Bonus');
      expect(i.netCents, i.grossCents - i.commissionCents + i.adjustmentCents);
    });
  });
}
