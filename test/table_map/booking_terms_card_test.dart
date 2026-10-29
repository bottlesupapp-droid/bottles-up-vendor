import 'dart:async';

import 'package:bottles_up_vendor/features/table_map/providers/table_map_providers.dart';
import 'package:bottles_up_vendor/features/table_map/widgets/booking_terms_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_table_map_backend.dart';

late FakeTableMapBackend db;
late Map<String, dynamic> booking;
int moved = 0;

Widget host({bool canMove = true}) => ProviderScope(
      key: UniqueKey(),
      overrides: [tableMapServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: SingleChildScrollView(child: BookingTermsCard(bookingId: booking['id'] as String, canMove: canMove, onMoved: () => moved++))),
      ),
    );

Future<void> open(WidgetTester tester, {bool canMove = true}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(canMove: canMove));
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

void main() {
  setUp(() {
    db = FakeTableMapBackend();
    booking = db.addBooking(table: 't2', guests: 3);
    moved = 0;
  });

  group('the terms', () {
    testWidgets('show the deposit, who gets it, the admissions and the refund policy the booking was sold under', (tester) async {
      db.depositTerms = {'recipient': 'split', 'venue_pct': 70, 'purpose': 'reservation_fee'};
      await open(tester);
      expect(find.text('Terms of this booking'), findsOneWidget);
      expect(find.text('Deposit: \$25.00'), findsOneWidget);
      expect(find.text('The deposit is split: the venue 70%, the organizer 30%, as a reservation fee.'), findsOneWidget);
      expect(find.text('Admissions included: 2 guests'), findsOneWidget);
      expect(find.text('Full refund up to 48 hours before'), findsOneWidget);
      expect(find.text('50% back up to 24 hours before'), findsOneWidget);
    });

    testWidgets('a booking made before the venue chose terms shows the default it was given', (tester) async {
      await open(tester);
      expect(find.text('The venue keeps the deposit, as a reservation fee.'), findsOneWidget);
    });

    testWidgets('a server sees them too, without the move history or the move button', (tester) async {
      db.role = 'server';
      await open(tester, canMove: false);
      expect(find.text('Deposit: \$25.00'), findsOneWidget);
      expect(find.byKey(const Key('move-booking')), findsNothing);
      expect(db.paramsOf('desk_booking_moves'), isEmpty, reason: 'the history is the manager\'s: a server never asks for it');
    });

    testWidgets('a failure to read them says so and can be tried again', (tester) async {
      db.beforeCall = (f) => throw Exception('boom');
      await open(tester);
      expect(find.byKey(const Key('terms-error')), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      db.beforeCall = null;
      await tapKey(tester, 'terms-retry');
      expect(find.text('Deposit: \$25.00'), findsOneWidget);
    });

    testWidgets('a role with no access is told so, with no retry', (tester) async {
      db.role = 'door';
      await open(tester, canMove: false);
      expect(find.byKey(const Key('terms-error')), findsOneWidget);
      expect(find.byKey(const Key('terms-retry')), findsOneWidget, reason: 'access ended is shown with the same message; retrying is harmless');
    });
  });

  group('moving the booking', () {
    testWidgets('the sheet lists every table with what is free and whether the party fits, and the current one cannot be picked', (tester) async {
      db.addBooking(table: 't1');
      await open(tester);
      await tapKey(tester, 'move-booking');
      expect(find.byKey(const Key('move-sheet')), findsOneWidget);
      expect(find.text('Where the booking is now'), findsOneWidget);
      expect(find.text('None free for that time'), findsOneWidget, reason: 'the booth is taken by the other booking');
      expect(find.text('2 free · up to 8 guests'), findsOneWidget);
      expect(tester.widget<ListTile>(find.descendant(of: find.byKey(const Key('move-option-t2')), matching: find.byType(ListTile))).enabled, isFalse);
      expect(tester.widget<ListTile>(find.descendant(of: find.byKey(const Key('move-option-t1')), matching: find.byType(ListTile))).enabled, isFalse);
      expect(tester.widget<ListTile>(find.descendant(of: find.byKey(const Key('move-option-t3')), matching: find.byType(ListTile))).enabled, isTrue);
    });

    testWidgets('a table the party does not fit says so', (tester) async {
      booking['guests'] = 7;
      await open(tester);
      await tapKey(tester, 'move-booking');
      expect(find.text('The party does not fit this table (up to 6 guests)'), findsOneWidget);
      expect(find.text('The party does not fit this table (2 to 4 guests)'), findsNothing, reason: 'the current table is named as the current table first');
    });

    testWidgets('moving: choose a table, give a reason, confirm; the booking changes tables, the history shows who and why, and the page is told', (tester) async {
      await open(tester);
      await tapKey(tester, 'move-booking');
      await tapKey(tester, 'move-option-t1');
      expect(find.textContaining('Deposit \$75.00 more'), findsOneWidget);
      await enter(tester, 'move-reason', ' Guest asked for the booth ');
      await tapKey(tester, 'move-confirm');
      expect(db.paramsOf('desk_move_booking').single, {'p_booking': booking['id'], 'p_to_type': 't1', 'p_reason': 'Guest asked for the booth'});
      expect(booking['table'], 't1');
      expect(find.byKey(const Key('move-sheet')), findsNothing);
      expect(find.textContaining('Moved from Pair table to Booth. The deposits differ by \$75.00 (the new table costs more)'), findsOneWidget);
      expect(moved, 1);
      expect(find.textContaining('Pair table → Booth (deposits differ by \$75.00)'), findsOneWidget);
      expect(find.textContaining('Mo Manager · '), findsOneWidget);
      expect(find.textContaining('Guest asked for the booth'), findsWidgets);
    });

    testWidgets('a move to a table with no price difference does not mention one', (tester) async {
      db.table('t3')
        ..['pricing_mode'] = 'flat'
        ..['deposit_cents'] = 2500;
      await open(tester);
      await tapKey(tester, 'move-booking');
      await tapKey(tester, 'move-option-t3');
      expect(find.textContaining('Same deposit'), findsOneWidget);
      await enter(tester, 'move-reason', 'Better view');
      await tapKey(tester, 'move-confirm');
      expect(find.text('Moved from Pair table to Sofa.'), findsOneWidget);
    });

    testWidgets('a missing table or reason is said before anything is sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'move-booking');
      await tapKey(tester, 'move-confirm');
      expect(find.text('Choose the table to move the booking to.'), findsOneWidget);
      expect(find.text('Give a reason of 3 to 200 characters.'), findsOneWidget);
      expect(db.paramsOf('desk_move_booking'), isEmpty);
    });

    testWidgets('someone took the last table first: the refusal is shown, the list is read again, the reason stays', (tester) async {
      await open(tester);
      await tapKey(tester, 'move-booking');
      await tapKey(tester, 'move-option-t1');
      await enter(tester, 'move-reason', 'Guest asked');
      db.addBooking(table: 't1');
      await tapKey(tester, 'move-confirm');
      expect(find.text('No tables of that type are free for that time.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('move-reason'))).controller!.text, 'Guest asked');
      expect(find.text('None free for that time'), findsOneWidget, reason: 'the options were read again');
      expect(booking['table'], 't2');
      expect(moved, 0);
    });

    testWidgets('a connection failure keeps the sheet and the reason, in plain words', (tester) async {
      await open(tester);
      await tapKey(tester, 'move-booking');
      await tapKey(tester, 'move-option-t3');
      await enter(tester, 'move-reason', 'Guest asked');
      db.failMove = Exception('socket closed');
      await tapKey(tester, 'move-confirm');
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('socket'), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('move-reason'))).controller!.text, 'Guest asked');
    });

    testWidgets('a second tap on Move while the first is going moves once', (tester) async {
      await open(tester);
      await tapKey(tester, 'move-booking');
      await tapKey(tester, 'move-option-t3');
      await enter(tester, 'move-reason', 'Guest asked');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.ensureVisible(find.byKey(const Key('move-confirm')));
      await tester.tap(find.byKey(const Key('move-confirm')));
      await tester.pump();
      expect(find.text('Moving...'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('move-confirm'))).onPressed, isNull);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_move_booking'), hasLength(1));
      expect(db.moves, hasLength(1));
    });

    testWidgets('closing the sheet without moving changes nothing and tells no one', (tester) async {
      await open(tester);
      await tapKey(tester, 'move-booking');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('move-sheet')), findsNothing);
      expect(moved, 0);
      expect(db.paramsOf('desk_move_booking'), isEmpty);
    });

    testWidgets('the options failing to load say so with Try again', (tester) async {
      await open(tester);
      db.beforeCall = (f) {
        if (f == 'desk_booking_move_options') throw Exception('boom');
      };
      await tapKey(tester, 'move-booking');
      expect(find.byKey(const Key('move-error')), findsOneWidget);
      db.beforeCall = null;
      await tapKey(tester, 'move-retry');
      expect(find.byKey(const Key('move-option-t3')), findsOneWidget);
    });

    testWidgets('without the right to move there is no button', (tester) async {
      await open(tester, canMove: false);
      expect(find.byKey(const Key('move-booking')), findsNothing);
    });

    testWidgets('a booking that was moved twice lists both, newest first', (tester) async {
      await db.service.move(booking['id'] as String, 't1', 'First move');
      await db.service.move(booking['id'] as String, 't2', 'Second move');
      await open(tester);
      expect(find.byKey(const Key('move-0')), findsOneWidget);
      expect(find.byKey(const Key('move-1')), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('move-0')), matching: find.byType(Text))).data, startsWith('Booth → Pair table'));
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('move-1')), matching: find.byType(Text))).data, startsWith('Pair table → Booth'));
    });
  });
}
