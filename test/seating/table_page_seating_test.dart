import 'package:bottles_up_vendor/features/seating/providers/seating_providers.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../table_service/fake_table_backend.dart';
import 'fake_seating_backend.dart';

void main() {
  late FakeTableBackend tables;
  late FakeSeatingBackend seating;

  setUp(() {
    tables = FakeTableBackend()..role = 'manager';
    tables.now = DateTime(2026, 10, 9, 21);
    tables.addBooking('b1', name: 'Ada Lovelace', total: 10000, paid: 6000);
    seating = FakeSeatingBackend(role: 'manager');
    seating.bookings.add(FakeSeatBooking('b1', 'ADA111', 'Ada Lovelace'));
  });

  Widget host() => ProviderScope(
        key: UniqueKey(),
        overrides: [
          tableServiceServiceProvider.overrideWithValue(tables.service),
          seatingServiceProvider.overrideWithValue(seating.service),
        ],
        child: MaterialApp(theme: ThemeData.dark(), home: const TableDetailScreen(bookingId: 'b1', title: 'VIP booth · Ada Lovelace')),
      );

  testWidgets('a table\'s page opens with the seating panel above the money, and a manager can un-seat from it', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    seating.bookings.first
      ..seated = true
      ..seatedAt = DateTime(2026, 10, 9, 21, 42)
      ..method = 'scan'
      ..seatedBy = 'Sam Server';
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seating-panel')), findsOneWidget);
    expect(find.textContaining('Seated at 9:42 PM'), findsOneWidget);
    expect(find.byKey(const Key('panel-unseat')), findsOneWidget, reason: 'the page knows this person is a manager');
    final panelTop = tester.getTopLeft(find.byKey(const Key('seating-panel'))).dy;
    final moneyTop = tester.getTopLeft(find.text('Bottle orders')).dy;
    expect(panelTop, lessThan(moneyTop));
  });

  testWidgets('a server\'s page offers no Un-seat', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tables.role = 'server';
    seating.role = 'server';
    seating.bookings.first
      ..seated = true
      ..seatedAt = DateTime(2026, 10, 9, 21, 42);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('seating-panel')), findsOneWidget);
    expect(find.byKey(const Key('panel-unseat')), findsNothing);
  });
}
