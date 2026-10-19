import 'dart:async';

import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/add_bottles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_backend.dart';

late FakeTableBackend db;
AddedBottles? result;
bool popped = false;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [tableServiceServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () async {
                  result = await Navigator.of(context).push<AddedBottles>(MaterialPageRoute(builder: (_) => const AddBottlesScreen(bookingId: 'b1', tableLabel: 'VIP booth · Ada')));
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String qty(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('bottle-qty-$id'))).data!;
String summary(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('basket-summary'))).data!;
FilledButton confirm(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('add-confirm')));

void main() {
  setUp(() {
    result = null;
    popped = false;
    db = FakeTableBackend()..role = 'manager';
    db.now = DateTime(2026, 10, 9, 21);
    db.addBooking('b1', total: 10000, paid: 10000);
    db.menu.addAll([
      FakeBottle('p', 'Patron', 25000, category: 'Tequila', stock: 3),
      FakeBottle('g', 'Grey Goose', 18000),
      FakeBottle('hidden', 'Hidden Gin', 7000, available: false),
    ]);
  });

  testWidgets('shows the club\'s menu with price, category and how many are left, and says bottles are paid for at the club', (tester) async {
    await open(tester);
    expect(find.text('VIP booth · Ada'), findsOneWidget);
    expect(find.text('Patron 750ml'), findsOneWidget);
    expect(find.text('Tequila · \$250.00 · 3 left'), findsOneWidget);
    expect(find.text('Spirits · \$180.00'), findsOneWidget, reason: 'a bottle the club does not count shows no number');
    expect(find.text('Hidden Gin 750ml'), findsNothing);
    expect(find.textContaining('paid for at the club'), findsOneWidget);
    expect(summary(tester), 'Nothing chosen yet');
    expect(confirm(tester).onPressed, isNull, reason: 'nothing to add yet');
    expect(db.params.single, {'p_booking': 'b1'});
  });

  testWidgets('choosing bottles updates the count and the price before tax, and Add is on', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-p');
    await tapKey(tester, 'bottle-more-p');
    await tapKey(tester, 'bottle-more-g');
    expect(qty(tester, 'p'), '2');
    expect(qty(tester, 'g'), '1');
    expect(summary(tester), '3 bottles · \$680.00 before tax');
    expect(confirm(tester).onPressed, isNotNull);
    await tapKey(tester, 'bottle-less-g');
    expect(summary(tester), '2 bottles · \$500.00 before tax');
    await tapKey(tester, 'bottle-less-p');
    await tapKey(tester, 'bottle-less-p');
    expect(summary(tester), 'Nothing chosen yet');
  });

  testWidgets('a bottle cannot be taken below zero or above what is left', (tester) async {
    await open(tester);
    expect(tester.widget<IconButton>(find.byKey(const Key('bottle-less-p'))).onPressed, isNull);
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, 'bottle-more-p');
    }
    expect(qty(tester, 'p'), '3');
    expect(tester.widget<IconButton>(find.byKey(const Key('bottle-more-p'))).onPressed, isNull, reason: 'only 3 are left');
  });

  testWidgets('adding sends the chosen bottles once, closes the screen and tells the table page how many and what they cost', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-p');
    await tapKey(tester, 'bottle-more-g');
    await tapKey(tester, 'bottle-more-g');
    await tapKey(tester, 'add-confirm');
    expect(db.invocations.length, 1);
    expect(db.invocations.single.$2['bottles'], [
      {'bottle_id': 'p', 'quantity': 1},
      {'bottle_id': 'g', 'quantity': 2},
    ]);
    expect(popped, isTrue);
    expect((result!.count, result!.subtotalCents), (3, 25000 + 36000));
    expect(db.lines.length, 2);
    expect(db.bookings['b1']!.total, 10000 + 61000);
  });

  testWidgets('while the call is on its way the button waits and a second tap changes nothing', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-g');
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.tap(find.byKey(const Key('add-confirm')));
    await tester.pump();
    expect(confirm(tester).onPressed, isNull);
    expect(find.text('Adding...'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('bottle-more-g'))).onPressed, isNull, reason: 'the basket cannot change meanwhile');
    expect(tester.widget<IconButton>(find.byKey(const Key('bottle-less-g'))).onPressed, isNull, reason: '...either way');
    await tester.tap(find.byKey(const Key('add-confirm')), warnIfMissed: false);
    await tester.pump();
    db.hold = null;
    gate.complete();
    await tester.pumpAndSettle();
    expect(db.invocations.length, 1);
    expect(db.lines.length, 1);
  });

  testWidgets('two taps in the same instant, before any redraw, still add once', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-g');
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.tap(find.byKey(const Key('add-confirm')));
    await tester.tap(find.byKey(const Key('add-confirm')));
    db.hold = null;
    gate.complete();
    await tester.pumpAndSettle();
    expect(db.invocations.length, 1);
  });

  testWidgets('stock taken meanwhile: the screen says so, keeps the basket, reads the menu again and cuts what is short', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-p');
    await tapKey(tester, 'bottle-more-p');
    await tapKey(tester, 'bottle-more-g');
    db.addLine('b1', 'Patron', bottleId: 'p', qty: 2, pay: 'paid');
    await tapKey(tester, 'add-confirm');
    expect(find.text('Not enough "Patron" left in stock.'), findsOneWidget);
    expect(db.count('desk_bottle_menu'), 2, reason: 'the menu was read again');
    expect(find.text('Tequila · \$250.00 · 1 left'), findsOneWidget);
    expect(qty(tester, 'p'), '1', reason: 'cut to what is left');
    expect(qty(tester, 'g'), '1', reason: 'the rest of the basket is kept');
    expect(db.lines.length, 1, reason: 'nothing was added');
    expect(popped, isFalse);
    // A second try with what is left works.
    await tapKey(tester, 'add-confirm');
    expect(popped, isTrue);
    expect(result!.count, 2);
  });

  testWidgets('a bottle that went off the menu meanwhile is dropped from the basket', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-g');
    db.menu.firstWhere((m) => m.id == 'g').soldOut = true;
    await tapKey(tester, 'add-confirm');
    expect(find.text('One of the selected bottles is no longer available.'), findsOneWidget);
    expect(find.text('Grey Goose 750ml'), findsNothing);
    expect(summary(tester), 'Nothing chosen yet');
    expect(confirm(tester).onPressed, isNull);
  });

  testWidgets('a refusal that is not about stock keeps the basket and the button, and says why', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-g');
    db.bookings['b1']!.nightClosed = true;
    await tapKey(tester, 'add-confirm');
    expect(find.text('This night has been closed, so no bottles can be added.'), findsOneWidget);
    expect(qty(tester, 'g'), '1');
    expect(confirm(tester).onPressed, isNotNull);
    expect(db.count('desk_bottle_menu'), 1, reason: 'the menu is not read again for this');
    expect(find.byKey(const Key('check-orders')), findsNothing);
  });

  testWidgets('no answer at all: the screen says the bottles may be on the table, keeps the basket, and offers to look at the orders first', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-g');
    db.failInvoke = Exception('connection reset');
    await tapKey(tester, 'add-confirm');
    expect(find.textContaining('could not tell whether the bottles were added'), findsOneWidget);
    expect(find.textContaining('connection reset'), findsNothing);
    expect(qty(tester, 'g'), '1', reason: 'what was chosen is kept');
    expect(find.byKey(const Key('add-confirm')), findsNothing, reason: 'no blind second tap');
    expect(find.byKey(const Key('check-orders')), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('bottle-more-g'))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(const Key('bottle-less-g'))).onPressed, isNull, reason: 'the basket is frozen until they decide');
    // They are not there: try again.
    db.failInvoke = null;
    await tapKey(tester, 'try-anyway');
    expect(find.byKey(const Key('add-confirm')), findsOneWidget);
    await tapKey(tester, 'add-confirm');
    expect(popped, isTrue);
    expect(db.lines.length, 1);
  });

  testWidgets('"Look at the table\'s orders" closes the screen with nothing added, so the table page can be read again', (tester) async {
    await open(tester);
    await tapKey(tester, 'bottle-more-g');
    db.failInvoke = FunctionException(status: 500, details: {'error': 'Failed to add bottles'});
    await tapKey(tester, 'add-confirm');
    await tapKey(tester, 'check-orders');
    expect(popped, isTrue);
    expect(result, isNull);
  });

  testWidgets('a person who may not add bottles (or a closed table) sees the database\'s sentence instead of a menu', (tester) async {
    db.bookings['b1']!.reconciled = true;
    await open(tester);
    expect(find.byKey(const Key('menu-refused')), findsOneWidget);
    expect(find.text('This table has already been closed out.'), findsOneWidget);
    expect(find.byKey(const Key('menu-list')), findsNothing);
  });

  testWidgets('a person whose access ended is told so, with no Try again', (tester) async {
    db.role = 'verifier';
    await open(tester);
    expect(find.text('Your access has ended, or you are signed out.'), findsOneWidget);
    expect(find.byKey(const Key('menu-retry')), findsNothing);
  });

  testWidgets('a dropped connection on the menu says so with Try again, and Try again works', (tester) async {
    db.failOn['desk_bottle_menu'] = Exception('boom');
    await open(tester);
    expect(find.text('Bottles could not be loaded. Check your connection and try again.'), findsOneWidget);
    expect(find.text('boom'), findsNothing);
    db.failOn.remove('desk_bottle_menu');
    await tapKey(tester, 'menu-retry');
    expect(find.byKey(const Key('menu-list')), findsOneWidget);
  });

  testWidgets('a server without the migration says the menu is not set up, with no Try again', (tester) async {
    db.failOn['desk_bottle_menu'] = PostgrestException(message: 'function does not exist', code: '42883');
    await open(tester);
    expect(find.text('Bottles are not set up on this server yet.'), findsOneWidget);
    expect(find.byKey(const Key('menu-retry')), findsNothing);
  });

  testWidgets('a club with nothing on sale says so', (tester) async {
    db.menu.clear();
    await open(tester);
    expect(find.byKey(const Key('menu-empty')), findsOneWidget);
  });
}
