import 'package:bottles_up_vendor/features/discounts/providers/discount_providers.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../table_service/fake_table_backend.dart';
import 'fake_discount_backend.dart';

late FakeDiscountBackend discounts;
late FakeTableBackend desk;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [discountServiceProvider.overrideWithValue(discounts.service), tableServiceServiceProvider.overrideWithValue(desk.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: const TableDetailScreen(bookingId: 'b1', title: 'VIP booth · Ada Lovelace')),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(Tab, 'Orders'));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    discounts = FakeDiscountBackend()..role = 'manager';
    discounts.limits = {'server_max_percent': 10, 'manager_max_percent': 25, 'server_free_bottles_per_night': 2, 'manager_free_bottles_per_night': 4, 'allow_stacking': false};
    discounts.addBooking('b1');
    desk = FakeTableBackend()..role = 'manager';
    desk.now = DateTime(2026, 10, 9, 21);
    desk.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD', total: 10000, paid: 6000, guests: 4);
    desk.addLine('b1', 'Patron', lineId: 'l1', minutesAgo: 40);
  });

  testWidgets('a manager finds discounts and free bottles on the Orders tab, above the bottle orders', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('discounts-card')), findsOneWidget);
    expect(find.byKey(const Key('give-discount')), findsOneWidget);
    expect(find.text('Bottle orders'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('discounts-card'))).dy, lessThan(tester.getTopLeft(find.text('Bottle orders')).dy));
  });

  testWidgets('giving a discount re-reads the table\'s money and orders, so the page shows the new total', (tester) async {
    await open(tester);
    final reads = desk.calls.where((c) => c.$1 == 'desk_booking_money').length;
    await tapKey(tester, 'give-discount');
    await tester.enterText(find.byKey(const Key('discount-value')), '10');
    await tester.enterText(find.byKey(const Key('discount-reason')), 'Regular guest');
    await tester.pump();
    await tapKey(tester, 'discount-confirm');
    expect(discounts.concessions.single.status, 'applied');
    expect(desk.calls.where((c) => c.$1 == 'desk_booking_money').length, greaterThan(reads));
  });

  testWidgets('the table\'s server gets it for their own table', (tester) async {
    desk.role = 'server';
    desk.assignments['b1'] = desk.myMembership;
    discounts.role = 'server';
    await open(tester);
    expect(find.byKey(const Key('discounts-card')), findsOneWidget);
  });

  testWidgets('a table that has been closed out has no card: nothing can be given on it', (tester) async {
    desk.bookings['b1']!.reconciled = true;
    await open(tester);
    expect(find.byKey(const Key('discounts-card')), findsNothing);
  });

  testWidgets('a booking that is not confirmed has no card', (tester) async {
    desk.bookings['b1']!.status = 'pending';
    await open(tester);
    expect(find.byKey(const Key('discounts-card')), findsNothing);
  });

  testWidgets('if the card cannot be read the bottle orders still show', (tester) async {
    discounts.beforeCall = (f) => throw Exception('boom');
    await open(tester);
    expect(find.byKey(const Key('discounts-card-error')), findsOneWidget);
    expect(find.text('Bottle orders'), findsOneWidget);
    expect(find.byKey(const Key('add-bottles')), findsOneWidget);
  });
}
