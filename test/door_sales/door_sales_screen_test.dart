import 'dart:async';

import 'package:bottles_up_vendor/features/door/providers/door_providers.dart';
import 'package:bottles_up_vendor/features/door_sales/logic/door_sales_rules.dart';
import 'package:bottles_up_vendor/features/door_sales/providers/door_sales_providers.dart';
import 'package:bottles_up_vendor/features/door_sales/screens/door_sales_screen.dart';
import 'package:bottles_up_vendor/features/door_sales/services/door_sales_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../door/fake_door_backend.dart';
import 'fake_door_sales_backend.dart';

late FakeDoorBackend door;
late FakeDoorSalesBackend db;
int keys = 0;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        doorServiceProvider.overrideWithValue(door.service),
        doorSalesServiceProvider.overrideWithValue(db.service),
        saleKeyMakerProvider.overrideWithValue(() => 'sale-key-${++keys}'),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: const Scaffold(body: DoorSalesScreen(membershipId: 'm1'))),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

/// Fills a good cash sale of [qty] General tickets, without pressing anything.
Future<void> fill(WidgetTester tester, {int qty = 1, String name = 'Dana Door', String method = 'cash', String tier = 't-gen'}) async {
  await tapKey(tester, 'sale-tier-$tier');
  for (var i = 1; i < qty; i++) {
    await tapKey(tester, 'sale-qty-plus');
  }
  await type(tester, 'sale-name', name);
  await tapKey(tester, 'sale-method-$method');
}

Future<void> review(WidgetTester tester) async {
  await tapKey(tester, 'sale-submit');
}

Future<void> confirm(WidgetTester tester) async {
  await tapKey(tester, 'sale-confirm');
}

String textOf(WidgetTester tester, String key) {
  final w = tester.widget(find.byKey(Key(key)));
  return w is SelectableText ? w.data! : (w as Text).data!;
}

