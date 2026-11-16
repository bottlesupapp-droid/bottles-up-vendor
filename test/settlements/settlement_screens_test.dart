import 'dart:async';

import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/settlements/providers/settlement_providers.dart';
import 'package:bottles_up_vendor/features/settlements/screens/settlement_detail_screen.dart';
import 'package:bottles_up_vendor/features/settlements/screens/settlements_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_settlement_backend.dart';

// The settlement screens (website 20261122120000; brief section 25). The list for the owner, the manager and the organizer; the detail with its calculation, payment record and history. What the
// person may do is whatever the database says (`can`); the buttons are those and nothing else. Record only: nothing is paid from here.

late FakeSettlementBackend db;

const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const organizer = Workspace(membershipId: 'w3', orgId: 'org1', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);

Widget host(Widget child) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    settlementServiceProvider.overrideWithValue(db.service),
    ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'published')]),
  ],
  child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
);

Future<void> open(WidgetTester tester, Widget child, {double height = 3000}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child));
  await tester.pumpAndSettle();
}

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

Future<void> openDetail(WidgetTester tester, {DateTime? now}) => open(tester, SettlementDetailScreen(agreementId: 'a1', clock: () => now ?? DateTime(2026, 11, 22, 15)));

const actionKeys = ['settlement-save-sales', 'settlement-review', 'settlement-approve', 'settlement-pay', 'settlement-resolve', 'settlement-ack', 'settlement-adjust', 'settlement-question'];

List<String> shownActions(WidgetTester tester) => [
  for (final k in actionKeys)
    if (find.byKey(Key(k)).evaluate().isNotEmpty) k,
];

