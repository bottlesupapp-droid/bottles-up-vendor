import 'dart:async';

import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/settlements/providers/settlement_providers.dart';
import 'package:bottles_up_vendor/features/settlements/screens/settlement_detail_screen.dart';
import 'package:bottles_up_vendor/features/settlements/screens/settlements_screen.dart';
import 'package:bottles_up_vendor/features/settlements/widgets/settlement_dialogs.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_settlement_backend.dart';

// Adjustments after payment on the settlement screens (website 20261125100000; brief sections 25 and 26, scenario 23 "Refund after settlement: original records retained; refund and settlement
// adjustment visible"). The section appears under a PAID settlement only; the payment above it is shown exactly as before. What the person may do is whatever the database says (`can`, per adjustment);
// the buttons are those and nothing else. Record only: nothing is paid or taken back from here.

late FakeSettlementBackend db;

const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const organizer = Workspace(membershipId: 'w3', orgId: 'org1', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);

Widget host(Widget child) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    settlementServiceProvider.overrideWithValue(db.service),
    ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published')]),
  ],
  child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
);

Future<void> open(WidgetTester tester, Widget child, {double height = 5000}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child));
  await tester.pumpAndSettle();
}

DateTime now() => DateTime(2026, 11, 25, 15);

Future<void> openDetail(WidgetTester tester) => open(tester, SettlementDetailScreen(agreementId: 'a1', clock: now));

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String textOf(WidgetTester tester, String key) {
  final w = tester.widget(find.byKey(Key(key)));
  return w is BuStatusPill ? w.label : (w as Text).data!;
}

