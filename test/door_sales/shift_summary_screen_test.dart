import 'package:bottles_up_vendor/features/door/providers/door_providers.dart';
import 'package:bottles_up_vendor/features/door_sales/logic/door_sales_rules.dart';
import 'package:bottles_up_vendor/features/door_sales/providers/door_sales_providers.dart';
import 'package:bottles_up_vendor/features/door_sales/screens/shift_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../door/fake_door_backend.dart';
import 'fake_door_sales_backend.dart';

late FakeDoorBackend door;
late FakeDoorSalesBackend db;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        doorServiceProvider.overrideWithValue(door.service),
        doorSalesServiceProvider.overrideWithValue(db.service),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: const Scaffold(body: ShiftSummaryScreen(membershipId: 'm1'))),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

/// Records a sale straight in the fake database.
Future<void> sold(String tier, int qty, DoorPayMethod method, String key, {String ref = ''}) =>
    db.service.sell(eventId: 'e1', tierId: tier, quantity: qty, method: method, name: 'Guest $key', email: '', phone: '', reference: ref, key: key);

void main() {
  setUp(() {
    door = FakeDoorBackend();
    door.handlers['door_events'] = (_) => [eventRow()];
    db = FakeDoorSalesBackend();
  });

  testWidgets('shows the event, and asks for this event\'s shift', (tester) async {
    await open(tester);
    expect(find.text('Friday Night'), findsOneWidget);
    expect(db.callsOf('door_shift_summary').single, {'p_event': 'e1'});
  });

  testWidgets('a shift with scans and sales: the cash and the card machine are kept apart, with the total', (tester) async {
    await sold('t-gen', 2, DoorPayMethod.cash, 'key-0000001');
    await sold('t-gen', 1, DoorPayMethod.cash, 'key-0000002');
    await sold('t-vip', 1, DoorPayMethod.terminal, 'key-0000003', ref: 'TERM-1');
    db.guestsAdmitted = 6;
    db.scansAccepted = 4;
    await open(tester);
    expect(textOf(tester, 'shift-guests'), '6');
    expect(textOf(tester, 'shift-scans'), '4');
    expect(textOf(tester, 'shift-sold'), '3 sales · 4 tickets');
    expect(textOf(tester, 'shift-cash'), '\$150.00 · 2 sales · 3 tickets');
    expect(textOf(tester, 'shift-terminal'), '\$120.00 · 1 sale · 1 ticket');
    expect(textOf(tester, 'shift-total'), '\$270.00');
    expect(find.byKey(const Key('shift-times')), findsOneWidget);
    expect(textOf(tester, 'shift-times'), allOf(startsWith('First sale '), contains(' · last sale ')));
  });

  testWidgets('only cash: the card machine reads zero, not missing', (tester) async {
    await sold('t-gen', 1, DoorPayMethod.cash, 'key-0000001');
    await open(tester);
    expect(textOf(tester, 'shift-cash'), '\$50.00 · 1 sale · 1 ticket');
    expect(textOf(tester, 'shift-terminal'), '\$0.00');
  });

  testWidgets('no sales says so, and still shows what was scanned', (tester) async {
    db.guestsAdmitted = 3;
    db.scansAccepted = 3;
    await open(tester);
    expect(textOf(tester, 'shift-no-sales'), 'You have not sold a ticket at this event.');
    expect(find.byKey(const Key('shift-cash')), findsNothing);
    expect(find.byKey(const Key('shift-total')), findsNothing);
    expect(textOf(tester, 'shift-guests'), '3');
  });

  testWidgets('says that the money is the person\'s own record, not something BottlesUp took', (tester) async {
    await open(tester);
    expect(textOf(tester, 'shift-note'), allOf(contains('BottlesUp did not take this money'), contains('count your cash'), contains('card machine')));
  });

  testWidgets('Refresh reads the shift again and shows a sale made since', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('shift-no-sales')), findsOneWidget);
    await sold('t-gen', 1, DoorPayMethod.cash, 'key-0000001');
    await tester.tap(find.byKey(const Key('shift-refresh')));
    await tester.pumpAndSettle();
    expect(db.callsOf('door_shift_summary').length, 2);
    expect(textOf(tester, 'shift-sold'), '1 sale · 1 ticket');
  });

  testWidgets('the shift failing to load says so and can be tried again', (tester) async {
    db.failAll = Exception('socket closed');
    await open(tester);
    expect(textOf(tester, 'shift-error'), contains('could not be loaded'));
    db.failAll = null;
    await tester.tap(find.byKey(const Key('shift-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shift-guests')), findsOneWidget);
  });

  testWidgets('a server without door sales yet says so, with nothing to retry', (tester) async {
    db.failAll = PostgrestException(message: 'function public.door_shift_summary does not exist', code: '42883');
    await open(tester);
    expect(textOf(tester, 'shift-error'), contains('not set up'));
    expect(find.byKey(const Key('shift-retry')), findsNothing);
  });

  testWidgets('access that has ended is said as such', (tester) async {
    db.role = 'none';
    await open(tester);
    expect(textOf(tester, 'shift-error'), contains('access has ended'));
  });

  testWidgets('choosing another event shows that event\'s shift', (tester) async {
    door.handlers['door_events'] = (_) => [eventRow(), eventRow(id: 'e2', title: 'Saturday Night')];
    await open(tester);
    await tester.tap(find.byKey(const Key('event-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saturday Night').last);
    await tester.pumpAndSettle();
    expect(db.callsOf('door_shift_summary').last, {'p_event': 'e2'});
  });

  testWidgets('no event says so', (tester) async {
    door.handlers['door_events'] = (_) => <Map<String, dynamic>>[];
    await open(tester);
    expect(find.text('No event to show a shift for right now.'), findsOneWidget);
    expect(db.calls, isEmpty);
  });
}
