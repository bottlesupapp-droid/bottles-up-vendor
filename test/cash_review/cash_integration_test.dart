import 'package:bottles_up_vendor/features/cash_review/providers/cash_providers.dart';
import 'package:bottles_up_vendor/features/cash_review/screens/cash_screen.dart';
import 'package:bottles_up_vendor/features/cash_review/screens/exceptions_screen.dart';
import 'package:bottles_up_vendor/features/cash_review/screens/summary_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/my_tables_screen.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/payment_review_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/screens/workspace_section_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../server_desk/fake_desk_backend.dart';
import '../table_service/fake_table_backend.dart';
import 'fake_cash_backend.dart';

Workspace ws(WorkspaceRole role) => Workspace(
      membershipId: 'w1',
      orgId: 'o1',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: role,
      venueId: 'v1',
      venueName: 'Club A',
    );

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

void main() {
  group('the verifier\'s tabs are built', () {
    test('Review, Cash, Exceptions and Summary open their screens', () {
      final v = ws(WorkspaceRole.verifier);
      expect(builtSectionFor(v, 'review'), isA<PaymentReviewScreen>());
      expect(builtSectionFor(v, 'cash'), isA<CashScreen>());
      expect(builtSectionFor(v, 'exceptions'), isA<ExceptionsScreen>());
      expect(builtSectionFor(v, 'summary'), isA<VerifierSummaryScreen>());
    });

    test('other roles have no such tab', () {
      for (final role in [WorkspaceRole.server, WorkspaceRole.door, WorkspaceRole.security]) {
        expect(builtSectionFor(ws(role), 'cash'), isNull, reason: role.label);
        expect(builtSectionFor(ws(role), 'exceptions'), isNull, reason: role.label);
        expect(builtSectionFor(ws(role), 'summary'), isNull, reason: role.label);
      }
    });
  });

  group('Tonight (manager) shows the cash and the flags', () {
    late FakeTableBackend tables;
    late FakeCashBackend cash;

    setUp(() {
      tables = FakeTableBackend()..role = 'manager';
      tables.now = friday9pm();
      tables.addBooking('b1', name: 'Ada Lovelace', total: 10000, paid: 6000, guests: 4);
      cash = FakeCashBackend(role: 'manager');
      cash.collected['u-sam'] = 5000;
      cash.handovers.add(FakeHandover('h1', 'u-sam', 3000, friday9pm()));
      cash.flags.add(FakeFlag('f1', 'p1', 'Ada Lovelace', 'VIP booth', 'debit', 4000, 'looks off', 'u-bea', friday9pm()));
    });

    Widget host() => ProviderScope(
          key: UniqueKey(),
          overrides: [
            tableServiceServiceProvider.overrideWithValue(tables.service),
            cashServiceProvider.overrideWithValue(cash.service),
          ],
          child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: TonightScreen(workspace: ws(WorkspaceRole.manager), clock: friday9pm))),
        );

    String countOf(WidgetTester tester, String key) =>
        tester.widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).map((t) => t.data ?? '').last;

    testWidgets('two new tiles with their counts, each opening its list', (tester) async {
      await open(tester, host());
      expect(countOf(tester, 'tile-handovers'), '1');
      expect(countOf(tester, 'tile-flags'), '1');

      await tester.tap(find.byKey(const Key('tile-handovers')));
      await tester.pumpAndSettle();
      expect(find.byType(CashScreen), findsOneWidget);
      expect(find.byKey(const Key('count-h1')), findsOneWidget);
    });

    testWidgets('the flags tile opens the flagged payments, where the manager can resolve', (tester) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('tile-flags')));
      await tester.pumpAndSettle();
      expect(find.byType(ExceptionsScreen), findsOneWidget);
      expect(find.byKey(const Key('resolve-f1')), findsOneWidget);
    });

    testWidgets('on a server without the cash functions the rest of Tonight is untouched', (tester) async {
      cash.missing = true;
      await open(tester, host());
      expect(find.byKey(const Key('tile-handovers')), findsNothing);
      expect(find.byKey(const Key('tile-flags')), findsNothing);
      expect(find.byKey(const Key('tile-payments')), findsOneWidget);
      expect(find.byKey(const Key('tile-orders-new')), findsOneWidget);
    });
  });

  group('flagging from the payments to check', () {
    late FakeTableBackend tables;
    late FakeCashBackend cash;

    setUp(() {
      tables = FakeTableBackend()..role = 'verifier';
      tables.now = friday9pm();
      tables.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD');
      tables.addPayment('b1', 3000, paymentId: 'p1', path: 'b1/r.jpg', method: 'debit', at: tables.now.subtract(const Duration(minutes: 30)));
      tables.addPayment('b1', 900, paymentId: 'mine', by: 'u-me', path: 'b1/r4.jpg', at: tables.now.subtract(const Duration(minutes: 2)));
      cash = FakeCashBackend(role: 'verifier');
    });

    Widget host() => ProviderScope(
          key: UniqueKey(),
          overrides: [
            tableServiceServiceProvider.overrideWithValue(tables.service),
            cashServiceProvider.overrideWithValue(cash.service),
          ],
          child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: PaymentReviewScreen(workspace: ws(WorkspaceRole.verifier), clock: friday9pm))),
        );

    testWidgets('a payment can be flagged with a reason; a payment you recorded has no such button', (tester) async {
      await open(tester, host());
      expect(find.byKey(const Key('flag-p1')), findsOneWidget);
      expect(find.byKey(const Key('flag-mine')), findsNothing, reason: 'someone else flags your entries');

      await tester.tap(find.byKey(const Key('flag-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Say what is wrong with this payment.'), findsOneWidget, reason: 'a reason is required before anything is sent');
      expect(cash.calledWith('desk_flag_payment'), isEmpty);

      await tester.enterText(find.byKey(const Key('text-field')), 'the till says 28.00');
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await tester.pumpAndSettle();

      expect(cash.calledWith('desk_flag_payment').single, {'p_payment': 'p1', 'p_reason': 'the till says 28.00'});
      expect(find.text('Payment flagged. A manager will resolve it.'), findsOneWidget);
    });

    testWidgets('flagging the same payment twice shows the database\'s sentence', (tester) async {
      cash.flags.add(FakeFlag('f0', 'p1', 'Ada', 'VIP', 'debit', 3000, 'earlier', 'u-bea', friday9pm()));
      await open(tester, host());
      await tester.tap(find.byKey(const Key('flag-p1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('text-field')), 'looks wrong');
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('This payment is already flagged.'), findsOneWidget);
    });

    testWidgets('backing out of the dialog flags nothing', (tester) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('flag-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog-back')));
      await tester.pumpAndSettle();
      expect(cash.calledWith('desk_flag_payment'), isEmpty);
    });
  });

  group('My Tables shows a server\'s cash', () {
    testWidgets('the card sits above the tables', (tester) async {
      final desk = FakeDeskBackend();
      desk.now = DateTime(2026, 10, 9, 21, 30);
      desk.addBooking('b1', code: 'AB12CD', label: 'Evening', name: 'Ada Lovelace');
      desk.assignments['b1'] = 'm-me';
      final cash = FakeCashBackend(role: 'server');
      cash.collected['u-me'] = 2500;
      await open(
        tester,
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            serverDeskServiceProvider.overrideWithValue(desk.service),
            cashServiceProvider.overrideWithValue(cash.service),
          ],
          child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: MyTablesScreen(workspace: ws(WorkspaceRole.server), clock: friday9pm, pickAsk: (c, l) async => null))),
        ),
      );
      expect(find.text(r'You are holding $25.00 in cash'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      final cardTop = tester.getTopLeft(find.byKey(const Key('cash-held-card'))).dy;
      final tableTop = tester.getTopLeft(find.text('Ada Lovelace')).dy;
      expect(cardTop, lessThan(tableTop));
    });
  });
}