bool shown(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

/// A paid settlement (30000 paid on 22 Nov), as the settlement detail says it, with the adjustments the test gives.
void paid({String side = 'venue', Map<String, dynamic>? adjustments}) {
  db.detailJson = detail(side: side, settlement: settlementJson(status: 'paid', paidAmount: 30000, paidOn: '2026-11-22', reference: 'TRF-1001', evidence: 'Bank transfer'));
  db.adjustmentsJson = adjustments ?? adjustmentsPayload(side: side);
}

const buttons = ['settle', 'answer', 'ack', 'waive', 'question'];
const buttonOf = {'settle': 'settle', 'answer': 'answer', 'acknowledge': 'ack', 'waive': 'waive', 'question': 'question'};

List<String> buttonsOf(String id) => [
  for (final b in buttons)
    if (shown('adjustment-$b-$id')) b,
];

void main() {
  setUp(() => db = FakeSettlementBackend());

  group('The section appears under a paid settlement, and only then', () {
    testWidgets('an estimated settlement has no adjustments section and the database is not asked about them', (tester) async {
      db.detailJson = detail(settlement: settlementJson(), can: {'review'});
      await openDetail(tester);
      expect(find.text('Adjustments after payment'), findsNothing);
      expect(db.count('settlement_adjustments'), 0);
    });

    testWidgets('a settlement with nothing started has none either', (tester) async {
      db.detailJson = detail(can: {'save_sales'});
      await openDetail(tester);
      expect(find.text('Adjustments after payment'), findsNothing);
      expect(db.count('settlement_adjustments'), 0);
    });

    testWidgets('a paid one asks by its agreement and shows the section after the payment record and before the history', (tester) async {
      paid();
      db.detailJson = detail(settlement: settlementJson(status: 'paid', paidAmount: 30000, paidOn: '2026-11-22', reference: 'TRF-1001'), log: [logJson('payment_recorded', amount: 30000, from: 'approved', to: 'paid')]);
      await openDetail(tester);
      expect(db.paramsOf('settlement_adjustments').single, {'p_agreement': 'a1'});
      expect(find.text('Adjustments after payment'), findsOneWidget);
      final payment = tester.getTopLeft(find.byKey(const Key('settlement-payment-label'))).dy;
      final section = tester.getTopLeft(find.text('Adjustments after payment')).dy;
      final history = tester.getTopLeft(find.text('History')).dy;
      expect(payment, lessThan(section));
      expect(section, lessThan(history));
    });

    testWidgets('with none: what was paid is unchanged, what is owed is the same, the note says what this is, and it says there are none', (tester) async {
      paid();
      await openDetail(tester);
      expect(textOf(tester, 'adjustments-net'), '\$300.00 CAD');
      expect(find.text('Paid (as recorded, unchanged)'), findsOneWidget);
      expect(textOf(tester, 'adjustments-line-0'), '\$300.00 CAD');
      expect(textOf(tester, 'adjustments-note'), contains('kept exactly as it was recorded'));
      expect(textOf(tester, 'adjustments-note'), contains('Nothing is paid or taken back from here'));
      expect(textOf(tester, 'adjustments-empty'), 'No adjustments after payment.');
      expect(shown('adjustment-record'), isFalse);
    });

    testWidgets('only the person the database allows is offered "Record an adjustment"', (tester) async {
      paid(adjustments: adjustmentsPayload(canRecord: true));
      await openDetail(tester);
      expect(shown('adjustment-record'), isTrue);
      paid(side: 'organizer');
      await openDetail(tester);
      expect(shown('adjustment-record'), isFalse);
    });
  });

  group('Each adjustment, and what is left of the original', () {
    testWidgets('the settlement\'s own payment record is shown exactly as before, with the adjusted figures beside it, not instead of it', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(amount: -5000)]));
      await openDetail(tester);
      expect(textOf(tester, 'settlement-status'), 'Paid');
      expect(textOf(tester, 'settlement-owed'), '\$300.00 CAD');
      expect(textOf(tester, 'settlement-paid-amount'), '\$300.00 CAD');
      expect(textOf(tester, 'settlement-paid-reference'), 'TRF-1001');
      expect(textOf(tester, 'adjustments-net'), '\$250.00 CAD');
      expect(textOf(tester, 'adjustments-line-1'), '−\$50.00 CAD');
      expect(find.text('Adjustments after payment'), findsWidgets);
    });

    testWidgets('a refund: what it is, the amount with its sign, which way the money goes, why, the reference, who recorded it and when', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(amount: -5000, kind: 'refund')]));
      await openDetail(tester);
      expect(textOf(tester, 'adjustment-title-x1'), 'Refund −\$50.00 CAD');
      expect(textOf(tester, 'adjustment-status-x1'), 'Open');
      expect(textOf(tester, 'adjustment-owes-x1'), 'Night Events was paid too much: they owe Club A \$50.00 CAD');
      expect(textOf(tester, 'adjustment-reason-x1'), 'Why: Refund of a Friday bottle');
      expect(textOf(tester, 'adjustment-ref-x1'), 'Reference: RF-2201');
      expect(textOf(tester, 'adjustment-recorded-x1'), startsWith('Recorded by Olly Owner, '));
    });

    testWidgets('a correction that adds says the club owes the organizer; with no reference there is no reference line', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(id: 'x2', kind: 'correction', amount: 1500, ref: null, reason: 'A chargeback was won')]));
      await openDetail(tester);
      expect(textOf(tester, 'adjustment-title-x2'), 'Correction +\$15.00 CAD');
      expect(textOf(tester, 'adjustment-owes-x2'), 'Club A owes Night Events \$15.00 CAD');
      expect(shown('adjustment-ref-x2'), isFalse);
    });

    testWidgets('what is still to come is said in each direction, never netted', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(amount: -5000), adjustmentJson(id: 'x2', kind: 'correction', amount: 1500)]));
      await openDetail(tester);
      expect(find.text('Still to come back from Night Events'), findsOneWidget);
      expect(find.text('Still to pay Night Events'), findsOneWidget);
      expect(textOf(tester, 'adjustments-net'), '\$265.00 CAD');
    });

    testWidgets('the buttons on an adjustment are exactly what the database says the person can do', (tester) async {
      for (final entry in buttonOf.entries) {
        paid(adjustments: adjustmentsPayload(items: [adjustmentJson(can: {entry.key})]));
        await openDetail(tester);
        expect(buttonsOf('x1'), [entry.value], reason: entry.key);
      }
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson()]));
      await openDetail(tester);
      expect(buttonsOf('x1'), isEmpty);
      expect(shown('adjustment-actions-x1'), isFalse);
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(can: {'settle', 'waive'})]));
      await openDetail(tester);
      expect(buttonsOf('x1'), ['settle', 'waive']);
    });

    testWidgets('each adjustment has its own buttons', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(can: {'settle'}), adjustmentJson(id: 'x2', kind: 'correction', amount: 100, can: {'acknowledge', 'question'})]));
      await openDetail(tester);
      expect(buttonsOf('x1'), ['settle']);
      expect(buttonsOf('x2'), ['ack', 'question']);
    });

    testWidgets('a settled one says it is a recorded external payment, with how much, when, the reference, the evidence and who, that nothing was sent, and has no buttons', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(status: 'settled', resolvedOn: '2026-11-25', resolutionReference: 'RPY-9001', resolutionNote: 'Bank transfer back, screenshot kept')]));
      await openDetail(tester);
      expect(textOf(tester, 'adjustment-status-x1'), 'Settled');
      expect(textOf(tester, 'adjustment-owes-x1'), 'Night Events paid Club A \$50.00 CAD back');
      expect(textOf(tester, 'adjustment-resolution-label-x1'), 'Recorded external payment');
      expect(textOf(tester, 'adjustment-resolved-amount-x1'), '\$50.00 CAD');
      expect(textOf(tester, 'adjustment-resolved-on-x1'), 'Wed 25 Nov 2026');
      expect(textOf(tester, 'adjustment-resolved-ref-x1'), 'RPY-9001');
      expect(textOf(tester, 'adjustment-resolved-evidence-x1'), 'Bank transfer back, screenshot kept');
      expect(find.textContaining('Recorded by Olly Owner, Nov 25'), findsOneWidget);
      expect(find.text('Nothing was sent from BottlesUp: this records a payment made outside it.'), findsWidgets);
      expect(buttonsOf('x1'), isEmpty);
    });

    testWidgets('a settled one with no evidence has no evidence line', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(status: 'settled', resolvedOn: '2026-11-25', resolutionReference: 'RPY-9001')]));
      await openDetail(tester);
      expect(shown('adjustment-resolved-evidence-x1'), isFalse);
    });

    testWidgets('a waived one says "Not recovered", why, and who decided', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(status: 'waived', amount: -2000)]));
      await openDetail(tester);
      expect(textOf(tester, 'adjustment-status-x1'), 'Not recovered');
      expect(textOf(tester, 'adjustment-owes-x1'), 'Club A chose not to recover \$20.00 CAD from Night Events');
      expect(textOf(tester, 'adjustment-resolution-label-x1'), 'Not recovered');
      expect(textOf(tester, 'adjustment-waived-reason-x1'), 'Not worth recovering');
      expect(find.textContaining('Decided by Olly Owner'), findsOneWidget);
    });

    testWidgets('a question is shown to both sides, with its reason', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(status: 'disputed', disputedReason: 'Which bottle was refunded?', can: {'answer'})]));
      await openDetail(tester);
      expect(textOf(tester, 'adjustment-status-x1'), 'Disputed');
      expect(textOf(tester, 'adjustment-question-text-x1'), 'Question from the organizer: Which bottle was refunded?');
      expect(buttonsOf('x1'), ['answer']);
      expect(tester.widget<BuCard>(find.byKey(const Key('adjustment-x1'))).accent, isNotNull, reason: 'a question wants attention');
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson()]));
      await openDetail(tester);
      expect(tester.widget<BuCard>(find.byKey(const Key('adjustment-x1'))).accent, isNull);
    });

    testWidgets('an acknowledgement says who and when; an unacknowledged one says nothing', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(ackAt: '2026-11-24T12:00:00Z'), adjustmentJson(id: 'x2')]));
      await openDetail(tester);
      expect(textOf(tester, 'adjustment-acknowledged-x1'), startsWith('Acknowledged by Olive Organizer, Nov 24'));
      expect(shown('adjustment-acknowledged-x2'), isFalse);
    });

    testWidgets('the history of the adjustments, newest first, says who did what, saying You for your own, with the note', (tester) async {
      paid(
        adjustments: adjustmentsPayload(
          items: [adjustmentJson()],
          log: [
            adjustmentLogJson('questioned', side: 'organizer', note: 'Which bottle was refunded?', by: 'Olive Organizer'),
            adjustmentLogJson('recorded', amount: -5000, note: 'refund: Refund of a Friday bottle', me: true),
          ],
        ),
      );
      await openDetail(tester);
      expect(find.text('History of the adjustments'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('adjustment-log-0')), matching: find.text('Question asked · Organizer')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('adjustment-log-0')), matching: find.textContaining('Olive Organizer · ')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('adjustment-log-0')), matching: find.textContaining('Which bottle was refunded?')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('adjustment-log-1')), matching: find.text('Adjustment recorded −\$50.00 CAD · Club')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('adjustment-log-1')), matching: find.textContaining('You · ')), findsOneWidget);
    });

    testWidgets('with no history there is no history heading', (tester) async {
      paid();
      await openDetail(tester);
      expect(find.text('History of the adjustments'), findsNothing);
    });
  });

  group('When they cannot be read', () {
    testWidgets('a server without the migration says so, and the payment record above is still there', (tester) async {
      paid();
      db.handlers['settlement_adjustments'] = (_) => throw PostgrestException(message: 'function public.settlement_adjustments does not exist', code: '42883');
      await openDetail(tester);
      expect(textOf(tester, 'settlement-paid-reference'), 'TRF-1001');
      expect(textOf(tester, 'adjustments-error'), 'The adjustments after payment are not set up on this server yet.');
      expect(find.byKey(const Key('ops-retry')), findsNothing);
    });

    testWidgets('a lost connection says so and Try again reads them again', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson()]));
      var up = false;
      db.handlers['settlement_adjustments'] = (_) => up ? db.adjustmentsJson : throw Exception('SocketException: connection lost');
      await openDetail(tester);
      expect(textOf(tester, 'adjustments-error'), 'The adjustments after payment could not be loaded. Check your connection and try again.');
      expect(textOf(tester, 'settlement-paid-reference'), 'TRF-1001');
      up = true;
      await tapKey(tester, 'ops-retry');
      expect(shown('adjustment-x1'), isTrue);
      expect(find.byKey(const Key('adjustments-error')), findsNothing);
    });

    testWidgets('a settlement the database says does not take adjustments shows nothing under the heading', (tester) async {
      paid(adjustments: adjustmentsPayload(applies: false));
      await openDetail(tester);
      expect(shown('adjustments-note'), isFalse);
      expect(shown('adjustments-error'), isFalse);
    });
  });

  group('The owner records an adjustment', () {
    setUp(() => paid(adjustments: adjustmentsPayload(canRecord: true)));

    testWidgets('the form says it cannot be edited afterwards and what is owed now, checks everything the database checks, and sends nothing until it is right', (tester) async {
      await openDetail(tester);
      await tapKey(tester, 'adjustment-record');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Record an adjustment')), findsOneWidget);
      expect(textOf(tester, 'form-message'), contains('cannot be edited or removed'));
      expect(textOf(tester, 'form-message'), contains('Owed to the organizer now: \$300.00 CAD'));
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Choose what the adjustment is for: a refund, a chargeback or a correction.'), findsOneWidget);
      await tapKey(tester, 'form-kind-refund');
      expect(find.text('Choose what the adjustment is for: a refund, a chargeback or a correction.'), findsNothing);
      expect(textOf(tester, 'form-kind-hint'), contains('takes money off'));
      await typeIn(tester, 'form-amount', 'abc');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Enter an amount like 50 or 50.00.'), findsOneWidget);
      await typeIn(tester, 'form-amount', '3');
      expect(find.text('Enter an amount like 50 or 50.00.'), findsNothing, reason: 'the problem goes as soon as it is being put right');
      await typeIn(tester, 'form-amount', '300.01');
      await typeIn(tester, 'form-note', 'Refund of a Friday bottle');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('The adjustments cannot take back more than was paid: at most \$300.00 CAD can still be taken off.'), findsOneWidget);
      await typeIn(tester, 'form-amount', '50.00');
      await typeIn(tester, 'form-note', 'ab');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say why (at least 3 characters).'), findsOneWidget);
      await typeIn(tester, 'form-note', 'Refund of a Friday bottle');
      await typeIn(tester, 'form-reference', 'ab');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('A reference is at least 3 characters (or leave it empty).'), findsOneWidget);
      expect(db.count('settlement_adjustment_record'), 0, reason: 'nothing is sent until it is right');
    });

    testWidgets('a refund is sent as a minus, with the reason and the reference; the section reads again and shows it, and says the payment is unchanged', (tester) async {
      db.handlers['settlement_adjustment_record'] = (p) {
        db.adjustmentsJson = adjustmentsPayload(canRecord: true, items: [adjustmentJson(id: 'x-new', can: {'settle', 'waive'})], log: [adjustmentLogJson('recorded', adjustment: 'x-new', amount: -5000, me: true)]);
        return 'x-new';
      };
      await openDetail(tester);
      await tapKey(tester, 'adjustment-record');
      await tapKey(tester, 'form-kind-refund');
      await typeIn(tester, 'form-amount', '50.00');
      await typeIn(tester, 'form-note', '  Refund of a Friday bottle ');
      await typeIn(tester, 'form-reference', ' RF-2201 ');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_adjustment_record').single, {'p_settlement': 's1', 'p_kind': 'refund', 'p_amount_cents': -5000, 'p_reason': 'Refund of a Friday bottle', 'p_ref': 'RF-2201'});
      expect(find.text('The adjustment is recorded. The payment above is unchanged.'), findsOneWidget);
      expect(textOf(tester, 'adjustment-title-x-new'), 'Refund −\$50.00 CAD');
      expect(textOf(tester, 'adjustments-net'), '\$250.00 CAD');
      expect(textOf(tester, 'settlement-paid-amount'), '\$300.00 CAD');
      expect(db.count('settlement_adjustments'), greaterThanOrEqualTo(2));
      expect(db.count('settlement_detail'), 1, reason: 'the settlement itself was not read again: it did not change');
    });

    testWidgets('the adjustment is recorded against the settlement the database named, not any other', (tester) async {
      db.adjustmentsJson = adjustmentsPayload(canRecord: true, settlementId: 's-77');
      await openDetail(tester);
      await tapKey(tester, 'adjustment-record');
      await tapKey(tester, 'form-kind-refund');
      await typeIn(tester, 'form-amount', '1');
      await typeIn(tester, 'form-note', 'Small refund');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_adjustment_record').single!['p_settlement'], 's-77');
    });

    testWidgets('a correction needs its sign and a plus is sent as a plus; no reference goes as null', (tester) async {
      await openDetail(tester);
      await tapKey(tester, 'adjustment-record');
      await tapKey(tester, 'form-kind-correction');
      expect(textOf(tester, 'form-kind-hint'), contains('plus or a minus'));
      await typeIn(tester, 'form-amount', '15.00');
      await typeIn(tester, 'form-note', 'A chargeback was won');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('A correction needs a plus or a minus, for example +15.00 or -15.00.'), findsOneWidget);
      await typeIn(tester, 'form-amount', '+15.00');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_adjustment_record').single, {'p_settlement': 's1', 'p_kind': 'correction', 'p_amount_cents': 1500, 'p_reason': 'A chargeback was won', 'p_ref': null});
    });

    testWidgets('a chargeback is a minus too, and the amount can be typed with the minus', (tester) async {
      await openDetail(tester);
      await tapKey(tester, 'adjustment-record');
      await tapKey(tester, 'form-kind-chargeback');
      await typeIn(tester, 'form-amount', '-12.50');
      await typeIn(tester, 'form-note', 'Card chargeback, Saturday');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_adjustment_record').single!['p_amount_cents'], -1250);
      expect(db.paramsOf('settlement_adjustment_record').single!['p_kind'], 'chargeback');
    });

    testWidgets('a plus in front of a refund is refused before anything is sent', (tester) async {
      await openDetail(tester);
      await tapKey(tester, 'adjustment-record');
      await tapKey(tester, 'form-kind-refund');
      await typeIn(tester, 'form-amount', '+50');
      await typeIn(tester, 'form-note', 'Refund of a Friday bottle');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('A refund takes money off: enter the amount without a plus sign.'), findsOneWidget);
      expect(db.count('settlement_adjustment_record'), 0);
    });

    testWidgets('the most that can be taken off is what the organizer is owed after the adjustments so far', (tester) async {
      paid(adjustments: adjustmentsPayload(canRecord: true, items: [adjustmentJson(amount: -29000, status: 'settled', resolvedOn: '2026-11-25', resolutionReference: 'RPY-1')]));
      await openDetail(tester);
      await tapKey(tester, 'adjustment-record');
      expect(textOf(tester, 'form-message'), contains('Owed to the organizer now: \$10.00 CAD'));
      await tapKey(tester, 'form-kind-refund');
      await typeIn(tester, 'form-amount', '10.01');
      await typeIn(tester, 'form-note', 'Too much');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('The adjustments cannot take back more than was paid: at most \$10.00 CAD can still be taken off.'), findsOneWidget);
    });

    testWidgets('backing out sends nothing', (tester) async {
      await openDetail(tester);
      await tapKey(tester, 'adjustment-record');
      await tapKey(tester, 'form-kind-refund');
      await typeIn(tester, 'form-amount', '50');
      await typeIn(tester, 'form-note', 'Refund of a Friday bottle');
      await tapKey(tester, 'dialog-back');
      expect(find.byType(AlertDialog), findsNothing);
      expect(db.count('settlement_adjustment_record'), 0);
    });

    testWidgets('a refusal is the database\'s own sentence, and the section reads again so it shows what the database says now', (tester) async {
      db.handlers['settlement_adjustment_record'] = (_) => throw refuse('this settlement already has 50 adjustments after payment');
      await openDetail(tester);
      final before = db.count('settlement_adjustments');
      await tapKey(tester, 'adjustment-record');
      await tapKey(tester, 'form-kind-refund');
      await typeIn(tester, 'form-amount', '1');
      await typeIn(tester, 'form-note', 'Small refund');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('This settlement already has 50 adjustments after payment.'), findsOneWidget);
      expect(db.count('settlement_adjustments'), greaterThan(before));
    });

    testWidgets('a lost connection says to look at the settlement before trying again', (tester) async {
      await openDetail(tester);
      db.handlers['settlement_adjustment_record'] = (_) => throw Exception('SocketException: connection lost');
      await tapKey(tester, 'adjustment-record');
      await tapKey(tester, 'form-kind-refund');
      await typeIn(tester, 'form-amount', '1');
      await typeIn(tester, 'form-note', 'Small refund');
      await tapKey(tester, 'dialog-confirm');
      expect(find.textContaining('look at the settlement before trying again'), findsOneWidget);
    });
  });

  group('Settling, not recovering, asking and answering', () {
    testWidgets('settling: the payment form says it is for a payment ALREADY made outside BottlesUp, fills in the exact amount, checks it, and sends the day, the reference and the evidence', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(can: {'settle', 'waive'})]));
      await openDetail(tester);
      await tapKey(tester, 'adjustment-settle-x1');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Record the payment')), findsWidgets);
      expect(textOf(tester, 'form-message'), contains('ALREADY been made, outside BottlesUp'));
      expect(textOf(tester, 'form-message'), contains('Night Events was paid too much: they owe Club A \$50.00 CAD'));
      expect(find.text('Exactly the adjustment: \$50.00 CAD'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('form-amount'))).controller!.text, '50.00');
      expect(find.text('Paid on Wed 25 Nov 2026'), findsOneWidget);
      await typeIn(tester, 'form-amount', '49.99');
      await typeIn(tester, 'form-reference', 'RPY-9001');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('The amount has to be exactly the adjustment: \$50.00 CAD.'), findsOneWidget);
      await typeIn(tester, 'form-amount', '50.00');
      await typeIn(tester, 'form-reference', 'ab');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Enter a reference for the payment (at least 3 characters).'), findsOneWidget);
      expect(db.count('settlement_adjustment_settle'), 0);
      await typeIn(tester, 'form-reference', ' RPY-9001 ');
      await typeIn(tester, 'form-evidence', 'Bank transfer back, screenshot kept');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_adjustment_settle').single, {'p_adjustment': 'x1', 'p_amount_cents': 5000, 'p_paid_on': '2026-11-25', 'p_reference': 'RPY-9001', 'p_evidence': 'Bank transfer back, screenshot kept'});
      expect(find.text('The payment is recorded.'), findsOneWidget);
    });

    testWidgets('settling an amount owed to the organizer says the club owes it, and the amount filled in is without its sign', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(id: 'x2', kind: 'correction', amount: 1500, can: {'settle'})]));
      await openDetail(tester);
      await tapKey(tester, 'adjustment-settle-x2');
      expect(textOf(tester, 'form-message'), contains('Club A owes Night Events \$15.00 CAD'));
      expect(tester.widget<TextField>(find.byKey(const Key('form-amount'))).controller!.text, '15.00');
      await typeIn(tester, 'form-reference', 'PAY-5001');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_adjustment_settle').single, {'p_adjustment': 'x2', 'p_amount_cents': 1500, 'p_paid_on': '2026-11-25', 'p_reference': 'PAY-5001', 'p_evidence': null});
    });

    testWidgets('settling then reads the adjustments again, and the settled one has no buttons', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(can: {'settle'})]));
      db.handlers['settlement_adjustment_settle'] = (_) {
        db.adjustmentsJson = adjustmentsPayload(items: [adjustmentJson(status: 'settled', resolvedOn: '2026-11-25', resolutionReference: 'RPY-9001')]);
        return 'settled';
      };
      await openDetail(tester);
      await tapKey(tester, 'adjustment-settle-x1');
      await typeIn(tester, 'form-reference', 'RPY-9001');
      await tapKey(tester, 'dialog-confirm');
      expect(textOf(tester, 'adjustment-status-x1'), 'Settled');
      expect(buttonsOf('x1'), isEmpty);
      expect(textOf(tester, 'adjustment-resolved-ref-x1'), 'RPY-9001');
    });

    testWidgets('not recovering: says what is being given up and that it cannot be changed, needs a reason, and sends it', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(can: {'settle', 'waive'})]));
      await openDetail(tester);
      await tapKey(tester, 'adjustment-waive-x1');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Do not recover this amount')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('\$50.00 CAD was paid to Night Events that they were not owed')), findsOneWidget);
      expect(find.textContaining('cannot be changed afterwards'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no');
      await tester.pump();
      await tester.tap(find.text('Do not recover'));
      await tester.pumpAndSettle();
      expect(find.text('Say why it is not being recovered (at least 3 characters).'), findsOneWidget);
      expect(db.count('settlement_adjustment_waive'), 0);
      await tester.enterText(find.byType(TextField), ' Not worth recovering ');
      await tester.pump();
      await tester.tap(find.text('Do not recover'));
      await tester.pumpAndSettle();
      expect(db.paramsOf('settlement_adjustment_waive').single, {'p_adjustment': 'x1', 'p_reason': 'Not worth recovering'});
      expect(find.text('Recorded as not recovered.'), findsOneWidget);
    });

    testWidgets('asking a question: checked, sent, and the section reads again', (tester) async {
      paid(side: 'organizer', adjustments: adjustmentsPayload(side: 'organizer', items: [adjustmentJson(can: {'acknowledge', 'question'})]));
      db.handlers['settlement_adjustment_question'] = (_) {
        db.adjustmentsJson = adjustmentsPayload(side: 'organizer', items: [adjustmentJson(status: 'disputed')]);
        return 'disputed';
      };
      await openDetail(tester);
      await tapKey(tester, 'adjustment-question-x1');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Ask a question')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'why');
      await tester.pump();
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();
      expect(find.text('Say what you are asking (at least 5 characters).'), findsOneWidget);
      expect(db.count('settlement_adjustment_question'), 0);
      await tester.enterText(find.byType(TextField), ' Which bottle was refunded? ');
      await tester.pump();
      await tester.tap(find.text('Send question'));
      await tester.pumpAndSettle();
      expect(db.paramsOf('settlement_adjustment_question').single, {'p_adjustment': 'x1', 'p_reason': 'Which bottle was refunded?'});
      expect(find.text('Your question has been sent.'), findsOneWidget);
      expect(textOf(tester, 'adjustment-status-x1'), 'Disputed');
      expect(buttonsOf('x1'), isEmpty);
    });

    testWidgets('answering: shows what was asked, needs an answer, sends it', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(status: 'disputed', disputedReason: 'Which bottle was refunded?', can: {'answer'})]));
      await openDetail(tester);
      await tapKey(tester, 'adjustment-answer-x1');
      expect(find.text('The organizer asked: "Which bottle was refunded?"'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();
      await tester.tap(find.text('Send answer'));
      await tester.pumpAndSettle();
      expect(find.text('Write your answer (at least 3 characters).'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'The house vodka');
      await tester.pump();
      await tester.tap(find.text('Send answer'));
      await tester.pumpAndSettle();
      expect(db.paramsOf('settlement_adjustment_answer').single, {'p_adjustment': 'x1', 'p_note': 'The house vodka'});
      expect(find.text('Answered. The adjustment is open again.'), findsOneWidget);
    });

    testWidgets('acknowledging: one tap sends it, says thank you, and the section reads again', (tester) async {
      paid(side: 'organizer', adjustments: adjustmentsPayload(side: 'organizer', items: [adjustmentJson(can: {'acknowledge', 'question'})]));
      db.handlers['settlement_adjustment_acknowledge'] = (_) {
        db.adjustmentsJson = adjustmentsPayload(side: 'organizer', items: [adjustmentJson(ackAt: '2026-11-25T10:00:00Z', can: {'question'})]);
        return true;
      };
      await openDetail(tester);
      await tapKey(tester, 'adjustment-ack-x1');
      expect(db.paramsOf('settlement_adjustment_acknowledge').single, {'p_adjustment': 'x1'});
      expect(find.text('Thank you. The club can see that you have seen it.'), findsOneWidget);
      expect(buttonsOf('x1'), ['question']);
      expect(shown('adjustment-acknowledged-x1'), isTrue);
    });

    testWidgets('a refusal on any step is the database\'s own sentence', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(can: {'settle', 'waive'})]));
      db.handlers['settlement_adjustment_settle'] = (_) => throw refuse('this adjustment has already been dealt with');
      await openDetail(tester);
      await tapKey(tester, 'adjustment-settle-x1');
      await typeIn(tester, 'form-reference', 'RPY-9001');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('This adjustment has already been dealt with.'), findsOneWidget);
    });

    testWidgets('while one step is being sent, the buttons cannot be pressed again', (tester) async {
      paid(adjustments: adjustmentsPayload(items: [adjustmentJson(can: {'settle', 'waive'}), adjustmentJson(id: 'x2', can: {'settle'})]));
      final gate = Completer<dynamic>();
      db.handlers['settlement_adjustment_waive'] = (_) => gate.future;
      await openDetail(tester);
      await tapKey(tester, 'adjustment-waive-x1');
      await tester.enterText(find.byType(TextField), 'Not worth recovering');
      await tester.pump();
      await tester.tap(find.text('Do not recover'));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('adjustment-waive-x1'))).onPressed, isNull);
      expect(tester.widget<FilledButton>(find.byKey(const Key('adjustment-settle-x1'))).onPressed, isNull);
      expect(tester.widget<FilledButton>(find.byKey(const Key('adjustment-settle-x2'))).onPressed, isNull);
      gate.complete('waived');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.byKey(const Key('adjustment-settle-x2'))).onPressed, isNotNull);
      expect(db.count('settlement_adjustment_waive'), 1);
    });
  });

  group('The payment form takes the words it is given', () {
    testWidgets('a title, a message, a helper, a button and a check of its own; and no others', (tester) async {
      String? checked;
      await open(
        tester,
        Builder(
          builder: (context) => TextButton(
            key: const Key('open-form'),
            onPressed: () => showPaymentDialog(
              context,
              payableCents: 1234,
              currency: 'usd',
              recipient: 'Somebody',
              clock: now,
              title: 'A different title',
              message: 'A different message',
              helper: 'Exactly this',
              confirmLabel: 'Go on',
              check: (amount, reference, evidence) {
                checked = '$amount|$reference|$evidence';
                return (cents: 1234, reference: 'ref', evidence: null, error: null);
              },
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tapKey(tester, 'open-form');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('A different title')), findsOneWidget);
      expect(textOf(tester, 'form-message'), 'A different message');
      expect(find.text('Exactly this: \$12.34 USD'), findsOneWidget);
      expect(find.text('Go on'), findsOneWidget);
      expect(find.text('Record payment'), findsNothing);
      await typeIn(tester, 'form-reference', 'RPY-1');
      await tapKey(tester, 'dialog-confirm');
      expect(checked, '12.34|RPY-1|');
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('The lists show which paid settlements have adjustments', () {
    setUp(() {
      db.rows = [listRow(), listRow(agreement: 'a2', event: 'Night Two', status: 'paid', payable: 30000), listRow(agreement: 'a3', event: 'Night Three', status: 'paid', payable: 20000)];
    });

    Future<void> list(WidgetTester tester, Workspace w) => open(tester, SettlementsScreen(workspace: w));

    testWidgets('the club\'s manager sees a line under each settlement that has them, saying how many are open, and nothing under the others', (tester) async {
      db.flags = [flagRow(agreement: 'a2', count: 5, open: 2), flagRow(agreement: 'a3', count: 1, open: 0)];
      await list(tester, manager);
      expect(db.paramsOf('settlement_adjustment_flags_for_venue').single, {'p_venue': 'v1'});
      expect(find.descendant(of: find.byKey(const Key('settlement-a2')), matching: find.textContaining('5 adjustments after payment, 2 still open')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-a3')), matching: find.textContaining('1 adjustment after payment, all settled')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-a1')), matching: find.textContaining('adjustment')), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('settlement-a2')), matching: find.text('Paid')), findsOneWidget);
    });

    testWidgets('the organizer sees theirs', (tester) async {
      db.flags = [flagRow(agreement: 'a2', count: 2, open: 1)];
      await list(tester, organizer);
      expect(db.paramsOf('settlement_adjustment_flags_for_organizer').single, {'p_org': 'org1'});
      expect(db.count('settlement_adjustment_flags_for_venue'), 0);
      expect(find.descendant(of: find.byKey(const Key('settlement-a2')), matching: find.textContaining('2 adjustments after payment, 1 still open')), findsOneWidget);
    });

    testWidgets('a list whose badges cannot be read still shows every settlement, with no badge', (tester) async {
      db.handlers['settlement_adjustment_flags_for_venue'] = (_) => throw Exception('SocketException: connection lost');
      await list(tester, manager);
      expect(find.byKey(const Key('settlement-a2')), findsOneWidget);
      expect(find.byKey(const Key('settlements-error')), findsNothing);
      expect(find.textContaining('adjustment'), findsNothing);
    });

    testWidgets('a server without the migration shows the list as before', (tester) async {
      db.handlers['settlement_adjustment_flags_for_venue'] = (_) => throw Exception('function public.settlement_adjustment_flags_for_venue does not exist 42883');
      await list(tester, manager);
      expect(find.byKey(const Key('settlement-a3')), findsOneWidget);
      expect(find.textContaining('after payment'), findsNothing);
    });

    testWidgets('the organizer coming back from a settlement reads their badges again', (tester) async {
      db.flags = [];
      await list(tester, organizer);
      expect(find.textContaining('after payment'), findsNothing);
      db.flags = [flagRow(agreement: 'a2', count: 2, open: 0)];
      db.detailJson = detail(side: 'organizer', settlement: settlementJson(status: 'paid', paidAmount: 20000, paidOn: '2026-11-22', reference: 'TRF-1'));
      db.adjustmentsJson = adjustmentsPayload(side: 'organizer');
      await tester.tap(find.byKey(const Key('settlement-a2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settlement-detail')), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('settlement-a2')), matching: find.textContaining('2 adjustments after payment, all settled')), findsOneWidget);
    });

    testWidgets('coming back from a settlement reads the badges again', (tester) async {
      db.flags = [];
      await list(tester, manager);
      expect(find.textContaining('after payment'), findsNothing);
      db.flags = [flagRow(agreement: 'a2', count: 1, open: 1)];
      db.detailJson = detail(settlement: settlementJson(status: 'paid', paidAmount: 20000, paidOn: '2026-11-22', reference: 'TRF-1'));
      db.adjustmentsJson = adjustmentsPayload();
      await tester.tap(find.byKey(const Key('settlement-a2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settlement-detail')), findsOneWidget);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('settlement-a2')), matching: find.textContaining('1 adjustment after payment, 1 still open')), findsOneWidget);
    });
  });
}