void main() {
  setUp(() {
    keys = 0;
    door = FakeDoorBackend();
    door.handlers['door_events'] = (_) => [eventRow()];
    db = FakeDoorSalesBackend();
  });

  group('the form', () {
    testWidgets('shows the event, and the ticket types with price and what is left; a sold out one cannot be chosen', (tester) async {
      await open(tester);
      expect(find.text('Friday Night'), findsOneWidget);
      expect(db.callsOf('door_sale_options').single, {'p_event': 'e1'});
      expect(textOf(tester, 'sale-price-t-gen'), '\$50.00');
      expect(textOf(tester, 'sale-left-t-gen'), '8 left');
      expect(textOf(tester, 'sale-price-t-vip'), '\$120.00');
      expect(textOf(tester, 'sale-left-t-vip'), '3 left');
      expect(textOf(tester, 'sale-left-t-full'), 'Sold out');
      await tapKey(tester, 'sale-tier-t-full');
      expect(find.byKey(const Key('sale-selected')), findsNothing, reason: 'a sold out type cannot be chosen');
      await tapKey(tester, 'sale-tier-t-gen');
      expect(find.byKey(const Key('sale-selected')), findsOneWidget);
    });

    testWidgets('says plainly that an email is optional and that nothing is emailed, and that discounts are not part of it yet', (tester) async {
      await open(tester);
      expect(find.text('Guest name (required)'), findsOneWidget);
      expect(find.text('Email (optional)'), findsOneWidget);
      expect(find.text('Phone (optional)'), findsOneWidget);
      expect(textOf(tester, 'sale-contact-note'), contains('No ticket is emailed or texted'));
      expect(find.byKey(const Key('sale-no-discounts')), findsOneWidget);
    });

    testWidgets('the number of tickets stops at what is left and at one', (tester) async {
      await open(tester);
      await tapKey(tester, 'sale-tier-t-vip');
      expect(textOf(tester, 'sale-qty'), '1');
      expect(tester.widget<IconButton>(find.byKey(const Key('sale-qty-minus'))).onPressed, isNull);
      await tapKey(tester, 'sale-qty-plus');
      await tapKey(tester, 'sale-qty-plus');
      expect(textOf(tester, 'sale-qty'), '3');
      expect(tester.widget<IconButton>(find.byKey(const Key('sale-qty-plus'))).onPressed, isNull, reason: 'only 3 VIP are left');
      await tapKey(tester, 'sale-tier-t-gen');
      await tapKey(tester, 'sale-qty-plus');
      expect(textOf(tester, 'sale-qty'), '4');
      await tapKey(tester, 'sale-tier-t-vip');
      expect(textOf(tester, 'sale-qty'), '3', reason: 'changing to a type with fewer left keeps the number inside it');
    });

    testWidgets('the card machine asks for its receipt number; cash does not', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('sale-reference')), findsNothing);
      await tapKey(tester, 'sale-method-external_terminal');
      expect(find.byKey(const Key('sale-reference')), findsOneWidget);
      expect(find.text('Card machine receipt number (required)'), findsOneWidget);
      expect(textOf(tester, 'sale-method-hint'), contains('receipt number is recorded'));
      await tapKey(tester, 'sale-method-cash');
      expect(find.byKey(const Key('sale-reference')), findsNothing);
    });

    testWidgets('a summary line follows the choices', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('sale-summary')), findsNothing);
      await fill(tester, qty: 2);
      expect(textOf(tester, 'sale-summary'), '2 × General · \$100.00 · Cash');
    });
  });

  group('refusing before the call', () {
    testWidgets('nothing chosen: the first thing missing is said, and nothing is sent', (tester) async {
      await open(tester);
      await review(tester);
      expect(textOf(tester, 'sale-problem'), 'Choose a ticket type.');
      expect(db.callsOf('door_sell_ticket'), isEmpty);
      expect(find.byKey(const Key('sale-confirm-dialog')), findsNothing);
    });

    testWidgets('then the name, a bad email, the way it was paid, and the receipt number', (tester) async {
      await open(tester);
      await tapKey(tester, 'sale-tier-t-gen');
      await review(tester);
      expect(textOf(tester, 'sale-problem'), 'Enter the guest\'s name (at least 2 letters).');
      await type(tester, 'sale-name', 'Dana');
      await type(tester, 'sale-email', 'dana@');
      await review(tester);
      expect(textOf(tester, 'sale-problem'), 'That email address does not look right. Fix it, or leave it empty.');
      await type(tester, 'sale-email', '');
      await review(tester);
      expect(textOf(tester, 'sale-problem'), 'Choose how the guest paid: cash, or the card machine.');
      await tapKey(tester, 'sale-method-external_terminal');
      await review(tester);
      expect(textOf(tester, 'sale-problem'), 'Enter the card machine\'s receipt number.');
      expect(db.callsOf('door_sell_ticket'), isEmpty);
      await type(tester, 'sale-reference', 'TERM-8841');
      await review(tester);
      expect(find.byKey(const Key('sale-problem')), findsNothing);
      expect(find.byKey(const Key('sale-confirm-dialog')), findsOneWidget);
    });
  });

  group('selling', () {
    testWidgets('a cash sale: the person confirms, the ticket is issued, and the sale carries exactly what was entered', (tester) async {
      await open(tester);
      await fill(tester, qty: 2);
      await type(tester, 'sale-email', ' dana@example.com ');
      await type(tester, 'sale-phone', '+1 555 0100');
      await review(tester);
      expect(textOf(tester, 'sale-confirm-line'), '2 × General · \$100.00 · Cash');
      expect(textOf(tester, 'sale-confirm-guest'), 'For Dana Door');
      expect(find.byKey(const Key('sale-confirm-reference')), findsNothing);
      expect(find.textContaining('Only confirm once the money is in your hand'), findsOneWidget);
      expect(db.callsOf('door_sell_ticket'), isEmpty, reason: 'nothing is sold before the person confirms');
      await confirm(tester);
      expect(db.callsOf('door_sell_ticket').single, {
        'p_event': 'e1',
        'p_tier': 't-gen',
        'p_quantity': 2,
        'p_method': 'cash',
        'p_name': 'Dana Door',
        'p_email': 'dana@example.com',
        'p_phone': '+1 555 0100',
        'p_reference': null,
        'p_client_key': 'sale-key-1',
      });
      expect(textOf(tester, 'sale-done-title'), 'Ticket issued');
      expect(textOf(tester, 'sale-done-code'), 'BU-FAKE0001');
      expect(textOf(tester, 'sale-done-line'), '2 × General · \$100.00 · Cash');
      expect(textOf(tester, 'sale-done-note'), '2 guests are checked in. The ticket cannot be scanned again. No ticket was emailed or texted.');
      expect(textOf(tester, 'sale-done-left'), '6 tickets of this type are left.');
      expect(find.byKey(const Key('sale-submit')), findsNothing, reason: 'the form is replaced by the result');
    });

    testWidgets('a card machine sale sends the receipt number, and shows it in the confirmation', (tester) async {
      await open(tester);
      await fill(tester, tier: 't-vip', method: 'external_terminal');
      await type(tester, 'sale-reference', ' TERM-8841 ');
      await review(tester);
      expect(textOf(tester, 'sale-confirm-line'), '1 × VIP · \$120.00 · Card machine');
      expect(textOf(tester, 'sale-confirm-reference'), 'Receipt number TERM-8841');
      await confirm(tester);
      final p = db.callsOf('door_sell_ticket').single;
      expect([p['p_method'], p['p_reference'], p['p_email'], p['p_phone']], ['external_terminal', 'TERM-8841', null, null]);
      expect(textOf(tester, 'sale-done-line'), '1 × VIP · \$120.00 · Card machine');
      expect(textOf(tester, 'sale-done-note'), startsWith('1 guest is checked in.'));
      expect(textOf(tester, 'sale-done-left'), '2 tickets of this type are left.');
    });

    testWidgets('a reference typed for the card machine is not sent with a cash sale', (tester) async {
      await open(tester);
      await fill(tester, method: 'external_terminal');
      await type(tester, 'sale-reference', 'TERM-1');
      await tapKey(tester, 'sale-method-cash');
      await review(tester);
      await confirm(tester);
      expect(db.callsOf('door_sell_ticket').single['p_reference'], isNull);
      expect(db.callsOf('door_sell_ticket').single['p_method'], 'cash');
    });

    testWidgets('"Not yet" in the confirmation sells nothing and keeps the form as it was', (tester) async {
      await open(tester);
      await fill(tester, qty: 2);
      await review(tester);
      await tapKey(tester, 'sale-confirm-cancel');
      expect(find.byKey(const Key('sale-confirm-dialog')), findsNothing);
      expect(db.callsOf('door_sell_ticket'), isEmpty);
      expect(textOf(tester, 'sale-qty'), '2');
      expect(tester.widget<TextField>(find.byKey(const Key('sale-name'))).controller!.text, 'Dana Door');
    });

    testWidgets('the number of guests in at the door is read again after a sale', (tester) async {
      await open(tester);
      final before = door.count('door_events');
      await fill(tester);
      await review(tester);
      await confirm(tester);
      expect(door.count('door_events'), before + 1);
    });

    testWidgets('free entry is a sale of nothing and says so', (tester) async {
      db.tiers = [FakeDoorSalesBackend.tier('t-free', 'Free Entry', 0, 5, 0)];
      await open(tester);
      await fill(tester, tier: 't-free', qty: 3);
      expect(textOf(tester, 'sale-summary'), '3 × Free Entry · Free · Cash');
      await review(tester);
      await confirm(tester);
      expect(textOf(tester, 'sale-done-line'), '3 × Free Entry · Free · Cash');
      expect(db.sales.values.single['amount_cents'], 0);
    });

    testWidgets('"Sell another" gives a clean form, keeping the ticket type and how they paid, and the tickets left are read again', (tester) async {
      await open(tester);
      await fill(tester, qty: 2, method: 'external_terminal');
      await type(tester, 'sale-reference', 'TERM-1');
      await review(tester);
      await confirm(tester);
      await tapKey(tester, 'sale-another');
      expect(find.byKey(const Key('sale-done')), findsNothing);
      expect(textOf(tester, 'sale-qty'), '1');
      expect(textOf(tester, 'sale-left-t-gen'), '6 left');
      expect(tester.widget<TextField>(find.byKey(const Key('sale-name'))).controller!.text, '');
      expect(tester.widget<TextField>(find.byKey(const Key('sale-reference'))).controller!.text, '');
      expect(find.byKey(const Key('sale-selected')), findsOneWidget, reason: 'the type is still chosen');
      expect(tester.widget<SegmentedButton<DoorPayMethod>>(find.byKey(const Key('sale-method'))).selected, {DoorPayMethod.terminal});
      // and the next sale gets its own key
      await type(tester, 'sale-name', 'Eli Entry');
      await type(tester, 'sale-reference', 'TERM-2');
      await review(tester);
      await confirm(tester);
      expect([for (final p in db.callsOf('door_sell_ticket')) p['p_client_key']], ['sale-key-1', 'sale-key-2']);
      expect(db.orderCount, 2);
    });
  });

  group('never selling twice', () {
    testWidgets('while a sale is going through, nothing on the form can be pressed or changed', (tester) async {
      final gate = Completer<void>();
      var held = 0;
      // the sale is held at the database until the test lets it go
      Future<dynamic> hold(String fn, {Map<String, dynamic>? params}) async {
        if (fn == 'door_sell_ticket') {
          held++;
          await gate.future;
        }
        return db.call(fn, params: params);
      }

      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          doorServiceProvider.overrideWithValue(door.service),
          doorSalesServiceProvider.overrideWithValue(DoorSalesService(caller: hold)),
          saleKeyMakerProvider.overrideWithValue(() => 'sale-key-${++keys}'),
        ],
        child: MaterialApp(theme: ThemeData.dark(), home: const Scaffold(body: DoorSalesScreen(membershipId: 'm1'))),
      ));
      await tester.pumpAndSettle();
      await fill(tester);
      await review(tester);
      await tester.tap(find.byKey(const Key('sale-confirm')));
      await tester.pump();
      await tester.pump();
      expect(held, 1);
      expect(tester.widget<FilledButton>(find.byKey(const Key('sale-submit'))).onPressed, isNull);
      expect(find.text('Issuing...'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('sale-name'))).enabled, isFalse);
      expect(tester.widget<IconButton>(find.byKey(const Key('sale-qty-plus'))).onPressed, isNull);
      expect(tester.widget<SegmentedButton<DoorPayMethod>>(find.byKey(const Key('sale-method'))).onSelectionChanged, isNull);
      // a second tap on the disabled button changes nothing
      await tester.tap(find.byKey(const Key('sale-submit')), warnIfMissed: false);
      await tester.pump();
      expect(held, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(db.orderCount, 1);
      expect(find.byKey(const Key('sale-done')), findsOneWidget);
    });

    testWidgets('an answer lost on the way: trying again returns the sale already made, not a second one', (tester) async {
      db.loseNextAnswer = true;
      await open(tester);
      await fill(tester);
      await review(tester);
      await confirm(tester);
      expect(textOf(tester, 'sale-problem'), contains('will not be made twice'));
      expect(db.orderCount, 1, reason: 'the database did record it');
      expect(find.byKey(const Key('sale-done')), findsNothing);
      await review(tester);
      await confirm(tester);
      expect(db.orderCount, 1, reason: 'still one sale');
      expect(db.soldOf('t-gen'), 3);
      expect([for (final p in db.callsOf('door_sell_ticket')) p['p_client_key']], ['sale-key-1', 'sale-key-1'], reason: 'the same key was sent again');
      expect(textOf(tester, 'sale-done-title'), 'This sale was already made');
      expect(textOf(tester, 'sale-done-code'), 'BU-FAKE0001');
      expect(textOf(tester, 'sale-done-note'), contains('Nothing new was recorded'));
      expect(find.byKey(const Key('sale-done-left')), findsNothing);
    });

    testWidgets('changing the sale after a failure is a different sale and gets its own key', (tester) async {
      db.failSell = Exception('socket closed');
      await open(tester);
      await fill(tester);
      await review(tester);
      await confirm(tester);
      expect(textOf(tester, 'sale-problem'), contains('will not be made twice'));
      db.failSell = null;
      await tapKey(tester, 'sale-qty-plus');
      await review(tester);
      await confirm(tester);
      expect([for (final p in db.callsOf('door_sell_ticket')) p['p_client_key']], ['sale-key-1', 'sale-key-2']);
      expect(db.sales.values.single['quantity'], 2);
    });

    testWidgets('changing the event drops the half-made sale', (tester) async {
      door.handlers['door_events'] = (_) => [eventRow(), eventRow(id: 'e2', title: 'Saturday Night')];
      await open(tester);
      await fill(tester);
      await tapKey(tester, 'event-picker');
      await tester.tap(find.text('Saturday Night').last);
      await tester.pumpAndSettle();
      expect(db.callsOf('door_sale_options').last, {'p_event': 'e2'});
      expect(find.byKey(const Key('sale-selected')), findsNothing);
    });
  });

  group('when the database says no', () {
    testWidgets('the last tickets went to another door: its sentence is shown, and what is left is read again', (tester) async {
      await open(tester);
      await fill(tester, qty: 3, tier: 't-vip');
      db.tiers.firstWhere((t) => t['id'] == 't-vip')['sold_count'] = 2; // another door sold two while this one filled the form
      final before = db.callsOf('door_sale_options').length;
      await review(tester);
      await confirm(tester);
      expect(textOf(tester, 'sale-problem'), 'Only 1 of these tickets are left.');
      expect(find.byKey(const Key('sale-done')), findsNothing);
      expect(db.callsOf('door_sale_options').length, before + 1);
      expect(textOf(tester, 'sale-left-t-vip'), '1 left');
      expect(db.orderCount, 0);
      expect(tester.widget<FilledButton>(find.byKey(const Key('sale-submit'))).onPressed, isNotNull, reason: 'the person can fix it and try again');
    });

    testWidgets('access ended while filling the form is said as such', (tester) async {
      await open(tester);
      await fill(tester);
      db.role = 'none';
      await review(tester);
      await confirm(tester);
      expect(textOf(tester, 'sale-problem'), 'You don\'t have access to do that.');
    });

    testWidgets('selling not open for the event says when it is', (tester) async {
      db.windowOpen = false;
      await open(tester);
      expect(textOf(tester, 'sale-closed'), salesClosedMessage);
      expect(find.byKey(const Key('sale-submit')), findsNothing);
    });

    testWidgets('an event with nothing to sell at the door says so', (tester) async {
      db.tiers = [FakeDoorSalesBackend.tier('t-gated', 'Invited Only', 8000, 5, 0, gated: true)];
      await open(tester);
      expect(textOf(tester, 'sale-none'), 'This event has no ticket types you can sell at the door.');
      expect(find.byKey(const Key('sale-submit')), findsNothing);
    });

    testWidgets('the ticket types failing to load can be tried again', (tester) async {
      db.failAll = Exception('socket closed');
      await open(tester);
      expect(textOf(tester, 'sale-load-error'), contains('could not be loaded'));
      db.failAll = null;
      await tapKey(tester, 'sale-retry');
      expect(find.byKey(const Key('sale-tier-t-gen')), findsOneWidget);
    });

    testWidgets('a server that does not have door sales yet says so, with nothing to retry', (tester) async {
      db.failAll = PostgrestException(message: 'function public.door_sale_options does not exist', code: '42883');
      await open(tester);
      expect(textOf(tester, 'sale-load-error'), contains('not set up'));
      expect(find.byKey(const Key('sale-retry')), findsNothing);
    });

    testWidgets('no event to sell for says so', (tester) async {
      door.handlers['door_events'] = (_) => <Map<String, dynamic>>[];
      await open(tester);
      expect(find.text('No event to sell tickets for right now.'), findsOneWidget);
      expect(db.calls, isEmpty);
    });
  });
}

