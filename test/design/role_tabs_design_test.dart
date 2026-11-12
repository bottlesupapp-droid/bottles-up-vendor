
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/floor/providers/floor_providers.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/my_tables_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/service_requests_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/widgets/desk_chip.dart';
import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/orders_screen.dart';
import 'package:bottles_up_vendor/features/table_service/widgets/night_bar.dart';
import 'package:bottles_up_vendor/features/table_service/widgets/order_card.dart';
import 'package:bottles_up_vendor/features/table_service/widgets/payment_tile.dart' show verificationColor;
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';

import '../floor/fake_floor_backend.dart';
import '../server_desk/fake_desk_backend.dart';
import '../table_service/fake_table_backend.dart';
import 'role_test_support.dart';


void main() {
  setUpAll(loadInter);

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('the pieces every role shares', () {
    testWidgets('a desk chip is a pill: a faint wash of its colour, the same colour at its edge and in its word', (tester) async {
      await showScreen(tester, const Center(child: DeskChip(text: 'Delivered', color: Color(0xFF59D7A2))), const []);
      final box = tester.widget<Container>(find.descendant(of: find.byType(DeskChip), matching: find.byType(Container)).first).decoration! as BoxDecoration;
      expect(box.color, const Color(0xFF59D7A2).withValues(alpha: 0.10));
      expect((box.border! as Border).top.color, const Color(0xFF59D7A2).withValues(alpha: 0.45));
      expect(box.borderRadius, BorderRadius.circular(BuRadius.pill));
      final text = tester.widget<Text>(find.text('Delivered')).style!;
      expect(text.color, const Color(0xFF59D7A2));
      expect(text.fontWeight, FontWeight.w700);
    });

    testWidgets('a desk chip can carry an icon in its colour', (tester) async {
      await showScreen(tester, const Center(child: DeskChip(text: 'Arrived', color: Color(0xFF59D7A2), icon: Ionicons.checkmark_circle)), const []);
      final icon = tester.widget<Icon>(find.descendant(of: find.byType(DeskChip), matching: find.byType(Icon)));
      expect([icon.icon, icon.color], [Ionicons.checkmark_circle, const Color(0xFF59D7A2)]);
    });

    test('an order is amber while it waits, then stronger as it is worked on, and green once delivered', () {
      expect(serviceStateColor(ServiceState.awaitingPrep), bu.amber);
      expect(serviceStateColor(ServiceState.accepted), bu.soft);
      expect(serviceStateColor(ServiceState.preparing), bu.orange);
      expect(serviceStateColor(ServiceState.ready), bu.orangeSoft);
      expect(serviceStateColor(ServiceState.pickedUp), bu.ink);
      expect(serviceStateColor(ServiceState.served), bu.green);
    });

    test('a line is green when paid, amber when due at the club, grey while pending', () {
      expect(linePaymentColor(LinePayment.paid), bu.green);
      expect(linePaymentColor(LinePayment.dueAtVenue), bu.amber);
      expect(linePaymentColor(LinePayment.pendingPayment), bu.muted);
    });

    test('a payment is amber until checked, green once verified, red when disputed', () {
      expect(verificationColor(Verification.pending), bu.amber);
      expect(verificationColor(Verification.verified), bu.green);
      expect(verificationColor(Verification.customerConfirmed), bu.soft);
      expect(verificationColor(Verification.disputed), bu.red);
    });

    testWidgets('a card can be lit in another colour than orange: an accent lights it, a highlight lights it orange, neither leaves it plain', (tester) async {
      await showScreen(tester, const Column(children: [
        BuCard(key: Key('plain'), child: Text('a')),
        BuCard(key: Key('orange'), highlight: true, child: Text('b')),
        BuCard(key: Key('red'), accent: Color(0xFFFF6B6B), child: Text('c')),
      ]), const []);
      Border edge(String k) => (tester.widget<Container>(find.descendant(of: find.byKey(Key(k)), matching: find.byType(Container)).first).decoration! as BoxDecoration).border! as Border;
      expect(edge('plain').top.color, bu.hairline);
      expect(edge('orange').top.color, bu.orange.withValues(alpha: 0.28));
      expect(edge('red').top.color, const Color(0xFFFF6B6B).withValues(alpha: 0.28));
    });

    testWidgets('a stat tile can carry a small line under its label, as the third text', (tester) async {
      await showScreen(tester, const BuMetricTile(value: '2', label: 'Confirmed bookings', hint: '1 night'), const []);
      final texts = tester.widgetList<Text>(find.descendant(of: find.byType(BuMetricTile), matching: find.byType(Text))).map((t) => t.data).toList();
      expect(texts, ['2', 'Confirmed bookings', '1 night']);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Orders (manager and server)', () {
    late FakeTableBackend db;
    setUp(() {
      db = FakeTableBackend()..role = 'manager';
      db.now = DateTime(2026, 10, 9, 21);
      db.addBooking('b1', name: 'Ada Lovelace', total: 10000, paid: 6000, guests: 4);
      db.addBooking('b3', name: 'Nobody Nell', total: 2000, paid: 0, guests: 3, table: 'Booth 3');
      db.addBooking('b2', name: 'Grace Hopper', total: 5000, paid: 5000, guests: 2, table: 'Corner');
      db.assignments['b1'] = 'm-me';
      db.assignments['b2'] = 'm-me';
      db.addLine('b1', 'Patron', state: 'awaiting_prep');
      db.addLine('b1', 'Grey Goose', state: 'preparing', pay: 'due_at_venue');
      db.addLine('b2', 'Moet', state: 'served');
      db.addLine('b3', 'Belvedere', state: 'awaiting_prep');
    });

    Future<void> open(WidgetTester tester, {Workspace ws = managerWs}) => showScreen(tester, OrdersScreen(workspace: ws, clock: friday9pm), [tableServiceServiceProvider.overrideWithValue(db.service)]);

    OrderLine line(WidgetTester tester, String title) => tester.widgetList<OrderCard>(find.byType(OrderCard)).map((c) => c.line).firstWhere((l) => l.title.contains(title));

    testWidgets('a manager sees "Orders" under a Service eyebrow, the club under it, then the night bar', (tester) async {
      await open(tester);
      expect(find.text('SERVICE'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(tester.getRect(find.text('Club A')).top, greaterThan(tester.getRect(find.text('Orders')).bottom));
      expect(tester.getRect(find.byKey(const Key('night-label'))).top, greaterThan(tester.getRect(find.text('Club A')).bottom));
      expect(textColor(tester, find.text('Club A')), bu.muted);
    });

    testWidgets('a server sees "My orders" under a Your shift eyebrow', (tester) async {
      await open(tester, ws: serverWs);
      expect(find.text('YOUR SHIFT'), findsOneWidget);
      expect(find.text('My orders'), findsOneWidget);
    });

    testWidgets('the filters are plain chips with no tick; the chosen one is selected', (tester) async {
      await open(tester);
      for (final f in OrderFilter.values) {
        final chip = tester.widget<ChoiceChip>(find.byKey(Key('filter-${f.name}')));
        expect(chip.showCheckmark, isFalse, reason: f.name);
        expect(chip.selected, f == OrderFilter.all, reason: f.name);
      }
    });

    testWidgets('each order is a card with its state as a pill in the colour of that state', (tester) async {
      await open(tester);
      final patron = line(tester, 'Patron');
      final goose = line(tester, 'Grey Goose');
      final moet = line(tester, 'Moet');
      expect(find.byKey(Key('order-${patron.lineId}')), findsOneWidget);
      expect(tester.widget<BuCard>(find.byKey(Key('order-${patron.lineId}'))).padding, const EdgeInsets.all(BuSpace.l));
      expect(chipColor(tester, 'state-${patron.lineId}'), bu.amber);
      expect(chipColor(tester, 'state-${goose.lineId}'), bu.orange);
      expect(chipColor(tester, 'state-${moet.lineId}'), bu.green);
    });

    testWidgets('how it is paid: green when paid, amber when due at the club', (tester) async {
      await open(tester);
      expect(chipColor(tester, 'payment-${line(tester, 'Patron').lineId}'), bu.green);
      expect(chipColor(tester, 'payment-${line(tester, 'Grey Goose').lineId}'), bu.amber);
    });

    testWidgets('"No server" is a red pill, shown to the manager only', (tester) async {
      await open(tester);
      expect(chipColor(tester, 'no-server-${line(tester, 'Belvedere').lineId}'), bu.red);
    });

    testWidgets('why a bottle cannot go out yet is said in amber', (tester) async {
      await open(tester);
      final goose = line(tester, 'Grey Goose');
      expect(textColor(tester, find.byKey(Key('blocked-${goose.lineId}'))), bu.amber);
    });

    testWidgets('the move to make next is the one orange button of the card', (tester) async {
      await open(tester);
      final patron = line(tester, 'Patron');
      expect(find.descendant(of: find.byKey(Key('order-${patron.lineId}')), matching: find.byType(FilledButton)), findsOneWidget);
      expect(find.byKey(Key('move-${patron.lineId}')), findsOneWidget);
    });

    testWidgets('a night with no orders says so in a card', (tester) async {
      db.lines.clear();
      await open(tester);
      expect(find.ancestor(of: find.byKey(const Key('orders-empty')), matching: find.byType(BuCard)), findsOneWidget);
    });

    testWidgets('a failure to load is a card with the sentence and Try again', (tester) async {
      db.failAll = true;
      await open(tester);
      expect(find.ancestor(of: find.byKey(const Key('orders-error')), matching: find.byType(BuCard)), findsOneWidget);
      expect(find.byKey(const Key('orders-retry')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Floor (manager)', () {
    late FakeFloorBackend floor;
    setUp(() {
      floor = FakeFloorBackend();
      floor.onList = (p) => [
            bookingRow('a1', guests: 4, checkedInAt: '2026-10-09T22:00:00Z'),
            bookingRow('a2', guests: 2, name: 'Grace Hopper', table: 'Corner'),
            bookingRow('a3', status: 'pending', name: 'Nobody Nell', table: 'Booth 3'),
          ];
    });

    Future<void> open(WidgetTester tester, {bool heading = true}) =>
        showScreen(tester, FloorScreen(venueId: 'v1', venueName: 'Club A', clock: friday9pm, showHeading: heading), [floorServiceProvider.overrideWithValue(floor.service)]);

    testWidgets('has a Floor eyebrow and "Bookings", the club under it', (tester) async {
      await open(tester);
      expect(find.text('FLOOR'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
    });

    testWidgets('has no heading of its own when it sits under a venue page that has one', (tester) async {
      await open(tester, heading: false);
      expect(find.byType(BuPageHeader), findsNothing);
      expect(find.text('Bookings'), findsNothing);
    });

    testWidgets('the ready-made ranges carry no tick', (tester) async {
      await open(tester);
      for (final id in ['tonight', 'next7', 'next30', 'last7']) {
        expect(tester.widget<ChoiceChip>(find.byKey(Key('preset-$id'))).showCheckmark, isFalse, reason: id);
      }
    });

    testWidgets('the four figures are stat tiles, two to a row, each with its small line', (tester) async {
      await open(tester);
      expect(find.byType(BuMetricTile), findsNWidgets(4));
      final confirmed = tester.getRect(find.byKey(const Key('tile-confirmed')));
      final guests = tester.getRect(find.byKey(const Key('tile-guests')));
      final arrived = tester.getRect(find.byKey(const Key('tile-arrived')));
      expect(confirmed.top, guests.top);
      expect(guests.left - confirmed.right, BuSpace.m, reason: 'a gap between the two tiles of a row');
      expect(arrived.top - confirmed.bottom, BuSpace.m, reason: 'and between the rows');
      expect(find.descendant(of: find.byKey(const Key('tile-arrived')), matching: find.text('Checked in at the venue')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tile-awaiting')), matching: find.text('Started, not paid yet')), findsOneWidget);
    });

    testWidgets('a booking is a card; "Arrived" is a green pill with a tick and the status a pill in its own colour', (tester) async {
      await open(tester);
      expect(tester.widget<BuCard>(find.byKey(const Key('booking-a1'))).margin, const EdgeInsets.only(top: BuSpace.s));
      final arrived = tester.widget<DeskChip>(find.byKey(const Key('arrived')));
      expect([arrived.color, arrived.icon], [bu.green, Ionicons.checkmark_circle]);
      expect(chipColor(tester, 'status-a1'), bu.green);
      await tester.tap(find.text('Everything'));
      await tester.pumpAndSettle();
      expect(chipColor(tester, 'status-a3'), bu.amber, reason: 'a booking that was started and not paid');
    });

    testWidgets('an end before the start is said in amber', (tester) async {
      await showScreen(
        tester,
        FloorScreen(venueId: 'v1', venueName: 'Club A', clock: friday9pm, pickNight: (c, i) async => DateTime(2026, 10, 1)),
        [floorServiceProvider.overrideWithValue(floor.service)],
      );
      await tester.tap(find.byKey(const Key('pick-to')));
      await tester.pumpAndSettle();
      expect(textColor(tester, find.byKey(const Key('range-problem'))), bu.amber);
    });

    testWidgets('a failure to load is a card with the sentence and Try again', (tester) async {
      floor.onList = (p) => throw Exception('offline');
      await open(tester);
      expect(find.ancestor(of: find.byKey(const Key('floor-error')), matching: find.byType(BuCard)), findsOneWidget);
    });

    testWidgets('with nothing to show it says so in a card', (tester) async {
      floor.onList = (p) => <Map<String, dynamic>>[];
      await open(tester);
      expect(find.ancestor(of: find.byKey(const Key('floor-empty')), matching: find.byType(BuCard)), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('My tables and Requests (server)', () {
    late FakeDeskBackend db;
    setUp(() {
      db = FakeDeskBackend();
      db.now = DateTime(2026, 10, 9, 21, 30);
      db.addBooking('b1', code: 'AB12CD', label: 'Evening', name: 'Ada Lovelace');
      db.addBooking('b2', time: '23:00:00', table: 'Dance floor table', guests: 2, name: 'Grace Hopper', code: 'EF34GH', checkedInAt: '2026-10-09T23:10:00Z');
      db.assignments['b1'] = 'm-me';
      db.assignments['b2'] = 'm-me';
      db.addRequest('b1', 'water_ice_mixers', createdAt: DateTime(2026, 10, 9, 21, 20));
    });

    Future<void> tables(WidgetTester tester) => showScreen(tester, MyTablesScreen(workspace: serverWs, clock: friday9pm, pickAsk: (c, l) async => null), [serverDeskServiceProvider.overrideWithValue(db.service)]);
    Future<void> requests(WidgetTester tester) => showScreen(tester, ServiceRequestsScreen(workspace: serverWs, clock: friday9pm), [serverDeskServiceProvider.overrideWithValue(db.service)]);

    testWidgets('My tables has a Your shift eyebrow, the club under the title, and the shared night bar', (tester) async {
      await tables(tester);
      expect(find.text('YOUR SHIFT'), findsOneWidget);
      expect(find.text('My tables'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(find.byType(NightBar), findsOneWidget);
    });

    testWidgets('"Expected" is a grey pill and "Arrived" a green one with a tick', (tester) async {
      await tables(tester);
      expect(chipColor(tester, 'expected-b1'), bu.muted);
      final arrived = tester.widget<DeskChip>(find.byKey(const Key('arrived-b2')));
      expect([arrived.color, arrived.icon], [bu.green, Ionicons.checkmark_circle]);
    });

    testWidgets('a table\'s two buttons are one under the other, each the width of the card\'s inside (side by side they did not fit a phone)', (tester) async {
      await tables(tester);
      final open = tester.getRect(find.byKey(const Key('open-b1')));
      final ask = tester.getRect(find.byKey(const Key('ask-b1')));
      expect(open.left, ask.left);
      expect(open.width, ask.width);
      expect(ask.top, greaterThan(open.bottom));
      final card = tester.getRect(find.byKey(const Key('table-b1')));
      expect(open.width, card.width - 2 * BuSpace.l - 2);
    });

    testWidgets('a table is a card', (tester) async {
      await tables(tester);
      expect(find.byKey(const Key('table-b1')), findsOneWidget);
      expect(tester.widget<BuCard>(find.byKey(const Key('table-b1'))).margin, const EdgeInsets.only(top: BuSpace.s));
    });

    testWidgets('an open request under a table is a pill in the colour of its status', (tester) async {
      await tables(tester);
      final chip = tester.widget<DeskChip>(find.descendant(of: find.byKey(const Key('table-b1')), matching: find.byType(DeskChip)).last);
      expect(chip.color, bu.amber);
    });

    testWidgets('with no tables it says so in a card', (tester) async {
      db.assignments.clear();
      await tables(tester);
      expect(find.ancestor(of: find.byKey(const Key('tables-empty')), matching: find.byType(BuCard)), findsOneWidget);
    });

    testWidgets('Requests has a Your shift eyebrow and a card per request with its status pill', (tester) async {
      await requests(tester);
      expect(find.text('YOUR SHIFT'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      final card = find.byType(BuCard).evaluate().where((e) => e.widget.key.toString().contains('request-')).toList();
      expect(card, hasLength(1));
      expect(tester.widget<DeskChip>(find.byWidgetPredicate((w) => w is DeskChip && w.key.toString().contains('status-'))).color, bu.amber);
    });

    testWidgets('with no requests it says so in a card', (tester) async {
      db.requests.clear();
      await requests(tester);
      expect(find.ancestor(of: find.byKey(const Key('requests-empty')), matching: find.byType(BuCard)), findsOneWidget);
    });
  });
}
