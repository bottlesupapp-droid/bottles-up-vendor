import 'dart:async';

import 'package:bottles_up_vendor/features/discounts/providers/discount_providers.dart';
import 'package:bottles_up_vendor/features/discounts/widgets/booking_discounts_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_discount_backend.dart';

late FakeDiscountBackend db;
int changed = 0;

const set10 = {'server_max_percent': 10, 'manager_max_percent': 25, 'server_free_bottles_per_night': 2, 'manager_free_bottles_per_night': 4, 'allow_stacking': false};

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [discountServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: SingleChildScrollView(child: BookingDiscountsCard(bookingId: 'b1', onChanged: () => changed++)))),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() {
    db = FakeDiscountBackend()..role = 'server';
    db.limits = Map.of(set10);
    db.addBooking('b1');
    changed = 0;
  });

  group('what the card says', () {
    testWidgets('a server sees what they may give tonight', (tester) async {
      await open(tester);
      expect(find.text('Discounts and free bottles'), findsOneWidget);
      expect(textOf(tester, 'discounts-limits'), 'You may give a discount up to 10% on your own, and 2 free bottles tonight (2 left). Anything more waits for a manager.');
      expect(find.byKey(const Key('give-discount')), findsOneWidget);
      expect(find.byKey(const Key('give-free-bottle')), findsOneWidget);
    });

    testWidgets('until the owner sets limits, staff cannot give their own and are told why', (tester) async {
      db.limits = null;
      await open(tester);
      expect(textOf(tester, 'discounts-limits'), 'The owner has not set discount limits for this club yet, so nothing can be given.');
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('give-discount'))).onPressed, isNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('give-free-bottle'))).onPressed, isNull);
    });

    testWidgets('the owner needs no limits', (tester) async {
      db.role = 'owner';
      db.limits = null;
      await open(tester);
      expect(textOf(tester, 'discounts-limits'), 'You are the owner: you can give any discount or free bottle.');
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('give-discount'))).onPressed, isNotNull);
    });

    testWidgets('someone who may not give anything here sees no card at all', (tester) async {
      db.role = 'verifier';
      await open(tester);
      expect(find.byKey(const Key('discounts-card')), findsNothing);
      expect(find.byKey(const Key('discounts-hidden')), findsOneWidget);
    });

    testWidgets('a server who was not given the table sees no card', (tester) async {
      db.bookings['b1']!.assignedToMe = false;
      await open(tester);
      expect(find.byKey(const Key('discounts-card')), findsNothing);
    });

    testWidgets('a failed read says so, with Try again, and trying again works', (tester) async {
      db.beforeCall = (f) => throw Exception('boom');
      await open(tester);
      expect(find.byKey(const Key('discounts-card-error')), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      db.beforeCall = null;
      await tapKey(tester, 'discounts-card-retry');
      expect(find.byKey(const Key('discounts-limits')), findsOneWidget);
    });

    testWidgets('what was given is listed with its status, who asked and who approved, and the total discounted so far', (tester) async {
      db.addConcession('b1', status: 'applied', amount: 2000, percent: 10);
      db.bookings['b1']!.discount = 2000;
      await open(tester);
      expect(find.text('10% discount: \$20.00 off'), findsOneWidget);
      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Asked by Sam Server (server), within their own limit'), findsOneWidget);
      expect(textOf(tester, 'discounts-so-far'), 'Discounted so far: \$20.00');
    });

    testWidgets('a server cannot take anything back, a manager can', (tester) async {
      final c = db.addConcession('b1', status: 'applied');
      await open(tester);
      expect(find.byKey(Key('take-back-${c.id}')), findsNothing);
      db.role = 'manager';
      await open(tester);
      expect(find.byKey(Key('take-back-${c.id}')), findsOneWidget);
    });

    testWidgets('when the list of what was given cannot be read the buttons still work and the card says so', (tester) async {
      db.beforeCall = (f) {
        if (f == 'desk_booking_concessions') throw Exception('boom');
      };
      await open(tester);
      expect(find.byKey(const Key('discounts-list-error')), findsOneWidget);
      expect(find.byKey(const Key('give-discount')), findsOneWidget);
    });
  });

  group('giving a discount', () {
    testWidgets('within the limit: the sheet says it will be applied, it is sent, the card and the page are updated', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      expect(find.byKey(const Key('discount-sheet')), findsOneWidget);
      expect(textOf(tester, 'discount-base'), 'On the table\'s bottles: \$200.00. The table still owes \$300.00.');
      await enter(tester, 'discount-value', '10');
      expect(textOf(tester, 'discount-preview'), '\$20.00 off (10% of the bottles): applied at once.');
      await enter(tester, 'discount-reason', 'Regular guest');
      await tapKey(tester, 'discount-confirm');
      expect(db.paramsOf('desk_request_discount').single, {'p_booking': 'b1', 'p_kind': 'percent', 'p_value': 10, 'p_reason': 'Regular guest'});
      expect(find.text('Discount applied: \$20.00 off. The table now owes less.'), findsOneWidget);
      expect(changed, 1);
      expect(textOf(tester, 'discounts-so-far'), 'Discounted so far: \$20.00');
      expect(find.text('Applied'), findsOneWidget);
    });

    testWidgets('above the limit: the sheet says it will wait for a manager, and it waits', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      await enter(tester, 'discount-value', '15');
      expect(textOf(tester, 'discount-preview'), '\$30.00 off (15% of the bottles) is above your limit of 10%: it waits for a manager to approve.');
      await enter(tester, 'discount-reason', 'VIP');
      await tapKey(tester, 'discount-confirm');
      expect(find.text('Waiting for approval: \$30.00 off. A manager will decide.'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(find.byKey(const Key('discounts-so-far')), findsNothing, reason: 'nothing was taken off the table');
    });

    testWidgets('by amount', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      await tapKey(tester, 'discount-kind');
      await tester.tap(find.text('Amount'));
      await tester.pumpAndSettle();
      await enter(tester, 'discount-value', '\$12.50');
      await enter(tester, 'discount-reason', 'Regular guest');
      await tapKey(tester, 'discount-confirm');
      expect(db.paramsOf('desk_request_discount').single, {'p_booking': 'b1', 'p_kind': 'amount', 'p_value': 1250, 'p_reason': 'Regular guest'});
    });

    testWidgets('there is no preview until what was typed makes sense', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      expect(find.byKey(const Key('discount-preview')), findsNothing);
      await enter(tester, 'discount-value', 'abc');
      expect(find.byKey(const Key('discount-preview')), findsNothing);
      await enter(tester, 'discount-value', '101');
      expect(find.byKey(const Key('discount-preview')), findsNothing);
    });

    testWidgets('what is wrong is said before anything is sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      await tapKey(tester, 'discount-confirm');
      expect(find.text('A percent discount is between 1 and 100.'), findsOneWidget);
      expect(find.text('Give a reason of 3 to 300 characters.'), findsOneWidget);
      expect(db.paramsOf('desk_request_discount'), isEmpty);
    });

    testWidgets('a second discount on a table that has one is refused with the reason', (tester) async {
      db.addConcession('b1', status: 'applied', amount: 2000, percent: 10);
      await open(tester);
      await tapKey(tester, 'give-discount');
      await enter(tester, 'discount-value', '5');
      await enter(tester, 'discount-reason', 'Regular guest');
      await tapKey(tester, 'discount-confirm');
      expect(find.text('This table already has a discount: discounts do not combine at this club.'), findsOneWidget);
      expect(db.paramsOf('desk_request_discount'), isEmpty);
    });

    testWidgets('the database refusing is shown and everything typed stays', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      await enter(tester, 'discount-value', '10');
      await enter(tester, 'discount-reason', 'Regular guest');
      db.bookings['b1']!.reconciled = true;
      await tapKey(tester, 'discount-confirm');
      expect(find.text('This table has already been closed out.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('discount-value'))).controller!.text, '10');
      expect(tester.widget<TextField>(find.byKey(const Key('discount-reason'))).controller!.text, 'Regular guest');
      expect(changed, 0);
    });

    testWidgets('a connection failure keeps the sheet and says what to do', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      await enter(tester, 'discount-value', '10');
      await enter(tester, 'discount-reason', 'Regular guest');
      db.beforeCall = (f) {
        if (f == 'desk_request_discount') throw Exception('socket closed');
      };
      await tapKey(tester, 'discount-confirm');
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('socket'), findsNothing);
    });

    testWidgets('a second tap while the first is going gives it once', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      await enter(tester, 'discount-value', '10');
      await enter(tester, 'discount-reason', 'Regular guest');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.ensureVisible(find.byKey(const Key('discount-confirm')));
      await tester.tap(find.byKey(const Key('discount-confirm')));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('discount-confirm'))).onPressed, isNull);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_request_discount'), hasLength(1));
      expect(db.concessions, hasLength(1));
    });

    testWidgets('closing the sheet gives nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-discount');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('discount-sheet')), findsNothing);
      expect(db.concessions, isEmpty);
      expect(changed, 0);
    });
  });

  group('giving a free bottle', () {
    testWidgets('choose a bottle and how many: the sheet says it is within the allowance, and it is added at no charge', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      expect(find.byKey(const Key('free-bottle-sheet')), findsOneWidget);
      expect(find.text('\$250.00 · 6 left'), findsOneWidget);
      await tapKey(tester, 'free-bottle-bt1');
      expect(textOf(tester, 'free-preview'), 'Within your allowance tonight (2 left): applied at once.');
      await enter(tester, 'free-reason', 'Birthday');
      await tapKey(tester, 'free-confirm');
      expect(db.paramsOf('desk_request_free_bottle').single, {'p_booking': 'b1', 'p_bottle': 'bt1', 'p_quantity': 1, 'p_reason': 'Birthday'});
      expect(find.textContaining('1 × Patron 750ml added at no charge'), findsOneWidget);
      expect(changed, 1);
      expect(find.text('1 × Patron free'), findsOneWidget);
    });

    testWidgets('more than the allowance waits for a manager, and the sheet says so before it is sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      await tapKey(tester, 'free-bottle-bt1');
      await tapKey(tester, 'free-more');
      await tapKey(tester, 'free-more');
      expect(textOf(tester, 'free-quantity'), '3');
      expect(textOf(tester, 'free-preview'), 'More than your allowance tonight (2 left): it waits for a manager to approve.');
      await enter(tester, 'free-reason', 'Birthday');
      await tapKey(tester, 'free-confirm');
      expect(find.text('Waiting for approval: 3 × Patron 750ml. A manager will decide.'), findsOneWidget);
    });

    testWidgets('the number cannot go past what is left in stock', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      await tapKey(tester, 'free-bottle-bt3');
      expect(tester.widget<IconButton>(find.byKey(const Key('free-more'))).onPressed, isNull);
      await tapKey(tester, 'free-bottle-bt1');
      for (var i = 0; i < 10; i++) {
        await tapKey(tester, 'free-more');
      }
      expect(textOf(tester, 'free-quantity'), '6');
    });

    testWidgets('choosing a bottle with less in stock brings the number down to what is left', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      await tapKey(tester, 'free-bottle-bt1');
      await tapKey(tester, 'free-more');
      await tapKey(tester, 'free-more');
      await tapKey(tester, 'free-bottle-bt3');
      expect(textOf(tester, 'free-quantity'), '1');
    });

    testWidgets('a bottle must be chosen, with a reason, before anything is sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      await tapKey(tester, 'free-confirm');
      expect(find.text('Choose the bottle.'), findsOneWidget);
      expect(find.text('Give a reason of 3 to 300 characters.'), findsOneWidget);
      expect(db.paramsOf('desk_request_free_bottle'), isEmpty);
    });

    testWidgets('the owner has no allowance to watch', (tester) async {
      db.role = 'owner';
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      await tapKey(tester, 'free-bottle-bt2');
      expect(textOf(tester, 'free-preview'), 'Applied at once.');
    });

    testWidgets('a club with no bottles on sale says so', (tester) async {
      db.menu.clear();
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      expect(find.byKey(const Key('free-bottle-none')), findsOneWidget);
    });

    testWidgets('the menu failing to load says so with Try again', (tester) async {
      await open(tester);
      db.beforeCall = (f) {
        if (f == 'desk_bottle_menu') throw Exception('boom');
      };
      await tapKey(tester, 'give-free-bottle');
      expect(find.byKey(const Key('free-bottle-error')), findsOneWidget);
      db.beforeCall = null;
      await tapKey(tester, 'free-bottle-retry');
      expect(find.byKey(const Key('free-bottle-bt1')), findsOneWidget);
    });

    testWidgets('stock that ran out in the meantime: the refusal is shown, the menu is read again, the reason stays', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      await tapKey(tester, 'free-bottle-bt1');
      await tapKey(tester, 'free-more');
      await enter(tester, 'free-reason', 'Birthday');
      db.menu.first['left_count'] = 1;
      await tapKey(tester, 'free-confirm');
      expect(find.text('Only 1 of that bottle are left.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('free-reason'))).controller!.text, 'Birthday');
      expect(find.text('\$250.00 · 1 left'), findsOneWidget, reason: 'the menu was read again');
    });

    testWidgets('a second tap while the first is going gives it once', (tester) async {
      await open(tester);
      await tapKey(tester, 'give-free-bottle');
      await tapKey(tester, 'free-bottle-bt1');
      await enter(tester, 'free-reason', 'Birthday');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.ensureVisible(find.byKey(const Key('free-confirm')));
      await tester.tap(find.byKey(const Key('free-confirm')));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_request_free_bottle'), hasLength(1));
    });
  });

  group('taking something back', () {
    testWidgets('a manager takes a discount back with a reason, and the table owes the amount again', (tester) async {
      db.role = 'manager';
      final c = db.addConcession('b1', status: 'applied', amount: 2000, percent: 10);
      db.bookings['b1']!.discount = 2000;
      db.bookings['b1']!.total = 28000;
      await open(tester);
      await tapKey(tester, 'take-back-${c.id}');
      expect(find.text('Take back 10% discount: \$20.00 off?'), findsOneWidget);
      await enter(tester, 'take-back-note', ' Given by mistake ');
      await tapKey(tester, 'take-back-confirm');
      expect(db.paramsOf('desk_void_concession').single, {'p_id': c.id, 'p_note': 'Given by mistake'});
      expect(find.text('Taken back: 10% discount: \$20.00 off.'), findsOneWidget);
      expect(changed, 1);
      expect(find.text('Taken back'), findsOneWidget);
    });

    testWidgets('a reason is needed', (tester) async {
      db.role = 'manager';
      final c = db.addConcession('b1', status: 'applied');
      await open(tester);
      await tapKey(tester, 'take-back-${c.id}');
      await tapKey(tester, 'take-back-confirm');
      expect(find.text('Say why it is taken back.'), findsOneWidget);
      expect(db.paramsOf('desk_void_concession'), isEmpty);
    });

    testWidgets('a bottle that has been served cannot be taken back, and the dialog says so', (tester) async {
      db.role = 'manager';
      final c = db.addConcession('b1', kind: 'free_bottle', status: 'applied');
      db.served.add(c.id);
      await open(tester);
      await tapKey(tester, 'take-back-${c.id}');
      await enter(tester, 'take-back-note', 'Mistake');
      await tapKey(tester, 'take-back-confirm');
      expect(find.text('That bottle has already been served, so it cannot be taken back.'), findsOneWidget);
      expect(changed, 0);
    });

    testWidgets('Keep it changes nothing', (tester) async {
      db.role = 'manager';
      final c = db.addConcession('b1', status: 'applied');
      await open(tester);
      await tapKey(tester, 'take-back-${c.id}');
      await tapKey(tester, 'take-back-keep');
      expect(db.paramsOf('desk_void_concession'), isEmpty);
      expect(find.byKey(const Key('take-back-note')), findsNothing);
    });
  });
}
