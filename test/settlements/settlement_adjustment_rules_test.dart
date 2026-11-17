import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/settlements/logic/settlement_adjustment_rules.dart';
import 'package:bottles_up_vendor/features/settlements/logic/settlement_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_settlement_backend.dart';

// Adjustments after payment (website 20261125100000; brief sections 25 and 26, scenario 23 "Refund after settlement"). The rules: money with a plus or a minus, what each status and kind says, which way
// the money goes in words, how a payload and a list badge are read (never guessed), what a history line says, and what was typed is checked the way the database will check it. The calls: each sends
// exactly what the database function takes, and a refusal is the database's own sentence.

SettlementAdjustments read(Map<String, dynamic> json) => parseSettlementAdjustments(json)!;

void main() {
  group('Money with its sign', () {
    test('a plus has a plus, a minus a minus, and the currency follows the settlement', () {
      expect(signedMoney(1500), '+\$15.00 CAD');
      expect(signedMoney(-5000), '−\$50.00 CAD');
      expect(signedMoney(-5, currency: 'usd'), '−\$0.05 USD');
      expect(signedMoney(0), '\$0.00 CAD');
    });
  });

  group('What a kind and a status say', () {
    test('the three kinds have their words, and an unknown one is just an adjustment', () {
      expect(adjustmentKinds, ['refund', 'chargeback', 'correction']);
      expect(adjustmentKindLabel('refund'), 'Refund');
      expect(adjustmentKindLabel('chargeback'), 'Chargeback');
      expect(adjustmentKindLabel('correction'), 'Correction');
      expect(adjustmentKindLabel('gift'), 'Adjustment');
    });

    test('each kind says what it is for, and that a refund and a chargeback take money off while a correction can add', () {
      expect(adjustmentKindHint('refund'), contains('takes money off'));
      expect(adjustmentKindHint('chargeback'), contains('takes money off'));
      expect(adjustmentKindHint('correction'), contains('plus or a minus'));
      expect(adjustmentKindHint('gift'), '');
    });

    test('every status has its words and a tone that says how much attention it wants', () {
      expect(adjustmentStatusInfo('open').label, 'Open');
      expect(adjustmentStatusInfo('open').note, 'Waiting to be settled');
      expect(adjustmentStatusInfo('open').tone, SettlementTone.attention);
      expect(adjustmentStatusInfo('disputed').label, 'Disputed');
      expect(adjustmentStatusInfo('disputed').tone, SettlementTone.bad);
      expect(adjustmentStatusInfo('settled').label, 'Settled');
      expect(adjustmentStatusInfo('settled').note, 'Recorded external payment');
      expect(adjustmentStatusInfo('settled').tone, SettlementTone.good);
      expect(adjustmentStatusInfo('waived').label, 'Not recovered');
      expect(adjustmentStatusInfo('waived').tone, SettlementTone.neutral);
      expect(adjustmentStatusInfo('whatever').label, 'Unknown');
    });
  });

  group('Which way the money goes', () {
    String owes(String direction, int cents) => adjustmentOwesText(direction: direction, cents: cents, club: 'Club A', organizer: 'Night Events');

    test('a minus means the organizer was paid too much and owes the club; a plus means the club owes the organizer', () {
      expect(owes('organizer_owes_club', -5000), 'Night Events was paid too much: they owe Club A \$50.00 CAD');
      expect(owes('club_owes_organizer', 1500), 'Club A owes Night Events \$15.00 CAD');
    });

    test('the amount in the sentence has no sign (the direction says it), and follows the currency', () {
      expect(adjustmentOwesText(direction: 'organizer_owes_club', cents: -5000, club: 'A', organizer: 'B', currency: 'usd'), 'B was paid too much: they owe A \$50.00 USD');
    });

    String outcome(String status, String direction, int cents) => adjustmentOutcomeText(status: status, direction: direction, cents: cents, club: 'Club A', organizer: 'Night Events');

    test('an open or disputed adjustment says who owes whom; a settled one says who paid whom; a waived one says the club chose not to recover it', () {
      expect(outcome('open', 'organizer_owes_club', -5000), 'Night Events was paid too much: they owe Club A \$50.00 CAD');
      expect(outcome('disputed', 'club_owes_organizer', 1500), 'Club A owes Night Events \$15.00 CAD');
      expect(outcome('settled', 'organizer_owes_club', -5000), 'Night Events paid Club A \$50.00 CAD back');
      expect(outcome('settled', 'club_owes_organizer', 1500), 'Club A paid Night Events \$15.00 CAD');
      expect(outcome('waived', 'organizer_owes_club', -2000), 'Club A chose not to recover \$20.00 CAD from Night Events');
    });
  });

  group('Reading what the database sends', () {
    test('an adjustment is read field by field, with who and when, and what the person can do', () {
      final a = read(
        adjustmentsPayload(
          items: [adjustmentJson(can: {'settle', 'waive'}), adjustmentJson(id: 'x2', kind: 'correction', amount: 1500, reason: 'A chargeback was won', ref: null, can: {'acknowledge'})],
          canRecord: true,
        ),
      );
      expect(a.applies, isTrue);
      expect(a.canRecord, isTrue);
      expect(a.settlementId, 's1');
      expect(a.side, 'venue');
      final x = a.items.first;
      expect([x.id, x.kind, x.amountCents, x.direction, x.reason, x.sourceRef, x.status, x.recordedByName], ['x1', 'refund', -5000, 'organizer_owes_club', 'Refund of a Friday bottle', 'RF-2201', 'open', 'Olly Owner']);
      expect(x.recordedAt, DateTime.utc(2026, 11, 24, 10));
      expect([x.can.settle, x.can.waive, x.can.acknowledge, x.can.question, x.can.answer], [true, true, false, false, false]);
      expect(x.can.any, isTrue);
      expect(x.isClosed, isFalse);
      final y = a.items.last;
      expect([y.kind, y.amountCents, y.direction, y.sourceRef], ['correction', 1500, 'club_owes_organizer', null]);
      expect(y.can.acknowledge, isTrue);
    });

    test('the totals are the database\'s: what was paid, the adjustments, what is owed after them, and what is still to settle each way', () {
      final a = read(adjustmentsPayload(items: [adjustmentJson(amount: -5000), adjustmentJson(id: 'x2', kind: 'correction', amount: 1500), adjustmentJson(id: 'x3', status: 'settled', amount: -2000)]));
      expect([a.paidAmountCents, a.count, a.adjustmentsCents, a.netCents, a.openToOrganizerCents, a.openToClubCents], [30000, 3, -5500, 24500, 1500, 5000]);
      expect(a.currency, 'cad');
      expect(a.paidOn, DateTime(2026, 11, 22));
      expect(a.isEmpty, isFalse);
    });

    test('a closed adjustment says how it was closed', () {
      final settled = read(adjustmentsPayload(items: [adjustmentJson(status: 'settled', resolvedOn: '2026-11-25', resolutionReference: 'RPY-9001', resolutionNote: 'Bank transfer back')])).items.single;
      expect([settled.isClosed, settled.resolvedAmountCents, settled.resolutionReference, settled.resolutionNote, settled.resolutionLabel, settled.resolvedByName], [true, 5000, 'RPY-9001', 'Bank transfer back', 'Recorded external payment', 'Olly Owner']);
      expect(settled.resolvedOn, DateTime(2026, 11, 25));
      final waived = read(adjustmentsPayload(items: [adjustmentJson(status: 'waived')])).items.single;
      expect([waived.isClosed, waived.resolutionLabel, waived.resolutionNote], [true, 'Not recovered', 'Not worth recovering']);
    });

    test('a question is read with its reason; an acknowledgement with who', () {
      final q = read(adjustmentsPayload(items: [adjustmentJson(status: 'disputed', disputedReason: 'Which bottle?', ackAt: '2026-11-24T12:00:00Z')])).items.single;
      expect([q.disputedReason, q.acknowledgedByName], ['Which bottle?', 'Olive Organizer']);
      expect(q.disputedAt, DateTime.utc(2026, 11, 24, 11));
      expect(q.isClosed, isFalse, reason: 'a question is not an ending');
      expect(q.acknowledgedAt, DateTime.utc(2026, 11, 24, 12));
    });

    test('a settlement that is not paid says it does not apply, with nothing in it and no way to record', () {
      final a = read(adjustmentsPayload(applies: false));
      expect([a.applies, a.settlementId, a.items, a.log, a.canRecord, a.count], [false, null, isEmpty, isEmpty, false, 0]);
    });

    test('the organizer\'s side is read as it is sent', () {
      expect(read(adjustmentsPayload(side: 'organizer')).side, 'organizer');
    });

    test('an adjustment that cannot be identified, or that is of nothing, is dropped rather than guessed at; the rest are kept', () {
      final json = adjustmentsPayload(items: [adjustmentJson()]);
      json['items'] = <Object?>[
        ...(json['items'] as List),
        {...adjustmentJson(id: 'x2'), 'id': null},
        {...adjustmentJson(id: 'x3'), 'kind': null},
        {...adjustmentJson(id: 'x4'), 'status': null},
        {...adjustmentJson(id: 'x5'), 'amount_cents': 0},
        {...adjustmentJson(id: 'x6'), 'amount_cents': 'lots'},
        'not even a row',
      ];
      expect(read(json).items.map((i) => i.id), ['x1']);
    });

    test('a payload with no agreement is no payload; odd values do not crash', () {
      expect(parseSettlementAdjustments({'items': []}), isNull);
      final a = parseSettlementAdjustments({'agreement_id': 'a1', 'applies': true, 'items': 'nope', 'log': 5, 'can': 'x', 'count': 'many'})!;
      expect([a.items, a.log, a.canRecord, a.count, a.netCents], [isEmpty, isEmpty, false, 0, 0]);
      final b = read({
        'agreement_id': 'a1',
        'applies': true,
        'items': [
          {'id': 'x1', 'kind': 'refund', 'status': 'open', 'amount_cents': -100},
        ],
      });
      expect(b.items.single.direction, 'organizer_owes_club');
      expect(b.items.single.can.any, isFalse);
      expect(b.items.single.reason, '');
    });

    test('the database\'s word on which way the money goes is used when it sends one', () {
      final x = read(adjustmentsPayload(items: [{...adjustmentJson(), 'direction': 'club_owes_organizer'}])).items.single;
      expect([x.amountCents, x.direction], [-5000, 'club_owes_organizer']);
    });

    test('the direction is worked out from the sign when the database does not say', () {
      final plus = read({
        'agreement_id': 'a1',
        'items': [
          {'id': 'x1', 'kind': 'correction', 'status': 'open', 'amount_cents': 100},
        ],
      });
      expect(plus.items.single.direction, 'club_owes_organizer');
    });
  });

  group('The history', () {
    test('each line says what was done and by whom: the club or the organizer', () {
      String line(String action, {String side = 'venue', int? amount}) =>
          adjustmentLogLine(parseSettlementAdjustments(adjustmentsPayload(log: [adjustmentLogJson(action, side: side, amount: amount)]))!.log.single);
      expect(line('recorded', amount: -5000), 'Adjustment recorded −\$50.00 CAD · Club');
      expect(line('recorded', amount: 1500), 'Adjustment recorded +\$15.00 CAD · Club');
      expect(line('acknowledged', side: 'organizer', amount: -5000), 'Acknowledged −\$50.00 CAD · Organizer');
      expect(line('questioned', side: 'organizer'), 'Question asked · Organizer');
      expect(line('answered'), 'Question answered · Club');
      expect(line('settled', amount: 5000), 'Payment recorded \$50.00 CAD · Club');
      expect(line('waived', amount: 2000), 'Not recovered \$20.00 CAD · Club');
      expect(line('whatever'), 'whatever · Club');
    });

    test('a line is read with who did it, whether it was you, the note and the adjustment it belongs to; a line with no action or adjustment is dropped', () {
      final a = read(
        adjustmentsPayload(
          log: [
            adjustmentLogJson('recorded', adjustment: 'x7', amount: -100, note: 'refund: A bottle', by: 'Olly Owner', me: true),
            {...adjustmentLogJson('questioned'), 'action': null},
            {...adjustmentLogJson('questioned'), 'adjustment_id': null},
          ],
        ),
      );
      final e = a.log.single;
      expect([e.adjustmentId, e.byName, e.byMe, e.note, e.amountCents, e.side], ['x7', 'Olly Owner', true, 'refund: A bottle', -100, 'venue']);
    });

    test('the currency follows the settlement', () {
      final e = read(adjustmentsPayload(log: [adjustmentLogJson('recorded', amount: -5000)])).log.single;
      expect(adjustmentLogLine(e, currency: 'usd'), 'Adjustment recorded −\$50.00 USD · Club');
    });
  });

  group('The figures at the top', () {
    List<({String label, String value, bool strong})> lines(List<Map<String, dynamic>> items) => adjustmentSummaryLines(read(adjustmentsPayload(items: items)), club: 'Club A', organizer: 'Night Events');

    test('with none: what was paid, unchanged, and what is owed, the same', () {
      final l = lines([]);
      expect(l.map((e) => e.label), ['Paid (as recorded, unchanged)', 'Amount owed to the organizer after adjustments']);
      expect(l.map((e) => e.value), ['\$300.00 CAD', '\$300.00 CAD']);
      expect(l.last.strong, isTrue);
      expect(l.first.strong, isFalse);
    });

    test('with some: the adjustments with their sign, what is owed after them, and what is still to settle each way, never netted', () {
      final l = lines([adjustmentJson(amount: -5000), adjustmentJson(id: 'x2', kind: 'correction', amount: 1500)]);
      expect(l.map((e) => '${e.label}: ${e.value}'), [
        'Paid (as recorded, unchanged): \$300.00 CAD',
        'Adjustments after payment: −\$35.00 CAD',
        'Amount owed to the organizer after adjustments: \$265.00 CAD',
        'Still to come back from Night Events: \$50.00 CAD',
        'Still to pay Night Events: \$15.00 CAD',
      ]);
    });

    test('adjustments that add are shown with a plus, as the sum of what was added', () {
      final l = lines([adjustmentJson(id: 'x2', kind: 'correction', amount: 1500), adjustmentJson(id: 'x3', kind: 'correction', amount: 500)]);
      expect(l[1].label, 'Adjustments after payment');
      expect(l[1].value, '+\$20.00 CAD');
      expect(l[2].value, '\$320.00 CAD');
    });

    test('a settled or waived adjustment is not still to settle', () {
      final l = lines([adjustmentJson(status: 'settled', amount: -5000), adjustmentJson(id: 'x2', status: 'waived', amount: -2000)]);
      expect(l.map((e) => e.label), ['Paid (as recorded, unchanged)', 'Adjustments after payment', 'Amount owed to the organizer after adjustments']);
      expect(l[1].value, '−\$70.00 CAD');
    });
  });

  group('The line a list row shows', () {
    AdjustmentFlag flag(Map<String, dynamic> row) => parseAdjustmentFlag(row)!;

    test('it counts the adjustments and says how many are still open, or that they are all settled', () {
      expect(adjustmentFlagText(flag(flagRow(count: 1, open: 1))), '1 adjustment after payment, 1 still open');
      expect(adjustmentFlagText(flag(flagRow(count: 5, open: 2))), '5 adjustments after payment, 2 still open');
      expect(adjustmentFlagText(flag(flagRow(count: 1, open: 0))), '1 adjustment after payment, all settled');
      expect(adjustmentFlagText(flag(flagRow(count: 3, open: 0))), '3 adjustments after payment, all settled');
    });

    test('a row is read with what is still to come each way; one with no agreement is dropped', () {
      final f = flag(flagRow(agreement: 'a9', count: 4, open: 2, toOrganizer: 100, toClub: 250));
      expect([f.agreementId, f.count, f.openCount, f.openToOrganizerCents, f.openToClubCents], ['a9', 4, 2, 100, 250]);
      expect(parseAdjustmentFlag({'adjustment_count': 1}), isNull);
    });
  });

  group('Recording an adjustment: what was typed is checked the way the database will check it', () {
    ({int? cents, String? kind, String? reason, String? reference, String? error}) check(String? kind, String amount, {String reason = 'Refund of a Friday bottle', String reference = '', int net = 30000}) =>
        checkAdjustmentRecordForm(kind: kind, amount: amount, reason: reason, reference: reference, netCents: net);

    test('a refund or a chargeback is typed as a plain amount and goes as a minus', () {
      expect(check('refund', '50.00').cents, -5000);
      expect(check('refund', '50').cents, -5000);
      expect(check('chargeback', '1,200.50', net: 1000000).cents, -120050);
      expect(check('refund', '\$50').cents, -5000);
      expect(check('refund', '0.05').cents, -5);
      expect(check('refund', '  50.00  ').cents, -5000);
      expect(check('refund', '50.00').error, isNull);
      expect(check('refund', '50.00').kind, 'refund');
    });

    test('a minus in front of a refund or a chargeback is accepted, a plus is not', () {
      expect(check('refund', '-50.00').cents, -5000);
      expect(check('chargeback', '−50.00').cents, -5000);
      expect(check('refund', '+50.00').error, 'A refund takes money off: enter the amount without a plus sign.');
      expect(check('chargeback', '+50.00').error, 'A chargeback takes money off: enter the amount without a plus sign.');
    });

    test('a correction needs its sign, and a plus adds while a minus takes off', () {
      expect(check('correction', '+15.00').cents, 1500);
      expect(check('correction', '-15.00').cents, -1500);
      expect(check('correction', '−15.00').cents, -1500);
      expect(check('correction', '+ 15').cents, 1500);
      expect(check('correction', '15.00').error, 'A correction needs a plus or a minus, for example +15.00 or -15.00.');
    });

    test('what the adjustment is for has to be chosen, from the three the database knows', () {
      expect(check(null, '50').error, 'Choose what the adjustment is for: a refund, a chargeback or a correction.');
      expect(check('gift', '50').error, 'Choose what the adjustment is for: a refund, a chargeback or a correction.');
    });

    test('the amount has to be there, be an amount, and not be nothing', () {
      expect(check('refund', '').error, 'Enter the amount, for example 50.00.');
      expect(check('refund', '   ').error, 'Enter the amount, for example 50.00.');
      expect(check('refund', 'abc').error, 'Enter an amount like 50 or 50.00.');
      expect(check('refund', '5.005').error, 'Enter an amount like 50 or 50.00.');
      expect(check('refund', '-').error, 'Enter an amount like 50 or 50.00.');
      expect(check('refund', '0').error, 'Enter an amount, not 0.');
      expect(check('correction', '+0.00').error, 'Enter an amount, not 0.');
    });

    test('nothing can take back more than the organizer is owed after the adjustments so far, and exactly that is allowed', () {
      expect(check('refund', '300.01').error, 'The adjustments cannot take back more than was paid: at most \$300.00 CAD can still be taken off.');
      expect(check('refund', '300.00').error, isNull);
      expect(check('refund', '300.00').cents, -30000);
      expect(check('refund', '0.01', net: 0).error, 'The adjustments cannot take back more than was paid: at most \$0.00 CAD can still be taken off.');
      expect(check('correction', '+500', net: 0).error, isNull);
      expect(check('correction', '-1', net: 0).error, isNotNull);
      expect(check('refund', '0.99', net: 99).error, isNull);
      expect(check('refund', '1', net: 99).error, isNotNull);
      expect(check('refund', '1', net: 100).error, isNull);
      expect(check('refund', '1.01', net: 100).error, isNotNull);
      expect(checkAdjustmentRecordForm(kind: 'refund', amount: '10', reason: 'abc', reference: '', netCents: 500, currency: 'usd').error, 'The adjustments cannot take back more than was paid: at most \$5.00 USD can still be taken off.');
    });

    test('a reason of at least 3 characters and at most 300', () {
      expect(check('refund', '50', reason: '').error, 'Say why (at least 3 characters).');
      expect(check('refund', '50', reason: '  ab  ').error, 'Say why (at least 3 characters).');
      expect(check('refund', '50', reason: 'abc').error, isNull);
      expect(check('refund', '50', reason: 'r' * 300).error, isNull);
      expect(check('refund', '50', reason: 'r' * 301).error, 'Keep the reason to 300 characters or fewer.');
      expect(check('refund', '50', reason: '  Refund  ').reason, 'Refund');
    });

    test('a reference is optional; if given it is 3 to 120 characters', () {
      expect(check('refund', '50').reference, isNull);
      expect(check('refund', '50', reference: '   ').reference, isNull);
      expect(check('refund', '50', reference: ' RF-2201 ').reference, 'RF-2201');
      expect(check('refund', '50', reference: 'ab').error, 'A reference is at least 3 characters (or leave it empty).');
      expect(check('refund', '50', reference: 'abc').error, isNull);
      expect(check('refund', '50', reference: 'r' * 120).error, isNull);
      expect(check('refund', '50', reference: 'r' * 121).error, 'Keep the reference to 120 characters or fewer.');
    });

    test('the first thing wrong is the one that is said, and a good form says nothing and hands back everything cleaned', () {
      expect(check(null, 'abc', reason: '').error, 'Choose what the adjustment is for: a refund, a chargeback or a correction.');
      expect(check('refund', 'abc', reason: '').error, 'Enter an amount like 50 or 50.00.');
      expect(check('refund', '50', reason: '', reference: 'ab').error, 'Say why (at least 3 characters).');
      final ok = check('chargeback', '12.50', reason: ' Card chargeback, Saturday ', reference: ' CB-77 ');
      expect(ok.error, isNull);
      expect([ok.cents, ok.kind, ok.reason, ok.reference], [-1250, 'chargeback', 'Card chargeback, Saturday', 'CB-77']);
    });
  });

  group('Recording the payment that settles an adjustment', () {
    ({int? cents, String? reference, String? evidence, String? error}) settle(String amount, {String reference = 'RPY-9001', String evidence = '', int adjustment = -5000}) =>
        checkAdjustmentSettleForm(amount, reference, evidence, adjustmentCents: adjustment);

    test('the amount has to be exactly the adjustment, whichever way it goes, typed without its sign', () {
      expect(settle('50.00').cents, 5000);
      expect(settle('50.00').error, isNull);
      expect(settle('15', adjustment: 1500).cents, 1500);
      expect(settle('49.99').error, 'The amount has to be exactly the adjustment: \$50.00 CAD.');
      expect(settle('50.01').error, 'The amount has to be exactly the adjustment: \$50.00 CAD.');
      expect(settle('0').error, 'The amount has to be exactly the adjustment: \$50.00 CAD.');
      expect(checkAdjustmentSettleForm('1', 'RPY', '', adjustmentCents: -5000, currency: 'usd').error, 'The amount has to be exactly the adjustment: \$50.00 USD.');
    });

    test('an empty amount and a non-amount are told apart', () {
      expect(settle('').error, 'Enter the amount that was paid.');
      expect(settle('abc').error, 'Enter an amount like 50 or 50.00.');
    });

    test('a reference is needed, of 3 to 120 characters', () {
      expect(settle('50', reference: '').error, 'Enter a reference for the payment (at least 3 characters).');
      expect(settle('50', reference: 'ab').error, 'Enter a reference for the payment (at least 3 characters).');
      expect(settle('50', reference: 'abc').error, isNull);
      expect(settle('50', reference: 'r' * 120).error, isNull);
      expect(settle('50', reference: 'r' * 121).error, 'Keep the reference to 120 characters or fewer.');
      expect(settle('50', reference: ' RPY-1 ').reference, 'RPY-1');
    });

    test('the evidence note is optional and at most 300 characters', () {
      expect(settle('50').evidence, isNull);
      expect(settle('50', evidence: '  ').evidence, isNull);
      expect(settle('50', evidence: ' Bank confirmation ').evidence, 'Bank confirmation');
      expect(settle('50', evidence: 'e' * 300).error, isNull);
      expect(settle('50', evidence: 'e' * 301).error, 'Keep the evidence note to 300 characters or fewer.');
    });
  });

  group('Not recovering an amount', () {
    test('a reason of 3 to 300 characters', () {
      expect(checkWaiveReason(''), 'Say why it is not being recovered (at least 3 characters).');
      expect(checkWaiveReason(' ab '), 'Say why it is not being recovered (at least 3 characters).');
      expect(checkWaiveReason('abc'), isNull);
      expect(checkWaiveReason('w' * 300), isNull);
      expect(checkWaiveReason('w' * 301), 'Keep it to 300 characters or fewer.');
    });
  });

  group('The words on the page', () {
    test('the note says the payment is kept as recorded, that an adjustment is a separate record, that nothing is paid from here, and that it is not taken off a later settlement', () {
      expect(adjustmentsNote, contains('kept exactly as it was recorded'));
      expect(adjustmentsNote, contains('separate record'));
      expect(adjustmentsNote, contains('Nothing is paid or taken back from here'));
      expect(adjustmentsNote, contains('not taken off a later settlement'));
    });

    test('the warning before recording says it cannot be edited or removed and how a mistake is put right', () {
      expect(adjustmentRecordWarning, contains('cannot be edited or removed'));
      expect(adjustmentRecordWarning, contains('opposite correction'));
    });
  });

  group('The service', () {
    late FakeSettlementBackend db;
    setUp(() => db = FakeSettlementBackend());

    test('the adjustments of a settlement are asked for by agreement and read', () async {
      db.adjustmentsJson = adjustmentsPayload(items: [adjustmentJson()], canRecord: true);
      final a = await db.service.adjustments('a1');
      expect(db.paramsOf('settlement_adjustments').single, {'p_agreement': 'a1'});
      expect(a.items.single.id, 'x1');
      expect(a.canRecord, isTrue);
    });

    test('the lists\' badges are asked for by club or by business and keyed by agreement', () async {
      db.flags = [flagRow(agreement: 'a1'), flagRow(agreement: 'a2', count: 3, open: 0)];
      final club = await db.service.adjustmentFlagsForVenue('v1');
      expect(db.paramsOf('settlement_adjustment_flags_for_venue').single, {'p_venue': 'v1'});
      expect(club.keys, ['a1', 'a2']);
      expect(club['a2']!.count, 3);
      final org = await db.service.adjustmentFlagsForOrganizer('o1');
      expect(db.paramsOf('settlement_adjustment_flags_for_organizer').single, {'p_org': 'o1'});
      expect(org.keys, ['a1', 'a2']);
    });

    test('a badge that cannot be read is no badge, never a failed list', () async {
      db.offline = true;
      expect(await db.service.adjustmentFlagsForVenue('v1'), isEmpty);
      expect(await db.service.adjustmentFlagsForOrganizer('o1'), isEmpty);
      db.offline = false;
      db.missing = true;
      expect(await db.service.adjustmentFlagsForVenue('v1'), isEmpty);
    });

    test('recording sends the settlement, the kind, the signed amount, the reason and the reference, trimmed, and gives back the new id', () async {
      expect(await db.service.recordAdjustment('s1', kind: 'refund', amountCents: -5000, reason: '  Refund of a Friday bottle ', reference: ' RF-2201 '), 'x-new');
      expect(db.paramsOf('settlement_adjustment_record').single, {'p_settlement': 's1', 'p_kind': 'refund', 'p_amount_cents': -5000, 'p_reason': 'Refund of a Friday bottle', 'p_ref': 'RF-2201'});
    });

    test('no reference goes as null, whether it is missing or blank', () async {
      await db.service.recordAdjustment('s1', kind: 'correction', amountCents: 1500, reason: 'A chargeback was won');
      expect(db.paramsOf('settlement_adjustment_record').last!['p_ref'], isNull);
      await db.service.recordAdjustment('s1', kind: 'correction', amountCents: 1500, reason: 'A chargeback was won', reference: '   ');
      expect(db.paramsOf('settlement_adjustment_record').last!['p_ref'], isNull);
    });

    test('each step sends exactly what the database function takes', () async {
      await db.service.questionAdjustment('x1', ' Which bottle? ');
      expect(db.paramsOf('settlement_adjustment_question').single, {'p_adjustment': 'x1', 'p_reason': 'Which bottle?'});
      await db.service.answerAdjustment('x1', ' The house vodka ');
      expect(db.paramsOf('settlement_adjustment_answer').single, {'p_adjustment': 'x1', 'p_note': 'The house vodka'});
      expect(await db.service.acknowledgeAdjustment('x1'), isTrue);
      expect(db.paramsOf('settlement_adjustment_acknowledge').single, {'p_adjustment': 'x1'});
      await db.service.waiveAdjustment('x1', ' Not worth recovering ');
      expect(db.paramsOf('settlement_adjustment_waive').single, {'p_adjustment': 'x1', 'p_reason': 'Not worth recovering'});
    });

    test('a payment sends the amount, the day as yyyy-mm-dd, the reference, and no evidence when there is none', () async {
      await db.service.settleAdjustment('x1', amountCents: 5000, paidOn: DateTime(2026, 3, 5), reference: ' RPY-1 ');
      expect(db.paramsOf('settlement_adjustment_settle').single, {'p_adjustment': 'x1', 'p_amount_cents': 5000, 'p_paid_on': '2026-03-05', 'p_reference': 'RPY-1', 'p_evidence': null});
      await db.service.settleAdjustment('x1', amountCents: 5000, paidOn: DateTime(2026, 11, 22), reference: 'RPY-2', evidence: '  ');
      expect(db.paramsOf('settlement_adjustment_settle').last!['p_evidence'], isNull);
      await db.service.settleAdjustment('x1', amountCents: 5000, paidOn: DateTime(2026, 11, 22), reference: 'RPY-3', evidence: ' Bank confirmation ');
      expect(db.paramsOf('settlement_adjustment_settle').last!['p_evidence'], 'Bank confirmation');
    });

    test('acknowledging a second time changes nothing and says so', () async {
      db.handlers['settlement_adjustment_acknowledge'] = (_) => false;
      expect(await db.service.acknowledgeAdjustment('x1'), isFalse);
    });

    test('a refusal is the database\'s own sentence, never a stack trace', () async {
      db.handlers['settlement_adjustment_record'] = (_) => throw refuse('the adjustments cannot take back more than was paid');
      await expectLater(
        db.service.recordAdjustment('s1', kind: 'refund', amountCents: -1, reason: 'abc'),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The adjustments cannot take back more than was paid.')),
      );
    });

    test('a lost connection is a plain sentence that says to look at the settlement before trying again, for the steps that move money records', () async {
      db.offline = true;
      await expectLater(
        db.service.recordAdjustment('s1', kind: 'refund', amountCents: -1, reason: 'abc'),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('look at the settlement before trying again'))),
      );
      await expectLater(
        db.service.settleAdjustment('x1', amountCents: 1, paidOn: DateTime(2026, 1, 1), reference: 'RPY'),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('look at the settlement before trying again'))),
      );
      await expectLater(
        db.service.waiveAdjustment('x1', 'abc'),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('look at the settlement before trying again'))),
      );
      await expectLater(db.service.questionAdjustment('x1', 'abcde'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('Check your connection'))));
    });

    test('a server without the migration is "not set up" for the adjustments; a lost connection is not', () async {
      db.missing = true;
      await expectLater(db.service.adjustments('a1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', true)));
      db.missing = false;
      db.offline = true;
      await expectLater(db.service.adjustments('a1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', false)));
    });
  });
}
