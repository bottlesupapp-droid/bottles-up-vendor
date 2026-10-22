import 'package:bottles_up_vendor/features/refunds/logic/refund_rules.dart';
import 'package:flutter_test/flutter_test.dart';

RefundPolicyForm form(List<(String, String)> rules, {bool after = true, String note = ''}) =>
    RefundPolicyForm(tiers: [for (final r in rules) TierForm(hours: r.$1, percent: r.$2)], noRefundAfterCheckIn: after, note: note);

RefundRequest request({String status = 'requested', String? method, int? approved, int available = 10000, int suggested = 5000, int? percent = 50, String? note, String? failure, String kind = 'guest', String? reference, String? receipt}) =>
    parseRefundRequest({
      'request_id': 'rq1',
      'booking_id': 'b1',
      'confirmation_code': 'AB12CD',
      'guest_name': 'Ada Lovelace',
      'table_name': 'VIP booth',
      'booking_date': '2026-10-24',
      'requested_by_kind': kind,
      'reason': 'I am ill',
      'status': status,
      'paid_cents': 10000,
      'available_cents': available,
      'policy_percent': percent,
      'suggested_cents': suggested,
      'approved_cents': approved,
      'method': method,
      'decision_note': note,
      'failure_note': failure,
      'refund_reference': reference,
      'refund_receipt_path': receipt,
      'created_at': '2026-10-21T12:00:00Z',
    })!;

