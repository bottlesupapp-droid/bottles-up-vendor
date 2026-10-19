import 'dart:async';

import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/add_bottles_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_backend.dart';

late FakeTableBackend db;

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [tableServiceServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: TableDetailScreen(bookingId: 'b1', title: 'VIP booth · Ada Lovelace', clock: friday9pm)),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
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

Map<String, dynamic>? lastPart() => db.calls.lastWhere((c) => c.$1 == 'desk_deliver_part').$2;

void main() {
  setUp(() {
    db = FakeTableBackend()..role = 'manager';
    db.now = DateTime(2026, 10, 9, 21);
    db.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD', total: 10000, paid: 10000);
    db.assignments['b1'] = 'm-me';
    db.menu.addAll([FakeBottle('p', 'Patron', 25000, stock: 10), FakeBottle('g', 'Grey Goose', 18000)]);
  });

  group('Add bottles', () {
    testWidgets('a manager and the table\'s server see Add bottles on the Orders tab', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('add-bottles')), findsOneWidget);
      db.role = 'server';
      await open(tester);
      expect(find.byKey(const Key('add-bottles')), findsOneWidget);
    });

    testWidgets('a table that is closed out, or not confirmed, has no Add bottles', (tester) async {
      db.bookings['b1']!.reconciled = true;
      await open(tester);
      expect(find.byKey(const Key('add-bottles')), findsNothing);
      db.bookings['b1']!.reconciled = false;
      db.bookings['b1']!.status = 'pending';
      await open(tester);
      expect(find.byKey(const Key('add-bottles')), findsNothing);
    });

    testWidgets('a verifier has no Orders tab and so no Add bottles', (tester) async {
      db.role = 'verifier';
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Tab, 'Orders'), findsNothing);
      expect(find.byKey(const Key('add-bottles')), findsNothing);
    });

    testWidgets('adding bottles: the screen opens for this table, and back on the table the orders and the money are read again and it says what was added', (tester) async {
      await open(tester);
      expect(find.text('No bottle orders on this table.'), findsOneWidget);
      final moneyReads = db.count('desk_booking_money');
      await tapKey(tester, 'add-bottles');
      expect(find.byType(AddBottlesScreen), findsOneWidget);
      await tapKey(tester, 'bottle-more-p');
      await tapKey(tester, 'bottle-more-p');
      await tapKey(tester, 'add-confirm');
      expect(find.byType(AddBottlesScreen), findsNothing);
      expect(find.text('Added 2 bottles. They are due at the club (\$500.00 before tax).'), findsOneWidget);
      expect(find.text('2 × Patron 750ml'), findsOneWidget, reason: 'the new line is on the table');
      expect(find.text('Added at the table'), findsOneWidget);
      expect(find.text('Pay at venue'), findsOneWidget);
      expect(db.count('desk_booking_money'), greaterThan(moneyReads), reason: 'the table\'s total was read again');
    });

    testWidgets('backing out of Add bottles changes nothing, and the table is read again anyway', (tester) async {
      await open(tester);
      final orderReads = db.count('desk_booking_orders');
      await tapKey(tester, 'add-bottles');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AddBottlesScreen), findsNothing);
      expect(db.invocations, isEmpty);
      expect(db.count('desk_booking_orders'), greaterThan(orderReads));
    });
  });

  group('Deliver some', () {
    setUp(() {
      db.addLine('b1', 'Patron', lineId: 'l1', qty: 5, state: 'ready');
    });

    testWidgets('a Ready line of five offers Deliver some; a line of one does not', (tester) async {
      db.addLine('b1', 'Single Malt', lineId: 'l2', qty: 1, state: 'ready');
      await open(tester);
      expect(find.byKey(const Key('deliver-part-l1')), findsOneWidget);
      expect(find.byKey(const Key('deliver-part-l2')), findsNothing);
    });

    testWidgets('not before it is ready, not once delivered, not on a cancelled line', (tester) async {
      db.addLine('b1', 'Prep', lineId: 'l3', qty: 4, state: 'preparing');
      db.addLine('b1', 'Done', lineId: 'l4', qty: 4, state: 'served');
      db.addLine('b1', 'Gone', lineId: 'l5', qty: 4, state: 'ready', cancelled: true, reason: 'changed their mind');
      await open(tester);
      for (final id in ['l3', 'l4', 'l5']) {
        expect(find.byKey(Key('deliver-part-$id')), findsNothing, reason: id);
      }
    });

    testWidgets('without the delivered count from the server nothing about partial delivery is offered, and the orders still show', (tester) async {
      db.failOn['desk_booking_deliveries'] = PostgrestException(message: 'function does not exist', code: '42883');
      await open(tester);
      expect(find.text('5 × Patron 750ml'), findsOneWidget);
      expect(find.byKey(const Key('deliver-part-l1')), findsNothing);
    });

    testWidgets('the dialog starts at one, stops at what is left, and says when that is all', (tester) async {
      await open(tester);
      await tapKey(tester, 'deliver-part-l1');
      expect(find.text('Deliver some'), findsWidgets);
      expect(tester.widget<Text>(find.byKey(const Key('deliver-n'))).data, '1');
      expect(tester.widget<IconButton>(find.byKey(const Key('deliver-less'))).onPressed, isNull);
      expect(find.byKey(const Key('deliver-all')), findsNothing);
      for (var i = 0; i < 6; i++) {
        final more = tester.widget<IconButton>(find.byKey(const Key('deliver-more')));
        if (more.onPressed == null) break;
        await tester.tap(find.byKey(const Key('deliver-more')));
        await tester.pump();
      }
      expect(tester.widget<Text>(find.byKey(const Key('deliver-n'))).data, '5');
      expect(find.byKey(const Key('deliver-all')), findsOneWidget);
    });

    testWidgets('the dialog says how many were already delivered, even when it is just one', (tester) async {
      db.line('l1').delivered = 1;
      db.line('l1').state = 'picked_up';
      await open(tester);
      expect(find.text('1 of 5 delivered'), findsOneWidget);
      await tapKey(tester, 'deliver-part-l1');
      expect(find.text('1 of 5 already delivered.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('deliver-n'))).data, '1');
    });

    testWidgets('cancelling the dialog sends nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'deliver-part-l1');
      await tapKey(tester, 'deliver-cancel');
      expect(db.count('desk_deliver_part'), 0);
    });

    testWidgets('delivering two of five: it says so, the line shows 2 of 5 delivered and stays On the way, and the next hand-over is based on 2', (tester) async {
      await open(tester);
      await tapKey(tester, 'deliver-part-l1');
      await tester.tap(find.byKey(const Key('deliver-more')));
      await tester.pump();
      await tapKey(tester, 'deliver-confirm');
      expect(lastPart(), {'p_line': 'l1', 'p_quantity': 2, 'p_already': 0});
      expect(find.text('2 of 5 Patron delivered.'), findsOneWidget);
      expect(find.byKey(const Key('delivered-count-l1')), findsOneWidget);
      expect(find.text('2 of 5 delivered'), findsOneWidget);
      expect(find.text('On the way'), findsWidgets);
      await tapKey(tester, 'deliver-part-l1');
      expect(find.byKey(const Key('deliver-already')), findsOneWidget);
      await tapKey(tester, 'deliver-confirm');
      expect(lastPart(), {'p_line': 'l1', 'p_quantity': 1, 'p_already': 2});
    });

    testWidgets('delivering the rest marks the line Delivered and the count disappears', (tester) async {
      db.line('l1').delivered = 3;
      await open(tester);
      await tapKey(tester, 'deliver-part-l1');
      await tester.tap(find.byKey(const Key('deliver-more')));
      await tester.pump();
      await tapKey(tester, 'deliver-confirm');
      expect(find.text('All 5 of Patron delivered.'), findsOneWidget);
      expect(db.line('l1').state, 'served');
      expect(find.byKey(const Key('delivered-count-l1')), findsNothing);
      expect(find.byKey(const Key('deliver-part-l1')), findsNothing);
    });

    testWidgets('someone else changed the line meanwhile: the refusal is said, and the line is read again (the new count shows)', (tester) async {
      await open(tester);
      await tapKey(tester, 'deliver-part-l1');
      db.line('l1').delivered = 3;
      db.line('l1').state = 'picked_up';
      await tapKey(tester, 'deliver-confirm');
      expect(find.text('Someone else has just changed this item, look at it again.'), findsOneWidget);
      expect(db.line('l1').delivered, 3, reason: 'nothing was added');
      expect(find.text('3 of 5 delivered'), findsOneWidget);
    });

    testWidgets('an item to be paid at the club cannot be handed over while the table owes: the button is off and says why', (tester) async {
      db.line('l1').pay = 'due_at_venue';
      db.bookings['b1']!.paid = 4000;
      await open(tester);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('deliver-part-l1'))).onPressed, isNull);
      expect(find.textContaining('Take payment first'), findsOneWidget);
    });

    testWidgets('while the hand-over is on its way the buttons wait', (tester) async {
      await open(tester);
      await tapKey(tester, 'deliver-part-l1');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.tap(find.byKey(const Key('deliver-confirm')));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('deliver-part-l1'))).onPressed, isNull);
      db.hold = null;
      gate.complete();
      await tester.pumpAndSettle();
      expect(db.count('desk_deliver_part'), 1);
    });

    testWidgets('a dropped connection says so and the line is unchanged', (tester) async {
      await open(tester);
      await tapKey(tester, 'deliver-part-l1');
      db.failOn['desk_deliver_part'] = Exception('connection reset');
      await tapKey(tester, 'deliver-confirm');
      expect(find.text('The delivery could not be recorded. Check your connection and try again.'), findsOneWidget);
      expect(find.textContaining('connection reset'), findsNothing);
      expect(db.line('l1').delivered, 0);
    });

    testWidgets('the ordinary Delivered button still marks the whole line delivered', (tester) async {
      db.line('l1').state = 'picked_up';
      await open(tester);
      await tapKey(tester, 'move-l1');
      expect(db.line('l1').state, 'served');
    });
  });
}
