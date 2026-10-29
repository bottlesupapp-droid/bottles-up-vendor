import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/refunds/logic/refund_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_refund_backend.dart';

late FakeRefundBackend db;

RefundPolicyForm form(List<(String, String)> rules, {bool after = true, String note = ''}) =>
    RefundPolicyForm(tiers: [for (final r in rules) TierForm(hours: r.$1, percent: r.$2)], noRefundAfterCheckIn: after, note: note);

Future<String> refusal(Future<Object?> Function() action) async {
  try {
    await action();
  } on OpsActionException catch (e) {
    return e.message;
  }
  fail('expected a refusal');
}

Future<RefundRequest> loaded(String id) async => (await db.service.requests('v1')).firstWhere((r) => r.requestId == id);

void main() {
  setUp(() => db = FakeRefundBackend());

  group('the policy', () {
    test('a venue that never set one reads as no policy, with the sentence that says so', () async {
      final p = await db.service.policy('v1');
      expect(db.paramsOf('venue_refund_policy').single, {'p_venue': 'v1'});
      expect(p.hasPolicy, isFalse);
      expect(p.lines, ['This venue has not set a refund policy: refunds are decided by the venue.']);
    });

    test('saving sends all three keys and answers with the sentences a guest will read; reading it back gives the same rules', () async {
      final lines = await db.service.savePolicy('v1', form([('24', '50'), ('48', '100')], note: 'Ask us at the door if something went wrong.'));
      expect(db.paramsOf('save_venue_refund_policy').single, {
        'p_venue': 'v1',
        'p_details': {
          'tiers': [
            {'hours': 48, 'percent': 100},
            {'hours': 24, 'percent': 50},
          ],
          'no_refund_after_check_in': true,
          'note': 'Ask us at the door if something went wrong.',
        },
      });
      expect(lines, [
        'Cancel at least 2 days before you arrive: the whole deposit is refunded.',
        'Cancel at least 1 day before you arrive: 50% of the deposit is refunded.',
        'Later than that: no refund.',
        'Once the guests have arrived there is no refund.',
        'Ask us at the door if something went wrong.',
      ]);
      final back = await db.service.policy('v1');
      expect(back.hasPolicy, isTrue);
      expect(back.tiers, const [RefundTier(hours: 48, percent: 100), RefundTier(hours: 24, percent: 50)]);
      expect(back.lines, lines);
    });

    test('what the app shows while editing is what the database then writes', () async {
      for (final rules in [
        [('48', '100'), ('24', '50')],
        [('36', '100'), ('1', '25'), ('0', '10')],
        <(String, String)>[],
        [('12', '0')],
      ]) {
        final f = form(rules, after: rules.length != 1);
        expect(await db.service.savePolicy('v1', f), previewLines(f), reason: '$rules');
      }
    });

    test('a blank note clears the note; an empty list is a policy that says the deposit is not refundable', () async {
      await db.service.savePolicy('v1', form([('24', '50')], note: 'Hello'));
      await db.service.savePolicy('v1', form([], note: ''));
      final p = await db.service.policy('v1');
      expect(p.note, isNull);
      expect(p.hasPolicy, isTrue);
      expect(p.lines.first, 'The deposit is not refundable.');
    });

    test('the database\'s refusals come through as sentences', () async {
      expect(await refusal(() => db.service.savePolicy('v1', form([('24', '50'), ('24', '10')]))), 'Two refund rules cannot have the same hours of notice.');
      expect(await refusal(() => db.service.savePolicy('v1', form([('48', '50'), ('24', '100')]))), 'Giving more notice cannot get less back: a rule with fewer hours cannot refund a larger percent.');
      expect(db.stored, isNull, reason: 'nothing was saved');
    });

    test('someone who is not the club\'s manager or owner is refused', () async {
      db.role = 'server';
      await expectLater(db.service.policy('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      expect(await refusal(() => db.service.savePolicy('v1', form([]))), 'You don\'t have access to do that.');
    });

    test('a failed read is a load failure; a missing function says it is not set up', () async {
      db.failAll = Exception('boom');
      await expectLater(db.service.policy('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
      db.failAll = PostgrestException(message: 'function venue_refund_policy does not exist', code: '42883');
      await expectLater(db.service.policy('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    });

    test('a save that fails in transit is the generic sentence, never a raw error', () async {
      db.failAll = Exception('socket closed at 10.0.0.1');
      final message = await refusal(() => db.service.savePolicy('v1', form([])));
      expect(message, contains('Check your connection'));
      expect(message, isNot(contains('socket')));
    });
  });

  group('the requests', () {
    test('asks for the venue and, when filtered, the status', () async {
      await db.service.requests('v1');
      await db.service.requests('v1', status: RefundStatus.completed);
      expect(db.paramsOf('desk_refund_requests'), [
        {'p_venue': 'v1', 'p_status': null},
        {'p_venue': 'v1', 'p_status': 'completed'},
      ]);
    });

    test('waiting ones come first, then the newest', () async {
      db.addBooking('b1');
      db.addBooking('b2');
      db.addBooking('b3');
      final done = db.addRequest('b1')..status = 'completed';
      final waitingOld = db.addRequest('b2');
      final waitingNew = db.addRequest('b3');
      final list = await db.service.requests('v1');
      expect(list.map((r) => r.requestId), [waitingNew.id, waitingOld.id, done.id]);
    });

    test('a request carries what the list needs: the booking, the guest, what was paid and what is left', () async {
      db.addBooking('b1', paid: 10000);
      final rq = db.addRequest('b1', percent: 50, suggested: 5000);
      final r = await loaded(rq.id);
      expect([r.bookingId, r.guestName, r.code, r.paidCents, r.availableCents, r.policyPercent, r.suggestedCents, r.byGuest], ['b1', 'Ada Lovelace', 'AB12CD', 10000, 10000, 50, 5000, true]);
    });

    test('a failed read is a load failure', () async {
      db.failAll = Exception('boom');
      await expectLater(db.service.requests('v1'), throwsA(isA<OpsLoadException>()));
    });
  });

  group('asking', () {
    test('the options tell what was paid, what can be refunded and what the booking\'s own policy suggests', () async {
      db.addBooking('b1', hours: 30);
      final o = await db.service.options('b1');
      expect(db.paramsOf('desk_refund_options').single, {'p_booking': 'b1'});
      expect([o.paidCents, o.availableCents, o.percent, o.suggestedCents, o.paidOnline, o.hoursToArrival, o.hasOpenRequest], [10000, 10000, 50, 5000, true, 30.0, false]);
      expect(o.why, 'The policy refunds 50% of the deposit for this much notice.');
      expect(o.policyLines.first, 'Cancel at least 2 days before you arrive: the whole deposit is refunded.');
    });

    test('a booking made without a policy has no suggestion', () async {
      db.addBooking('b1').policy;
      db.bookings['b1'] = FakeRefundBooking('b1', policy: null);
      final o = await db.service.options('b1');
      expect(o.percent, isNull);
      expect(o.suggestedCents, 0);
      expect(o.why, 'This booking was made without a refund policy, so the amount is the venue\'s decision.');
    });

    test('guests who have arrived get nothing back when the policy says so', () async {
      db.addBooking('b1', checkedIn: true);
      final o = await db.service.options('b1');
      expect([o.percent, o.suggestedCents, o.checkedIn], [0, 0, true]);
    });

    test('the suggestion never goes above what is left', () async {
      db.addBooking('b1', paid: 3000, hours: 72);
      expect((await db.service.options('b1')).suggestedCents, 3000);
    });

    test('asking records a request with the trimmed reason and the policy\'s suggestion, and the options then show it open', () async {
      db.addBooking('b1', hours: 30);
      final id = await db.service.ask('b1', ' Guest is ill ');
      expect(db.paramsOf('desk_request_refund').single, {'p_booking': 'b1', 'p_reason': 'Guest is ill'});
      final r = await loaded(id);
      expect([r.status, r.reason, r.byGuest, r.suggestedCents, r.policyPercent], [RefundStatus.requested, 'Guest is ill', false, 5000, 50]);
      expect((await db.service.options('b1')).openRequestId, id);
    });

    test('the database\'s refusals are sentences', () async {
      db.addBooking('b1');
      db.addBooking('b2', status: 'pending');
      db.addBooking('b3', paid: 0);
      expect(await refusal(() => db.service.ask('b1', 'x')), 'Give a reason of 3 to 500 characters.');
      expect(await refusal(() => db.service.ask('b2', 'Guest is ill')), 'Only a confirmed or cancelled booking can be refunded.');
      expect(await refusal(() => db.service.ask('b3', 'Guest is ill')), 'Nothing is left to refund on this booking.');
      await db.service.ask('b1', 'Guest is ill');
      expect(await refusal(() => db.service.ask('b1', 'Guest is ill again')), 'A refund request for this booking is already open.');
      expect(db.requests, hasLength(1), reason: 'a second tap makes no second request');
    });

    test('an answer that is not an id is not trusted', () async {
      final broken = _Replying(null);
      expect(await refusal(() => broken.service.ask('b1', 'Guest is ill')), contains('Look at the booking before trying again'));
    });

    test('a manager of another club, or a server, is refused', () async {
      db.addBooking('b1');
      db.role = 'server';
      expect(await refusal(() => db.service.ask('b1', 'Guest is ill')), 'You don\'t have access to do that.');
    });
  });

  group('deciding', () {
    FakeRefundRequest waiting({int paid = 10000, int percent = 50, int suggested = 5000, bool online = true}) {
      db.addBooking('b1', paid: paid, paidOnline: online);
      return db.addRequest('b1', percent: percent, suggested: suggested);
    }

    Future<String> decide(FakeRefundRequest rq, DecisionForm f, {bool online = true}) async => db.service.decide(rq.id, f, await loaded(rq.id), paidOnline: online);

    test('approving sends the amount in cents and how it is paid back, and the request then reads approved', () async {
      final rq = waiting();
      final answer = await decide(rq, const DecisionForm(approve: true, amountText: '50.00', method: RefundMethod.club, note: ' ok '));
      expect(answer, 'approved');
      expect(db.paramsOf('desk_decide_refund').single, {'p_request': rq.id, 'p_approve': true, 'p_amount_cents': 5000, 'p_method': 'club', 'p_note': 'ok'});
      final r = await loaded(rq.id);
      expect([r.status, r.approvedCents, r.method], [RefundStatus.approved, 5000, RefundMethod.club]);
      expect(r.availableCents, 10000, reason: 'the request itself is not counted against what is left');
    });

    test('an approved refund is held against the booking, so another cannot be approved for the same money', () async {
      final a = waiting(paid: 10000, suggested: 10000);
      db.addBooking('b2', paid: 10000);
      await decide(a, const DecisionForm(approve: true, amountText: '80.00', method: RefundMethod.club, note: 'Our mistake'));
      final b = db.addRequest('b1', percent: 100, suggested: 10000)..status = 'requested';
      expect((await loaded(b.id)).availableCents, 2000);
    });

    test('declining sends the reason and no amount', () async {
      final rq = waiting();
      expect(await decide(rq, const DecisionForm(approve: false, note: 'Too late to cancel')), 'declined');
      expect(db.paramsOf('desk_decide_refund').single, {'p_request': rq.id, 'p_approve': false, 'p_amount_cents': null, 'p_method': null, 'p_note': 'Too late to cancel'});
      expect((await loaded(rq.id)).decisionNote, 'Too late to cancel');
    });

    test('a decision the app can see is wrong is not sent at all', () async {
      final rq = waiting();
      expect(await refusal(() => decide(rq, const DecisionForm(approve: true, amountText: '', method: RefundMethod.club))), 'How much is refunded? Enter an amount above \$0.00.');
      expect(await refusal(() => decide(rq, const DecisionForm(approve: false, note: ''))), 'Say why the refund is declined, so the guest can be told.');
      expect(db.paramsOf('desk_decide_refund'), isEmpty);
    });

    test('the database still refuses what the app let through, in its own sentences', () async {
      final rq = waiting(online: false);
      // The app was told the booking was paid online (a stale view), the database knows better.
      expect(await refusal(() => decide(rq, const DecisionForm(approve: true, amountText: '50.00', method: RefundMethod.online))), 'There is no online payment on this booking to return; record a refund made at the club instead.');
      expect((await loaded(rq.id)).status, RefundStatus.requested);
    });

    test('it was decided by someone else a moment ago', () async {
      final rq = waiting();
      final stale = await loaded(rq.id);
      await decide(rq, const DecisionForm(approve: false, note: 'Too late to cancel'));
      expect(await refusal(() => db.service.decide(rq.id, const DecisionForm(approve: true, amountText: '50.00', method: RefundMethod.club), stale, paidOnline: true)), 'This request has already been decided.');
    });

    test('money taken by another approval in the meantime is said in dollars', () async {
      final rq = waiting(paid: 10000, suggested: 10000);
      final stale = await loaded(rq.id);
      db.addBooking('b9');
      final other = db.addRequest('b1', percent: 100, suggested: 10000);
      other
        ..status = 'approved'
        ..approved = 9000
        ..method = 'club';
      expect(await refusal(() => db.service.decide(rq.id, const DecisionForm(approve: true, amountText: '50.00', method: RefundMethod.club), stale, paidOnline: true)), 'Only 10.00 can still be refunded on this booking.');
    });

    test('someone who is not a manager is refused', () async {
      final rq = waiting();
      final r = await loaded(rq.id);
      db.role = 'server';
      expect(await refusal(() => db.service.decide(rq.id, const DecisionForm(approve: false, note: 'Too late to cancel'), r, paidOnline: true)), 'You don\'t have access to do that.');
    });

    test('an answer that is not approved or declined is not trusted', () async {
      final rq = waiting();
      final r = await loaded(rq.id);
      final broken = _Replying('maybe');
      expect(await refusal(() => broken.service.decide(rq.id, const DecisionForm(approve: false, note: 'Too late to cancel'), r, paidOnline: true)), contains('Look at the request before trying again'));
    });
  });

  group('recording a refund paid back at the club', () {
    FakeRefundRequest approvedAtClub({int paid = 10000, int approved = 5000}) {
      db.addBooking('b1', paid: paid);
      final rq = db.addRequest('b1')
        ..status = 'approved'
        ..approved = approved
        ..method = 'club';
      return rq;
    }

    test('records it with the reference, the request is completed and the booking\'s paid amount goes down', () async {
      final rq = approvedAtClub();
      await db.service.completeClubRefund(rq.id, ' TERM-123 ');
      expect(db.paramsOf('desk_complete_club_refund').single, {'p_request': rq.id, 'p_pos_reference': 'TERM-123', 'p_receipt_path': null});
      expect((await loaded(rq.id)).status, RefundStatus.completed);
      expect(db.bookings['b1']!.paid, 5000);
    });

    test('a photo alone is evidence: it is sent without a reference, and the request then carries the photo', () async {
      final rq = approvedAtClub();
      await db.service.completeClubRefund(rq.id, '  ', receiptPath: 'b1/photo.jpg');
      expect(db.paramsOf('desk_complete_club_refund').single, {'p_request': rq.id, 'p_pos_reference': null, 'p_receipt_path': 'b1/photo.jpg'});
      final r = await loaded(rq.id);
      expect([r.reference, r.receiptPath], [null, 'b1/photo.jpg']);
    });

    test('a reference and a photo together are both kept', () async {
      final rq = approvedAtClub();
      await db.service.completeClubRefund(rq.id, 'TERM-9', receiptPath: 'b1/photo.jpg');
      final r = await loaded(rq.id);
      expect([r.reference, r.receiptPath], ['TERM-9', 'b1/photo.jpg']);
    });

    test('a photo filed under another booking is refused by the database in its own words', () async {
      final rq = approvedAtClub();
      expect(await refusal(() => db.service.completeClubRefund(rq.id, 'TERM-9', receiptPath: 'other-booking/photo.jpg')), 'The receipt photo does not belong to this booking.');
      expect(db.bookings['b1']!.paid, 10000, reason: 'nothing was recorded');
    });

    test('a repeated tap records it once', () async {
      final rq = approvedAtClub();
      await db.service.completeClubRefund(rq.id, 'TERM-123');
      await db.service.completeClubRefund(rq.id, 'TERM-123');
      expect(db.bookings['b1']!.paid, 5000, reason: 'the paid amount went down once');
    });

    test('a reference is needed, and is checked before anything is sent', () async {
      final rq = approvedAtClub();
      expect(await refusal(() => db.service.completeClubRefund(rq.id, '  ')), 'Add the terminal or receipt reference, or a photo of the receipt, as evidence.');
      expect(await refusal(() => db.service.completeClubRefund(rq.id, 'x' * 201)), 'The reference is too long (200 characters at most).');
      expect(db.paramsOf('desk_complete_club_refund'), isEmpty);
    });

    test('only an approved refund that is paid back at the club can be recorded', () async {
      db.addBooking('b1');
      final waitingRq = db.addRequest('b1');
      expect(await refusal(() => db.service.completeClubRefund(waitingRq.id, 'TERM-1')), 'Only an approved refund that is paid back at the club can be recorded here.');
      waitingRq
        ..status = 'approved'
        ..approved = 100
        ..method = 'online';
      expect(await refusal(() => db.service.completeClubRefund(waitingRq.id, 'TERM-1')), 'Only an approved refund that is paid back at the club can be recorded here.');
    });

    test('someone who is not a manager is refused', () async {
      final rq = approvedAtClub();
      db.role = 'server';
      expect(await refusal(() => db.service.completeClubRefund(rq.id, 'TERM-1')), 'You don\'t have access to do that.');
    });
  });

  group('cancelling a booking', () {
    test('goes through the website\'s function with the booking and the trimmed reason, and says whether money had been paid', () async {
      db.addBooking('b1', paid: 10000);
      expect(await db.service.cancelBooking('b1', ' Guest asked '), isTrue);
      expect(db.invocations.single.$1, 'cancel-table-booking');
      expect(db.invocations.single.$2, {'booking_id': 'b1', 'reason': 'Guest asked'});
      expect(db.bookings['b1']!.status, 'cancelled');
    });

    test('a booking with nothing paid says so', () async {
      db.addBooking('b1', paid: 0);
      expect(await db.service.cancelBooking('b1', 'Guest asked'), isFalse);
    });

    test('a reason is needed before anything is sent', () async {
      db.addBooking('b1');
      expect(await refusal(() => db.service.cancelBooking('b1', ' x ')), 'Give a reason of 3 to 500 characters.');
      expect(db.invocations, isEmpty);
    });

    test('a booking that is already cancelled is told so in the function\'s words', () async {
      db.addBooking('b1', status: 'cancelled');
      expect(await refusal(() => db.service.cancelBooking('b1', 'Guest asked')), 'This booking is already cancelled.');
    });

    test('someone who may not cancel, and a booking that is not there', () async {
      db.addBooking('b1');
      db.role = 'server';
      expect(await refusal(() => db.service.cancelBooking('b1', 'Guest asked')), 'You don\'t have access to cancel this booking.');
      db.role = 'manager';
      expect(await refusal(() => db.service.cancelBooking('nope', 'Guest asked')), 'This booking could not be found.');
    });

    test('a call with no answer, or a server error, says to look at the booking before trying again', () async {
      db.addBooking('b1');
      db.failInvoke = Exception('socket closed');
      expect(await refusal(() => db.service.cancelBooking('b1', 'Guest asked')), contains('Look at the booking before trying again'));
      db.failInvoke = FunctionException(status: 500, details: {'error': 'Internal server error'});
      expect(await refusal(() => db.service.cancelBooking('b1', 'Guest asked')), contains('Look at the booking before trying again'));
    });

    test('an answer that is not a success is not trusted', () async {
      final odd = FakeRefundBackend();
      final svc = _OddInvoke().service;
      expect(await refusal(() => svc.cancelBooking('b1', 'Guest asked')), contains('Look at the booking before trying again'));
      expect(odd.invocations, isEmpty);
    });
  });
}

/// A backend whose every database answer is [reply]: how the app behaves when a function answers with something it does not expect.
class _Replying extends FakeRefundBackend {
  _Replying(this.reply);

  final Object? reply;

  @override
  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async => reply;
}

/// An edge function that answers 200 with something that is not a success.
class _OddInvoke extends FakeRefundBackend {
  @override
  Future<dynamic> invoke(String name, Map<String, dynamic> body) async => {'ok': true};
}