void main() {
  setUp(() => db = FakeSettlementBackend());

  group('The list', () {
    setUp(() {
      db.rows = [listRow(), listRow(agreement: 'a2', event: 'Night Two', status: 'estimated', payable: 30000), listRow(agreement: 'a3', event: 'Night Three', status: 'paid', payable: 12345)];
    });

    testWidgets('the club\'s manager sees each agreement with the organizer, the share, the status and what is owed, under a note that says this is a record', (tester) async {
      await open(tester, const SettlementsScreen(workspace: manager));
      expect(db.paramsOf('settlements_for_venue').single, {'p_venue': 'v1'});
      expect(textOf(tester, 'settlements-note'), contains('does not pay organizers from here'));
      expect(find.text('Settlement review'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-a1')), matching: find.textContaining('Night Events · 10% of the sales above \$5,000.00')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-a1')), matching: find.textContaining('Waiting for the club to enter the bar sales')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-a2')), matching: find.textContaining('Owed: \$300.00 CAD')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-a3')), matching: find.textContaining('Owed: \$123.45 CAD')), findsOneWidget);
      expect(
        [
          for (final id in ['a1', 'a2', 'a3']) textOf(tester, 'settlement-status-$id'),
        ],
        ['Not started', 'Estimated', 'Paid'],
      );
    });

    testWidgets('the owner chooses a club first, sees its list, and can choose another', (tester) async {
      await open(tester, const SettlementsScreen(workspace: owner));
      expect(db.count('settlements_for_venue'), 0);
      await tapKey(tester, 'settlements-club-v2');
      expect(db.paramsOf('settlements_for_venue').single, {'p_venue': 'v2'});
      expect(find.text('Organizer settlements'), findsOneWidget);
      await tapKey(tester, 'settlements-change-club');
      expect(find.byKey(const Key('settlements-pick-club')), findsOneWidget);
    });

    testWidgets('the organizer sees their own, with the club in place of the organizer, from their business', (tester) async {
      await open(tester, const SettlementsScreen(workspace: organizer));
      expect(db.paramsOf('settlements_for_organizer').single, {'p_org': 'org1'});
      expect(db.count('settlements_for_venue'), 0);
      expect(find.text('Settlement'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-a1')), matching: find.textContaining('Club A · 10% of the sales above')), findsOneWidget);
      expect(find.byKey(const Key('settlements-change-club')), findsNothing);
    });

    testWidgets('tapping an agreement opens its settlement, and coming back reads the list again', (tester) async {
      db.detailJson = detail(settlement: settlementJson(), can: {'review'});
      await open(tester, const SettlementsScreen(workspace: manager));
      final before = db.count('settlements_for_venue');
      await tapKey(tester, 'settlement-a2');
      expect(db.paramsOf('settlement_detail').single, {'p_agreement': 'a2'});
      expect(find.byKey(const Key('settlement-detail')), findsOneWidget);
      await tapKey(tester, 'detail-back');
      expect(db.count('settlements_for_venue'), greaterThan(before));
    });

    testWidgets('nothing to settle, a server without the migration, a lost connection and a person without access are said in words', (tester) async {
      db.rows = [];
      await open(tester, const SettlementsScreen(workspace: manager));
      expect(find.byKey(const Key('settlements-empty')), findsOneWidget);
      expect(find.textContaining('once it is active'), findsOneWidget);

      db.missing = true;
      await open(tester, const SettlementsScreen(workspace: manager));
      expect(textOf(tester, 'settlements-error'), 'The settlements are not set up on this server yet.');
      expect(find.byKey(const Key('ops-retry')), findsNothing, reason: 'nothing the person can do');

      db.missing = false;
      db.offline = true;
      await open(tester, const SettlementsScreen(workspace: manager));
      expect(find.byKey(const Key('settlements-error')), findsOneWidget);
      db.offline = false;
      db.rows = [listRow()];
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('settlement-a1')), findsOneWidget);

      db.handlers['settlements_for_venue'] = (_) => throw refuse('not allowed');
      await open(tester, const SettlementsScreen(workspace: manager));
      expect(find.byKey(const Key('settlements-error')), findsOneWidget);
    });
  });

  group('The settlement: what is shown', () {
    testWidgets('not started: the agreed terms and one button, to enter the bar sales; no calculation', (tester) async {
      db.detailJson = detail(can: {'save_sales'});
      await openDetail(tester);
      expect(db.paramsOf('settlement_detail').single, {'p_agreement': 'a1'});
      expect(textOf(tester, 'settlement-event'), 'Night One');
      expect(textOf(tester, 'settlement-parties'), 'Club A pays Night Events');
      expect(textOf(tester, 'settlement-status'), 'Not started');
      expect(textOf(tester, 'settlement-terms'), '10% of the sales above \$5,000.00');
      expect(find.text('bar sales net of tax'), findsOneWidget);
      expect(find.text('deducted'), findsOneWidget);
      expect(find.text('excluded'), findsOneWidget);
      expect(find.text('within 7 days'), findsOneWidget);
      expect(find.text('Calculation'), findsNothing);
      expect(shownActions(tester), ['settlement-save-sales']);
      expect(find.text('Enter the bar sales'), findsOneWidget);
    });

    testWidgets('an agreement with no share of bar sales says there is nothing to settle and has no buttons', (tester) async {
      db.detailJson = detail(hasShare: false);
      await openDetail(tester);
      expect(find.byKey(const Key('settlement-no-share')), findsOneWidget);
      expect(shownActions(tester), isEmpty);
    });

    testWidgets('estimated: the calculation line by line, as the venue\'s own figure, with where it came from and who entered it', (tester) async {
      db.detailJson = detail(settlement: settlementJson(), can: {'save_sales', 'adjust', 'review'}, log: [logJson('sales_saved', amount: 800000, from: null, to: 'estimated')]);
      await openDetail(tester);
      expect(textOf(tester, 'settlement-status'), 'Estimated');
      expect(textOf(tester, 'settlement-status-note'), 'Reconciliation pending');
      expect(find.text('Venue-reported eligible bar sales'), findsOneWidget);
      expect(find.text('\$8,000.00 CAD'), findsOneWidget);
      expect(find.text('Sales the share is worked on'), findsOneWidget);
      expect(find.text('\$3,000.00 CAD'), findsOneWidget);
      expect(find.text("Organizer's share"), findsWidgets);
      expect(textOf(tester, 'settlement-owed'), '\$300.00 CAD');
      expect(textOf(tester, 'settlement-source'), 'Source: Closing report of Fri 14 Nov, reviewed');
      expect(find.textContaining('Entered by Mia Manager'), findsOneWidget);
      expect(shownActions(tester), ['settlement-save-sales', 'settlement-review', 'settlement-adjust']);
      expect(find.text('Change the bar sales'), findsOneWidget);
    });

    testWidgets('an adjustment shows as its own line with its note, and what is owed includes it', (tester) async {
      db.detailJson = detail(settlement: settlementJson(adjustment: -5000, adjustmentNote: 'Refund of a Friday bottle'), can: {'adjust'});
      await openDetail(tester);
      expect(find.text('−\$50.00 CAD'), findsOneWidget);
      expect(textOf(tester, 'settlement-owed'), '\$250.00 CAD');
      expect(textOf(tester, 'settlement-adjustment-note'), 'Last adjustment: Refund of a Friday bottle');
    });

    testWidgets('the buttons are exactly what the database says the person can do', (tester) async {
      const map = {
        'save_sales': 'settlement-save-sales',
        'review': 'settlement-review',
        'approve': 'settlement-approve',
        'record_payment': 'settlement-pay',
        'resolve': 'settlement-resolve',
        'acknowledge': 'settlement-ack',
        'adjust': 'settlement-adjust',
        'question': 'settlement-question',
      };
      for (final entry in map.entries) {
        db.detailJson = detail(settlement: settlementJson(), can: {entry.key});
        await openDetail(tester);
        expect(shownActions(tester), [entry.value], reason: entry.key);
      }
      db.detailJson = detail(settlement: settlementJson(status: 'paid', paidAmount: 30000, paidOn: '2026-11-22', reference: 'TRF-1'));
      await openDetail(tester);
      expect(shownActions(tester), isEmpty);
      expect(find.byKey(const Key('settlement-nothing')), findsOneWidget);
      expect(find.text('Nothing more to do here.'), findsOneWidget);
    });

    testWidgets('who reviewed and who approved it are shown, and the organizer is told when there is nothing for them to do', (tester) async {
      db.detailJson = detail(side: 'organizer', settlement: settlementJson(status: 'reviewed', reviewedBy: 'Mia Manager'), can: {'question'});
      await openDetail(tester);
      expect(textOf(tester, 'settlement-reviewed'), startsWith('Reviewed by Mia Manager'));
      expect(find.byKey(const Key('settlement-approved')), findsNothing);
      db.detailJson = detail(side: 'organizer', settlement: settlementJson(status: 'approved', reviewedBy: 'Mia Manager', approvedBy: 'Olly Owner'));
      await openDetail(tester);
      expect(textOf(tester, 'settlement-approved'), startsWith('Approved by Olly Owner'));
      expect(textOf(tester, 'settlement-status-note'), 'Payment pending');
      expect(find.text('Nothing for you to do here.'), findsOneWidget);
    });

    testWidgets('paid: labelled a recorded external payment, with who paid whom, how much, when, the reference and the evidence, and that nothing was sent', (tester) async {
      db.detailJson = detail(
        settlement: settlementJson(status: 'paid', paidAmount: 30000, paidOn: '2026-11-22', reference: 'TRF-1001', evidence: 'Bank confirmation kept', ackAt: '2026-11-23T10:00:00Z'),
      );
      await openDetail(tester);
      expect(textOf(tester, 'settlement-status'), 'Paid');
      expect(textOf(tester, 'settlement-payment-label'), 'Recorded external payment');
      expect(find.text('Paid by'), findsOneWidget);
      expect(find.text('Club A'), findsWidgets);
      expect(find.text('Paid to'), findsOneWidget);
      expect(textOf(tester, 'settlement-paid-amount'), '\$300.00 CAD');
      expect(textOf(tester, 'settlement-paid-on'), 'Sun 22 Nov 2026');
      expect(textOf(tester, 'settlement-paid-reference'), 'TRF-1001');
      expect(find.text('Bank confirmation kept'), findsOneWidget);
      expect(textOf(tester, 'settlement-recorded-by'), startsWith('Olly Owner'));
      expect(find.textContaining('Nothing was sent from BottlesUp'), findsOneWidget);
      expect(textOf(tester, 'settlement-acknowledged'), startsWith('Acknowledged by Olive Organizer'));
    });

    testWidgets('disputed: the organizer\'s question is shown to both sides', (tester) async {
      db.detailJson = detail(settlement: settlementJson(status: 'disputed', disputedReason: 'Our records show more bar sales'), can: {'resolve', 'adjust'});
      await openDetail(tester);
      expect(textOf(tester, 'settlement-status'), 'Disputed');
      expect(textOf(tester, 'settlement-question-text'), 'Our records show more bar sales');
      expect(shownActions(tester), ['settlement-resolve', 'settlement-adjust']);
    });

    testWidgets('an ended agreement says so next to its version', (tester) async {
      db.detailJson = detail(settlement: settlementJson(), agreementStatus: 'cancelled', can: {'adjust', 'review'});
      await openDetail(tester);
      expect(find.text('1 (the agreement has ended)'), findsOneWidget);
    });

    testWidgets('the history lists every step, newest first, saying You for your own, who did the others, and the note', (tester) async {
      db.detailJson = detail(
        settlement: settlementJson(status: 'approved'),
        log: [
          logJson('approved', amount: 30000, from: 'reviewed', to: 'approved', by: 'Olly Owner', me: true),
          logJson('questioned', side: 'organizer', note: 'Is this right?', by: 'Olive Organizer'),
        ],
      );
      await openDetail(tester);
      expect(find.text('History'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-log-0')), matching: find.text('Approved \$300.00 CAD · Club')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-log-0')), matching: find.textContaining('You · ')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-log-1')), matching: find.text('Question asked · Organizer')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-log-1')), matching: find.textContaining('Olive Organizer · ')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('settlement-log-1')), matching: find.textContaining('Is this right?')), findsOneWidget);
    });

    testWidgets('a server without the migration, a lost connection and a refusal are said in words', (tester) async {
      db.missing = true;
      await openDetail(tester);
      expect(textOf(tester, 'settlement-error'), 'The settlement figures are not set up on this server yet.');
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.offline = true;
      await openDetail(tester);
      expect(find.byKey(const Key('settlement-error')), findsOneWidget);
      db.offline = false;
      db.detailJson = detail(can: {'save_sales'});
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('settlement-save-sales')), findsOneWidget);
    });
  });

  group('The settlement: doing something', () {
    testWidgets('entering the sales: the amount and the source are checked, then sent; the page reads the settlement again and shows the new figures', (tester) async {
      db.detailJson = detail(can: {'save_sales'});
      db.handlers['settlement_save_sales'] = (p) {
        db.detailJson = detail(settlement: settlementJson(), can: {'save_sales', 'adjust', 'review'});
        return 's1';
      };
      await openDetail(tester);
      await tapKey(tester, 'settlement-save-sales');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Enter the bar sales')), findsOneWidget);
      await tapKey(tester, 'dialog-confirm');
      expect(find.textContaining('Enter the eligible bar sales'), findsOneWidget);
      await typeIn(tester, 'form-amount', 'abc');
      await typeIn(tester, 'form-note', 'Closing report of Fri 14 Nov, reviewed');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Enter an amount like 8000 or 8,000.50.'), findsOneWidget);
      await typeIn(tester, 'form-amount', '8,000.00');
      await typeIn(tester, 'form-note', 'ab');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say where the figure comes from (at least 3 characters).'), findsOneWidget);
      expect(db.count('settlement_save_sales'), 0, reason: 'nothing is sent until it is right');
      await typeIn(tester, 'form-note', 'Closing report of Fri 14 Nov, reviewed');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_save_sales').single, {'p_agreement': 'a1', 'p_eligible_sales_cents': 800000, 'p_note': 'Closing report of Fri 14 Nov, reviewed'});
      expect(find.text('The bar sales are saved. Look at the share below.'), findsOneWidget);
      expect(textOf(tester, 'settlement-status'), 'Estimated');
      expect(textOf(tester, 'settlement-owed'), '\$300.00 CAD');
      expect(db.count('settlement_detail'), greaterThanOrEqualTo(2));
    });

    testWidgets('changing the sales starts from the figure that is there', (tester) async {
      db.detailJson = detail(settlement: settlementJson(), can: {'save_sales'});
      await openDetail(tester);
      await tapKey(tester, 'settlement-save-sales');
      expect(tester.widget<TextField>(find.byKey(const Key('form-amount'))).controller!.text, '8000.00');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Change the bar sales')), findsOneWidget);
    });

    testWidgets('an adjustment: a sign, an amount and a reason; it cannot take the amount owed below zero; it is sent as cents', (tester) async {
      db.detailJson = detail(settlement: settlementJson(), can: {'adjust'});
      await openDetail(tester);
      await tapKey(tester, 'settlement-adjust');
      expect(find.textContaining('Owed now: \$300.00 CAD'), findsOneWidget);
      await typeIn(tester, 'form-amount', '-400');
      await typeIn(tester, 'form-note', 'Too much');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('The amount owed cannot go below zero.'), findsOneWidget);
      await typeIn(tester, 'form-amount', '0');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Enter a plus or minus amount, not 0.'), findsOneWidget);
      await typeIn(tester, 'form-amount', '-50');
      await typeIn(tester, 'form-note', 'Refund of a Friday bottle');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_adjust').single, {'p_settlement': 's1', 'p_amount_cents': -5000, 'p_note': 'Refund of a Friday bottle'});
      expect(find.text('The adjustment is saved.'), findsOneWidget);
    });

    testWidgets('marking reviewed asks first, saying the amount and who it is owed to; backing out sends nothing', (tester) async {
      db.detailJson = detail(settlement: settlementJson(), can: {'review'});
      await openDetail(tester);
      await tapKey(tester, 'settlement-review');
      expect(textOf(tester, 'confirm-message'), contains('\$300.00 CAD owed to Night Events'));
      await tapKey(tester, 'confirm-back');
      expect(db.count('settlement_review'), 0);
      await tapKey(tester, 'settlement-review');
      await tapKey(tester, 'confirm-yes');
      expect(db.paramsOf('settlement_review').single, {'p_settlement': 's1'});
      expect(find.text('Marked as reviewed.'), findsOneWidget);
    });

    testWidgets('approving asks first and says that nothing is paid by it', (tester) async {
      db.detailJson = detail(settlement: settlementJson(status: 'reviewed', reviewedBy: 'Mia Manager'), can: {'approve'});
      await openDetail(tester);
      await tapKey(tester, 'settlement-approve');
      expect(textOf(tester, 'confirm-message'), allOf(contains('\$300.00 CAD'), contains('Nothing is paid by approving')));
      await tapKey(tester, 'confirm-back');
      expect(db.count('settlement_approve'), 0);
      await tapKey(tester, 'settlement-approve');
      await tapKey(tester, 'confirm-yes');
      expect(db.paramsOf('settlement_approve').single, {'p_settlement': 's1'});
      expect(find.text('Approved. Record the payment once it has been made.'), findsOneWidget);
    });

    testWidgets('recording a payment: it says it is for a payment already made elsewhere, starts from the exact amount, and checks the amount and the reference', (tester) async {
      db.detailJson = detail(settlement: settlementJson(status: 'approved', reviewedBy: 'Mia Manager', approvedBy: 'Olly Owner'), can: {'record_payment'});
      await openDetail(tester);
      await tapKey(tester, 'settlement-pay');
      expect(textOf(tester, 'form-message'), 'Only record a payment that has ALREADY been made to Night Events, outside BottlesUp. Nothing is sent from here.');
      expect(tester.widget<TextField>(find.byKey(const Key('form-amount'))).controller!.text, '300.00');
      expect(find.text('Exactly what was approved: \$300.00 CAD'), findsOneWidget);
      expect(find.text('Paid on Sun 22 Nov 2026'), findsOneWidget);
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Enter a reference for the payment (at least 3 characters).'), findsOneWidget);
      await typeIn(tester, 'form-amount', '250');
      await typeIn(tester, 'form-reference', 'TRF-1001');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('The amount has to be exactly what was approved: \$300.00 CAD.'), findsOneWidget);
      expect(db.count('settlement_record_payment'), 0);
      await typeIn(tester, 'form-amount', '300.00');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_record_payment').single, {'p_settlement': 's1', 'p_amount_cents': 30000, 'p_paid_on': '2026-11-22', 'p_reference': 'TRF-1001', 'p_evidence': null});
      expect(find.text('The payment is recorded.'), findsOneWidget);
    });

    testWidgets('the day it was paid can be chosen, and the evidence note is sent when there is one', (tester) async {
      db.detailJson = detail(settlement: settlementJson(status: 'approved', reviewedBy: 'Mia Manager', approvedBy: 'Olly Owner'), can: {'record_payment'});
      await openDetail(tester);
      await tapKey(tester, 'settlement-pay');
      await tapKey(tester, 'form-date');
      await tester.tap(find.text('20'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Paid on Fri 20 Nov 2026'), findsOneWidget);
      await typeIn(tester, 'form-reference', 'CHQ-77');
      await typeIn(tester, 'form-evidence', 'Cheque photo kept');
      await tapKey(tester, 'dialog-confirm');
      final sent = db.paramsOf('settlement_record_payment').single!;
      expect([sent['p_paid_on'], sent['p_reference'], sent['p_evidence']], ['2026-11-20', 'CHQ-77', 'Cheque photo kept']);
    });

    testWidgets('the organizer questions the figure: at least 5 characters, then it is sent', (tester) async {
      db.detailJson = detail(side: 'organizer', settlement: settlementJson(), can: {'question'});
      await openDetail(tester);
      await tapKey(tester, 'settlement-question');
      await typeIn(tester, 'text-field', 'why?');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say what you are asking (at least 5 characters).'), findsOneWidget);
      expect(db.count('settlement_question'), 0);
      await typeIn(tester, 'text-field', 'Our records show more bar sales');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_question').single, {'p_settlement': 's1', 'p_reason': 'Our records show more bar sales'});
      expect(find.text('Your question has been sent.'), findsOneWidget);
    });

    testWidgets('the organizer acknowledges an approved settlement', (tester) async {
      db.detailJson = detail(side: 'organizer', settlement: settlementJson(status: 'approved', reviewedBy: 'Mia Manager', approvedBy: 'Olly Owner'), can: {'acknowledge', 'question'});
      await openDetail(tester);
      expect(shownActions(tester), ['settlement-ack', 'settlement-question']);
      await tapKey(tester, 'settlement-ack');
      expect(db.paramsOf('settlement_acknowledge').single, {'p_settlement': 's1'});
      expect(find.text('Thank you. The club can see that you have seen it.'), findsOneWidget);
    });

    testWidgets('the club answers the question, and sees what was asked', (tester) async {
      db.detailJson = detail(settlement: settlementJson(status: 'disputed', disputedReason: 'Our records show more bar sales'), can: {'resolve'});
      await openDetail(tester);
      await tapKey(tester, 'settlement-resolve');
      expect(find.text('The organizer asked: "Our records show more bar sales"'), findsOneWidget);
      await typeIn(tester, 'text-field', 'ok');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Write your answer (at least 3 characters).'), findsOneWidget);
      await typeIn(tester, 'text-field', 'Added the late sale you pointed out');
      await tapKey(tester, 'dialog-confirm');
      expect(db.paramsOf('settlement_resolve').single, {'p_settlement': 's1', 'p_note': 'Added the late sale you pointed out'});
      expect(find.text('Answered. The settlement is back to Estimated.'), findsOneWidget);
    });

    testWidgets('a refusal is said in the database\'s own words, and the page reads the settlement again to show what is true now', (tester) async {
      db.detailJson = detail(settlement: settlementJson(status: 'reviewed', reviewedBy: 'Mia Manager'), can: {'approve'});
      db.handlers['settlement_approve'] = (_) {
        db.detailJson = detail(settlement: settlementJson(status: 'estimated'), can: {'review'});
        throw refuse('only a reviewed settlement can be approved');
      };
      await openDetail(tester);
      final before = db.count('settlement_detail');
      await tapKey(tester, 'settlement-approve');
      await tapKey(tester, 'confirm-yes');
      expect(find.text('Only a reviewed settlement can be approved.'), findsOneWidget);
      expect(db.count('settlement_detail'), greaterThan(before));
      expect(textOf(tester, 'settlement-status'), 'Estimated');
      expect(shownActions(tester), ['settlement-review']);
    });

    testWidgets('a lost connection says to look at the settlement before trying again', (tester) async {
      db.detailJson = detail(settlement: settlementJson(status: 'approved', reviewedBy: 'Mia Manager', approvedBy: 'Olly Owner'), can: {'record_payment'});
      db.handlers['settlement_record_payment'] = (_) => throw Exception('SocketException: connection lost');
      await openDetail(tester);
      await tapKey(tester, 'settlement-pay');
      await typeIn(tester, 'form-reference', 'TRF-1001');
      await tapKey(tester, 'dialog-confirm');
      expect(find.textContaining('look at the settlement before trying again'), findsOneWidget);
    });

    testWidgets('a second tap while a step is being sent does nothing', (tester) async {
      db.detailJson = detail(side: 'organizer', settlement: settlementJson(status: 'approved', reviewedBy: 'Mia Manager', approvedBy: 'Olly Owner'), can: {'acknowledge'});
      final gate = Completer<bool>();
      db.handlers['settlement_acknowledge'] = (_) => gate.future;
      await openDetail(tester);
      await tester.tap(find.byKey(const Key('settlement-ack')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('settlement-ack')), warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('settlement-ack'))).onPressed, isNull, reason: 'the buttons wait while it is being sent');
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(db.count('settlement_acknowledge'), 1);
    });
  });
}