void main() {
  group('the policy in words (the same sentences the database writes)', () {
    test('rules are listed most notice first, with days spoken plainly, and the notes the venue wrote', () {
      expect(
        refundPolicyLines(tiers: const [RefundTier(hours: 24, percent: 50), RefundTier(hours: 48, percent: 100)], noRefundAfterCheckIn: true, note: 'Ask us at the door if something went wrong.'),
        [
          'Cancel at least 2 days before you arrive: the whole deposit is refunded.',
          'Cancel at least 1 day before you arrive: 50% of the deposit is refunded.',
          'Later than that: no refund.',
          'Once the guests have arrived there is no refund.',
          'Ask us at the door if something went wrong.',
        ],
      );
    });

    test('hours that are not whole days stay hours; 1 is singular; 0 is any time before arrival; no "later than" when the last rule is any time', () {
      expect(
        refundPolicyLines(tiers: const [RefundTier(hours: 36, percent: 100), RefundTier(hours: 1, percent: 25), RefundTier(hours: 0, percent: 10)], noRefundAfterCheckIn: false),
        [
          'Cancel at least 36 hours before you arrive: the whole deposit is refunded.',
          'Cancel at least 1 hour before you arrive: 25% of the deposit is refunded.',
          'Cancel any time before you arrive: 10% of the deposit is refunded.',
        ],
      );
    });

    test('no rules means the deposit is not refundable', () {
      expect(refundPolicyLines(tiers: const [], noRefundAfterCheckIn: true), ['The deposit is not refundable.', 'Once the guests have arrived there is no refund.']);
    });

    test('0 percent reads "no refund"', () {
      expect(refundPolicyLines(tiers: const [RefundTier(hours: 12, percent: 0)], noRefundAfterCheckIn: true), [
        'Cancel at least 12 hours before you arrive: no refund.',
        'Later than that: no refund.',
        'Once the guests have arrived there is no refund.',
      ]);
    });

    test('a venue with no policy says refunds are decided by the venue, and a blank note adds nothing', () {
      expect(refundPolicyLines(tiers: const [], noRefundAfterCheckIn: true, hasPolicy: false), ['This venue has not set a refund policy: refunds are decided by the venue.']);
      expect(refundPolicyLines(tiers: const [], noRefundAfterCheckIn: false, note: '   '), ['The deposit is not refundable.']);
    });
  });

  group('reading the policy', () {
    test('the rows are read, with what the database says in words', () {
      final p = parseRefundPolicy({
        'has_policy': true,
        'tiers': [
          {'hours': 48, 'percent': 100},
          {'hours': '24', 'percent': 50},
          {'hours': 'x', 'percent': 50},
          'nonsense',
        ],
        'no_refund_after_check_in': false,
        'note': ' Hello ',
        'lines': ['One.', '', null, 'Two.'],
      })!;
      expect(p.hasPolicy, isTrue);
      expect(p.tiers, const [RefundTier(hours: 48, percent: 100), RefundTier(hours: 24, percent: 50)]);
      expect(p.noRefundAfterCheckIn, isFalse);
      expect(p.note, 'Hello');
      expect(p.lines, ['One.', 'Two.']);
    });

    test('no policy yet, and something that is not a policy', () {
      final p = parseRefundPolicy({'has_policy': false, 'tiers': [], 'lines': ['This venue has not set a refund policy: refunds are decided by the venue.']})!;
      expect(p.hasPolicy, isFalse);
      expect(p.noRefundAfterCheckIn, isTrue, reason: 'a missing flag is the safe default');
      expect(parseRefundPolicy({'hello': 1}), isNull);
    });

    test('a venue with no policy is offered a starting point; one with a policy is edited as it is', () {
      final start = policyFormFrom(null);
      expect([for (final t in start.tiers) '${t.hours}:${t.percent}'], ['48:100', '24:50']);
      expect(policyFormFrom(parseRefundPolicy({'has_policy': false, 'tiers': []})).tiers.length, 2);
      final saved = policyFormFrom(parseRefundPolicy({
        'has_policy': true,
        'tiers': [
          {'hours': 12, 'percent': 20},
        ],
        'no_refund_after_check_in': false,
        'note': 'Hi',
      }));
      expect([for (final t in saved.tiers) '${t.hours}:${t.percent}'], ['12:20']);
      expect([saved.noRefundAfterCheckIn, saved.note], [false, 'Hi']);
    });
  });

  group('checking the policy', () {
    test('a sensible policy is fine, including none at all (not refundable) and six rules', () {
      expect(validatePolicy(form([('48', '100'), ('24', '50')])), isEmpty);
      expect(validatePolicy(form([])), isEmpty);
      expect(validatePolicy(form([for (var i = 0; i < 6; i++) ('${i * 10}', '${i * 10}')])), isEmpty);
      expect(validatePolicy(form([('0', '0'), ('2160', '100')])), isEmpty);
    });

    test('a rule needs whole hours from 0 to 2160 and a whole percent from 0 to 100', () {
      for (final bad in ['', 'x', '-1', '1.5', '2161', '1e3']) {
        expect(validatePolicy(form([(bad, '50')])), ['Rule 1: give the hours of notice as a whole number from 0 to 2160.'], reason: 'hours "$bad"');
      }
      for (final bad in ['', 'x', '-1', '1.5', '101']) {
        expect(validatePolicy(form([('24', bad)])), ['Rule 1: give the percent refunded as a whole number from 0 to 100.'], reason: 'percent "$bad"');
      }
    });

    test('the problem names the rule it is in', () {
      expect(validatePolicy(form([('48', '100'), ('', '50')])), ['Rule 2: give the hours of notice as a whole number from 0 to 2160.']);
      expect(validatePolicy(form([('x', 'y'), ('z', '50')])), hasLength(3));
    });

    test('more than six rules are refused', () {
      expect(validatePolicy(form([for (var i = 0; i < 7; i++) ('$i', '0')])), contains('A refund policy can have 6 rules at most.'));
    });

    test('two rules cannot have the same notice', () {
      expect(validatePolicy(form([('24', '50'), ('24', '10')])), ['Two rules cannot have the same hours of notice.']);
    });

    test('more notice can never get less back, in any order they are typed', () {
      const msg = 'Giving more notice cannot get less back: a rule with fewer hours cannot refund a larger percent.';
      expect(validatePolicy(form([('48', '50'), ('24', '100')])), [msg]);
      expect(validatePolicy(form([('24', '100'), ('48', '50')])), [msg]);
      expect(validatePolicy(form([('48', '50'), ('24', '50')])), isEmpty, reason: 'the same percent is fine');
      expect(validatePolicy(form([('72', '100'), ('48', '50'), ('24', '60')])), [msg], reason: 'any pair that goes the wrong way');
    });

    test('the note is at most 300 characters', () {
      expect(validatePolicy(form([], note: 'x' * 300)), isEmpty);
      expect(validatePolicy(form([], note: 'x' * 301)), ['The note can be up to 300 characters.']);
      expect(validatePolicy(form([], note: '  ${'x' * 300}  ')), isEmpty, reason: 'spaces round the note do not count');
    });

    test('the payload sends all three keys, rules most notice first as whole numbers, and a blank note as none', () {
      expect(policyPayload(form([('24', '50'), ('48', '100')], after: false, note: '  ')), {
        'tiers': [
          {'hours': 48, 'percent': 100},
          {'hours': 24, 'percent': 50},
        ],
        'no_refund_after_check_in': false,
        'note': null,
      });
      expect(policyPayload(form([], note: ' Be kind ')), {'tiers': [], 'no_refund_after_check_in': true, 'note': 'Be kind'});
    });

    test('the keys are exactly the three the database accepts', () {
      expect(policyPayload(form([('1', '1')])).keys.toSet(), {'tiers', 'no_refund_after_check_in', 'note'});
      expect((policyPayload(form([('1', '1')]))['tiers'] as List).single.keys.toSet(), {'hours', 'percent'});
    });

    test('the preview is what a guest will read, and nothing while the rules are wrong', () {
      expect(previewLines(form([('48', '100')])), ['Cancel at least 2 days before you arrive: the whole deposit is refunded.', 'Later than that: no refund.', 'Once the guests have arrived there is no refund.']);
      expect(previewLines(form([('48', 'x')])), isEmpty);
    });

    test('the Save button is wanted only when something would change', () {
      final saved = parseRefundPolicy({
        'has_policy': true,
        'tiers': [
          {'hours': 48, 'percent': 100},
          {'hours': 24, 'percent': 50},
        ],
        'no_refund_after_check_in': true,
        'note': null,
        'lines': [],
      })!;
      expect(policyChanged(saved, form([('48', '100'), ('24', '50')])), isFalse);
      expect(policyChanged(saved, form([('24', '50'), ('48', '100')])), isFalse, reason: 'the order they are typed in does not matter');
      expect(policyChanged(saved, form([('48', '100'), ('24', '60')])), isTrue);
      expect(policyChanged(saved, form([('48', '100'), ('24', '50')], after: false)), isTrue);
      expect(policyChanged(saved, form([('48', '100'), ('24', '50')], note: 'x')), isTrue);
      expect(policyChanged(saved, form([('48', '100')])), isTrue);
      expect(policyChanged(saved, form([('48', 'x')])), isTrue, reason: 'a wrong one can be saved to be told what is wrong');
      expect(policyChanged(null, form([])), isTrue);
      expect(policyChanged(parseRefundPolicy({'has_policy': false, 'tiers': []}), form([])), isTrue, reason: 'a venue with no policy saving "not refundable" is a change');
    });
  });

  group('requests', () {
    test('a request is read, and one without an id, a booking, a known status, a time or a reason is dropped', () {
      final r = request(status: 'approved', method: 'club', approved: 5000);
      expect([r.guestName, r.tableName, r.code, r.byGuest, r.status, r.method, r.approvedCents], ['Ada Lovelace', 'VIP booth', 'AB12CD', true, RefundStatus.approved, RefundMethod.club, 5000]);
      final base = {'request_id': 'a', 'booking_id': 'b', 'status': 'requested', 'created_at': '2026-10-21T12:00:00Z', 'reason': 'x y z'};
      expect(parseRefundRequest(base), isNotNull);
      for (final key in ['request_id', 'booking_id', 'created_at', 'reason']) {
        expect(parseRefundRequest({...base}..remove(key)), isNull, reason: key);
      }
      expect(parseRefundRequest({...base, 'status': 'mystery'}), isNull);
      expect(parseRefundRequest({...base, 'created_at': 'yesterday'}), isNull);
    });

    test('the reference and the receipt photo of a refund paid back at the club are read', () {
      final r = request(status: 'completed', method: 'club', approved: 100, reference: 'TERM-1', receipt: 'b1/photo.jpg');
      expect([r.reference, r.receiptPath, r.hasReceiptPhoto], ['TERM-1', 'b1/photo.jpg', true]);
      final none = request(status: 'completed', method: 'club', approved: 100);
      expect([none.reference, none.receiptPath, none.hasReceiptPhoto], [null, null, false]);
    });

    test('a request made by staff is not shown as the guest\'s', () {
      expect(request(kind: 'staff').byGuest, isFalse);
    });

    test('what can be done with a request follows where it stands', () {
      expect(request().canDecide, isTrue);
      expect(request(status: 'approved', method: 'club', approved: 100).needsClubPayment, isTrue);
      expect(request(status: 'approved', method: 'online', approved: 100).waitsForBottlesUp, isTrue);
      expect(request(status: 'approved', method: 'online', approved: 100).needsClubPayment, isFalse);
      for (final s in ['declined', 'processing', 'completed', 'failed']) {
        final r = request(status: s, method: 'club', approved: 100);
        expect([r.canDecide, r.needsClubPayment, r.waitsForBottlesUp], [false, false, false], reason: s);
      }
    });

    test('each status is in plain words, and an open one is told apart', () {
      expect([for (final s in RefundStatus.values) s.label], ['Waiting for a decision', 'Approved', 'Declined', 'Being returned', 'Paid back', 'Could not be returned']);
      expect([for (final s in RefundStatus.values) s.isOpen], [true, true, false, true, false, false]);
    });

    test('the open filter keeps what needs someone, including a card refund that failed', () {
      expect(RefundFilter.open.matches(request()), isTrue);
      expect(RefundFilter.open.matches(request(status: 'approved', method: 'club', approved: 1)), isTrue);
      expect(RefundFilter.open.matches(request(status: 'processing', method: 'online', approved: 1)), isTrue);
      expect(RefundFilter.open.matches(request(status: 'failed', method: 'online', approved: 1)), isTrue);
      expect(RefundFilter.open.matches(request(status: 'completed', method: 'club', approved: 1)), isFalse);
      expect(RefundFilter.open.matches(request(status: 'declined')), isFalse);
      expect(RefundFilter.all.matches(request(status: 'declined')), isTrue);
    });

    test('the suggestion and the status read as sentences', () {
      expect(suggestionLine(request()), 'The policy suggests 50% of the deposit: \$50.00.');
      expect(suggestionLine(request(percent: null, suggested: 0)), 'This booking has no refund policy, so the amount is yours to decide.');
      expect(requestStatusLine(request()), 'Waiting for your decision');
      expect(requestStatusLine(request(status: 'approved', method: 'club', approved: 5000)), '\$50.00 approved: pay it back at the club, then record it');
      expect(requestStatusLine(request(status: 'approved', method: 'online', approved: 5000)), '\$50.00 approved: BottlesUp returns it to the guest\'s card');
      expect(requestStatusLine(request(status: 'declined', note: 'Too late')), 'Declined: Too late');
      expect(requestStatusLine(request(status: 'declined')), 'Declined');
      expect(requestStatusLine(request(status: 'processing', method: 'online', approved: 5000)), '\$50.00 is being returned to the guest\'s card');
      expect(requestStatusLine(request(status: 'completed', method: 'club', approved: 5000)), '\$50.00 paid back at the club');
      expect(requestStatusLine(request(status: 'completed', method: 'club', approved: 5000, reference: 'TERM-1')), '\$50.00 paid back at the club · reference TERM-1');
      expect(requestStatusLine(request(status: 'completed', method: 'online', approved: 5000)), '\$50.00 paid back to the guest\'s card');
      expect(requestStatusLine(request(status: 'failed', method: 'online', approved: 5000, failure: 'Card closed')), 'The card refund did not go through: Card closed. BottlesUp has been told.');
    });
  });

  group('asking for a refund', () {
    test('the options are read, and an answer that is not the options is not trusted', () {
      final o = parseRefundOptions({
        'paid_cents': 10000,
        'deposit_cents': 10000,
        'available_cents': 7500,
        'hours_to_arrival': 30.5,
        'checked_in': false,
        'paid_online': true,
        'status': 'paid',
        'policy_lines': ['One.', ''],
        'percent': 50,
        'suggested_cents': 5000,
        'why': 'The policy refunds 50% of the deposit for this much notice.',
        'open_request_id': null,
      })!;
      expect([o.paidCents, o.availableCents, o.hoursToArrival, o.paidOnline, o.percent, o.suggestedCents, o.policyLines, o.hasOpenRequest], [10000, 7500, 30.5, true, 50, 5000, ['One.'], false]);
      expect(parseRefundOptions(null), isNull);
      expect(parseRefundOptions({'hello': 1}), isNull);
      expect(parseRefundOptions('paid'), isNull);
    });

    test('a refund can be asked for only on a paid or cancelled booking with something left and no request open', () {
      RefundOptions with_({String status = 'paid', int available = 5000, String? open}) =>
          parseRefundOptions({'available_cents': available, 'status': status, 'open_request_id': open, 'suggested_cents': 0})!;
      expect(with_().canAsk, isTrue);
      expect(with_(status: 'cancelled').canAsk, isTrue);
      expect(with_(status: 'pending').canAsk, isFalse);
      expect(with_(available: 0).canAsk, isFalse);
      expect(with_(open: 'rq1').canAsk, isFalse);
    });

    test('the arrival is said in hours, then days, and once passed', () {
      expect(arrivalLine(null), '');
      expect(arrivalLine(-3), 'The guests\' arrival time has passed.');
      expect(arrivalLine(0), 'The guests\' arrival time has passed.');
      expect(arrivalLine(0.5), 'The guests arrive in less than an hour.');
      expect(arrivalLine(1), 'The guests arrive in 1 hour.');
      expect(arrivalLine(30.9), 'The guests arrive in 30 hours.');
      expect(arrivalLine(47.9), 'The guests arrive in 47 hours.');
      expect(arrivalLine(48), 'The guests arrive in 2 days.');
      expect(arrivalLine(100), 'The guests arrive in 4 days.');
    });

    test('a reason of 3 to 500 characters is needed', () {
      expect(validateRequestReason('Guest is ill'), isNull);
      expect(validateRequestReason(' ab '), 'Give a reason of 3 to 500 characters.');
      expect(validateRequestReason('x' * 501), 'Give a reason of 3 to 500 characters.');
      expect(validateRequestReason('x' * 500), isNull);
    });
  });

  group('deciding', () {
    test('declining needs a reason the guest can be told, and nothing else', () {
      final r = request();
      expect(validateDecision(const DecisionForm(approve: false, note: 'Too late to cancel'), r, paidOnline: true), isEmpty);
      expect(validateDecision(const DecisionForm(approve: false, note: ' no '), r, paidOnline: true), ['Say why the refund is declined, so the guest can be told.']);
      expect(validateDecision(const DecisionForm(approve: false), r, paidOnline: true), ['Say why the refund is declined, so the guest can be told.']);
      expect(validateDecision(DecisionForm(approve: false, note: 'x' * 501), r, paidOnline: true), contains('The note can be up to 500 characters.'));
      expect(validateDecision(const DecisionForm(approve: false, note: 'Too late', amountText: 'garbage'), r, paidOnline: true), isEmpty, reason: 'an amount means nothing when declining');
    });

    test('approving needs an amount, a way to pay it back, and a reason only above the policy', () {
      final r = request(suggested: 5000, available: 10000);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '50.00', method: RefundMethod.club), r, paidOnline: true), isEmpty);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '\$25', method: RefundMethod.online), r, paidOnline: true), isEmpty);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '50.00'), r, paidOnline: true), ['Choose how it is paid back: to the card through BottlesUp, or at the club.']);
      for (final bad in ['', 'x', '0', '0.00', '-5', '1.234']) {
        expect(validateDecision(DecisionForm(approve: true, amountText: bad, method: RefundMethod.club), r, paidOnline: true), ['How much is refunded? Enter an amount above \$0.00.'], reason: '"$bad"');
      }
    });

    test('more than what is left is refused, and exactly what is left is fine', () {
      final r = request(suggested: 10000, available: 7500);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '75.01', method: RefundMethod.club), r, paidOnline: true), ['Only \$75.00 can still be refunded on this booking.']);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '75.00', method: RefundMethod.club), r, paidOnline: true), isEmpty);
    });

    test('more than the policy suggests needs a reason of 3 characters; exactly the suggestion does not', () {
      final r = request(suggested: 5000, available: 10000);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '50.01', method: RefundMethod.club), r, paidOnline: true), ['This is more than the refund policy suggests (\$50.00): say why.']);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '50.01', method: RefundMethod.club, note: 'ok'), r, paidOnline: true), hasLength(1));
      expect(validateDecision(const DecisionForm(approve: true, amountText: '100.00', method: RefundMethod.club, note: 'Our mistake'), r, paidOnline: true), isEmpty);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '50.00', method: RefundMethod.club), r, paidOnline: true), isEmpty);
    });

    test('with no policy suggestion any amount needs a reason', () {
      final r = request(percent: null, suggested: 0);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '10.00', method: RefundMethod.club), r, paidOnline: true), ['This is more than the refund policy suggests (\$0.00): say why.']);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '10.00', method: RefundMethod.club, note: 'Venue decision'), r, paidOnline: true), isEmpty);
    });

    test('a card refund needs an online payment on the booking', () {
      final r = request();
      expect(validateDecision(const DecisionForm(approve: true, amountText: '50.00', method: RefundMethod.online), r, paidOnline: false), ['There is no online payment on this booking to return. Record a refund made at the club instead.']);
      expect(validateDecision(const DecisionForm(approve: true, amountText: '50.00', method: RefundMethod.club), r, paidOnline: false), isEmpty);
    });

    test('the payload is what desk_decide_refund takes, with a blank note as none and no amount when declining', () {
      expect(decisionParams('rq1', const DecisionForm(approve: true, amountText: '\$50', method: RefundMethod.club, note: ' Ok ')), {
        'p_request': 'rq1',
        'p_approve': true,
        'p_amount_cents': 5000,
        'p_method': 'club',
        'p_note': 'Ok',
      });
      expect(decisionParams('rq1', const DecisionForm(approve: false, amountText: '50', method: RefundMethod.online, note: 'Too late')), {
        'p_request': 'rq1',
        'p_approve': false,
        'p_amount_cents': null,
        'p_method': null,
        'p_note': 'Too late',
      });
      expect(decisionParams('rq1', const DecisionForm(approve: true, amountText: '1', method: RefundMethod.online))['p_note'], isNull);
    });

    test('what is said after a decision', () {
      expect(decisionMessage(false, null, null), 'Declined. The guest will be told.');
      expect(decisionMessage(true, RefundMethod.club, 5000), 'Approved: \$50.00. Pay it back at the club, then record it here.');
      expect(decisionMessage(true, RefundMethod.online, 5000), 'Approved: \$50.00. BottlesUp will return it to the guest\'s card.');
    });

    test('the club needs a reference of up to 200 characters as evidence', () {
      expect(validateClubReference('TERM-123'), isNull);
      expect(validateClubReference('  '), 'Add the terminal or receipt reference, or a photo of the receipt, as evidence.');
      expect(validateClubReference('  ', hasPhoto: true), isNull, reason: 'a photo is evidence on its own');
      expect(validateClubReference('TERM-1', hasPhoto: true), isNull);
      expect(validateClubReference('x' * 201, hasPhoto: true), 'The reference is too long (200 characters at most).');
      expect(validateClubReference('x' * 200), isNull);
      expect(validateClubReference('x' * 201), 'The reference is too long (200 characters at most).');
    });
  });

  group('cancelling', () {
    test('a reason of 3 to 500 characters is needed', () {
      expect(validateCancelReason('Guest asked to cancel'), isNull);
      expect(validateCancelReason(' x '), 'Give a reason of 3 to 500 characters.');
      expect(validateCancelReason('x' * 501), 'Give a reason of 3 to 500 characters.');
    });

    test('what is said afterwards depends on whether money was paid', () {
      expect(cancelledMessage(refundSuggested: false), 'The booking is cancelled.');
      expect(cancelledMessage(refundSuggested: true), 'The booking is cancelled. Money was paid on it, so decide the refund next.');
    });

    test('a failure is in plain words, and a call with no answer or a server error says to look first', () {
      expect(cancelFailure(), contains('Look at the booking before trying again'));
      expect(cancelFailure(status: 401), contains('Sign in again'));
      expect(cancelFailure(status: 403), 'You don\'t have access to cancel this booking.');
      expect(cancelFailure(status: 404), 'This booking could not be found.');
      expect(cancelFailure(status: 400, message: 'This booking is already cancelled'), 'This booking is already cancelled.');
      expect(cancelFailure(status: 400, message: 'A reason is required.'), 'A reason is required.');
      expect(cancelFailure(status: 400), 'The booking could not be cancelled.');
      expect(cancelFailure(status: 502), contains('Look at the booking before trying again'));
      expect(cancelOutcomeUnknown(null), isTrue);
      expect(cancelOutcomeUnknown(500), isTrue);
      expect(cancelOutcomeUnknown(502), isTrue);
      expect(cancelOutcomeUnknown(400), isFalse);
      expect(cancelOutcomeUnknown(403), isFalse);
    });
  });
}
