import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/payouts/providers/payout_providers.dart';
import 'package:bottles_up_vendor/features/payouts/screens/payouts_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_payout_backend.dart';

late FakePayoutBackend db;

const owner = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const organizer = Workspace(membershipId: 'w3', orgId: 'o2', orgName: 'Events Co', orgKind: 'organizer', role: WorkspaceRole.organizer);

Widget host(Workspace ws) => ProviderScope(
      key: UniqueKey(),
      overrides: [payoutServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: PayoutsScreen(workspace: ws))),
    );

Future<void> open(WidgetTester tester, {Workspace ws = owner, double height = 3600}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(ws));
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() => db = FakePayoutBackend());

  testWidgets('asks for the business\'s own payouts, and shows the account with the account holder and the masked number only', (tester) async {
    await open(tester);
    expect(db.calls.single.$1, 'my_payouts');
    expect(db.calls.single.$2, {'p_org': 'o1'});
    expect(find.text('Ready'), findsOneWidget);
    expect(textOf(tester, 'payout-account-explained'), 'Your payout account is ready to receive payments.');
    expect(textOf(tester, 'payout-holder'), 'Account holder: Club Co Inc.');
    expect(textOf(tester, 'payout-masked'), 'Account: •••• 1234');
    expect(find.byKey(const Key('payout-note')), findsNothing);
  });

  testWidgets('nothing on the screen can be typed into: it is read only', (tester) async {
    db.items = [FakePayoutBackend.item('i1')];
    await open(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byKey(const Key('payouts-footnote')), findsOneWidget);
  });

  testWidgets('an account that needs something says what, in BottlesUp\'s words', (tester) async {
    db.account = {'status': 'action_required', 'account_holder': null, 'masked_account': null, 'note': 'Send us a void cheque.'};
    await open(tester);
    expect(find.text('Action needed'), findsOneWidget);
    expect(textOf(tester, 'payout-note'), 'Send us a void cheque.');
    expect(find.byKey(const Key('payout-holder')), findsNothing);
    expect(find.byKey(const Key('payout-masked')), findsNothing);
  });

  testWidgets('a business whose account is not set up is told nothing can be paid yet', (tester) async {
    db.account = {'status': 'incomplete', 'account_holder': null, 'masked_account': null, 'note': null};
    await open(tester);
    expect(find.text('Not set up yet'), findsOneWidget);
    expect(textOf(tester, 'payout-account-explained'), contains('Nothing can be paid out'));
  });

  testWidgets('the weekday, the wait, BottlesUp\'s percentage and the next payout day are as the CMS set them', (tester) async {
    await open(tester);
    expect(find.text('BottlesUp pays out every Wednesday, by bank transfer.'), findsOneWidget);
    expect(find.text('Money waits 2 days after the night before it is included.'), findsOneWidget);
    expect(find.text('BottlesUp keeps 12.5% of what it pays out.'), findsOneWidget);
    expect(textOf(tester, 'payout-next'), 'Next payout day: Wednesday 28 October 2026');
  });

  testWidgets('a percentage BottlesUp has not set yet is not made up', (tester) async {
    db.settings = {...db.settings, 'commission_set': false, 'commission_bps': null};
    await open(tester);
    expect(find.text('BottlesUp has not set its percentage yet.'), findsOneWidget);
    expect(find.textContaining('% of what it pays out'), findsNothing);
  });

  testWidgets('an arrangement made for this business is said so', (tester) async {
    db.settings = {...db.settings, 'own_arrangement': true, 'payout_weekday': 5, 'commission_bps': 800};
    await open(tester);
    expect(find.text('This is an arrangement made for your business.'), findsOneWidget);
    expect(find.text('BottlesUp pays out every Friday, by bank transfer.'), findsOneWidget);
    expect(find.text('BottlesUp keeps 8% of what it pays out.'), findsOneWidget);
  });

  testWidgets('a venue business sees what is waiting, and that money taken at the club is never paid twice', (tester) async {
    await open(tester);
    expect(textOf(tester, 'payout-waiting-line'), '3 bookings with \$450.00 collected online are waiting for the next payout. This is an estimate, before BottlesUp\'s percentage.');
    expect(textOf(tester, 'payout-cash-note'), contains('never paid to you again'));
  });

  testWidgets('nothing waiting says so', (tester) async {
    db.waiting = {'bookings': 0, 'gross_cents': 0};
    await open(tester);
    expect(textOf(tester, 'payout-waiting-line'), 'Nothing is waiting for the next payout.');
  });

  testWidgets('every payout shows what it was worked out from and where it stands; Paid shows its reference', (tester) async {
    db.items = [
      FakePayoutBackend.item('i1', status: 'paid', adjustment: 2500, note: 'Bonus'),
      FakePayoutBackend.item('i2', status: 'processing', reference: null, expected: '2026-10-28'),
      FakePayoutBackend.item('i3', status: 'pending', reference: null),
      FakePayoutBackend.item('i4', status: 'failed', reference: null, failure: 'Bank rejected it'),
    ];
    await open(tester);
    expect(find.text('No payout has been made yet.'), findsNothing);
    expect(textOf(tester, 'payout-money-i1'), '\$1,000.00 collected · \$125.00 BottlesUp · +\$25.00 adjustment');
    expect(textOf(tester, 'payout-adjustment-i1'), 'Adjustment: Bonus');
    expect(find.text('\$875.00'), findsNWidgets(3), reason: 'gross less BottlesUp\'s share, for the three without an adjustment');
    expect(find.text('\$900.00'), findsOneWidget, reason: 'the same plus the \$25.00 adjustment');
    expect(textOf(tester, 'payout-line-i1'), allOf(startsWith('Paid on '), endsWith(' · reference TRF-1001')));
    expect(textOf(tester, 'payout-line-i2'), 'On its way: expected Wednesday 28 October 2026');
    expect(textOf(tester, 'payout-line-i3'), 'Being prepared');
    expect(textOf(tester, 'payout-line-i4'), 'Did not go through: Bank rejected it. BottlesUp will be in touch.');
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('On its way'), findsOneWidget);
    expect(find.text('Being prepared'), findsWidgets);
    expect(find.text('Did not go through'), findsOneWidget);
  });

  testWidgets('no payout yet says so', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('payouts-none')), findsOneWidget);
  });

  testWidgets('an organizer sees the account and the arrangement, nothing waiting, and is told ticket earnings are not here yet', (tester) async {
    db.role = 'organizer';
    db.orgKind = 'organizer';
    await open(tester, ws: organizer);
    expect(db.calls.single.$2, {'p_org': 'o2'});
    expect(find.byKey(const Key('payout-waiting')), findsNothing);
    expect(find.byKey(const Key('payouts-organizer-note')), findsOneWidget);
    expect(find.byKey(const Key('payout-settings')), findsOneWidget);
  });

  testWidgets('a failed read says so with Try again, and trying again works', (tester) async {
    db.failAll = Exception('boom');
    await open(tester);
    expect(find.byKey(const Key('payouts-error')), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    db.failAll = null;
    await tester.tap(find.byKey(const Key('ops-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('payout-account')), findsOneWidget);
  });

  testWidgets('someone who is not the business\'s owner or an organizer is told their access has ended', (tester) async {
    db.role = 'manager';
    await open(tester);
    expect(find.byKey(const Key('payouts-error')), findsOneWidget);
    expect(find.byKey(const Key('payout-account')), findsNothing);
  });

  testWidgets('a server without the function says it is not set up on this server, with no retry', (tester) async {
    db.failAll = PostgrestException(message: 'function my_payouts does not exist', code: '42883');
    await open(tester);
    expect(find.textContaining('not set up'), findsOneWidget);
    expect(find.byKey(const Key('ops-retry')), findsNothing);
  });

  testWidgets('pulling down reads it again', (tester) async {
    await open(tester, height: 700);
    final before = db.calls.length;
    await tester.drag(find.byKey(const Key('payouts')), const Offset(0, 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(db.calls.length, greaterThan(before));
  });

  test('a failed read is a load failure', () async {
    db.failAll = Exception('boom');
    await expectLater(db.service.mine('o1'), throwsA(isA<OpsLoadException>()));
  });
}
