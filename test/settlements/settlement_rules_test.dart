import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/settlements/logic/settlement_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_settlement_backend.dart';

// Organizer settlement records (website 20261122120000; brief section 25). The rules: money in words, what each status says, how a row and a detail are read (never guessed), what a history line
// says, and what was typed is checked the way the database will check it. The calls: each sends exactly what the database function takes, and a refusal is the database's own sentence.

void main() {
  group('Money in words', () {
    test('cents become dollars with the currency, thousands separated, whole cents only', () {
      expect(settlementMoney(30000), '\$300.00 CAD');
      expect(settlementMoney(5), '\$0.05 CAD');
      expect(settlementMoney(0), '\$0.00 CAD');
      expect(settlementMoney(123456789), '\$1,234,567.89 CAD');
      expect(settlementMoney(100000), '\$1,000.00 CAD');
      expect(settlementMoney(99), '\$0.99 CAD');
    });

    test('a negative amount has a minus sign in front of the dollar sign, and the currency is whatever the settlement says', () {
      expect(settlementMoney(-5000), '−\$50.00 CAD');
      expect(settlementMoney(-5), '−\$0.05 CAD');
      expect(settlementMoney(30000, currency: 'usd'), '\$300.00 USD');
    });
  });

  group('What a status says', () {
    test('every status has its words, and the brief\'s two waiting states are the notes', () {
      expect(settlementStatusInfo(null).label, 'Not started');
      expect(settlementStatusInfo('estimated').label, 'Estimated');
      expect(settlementStatusInfo('estimated').note, 'Reconciliation pending');
      expect(settlementStatusInfo('reviewed').label, 'Reviewed');
      expect(settlementStatusInfo('approved').label, 'Approved');
      expect(settlementStatusInfo('approved').note, 'Payment pending');
      expect(settlementStatusInfo('paid').label, 'Paid');
      expect(settlementStatusInfo('paid').note, 'Recorded external payment');
      expect(settlementStatusInfo('disputed').label, 'Disputed');
      expect(settlementStatusInfo('whatever').label, 'Unknown');
    });

    test('the tone says how much attention it wants', () {
      expect(settlementStatusInfo(null).tone, SettlementTone.neutral);
      expect(settlementStatusInfo('estimated').tone, SettlementTone.attention);
      expect(settlementStatusInfo('reviewed').tone, SettlementTone.attention);
      expect(settlementStatusInfo('approved').tone, SettlementTone.attention);
      expect(settlementStatusInfo('paid').tone, SettlementTone.good);
      expect(settlementStatusInfo('disputed').tone, SettlementTone.bad);
    });
  });

  group('The agreed share in a sentence', () {
    test('a percentage of the sales above the threshold, or of all of them once it is reached; fractions and no share are said as they are', () {
      expect(shareSummary(percent: 10, thresholdCents: 500000, formula: 'above_threshold'), '10% of the sales above \$5,000.00');
      expect(shareSummary(percent: 12.5, thresholdCents: 0, formula: 'above_threshold'), '12.5% of the sales above \$0.00');
      expect(shareSummary(percent: 10.0, thresholdCents: 500000, formula: 'above_threshold'), '10% of the sales above \$5,000.00', reason: 'a whole percentage that arrives as 10.0 is still 10');
      expect(shareSummary(percent: 15, thresholdCents: 800000, formula: 'all_once_reached'), '15% of all the sales once \$8,000.00 is reached');
      expect(shareSummary(percent: 10, thresholdCents: null, formula: null), '10% of bar sales');
      expect(shareSummary(percent: 0, thresholdCents: 0, formula: 'above_threshold'), 'No share of bar sales');
      expect(shareSummary(percent: null, thresholdCents: null, formula: null), 'No share of bar sales');
    });
  });

  group('Reading a list row', () {
    test('a complete row is read as it is', () {
      final r = parseSettlementRow(listRow(status: 'estimated', payable: 30000))!;
      expect([r.agreementId, r.eventTitle, r.venueName, r.organizerName, r.status, r.payableCents], ['a1', 'Night One', 'Club A', 'Night Events', 'estimated', 30000]);
      expect(r.started, isTrue);
      expect(r.terms, '10% of the sales above \$5,000.00');
    });

    test('an agreement with no settlement yet is not started, and has no figures', () {
      final r = parseSettlementRow(listRow())!;
      expect(r.started, isFalse);
      expect(r.status, isNull);
      expect(r.payableCents, isNull);
    });

    test('a row without an agreement is dropped, and a missing name is a plain word, never a crash', () {
      expect(parseSettlementRow({'event_title': 'x'}), isNull);
      final r = parseSettlementRow({'agreement_id': 'a9'})!;
      expect([r.eventTitle, r.venueName, r.organizerName], ['Event', 'Club', 'Organizer']);
    });
  });

  group('Reading a detail', () {
    test('everything the database sends is read: the terms, the figures, who did what, the history and what the person can do', () {
      final d =
          parseSettlementDetail(
            detail(
              settlement: settlementJson(status: 'approved', adjustment: -5000, adjustmentNote: 'Refund', reviewedBy: 'Mia Manager', approvedBy: 'Olly Owner'),
              can: {'record_payment', 'adjust'},
              log: [logJson('approved', amount: 25000, by: 'Olly Owner', me: true), logJson('sales_saved', amount: 800000)],
            ),
          )!;
      expect([d.eventTitle, d.venueName, d.organizerName, d.side, d.agreementVersion, d.hasShare], ['Night One', 'Club A', 'Night Events', 'venue', 1, true]);
      expect(d.terms!.summary, '10% of the sales above \$5,000.00');
      expect([d.terms!.eligibleRevenue, d.terms!.refunds, d.terms!.taxesTipsFees, d.terms!.settlementTiming], ['bar sales net of tax', 'deducted', 'excluded', 'within 7 days']);
      final s = d.settlement!;
      expect([s.status, s.eligibleSalesCents, s.baseCents, s.shareCents, s.adjustmentCents, s.payableCents], ['approved', 800000, 300000, 30000, -5000, 25000]);
      expect([s.enteredByName, s.reviewedByName, s.approvedByName, s.adjustmentNote, s.salesNote], ['Mia Manager', 'Mia Manager', 'Olly Owner', 'Refund', 'Closing report of Fri 14 Nov, reviewed']);
      expect(d.can.recordPayment, isTrue);
      expect(d.can.adjust, isTrue);
      expect([d.can.saveSales, d.can.review, d.can.approve, d.can.acknowledge, d.can.question, d.can.resolve], [false, false, false, false, false, false]);
      expect(d.log, hasLength(2));
      expect([d.log.first.action, d.log.first.byMe, d.log.first.amountCents], ['approved', true, 25000]);
    });

    test('a payment is read with its reference, date, evidence, label and who recorded it', () {
      final s =
          parseSettlementDetail(
            detail(settlement: settlementJson(status: 'paid', paidAmount: 30000, paidOn: '2026-11-22', reference: 'TRF-1001', evidence: 'Bank confirmation', ackAt: '2026-11-23T10:00:00Z')),
          )!.settlement!;
      expect(
        [s.isPaid, s.paidAmountCents, s.paymentReference, s.paymentEvidence, s.paymentLabel, s.paidRecordedByName, s.acknowledgedByName],
        [true, 30000, 'TRF-1001', 'Bank confirmation', 'Recorded external payment', 'Olly Owner', 'Olive Organizer'],
      );
      expect(s.paidOn, DateTime(2026, 11, 22));
      expect(s.acknowledgedAt, isNotNull);
    });

    test('an agreement with no share of bar sales has no terms to show and nothing to do', () {
      final d = parseSettlementDetail(detail(hasShare: false))!;
      expect(d.hasShare, isFalse);
      expect(d.settlement, isNull);
      expect(d.can.any, isFalse);
    });

    test('an ended agreement is known as ended', () {
      expect(parseSettlementDetail(detail(agreementStatus: 'cancelled'))!.agreementEnded, isTrue);
      expect(parseSettlementDetail(detail(agreementStatus: 'declined'))!.agreementEnded, isTrue);
      expect(parseSettlementDetail(detail())!.agreementEnded, isFalse);
    });

    test('anything unreadable is dropped or left false, never guessed', () {
      expect(parseSettlementDetail({'event_title': 'x'}), isNull);
      final d =
          parseSettlementDetail({
            ...detail(),
            'settlement': {'status': 'estimated'},
            'can': 'yes',
            'log': [
              5,
              {'note': 'x'},
              logJson('reviewed'),
            ],
          })!;
      expect(d.settlement, isNull, reason: 'a settlement without an id is not one');
      expect(d.can.any, isFalse);
      expect(d.log.map((e) => e.action), ['reviewed']);
    });

    test('what the person can do is only what the database says is true', () {
      for (final k in ['save_sales', 'adjust', 'review', 'approve', 'record_payment', 'acknowledge', 'question', 'resolve']) {
        final c = parseSettlementDetail(detail(can: {k}))!.can;
        final on = [c.saveSales, c.adjust, c.review, c.approve, c.recordPayment, c.acknowledge, c.question, c.resolve].where((b) => b).length;
        expect(on, 1, reason: k);
        expect(c.any, isTrue, reason: k);
      }
    });
  });

  group('The calculation and the history in words', () {
    test('the calculation says it is the venue\'s own figure, and ends with what is owed', () {
      final d = parseSettlementDetail(detail(settlement: settlementJson(adjustment: -5000, adjustmentNote: 'Refund')))!;
      final lines = calculationLines(d.terms, d.settlement!);
      expect(lines.map((l) => l.label), ['Venue-reported eligible bar sales', 'Agreed share', 'Sales the share is worked on', "Organizer's share", 'Adjustments', 'Amount owed to the organizer']);
      expect(lines.map((l) => l.value), ['\$8,000.00 CAD', '10% of the sales above \$5,000.00', '\$3,000.00 CAD', '\$300.00 CAD', '−\$50.00 CAD', '\$250.00 CAD']);
      expect(lines.last.strong, isTrue);
      expect(lines.where((l) => l.strong), hasLength(1));
    });

    test('with no adjustment there is no adjustment line, and a plus adjustment shows its sign', () {
      final none = calculationLines(null, parseSettlementDetail(detail(settlement: settlementJson()))!.settlement!);
      expect(none.map((l) => l.label), ['Venue-reported eligible bar sales', 'Sales the share is worked on', "Organizer's share", 'Amount owed to the organizer']);
      final plus = calculationLines(null, parseSettlementDetail(detail(settlement: settlementJson(adjustment: 1000, adjustmentNote: 'Late sale')))!.settlement!);
      expect(plus.firstWhere((l) => l.label == 'Adjustments').value, '+\$10.00 CAD');
    });

    test('a history line says what happened, with the amount where there is one, and which side did it', () {
      SettlementLogEntry e(String action, {String side = 'venue', int? amount}) => parseSettlementDetail(detail(log: [logJson(action, side: side, amount: amount)]))!.log.single;
      expect(logLine(e('sales_saved', amount: 800000)), 'Eligible bar sales entered \$8,000.00 CAD · Club');
      expect(logLine(e('adjusted', amount: -5000)), 'Amount adjusted −\$50.00 CAD · Club');
      expect(logLine(e('adjusted', amount: 1000)), 'Amount adjusted +\$10.00 CAD · Club');
      expect(logLine(e('reviewed', amount: 30000)), 'Reviewed \$300.00 CAD · Club');
      expect(logLine(e('approved', amount: 30000)), 'Approved \$300.00 CAD · Club');
      expect(logLine(e('payment_recorded', amount: 30000)), 'Payment recorded \$300.00 CAD · Club');
      expect(logLine(e('questioned', side: 'organizer')), 'Question asked · Organizer');
      expect(logLine(e('resolved')), 'Question answered · Club');
      expect(logLine(e('acknowledged', side: 'organizer', amount: 30000)), 'Acknowledged \$300.00 CAD · Organizer');
      expect(logLine(e('something_new')), 'something_new · Club');
    });
  });

  group('What was typed', () {
    test('the sales: an amount and where it comes from', () {
      expect(checkSalesForm('8000', 'Closing report').cents, 800000);
      expect(checkSalesForm('8,000.50', 'Closing report').cents, 800050);
      expect(checkSalesForm(r'$8000', '  Closing report  ').note, 'Closing report');
      expect(checkSalesForm('0', 'Quiet night').cents, 0, reason: 'a night with no eligible sales is a real answer');
      expect(checkSalesForm('', 'Closing report').error, startsWith('Enter the eligible bar sales'));
      expect(checkSalesForm('abc', 'Closing report').error, 'Enter an amount like 8000 or 8,000.50.');
      expect(checkSalesForm('-5', 'Closing report').error, 'Enter an amount like 8000 or 8,000.50.');
      expect(checkSalesForm('8000', '').error, 'Say where the figure comes from (at least 3 characters).');
      expect(checkSalesForm('8000', 'ab').error, 'Say where the figure comes from (at least 3 characters).');
      expect(checkSalesForm('8000', 'x' * 301).error, 'Keep it to 300 characters or fewer.');
      expect(checkSalesForm('8000', 'x' * 300).error, isNull);
    });

    test('an adjustment: a plus or minus amount that is not 0 and never takes the amount owed below 0, with a reason', () {
      expect(checkAdjustmentForm('-50', 'Refund', payableCents: 30000).cents, -5000);
      expect(checkAdjustmentForm('−50', 'Refund', payableCents: 30000).cents, -5000, reason: 'the typographic minus works too');
      expect(checkAdjustmentForm('+10.50', 'Late sale', payableCents: 30000).cents, 1050);
      expect(checkAdjustmentForm('10', 'Late sale', payableCents: 30000).cents, 1000, reason: 'no sign is a plus');
      expect(checkAdjustmentForm('0', 'Nothing', payableCents: 30000).error, 'Enter a plus or minus amount, not 0.');
      expect(checkAdjustmentForm('-300', 'All of it', payableCents: 30000).cents, -30000, reason: 'down to exactly 0 is allowed');
      expect(checkAdjustmentForm('-300.01', 'Too much', payableCents: 30000).error, 'The amount owed cannot go below zero.');
      expect(checkAdjustmentForm('', 'Refund', payableCents: 30000).error, startsWith('Enter the change'));
      expect(checkAdjustmentForm('abc', 'Refund', payableCents: 30000).error, 'Enter an amount like 8000 or 8,000.50.');
      expect(checkAdjustmentForm('-50', 'x', payableCents: 30000).error, 'Say why the amount is changing (at least 3 characters).');
      expect(checkAdjustmentForm('-50', 'x' * 301, payableCents: 30000).error, 'Keep it to 300 characters or fewer.');
    });

    test('a payment: exactly what was approved, a reference, and a short evidence note that may be left out', () {
      final ok = checkPaymentForm('300.00', ' TRF-1001 ', '', payableCents: 30000);
      expect([ok.cents, ok.reference, ok.evidence, ok.error], [30000, 'TRF-1001', null, null]);
      expect(checkPaymentForm('300', 'TRF-1001', ' Bank confirmation ', payableCents: 30000).evidence, 'Bank confirmation');
      expect(checkPaymentForm('299.99', 'TRF-1001', '', payableCents: 30000).error, 'The amount has to be exactly what was approved: \$300.00 CAD.');
      expect(checkPaymentForm('300.01', 'TRF-1001', '', payableCents: 30000).error, 'The amount has to be exactly what was approved: \$300.00 CAD.');
      expect(checkPaymentForm('', 'TRF-1001', '', payableCents: 30000).error, 'Enter the amount that was paid.');
      expect(checkPaymentForm('abc', 'TRF-1001', '', payableCents: 30000).error, 'Enter an amount like 8000 or 8,000.50.');
      expect(checkPaymentForm('300', 'ab', '', payableCents: 30000).error, 'Enter a reference for the payment (at least 3 characters).');
      expect(checkPaymentForm('300', 'r' * 121, '', payableCents: 30000).error, 'Keep the reference to 120 characters or fewer.');
      expect(checkPaymentForm('300', 'r' * 120, '', payableCents: 30000).error, isNull);
      expect(checkPaymentForm('300', 'TRF-1001', 'e' * 301, payableCents: 30000).error, 'Keep the evidence note to 300 characters or fewer.');
      expect(checkPaymentForm('250', 'TRF-1001', '', payableCents: 25000, currency: 'usd').cents, 25000);
      expect(checkPaymentForm('1', 'TRF-1001', '', payableCents: 25000, currency: 'usd').error, 'The amount has to be exactly what was approved: \$250.00 USD.');
    });

    test('a question needs at least 5 characters, an answer 3, and neither more than 500', () {
      expect(checkQuestion('why?'), 'Say what you are asking (at least 5 characters).');
      expect(checkQuestion('Why this much?'), isNull);
      expect(checkQuestion('q' * 501), 'Keep it to 500 characters or fewer.');
      expect(checkQuestion('q' * 500), isNull);
      expect(checkAnswer('ok'), 'Write your answer (at least 3 characters).');
      expect(checkAnswer('Added it'), isNull);
      expect(checkAnswer('a' * 501), 'Keep it to 500 characters or fewer.');
    });

    test('the note on the page says this is a record, that nothing is paid from here, and that tickets and tables are not in it', () {
      expect(recordOnlyNote, contains('does not pay organizers from here'));
      expect(recordOnlyNote, contains('Tickets and tables are not part of this settlement'));
    });
  });

  group('The service', () {
    late FakeSettlementBackend db;
    setUp(() => db = FakeSettlementBackend());

    test('the lists ask for the club or the business and read the rows', () async {
      db.rows = [listRow(), listRow(agreement: 'a2', event: 'Night Two', status: 'paid')];
      final club = await db.service.forVenue('v1');
      expect(db.paramsOf('settlements_for_venue').single, {'p_venue': 'v1'});
      expect(club.map((r) => r.eventTitle), ['Night One', 'Night Two']);
      await db.service.forOrganizer('o1');
      expect(db.paramsOf('settlements_for_organizer').single, {'p_org': 'o1'});
    });

    test('the detail asks for the agreement and reads it', () async {
      db.detailJson = detail(settlement: settlementJson(), can: {'review'});
      final d = await db.service.detail('a1');
      expect(db.paramsOf('settlement_detail').single, {'p_agreement': 'a1'});
      expect(d.settlement!.status, 'estimated');
      expect(d.can.review, isTrue);
    });

    test('each step sends exactly what the database function takes', () async {
      await db.service.saveSales('a1', 800000, '  Closing report  ');
      expect(db.paramsOf('settlement_save_sales').single, {'p_agreement': 'a1', 'p_eligible_sales_cents': 800000, 'p_note': 'Closing report'});
      expect(await db.service.adjust('s1', -5000, ' Refund '), 35000);
      expect(db.paramsOf('settlement_adjust').single, {'p_settlement': 's1', 'p_amount_cents': -5000, 'p_note': 'Refund'});
      await db.service.review('s1');
      expect(db.paramsOf('settlement_review').single, {'p_settlement': 's1'});
      await db.service.approve('s1');
      expect(db.paramsOf('settlement_approve').single, {'p_settlement': 's1'});
      await db.service.question('s1', ' Why this much? ');
      expect(db.paramsOf('settlement_question').single, {'p_settlement': 's1', 'p_reason': 'Why this much?'});
      await db.service.resolve('s1', ' Added it ');
      expect(db.paramsOf('settlement_resolve').single, {'p_settlement': 's1', 'p_note': 'Added it'});
      expect(await db.service.acknowledge('s1'), isTrue);
      expect(db.paramsOf('settlement_acknowledge').single, {'p_settlement': 's1'});
    });

    test('a payment sends the amount, the day as yyyy-mm-dd, the reference, and no evidence when there is none', () async {
      await db.service.recordPayment('s1', amountCents: 30000, paidOn: DateTime(2026, 3, 5), reference: ' TRF-1 ');
      expect(db.paramsOf('settlement_record_payment').single, {'p_settlement': 's1', 'p_amount_cents': 30000, 'p_paid_on': '2026-03-05', 'p_reference': 'TRF-1', 'p_evidence': null});
      await db.service.recordPayment('s1', amountCents: 30000, paidOn: DateTime(2026, 11, 22), reference: 'TRF-2', evidence: '  ');
      expect(db.paramsOf('settlement_record_payment').last!['p_evidence'], isNull);
      await db.service.recordPayment('s1', amountCents: 30000, paidOn: DateTime(2026, 11, 22), reference: 'TRF-3', evidence: ' Bank confirmation ');
      expect(db.paramsOf('settlement_record_payment').last!['p_evidence'], 'Bank confirmation');
    });

    test('acknowledging a second time changes nothing and says so', () async {
      db.handlers['settlement_acknowledge'] = (_) => false;
      expect(await db.service.acknowledge('s1'), isFalse);
    });

    test('a refusal is the database\'s own sentence, never a stack trace', () async {
      db.handlers['settlement_approve'] = (_) => throw refuse('only a reviewed settlement can be approved');
      await expectLater(db.service.approve('s1'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'Only a reviewed settlement can be approved.')));
    });

    test('a lost connection is a plain sentence that says to look at the settlement before trying again', () async {
      db.offline = true;
      await expectLater(
        db.service.saveSales('a1', 1, 'Closing report'),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('look at the settlement before trying again'))),
      );
      await expectLater(
        db.service.recordPayment('s1', amountCents: 1, paidOn: DateTime(2026, 1, 1), reference: 'TRF'),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('look at the settlement before trying again'))),
      );
    });

    test('a server without the migration is "not set up" for the lists and the detail; a refusal or lost connection is not', () async {
      db.missing = true;
      for (final call in [() => db.service.forVenue('v1'), () => db.service.forOrganizer('o1'), () => db.service.detail('a1')]) {
        await expectLater(call(), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', true)));
      }
      db.missing = false;
      db.offline = true;
      await expectLater(db.service.forVenue('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', false)));
    });
  });
}
