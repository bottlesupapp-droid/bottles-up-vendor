import 'dart:async';

import 'package:bottles_up_vendor/features/owner/logic/setup_forms.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/booking_times_editor.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/bottle_menu_editor.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/table_types_editor.dart';
import 'package:bottles_up_vendor/features/owner/widgets/venue_setup_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_owner_backend.dart';
import 'fake_setup_backend.dart';

late FakeSetupBackend setup;
late FakeOwnerBackend owner;

Widget host(Widget screen) => ProviderScope(
      key: UniqueKey(),
      overrides: [venueSetupServiceProvider.overrideWithValue(setup.service), ownerServiceProvider.overrideWithValue(owner.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: screen),
    );

Future<void> open(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
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

String textOf(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

Finder inProblems(String text) => find.descendant(of: find.byKey(const Key('problems')), matching: find.text(text));

void main() {
  setUp(() {
    setup = FakeSetupBackend();
    owner = FakeOwnerBackend();
  });

  // Forms are long; a tall screen keeps every field on it without scrolling in the test.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('booking times', () {
    TimeOfDay? initialSeen;
    Widget editor({TimeOfDay? picks}) => host(BookingTimesEditor(
          venueId: 'v1',
          pickTime: (context, initial) async {
            initialSeen = initial;
            return picks;
          },
        ));

    setUp(() => initialSeen = null);

    testWidgets('shows every day, Monday first, with the times that exist and the days that take no bookings', (tester) async {
      tall(tester);
      setup.slots.addAll([slotRow('s1', 5, '21:00:00'), slotRow('s2', 5, '23:30:00', label: 'Late'), slotRow('s3', 0, '20:00:00')]);
      await open(tester, editor());
      expect(find.text('9:00 PM'), findsOneWidget);
      expect(find.text('11:30 PM · Late'), findsOneWidget);
      expect(find.text('8:00 PM'), findsOneWidget);
      expect(find.text('No bookings accepted'), findsNWidgets(5));
      final tops = [for (final d in dayOrder) tester.getTopLeft(find.byKey(Key('day-$d'))).dy];
      expect(tops, [...tops]..sort());
      expect(dayOrder.first, 1);
      expect(dayOrder.last, 0);
    });

    testWidgets('a time that has bookings offers no way to remove it', (tester) async {
      tall(tester);
      setup.slots.addAll([slotRow('s1', 5, '21:00:00'), slotRow('s2', 5, '22:00:00', bookings: 3)]);
      await open(tester, editor());
      expect(tester.widget<InputChip>(find.byKey(const Key('time-s1'))).onDeleted, isNotNull);
      expect(tester.widget<InputChip>(find.byKey(const Key('time-s2'))).onDeleted, isNull);
      expect(find.text('10:00 PM · 3 bookings'), findsOneWidget);
      expect(find.text('9:00 PM'), findsOneWidget, reason: 'a time without bookings says nothing about them');
      expect(find.byKey(const Key('times-protected-note')), findsOneWidget);
    });

    testWidgets('one booking is "1 booking", and with none the explanation is not shown', (tester) async {
      tall(tester);
      setup.slots.add(slotRow('s1', 5, '21:00:00', bookings: 1));
      await open(tester, editor());
      expect(find.text('9:00 PM · 1 booking'), findsOneWidget);
      setup.slots.single['booking_count'] = 0;
      await open(tester, editor());
      expect(find.byKey(const Key('times-protected-note')), findsNothing);
    });

    testWidgets('adds one time to several days at once: asks for the time from 9 PM, sends each day, clears the form, shows the new times', (tester) async {
      tall(tester);
      await open(tester, editor(picks: const TimeOfDay(hour: 22, minute: 30)));
      await tapKey(tester, 'pick-day-5');
      await tapKey(tester, 'pick-day-6');
      await tapKey(tester, 'pick-time');
      expect(initialSeen, const TimeOfDay(hour: 21, minute: 0));
      expect(find.text('Arrival time: 10:30 PM'), findsOneWidget);
      await type(tester, 'slot-note', '  Early seating ');
      await tapKey(tester, 'add-times');

      expect(setup.paramsOf('add_venue_time_slot'), [
        {'p_venue': 'v1', 'p_day': 5, 'p_start': '22:30', 'p_label': 'Early seating'},
        {'p_venue': 'v1', 'p_day': 6, 'p_start': '22:30', 'p_label': 'Early seating'},
      ]);
      expect(find.text('2 arrival times added'), findsOneWidget);
      expect(find.text('10:30 PM · Early seating'), findsNWidgets(2));
      expect(tester.widget<FilterChip>(find.byKey(const Key('pick-day-5'))).selected, isFalse);
      expect(textOf(tester, 'slot-note'), isEmpty);
    });

    testWidgets('cancelling the time picker changes nothing', (tester) async {
      tall(tester);
      await open(tester, editor(picks: null));
      await tapKey(tester, 'pick-time');
      expect(find.text('Arrival time: 9:00 PM'), findsOneWidget);
    });

    testWidgets('adding with no day chosen says so and sends nothing', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-times');
      expect(inProblems('Choose at least one day.'), findsOneWidget);
      expect(setup.count('add_venue_time_slot'), 0);
      expect(find.byType(SnackBar), findsNothing, reason: 'nothing was attempted, so nothing is announced');
    });

    testWidgets('a second tap while the first is still adding does nothing', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'pick-day-5');
      final gate = Completer<void>();
      setup.hold = gate.future;
      await tester.tap(find.byKey(const Key('add-times')));
      await tester.pump();
      expect(find.text('Adding…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('add-times'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('add-times')), warnIfMissed: false);
      gate.complete();
      await tester.pumpAndSettle();
      expect(setup.count('add_venue_time_slot'), 1);
    });

    testWidgets('a time that already exists is said, not duplicated, and the choices stay so they can be changed', (tester) async {
      tall(tester);
      setup.slots.add(slotRow('s1', 5, '21:00:00'));
      await open(tester, editor());
      await tapKey(tester, 'pick-day-5');
      await tapKey(tester, 'add-times');
      expect(find.text('Already added. Friday already has that arrival time.'), findsOneWidget);
      expect(setup.slots, hasLength(1));
      expect(tester.widget<FilterChip>(find.byKey(const Key('pick-day-5'))).selected, isTrue);
    });

    testWidgets('when one day was already there and another is new, the new one is added and the other is mentioned', (tester) async {
      tall(tester);
      setup.slots.add(slotRow('s1', 5, '21:00:00'));
      await open(tester, editor());
      await tapKey(tester, 'pick-day-5');
      await tapKey(tester, 'pick-day-6');
      await tapKey(tester, 'add-times');
      expect(find.text('Arrival time added. Friday already had it.'), findsOneWidget);
      expect(setup.slots.map((s) => s['day_of_week']), [5, 6]);
    });

    testWidgets('a failure for one day does not stop the others and is reported by name', (tester) async {
      tall(tester);
      var adds = 0;
      setup.beforeCall = (f) {
        if (f == 'add_venue_time_slot' && ++adds == 1) throw const PostgrestException(message: 'a venue can have 150 arrival times at most', code: 'P0001');
      };
      await open(tester, editor());
      await tapKey(tester, 'pick-day-5');
      await tapKey(tester, 'pick-day-6');
      await tapKey(tester, 'add-times');
      expect(find.text('Added 1, but some could not be added. Friday: a venue can have 150 arrival times at most'), findsOneWidget);
      expect(setup.slots.map((s) => s['day_of_week']), [6]);
    });

    testWidgets('removing a time asks the database and the chip goes', (tester) async {
      tall(tester);
      setup.slots.addAll([slotRow('s1', 5, '21:00:00'), slotRow('s2', 6, '21:00:00')]);
      await open(tester, editor());
      await tester.tap(find.byTooltip('Remove 9:00 PM on Friday'));
      await tester.pumpAndSettle();
      expect(setup.paramsOf('remove_venue_time_slot'), [
        {'p_venue': 'v1', 'p_slot': 's1'},
      ]);
      expect(find.byKey(const Key('time-s1')), findsNothing);
      expect(find.byKey(const Key('time-s2')), findsOneWidget);
    });

    testWidgets('a removal the database refuses (bookings arrived since the list was read) is said, and the time stays until it is read again', (tester) async {
      tall(tester);
      setup.slots.add(slotRow('s1', 5, '21:00:00'));
      await open(tester, editor());
      setup.slots.single['booking_count'] = 2;
      await tester.tap(find.byTooltip('Remove 9:00 PM on Friday'));
      await tester.pumpAndSettle();
      expect(find.text('this arrival time has bookings, so it cannot be removed'), findsOneWidget);
      expect(setup.slots, hasLength(1));
    });

    testWidgets('a server without the migration says so, with no retry; a dropped connection offers one that works', (tester) async {
      tall(tester);
      setup.failAll = const PostgrestException(message: 'no function', code: '42883');
      await open(tester, editor());
      expect(find.byKey(const Key('editor-error')), findsOneWidget);
      expect(find.textContaining('not set up on this server yet'), findsOneWidget);
      expect(find.byKey(const Key('editor-retry')), findsNothing);

      setup.failAll = Exception('socket closed');
      await open(tester, editor());
      expect(find.byKey(const Key('editor-retry')), findsOneWidget);
      setup.failAll = null;
      setup.slots.add(slotRow('s1', 5, '21:00:00'));
      await tapKey(tester, 'editor-retry');
      expect(find.text('9:00 PM'), findsOneWidget);
      expect(find.byKey(const Key('editor-error')), findsNothing);
    });
  });

  group('tables', () {
    Widget editor() => host(const TableTypesEditor(venueId: 'v1', orgId: 'o1'));

    testWidgets('says plainly when there are no tables yet', (tester) async {
      tall(tester);
      await open(tester, editor());
      expect(find.byKey(const Key('no-tables')), findsOneWidget);
    });

    testWidgets('shows each table with what a guest pays, how many guests, how many tables, and what protects it from removal', (tester) async {
      tall(tester);
      setup.tables.addAll([
        tableRowJson('t1', 'VIP booth', featured: true, badge: 'Popular'),
        tableRowJson('t2', 'Dance floor', count: 0, spend: 0, deposit: 0, bookings: 2),
      ]);
      await open(tester, editor());
      expect(find.text('min spend \$1,500.00 · deposit \$500.00'), findsOneWidget);
      expect(find.text('Up to 6 guests · 3 tables'), findsOneWidget);
      expect(find.byKey(const Key('featured')), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('No minimum spend or deposit'), findsOneWidget);
      expect(find.text('Up to 6 guests · none available to book · 2 bookings'), findsOneWidget);
      expect(find.byKey(const Key('protected-t2')), findsOneWidget);
      expect(find.byKey(const Key('protected-t1')), findsNothing);
      expect(tester.widget<TextButton>(find.byKey(const Key('remove-t2'))).onPressed, isNull);
      expect(tester.widget<TextButton>(find.byKey(const Key('remove-t1'))).onPressed, isNotNull);
    });

    testWidgets('an empty form says what is missing and sends nothing', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      await tapKey(tester, 'save-table');
      expect(inProblems('Give the table a name.'), findsOneWidget);
      expect(inProblems('Maximum guests must be a whole number from 1 to 100.'), findsOneWidget);
      expect(setup.count('save_venue_table_type'), 0);
    });

    testWidgets('adds a table: dollars typed become cents, no photo is sent as none, the list shows it, the checklist is read again', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      await type(tester, 'field-name', 'Booth');
      await type(tester, 'field-max', '8');
      await type(tester, 'field-count', '2');
      await type(tester, 'field-spend', '1,500.50');
      await type(tester, 'field-deposit', '\$500');
      await tapKey(tester, 'save-table');

      final call = setup.paramsOf('save_venue_table_type').single!;
      expect([call['p_venue'], call['p_type']], ['v1', null]);
      final d = call['p_details'] as Map;
      expect([d['name'], d['max_guests'], d['inventory_count'], d['min_spend_cents'], d['deposit_cents'], d['pricing_mode']], ['Booth', 8, 2, 150050, 50000, 'flat']);
      expect(d['image_url'], isNull, reason: 'no photo was chosen');
      expect(find.text('Table added.'), findsOneWidget);
      expect(find.text('Booth'), findsOneWidget);
      expect(find.text('min spend \$1,500.50 · deposit \$500.00'), findsOneWidget);
    });

    testWidgets('hourly fields appear only for hourly pricing and are sent with it', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      expect(find.byKey(const Key('field-rate')), findsNothing);
      await tester.tap(find.text('By the hour'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field-rate')), findsOneWidget);
      await type(tester, 'field-name', 'Lounge');
      await type(tester, 'field-max', '4');
      await type(tester, 'field-count', '1');
      await tapKey(tester, 'save-table');
      expect(inProblems('Enter the hourly rate, for example 200.'), findsOneWidget);
      expect(setup.count('save_venue_table_type'), 0);
      await type(tester, 'field-rate', '200');
      await type(tester, 'field-hours', '3');
      await tapKey(tester, 'save-table');
      final d = setup.paramsOf('save_venue_table_type').single!['p_details'] as Map;
      expect([d['pricing_mode'], d['hourly_rate_cents'], d['min_hours']], ['hourly', 20000, 3]);
      expect(find.textContaining('\$200.00 per hour, 3 hour minimum'), findsOneWidget);
    });

    testWidgets('the featured switch and the minimum guests are sent, and a minimum above the maximum is refused', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      await type(tester, 'field-name', 'Booth');
      await type(tester, 'field-max', '6');
      await type(tester, 'field-min', '8');
      await tapKey(tester, 'save-table');
      expect(inProblems('Minimum guests cannot be more than maximum guests.'), findsOneWidget);
      expect(setup.count('save_venue_table_type'), 0);
      await type(tester, 'field-min', '4');
      await tapKey(tester, 'switch-featured');
      await type(tester, 'field-badge', ' Best view ');
      await tapKey(tester, 'save-table');
      final d = setup.paramsOf('save_venue_table_type').single!['p_details'] as Map;
      expect([d['min_guests'], d['is_featured'], d['badge_label']], [4, true, 'Best view']);
      expect(find.byKey(const Key('featured')), findsOneWidget);
    });

    testWidgets('a second tap on Save while the first is still going does not save twice', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      await type(tester, 'field-name', 'Booth');
      await type(tester, 'field-max', '6');
      final gate = Completer<void>();
      setup.hold = gate.future;
      await tester.tap(find.byKey(const Key('save-table')));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-table')), warnIfMissed: false);
      gate.complete();
      await tester.pumpAndSettle();
      expect(setup.count('save_venue_table_type'), 1);
      expect(setup.tables, hasLength(1));
    });

    testWidgets('editing opens with what is saved, changes it, and leaves the photo alone', (tester) async {
      tall(tester);
      setup.tables.add(tableRowJson('t1', 'VIP booth', badge: 'Popular'));
      await open(tester, editor());
      await tapKey(tester, 'edit-t1');
      expect(textOf(tester, 'field-name'), 'VIP booth');
      expect(textOf(tester, 'field-max'), '6');
      expect(textOf(tester, 'field-count'), '3');
      expect(textOf(tester, 'field-spend'), moneyInput(150000));
      expect(textOf(tester, 'field-deposit'), moneyInput(50000));
      expect(textOf(tester, 'field-badge'), 'Popular');
      await type(tester, 'field-name', 'Corner booth');
      await tapKey(tester, 'save-table');
      expect(setup.paramsOf('save_venue_table_type').single!['p_type'], 't1');
      expect(setup.tables.single['name'], 'Corner booth');
      expect(setup.tables.single['image_url'], 'https://img.example/t1.jpg');
      expect(setup.tables.single['badge_label'], 'Popular');
      expect(find.text('Table saved.'), findsOneWidget);
      expect(find.text('Corner booth'), findsOneWidget);
    });

    testWidgets('a refusal from the database is shown in the form and nothing typed is lost', (tester) async {
      tall(tester);
      setup.failAll = const PostgrestException(message: 'a venue can have 50 table types at most', code: 'P0001');
      await open(tester, host(const TableTypesEditor(venueId: 'v1', orgId: 'o1')));
      setup.failAll = null;
      await tapKey(tester, 'add-table');
      await type(tester, 'field-name', 'Booth');
      await type(tester, 'field-max', '8');
      await type(tester, 'field-count', '2');
      setup.failAll = const PostgrestException(message: 'a venue can have 50 table types at most', code: 'P0001');
      await tapKey(tester, 'save-table');
      expect(inProblems('a venue can have 50 table types at most'), findsOneWidget);
      expect(textOf(tester, 'field-name'), 'Booth');
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-table'))).onPressed, isNotNull);
    });

    testWidgets('keeping a table at the confirmation changes nothing; removing it asks the database and it goes', (tester) async {
      tall(tester);
      setup.tables.add(tableRowJson('t1', 'VIP booth'));
      await open(tester, editor());
      await tapKey(tester, 'remove-t1');
      expect(find.text('Remove VIP booth?'), findsOneWidget);
      await tapKey(tester, 'keep');
      expect(setup.count('remove_venue_table_type'), 0);
      expect(find.byKey(const Key('table-t1')), findsOneWidget);

      await tapKey(tester, 'remove-t1');
      await tapKey(tester, 'confirm-remove');
      expect(setup.paramsOf('remove_venue_table_type'), [
        {'p_venue': 'v1', 'p_type': 't1'},
      ]);
      expect(find.byKey(const Key('table-t1')), findsNothing);
      expect(find.text('Table removed.'), findsOneWidget);
    });

    testWidgets('dismissing the confirmation by tapping outside it removes nothing', (tester) async {
      tall(tester);
      setup.tables.add(tableRowJson('t1', 'VIP booth'));
      await open(tester, editor());
      await tapKey(tester, 'remove-t1');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Remove VIP booth?'), findsNothing);
      expect(setup.count('remove_venue_table_type'), 0);
      expect(find.byKey(const Key('table-t1')), findsOneWidget);
    });

    testWidgets('a removal the database refuses is said in its words, and the table stays', (tester) async {
      tall(tester);
      setup.tables.add(tableRowJson('t1', 'VIP booth'));
      await open(tester, editor());
      setup.tables.single['booking_count'] = 1;
      await tapKey(tester, 'remove-t1');
      await tapKey(tester, 'confirm-remove');
      expect(find.textContaining('this table type has bookings, so it cannot be removed'), findsOneWidget);
      expect(find.byKey(const Key('table-t1')), findsOneWidget);
    });
  });

  group('bottle menu', () {
    Widget editor() => host(const BottleMenuEditor(venueId: 'v1', orgId: 'o1'));

    testWidgets('says plainly when the menu is empty', (tester) async {
      tall(tester);
      await open(tester, editor());
      expect(find.byKey(const Key('no-bottles')), findsOneWidget);
    });

    testWidgets('shows each bottle with its price, stock and whether guests can order it', (tester) async {
      tall(tester);
      setup.bottles.addAll([
        bottleRowJson('b1', 'Grey Goose', stock: 4, category: 'Vodka'),
        bottleRowJson('b2', 'Don Julio', price: 62050, soldOut: true),
        bottleRowJson('b3', 'Old stock', available: false, soldOut: true),
      ]);
      await open(tester, editor());
      expect(find.text('Grey Goose  750ml'), findsOneWidget);
      expect(find.text('\$195.00 · Vodka · 4 in stock'), findsOneWidget);
      expect(find.text('\$620.50'), findsOneWidget);
      String stateOf(String id) => ((tester.widget(find.descendant(of: find.byKey(Key('state-$id')), matching: find.byType(Text)))) as Text).data!;
      expect([stateOf('b1'), stateOf('b2'), stateOf('b3')], ['On menu', 'Sold out', 'Off the menu']);
    });

    testWidgets('one tap takes a bottle off the menu and sends only that field; another marks it sold out', (tester) async {
      tall(tester);
      setup.bottles.add(bottleRowJson('b1', 'Grey Goose'));
      await open(tester, editor());
      await tapKey(tester, 'on-menu-b1');
      await tapKey(tester, 'sold-out-b1');
      expect(setup.paramsOf('save_venue_bottle'), [
        {'p_venue': 'v1', 'p_bottle': 'b1', 'p_details': {'is_available': false}},
        {'p_venue': 'v1', 'p_bottle': 'b1', 'p_details': {'is_sold_out': true}},
      ]);
      expect(setup.bottles.single['price_cents'], 19500);
      expect(setup.bottles.single['image_url'], 'https://img.example/b1.jpg');
      expect(tester.widget<Switch>(find.byKey(const Key('on-menu-b1'))).value, isFalse);
      expect(tester.widget<Switch>(find.byKey(const Key('sold-out-b1'))).value, isTrue);
    });

    testWidgets('a quick change that fails is said, and the switch shows what is really saved', (tester) async {
      tall(tester);
      setup.bottles.add(bottleRowJson('b1', 'Grey Goose'));
      await open(tester, editor());
      setup.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
      await tapKey(tester, 'on-menu-b1');
      expect(find.text("You don't have access to do that."), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('on-menu-b1'))).value, isTrue);
    });

    testWidgets('an empty form says what is missing and sends nothing', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-bottle');
      await tapKey(tester, 'save-bottle');
      expect(inProblems('Give the bottle a name.'), findsOneWidget);
      expect(inProblems('Enter the price as an amount like 195 or 195.50.'), findsOneWidget);
      expect(setup.count('save_venue_bottle'), 0);
    });

    testWidgets('adds a bottle: the price becomes cents, an empty stock means not counted, no photo is sent as none', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-bottle');
      await type(tester, 'field-name', 'Grey Goose');
      await type(tester, 'field-price', '195.5');
      await type(tester, 'field-size', '750ml');
      await tapKey(tester, 'save-bottle');
      final d = setup.paramsOf('save_venue_bottle').single!['p_details'] as Map;
      expect([d['name'], d['price_cents'], d['size'], d['stock_quantity'], d['is_available'], d['is_sold_out']], ['Grey Goose', 19550, '750ml', null, true, false]);
      expect(d['image_url'], isNull, reason: 'no photo was chosen');
      expect(find.text('Bottle added.'), findsOneWidget);
      expect(find.text('Grey Goose  750ml'), findsOneWidget);
    });

    testWidgets('stock, the menu switch and the sold-out switch in the form are all sent', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-bottle');
      await type(tester, 'field-name', 'Grey Goose');
      await type(tester, 'field-price', '195');
      await type(tester, 'field-stock', '12');
      await tapKey(tester, 'switch-available');
      await tapKey(tester, 'switch-soldout');
      await tapKey(tester, 'save-bottle');
      final d = setup.paramsOf('save_venue_bottle').single!['p_details'] as Map;
      expect([d['stock_quantity'], d['is_available'], d['is_sold_out']], [12, false, true]);
    });

    testWidgets('a second tap on Save while the first is still going does not save twice', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-bottle');
      await type(tester, 'field-name', 'Grey Goose');
      await type(tester, 'field-price', '195');
      final gate = Completer<void>();
      setup.hold = gate.future;
      await tester.tap(find.byKey(const Key('save-bottle')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-bottle')), warnIfMissed: false);
      gate.complete();
      await tester.pumpAndSettle();
      expect(setup.count('save_venue_bottle'), 1);
    });

    testWidgets('editing opens with what is saved and saves the change without touching the photo', (tester) async {
      tall(tester);
      setup.bottles.add(bottleRowJson('b1', 'Grey Goose', stock: 4));
      await open(tester, editor());
      await tapKey(tester, 'edit-b1');
      expect(textOf(tester, 'field-name'), 'Grey Goose');
      expect(textOf(tester, 'field-price'), moneyInput(19500));
      expect(textOf(tester, 'field-stock'), '4');
      await type(tester, 'field-price', '205');
      await tapKey(tester, 'save-bottle');
      expect(setup.bottles.single['price_cents'], 20500);
      expect(setup.bottles.single['image_url'], 'https://img.example/b1.jpg');
      expect(find.text('Bottle saved.'), findsOneWidget);
    });

    testWidgets('a refusal from the database is shown in the form and nothing typed is lost', (tester) async {
      tall(tester);
      await open(tester, editor());
      await tapKey(tester, 'add-bottle');
      await type(tester, 'field-name', 'Grey Goose');
      await type(tester, 'field-price', '195');
      setup.failAll = const PostgrestException(message: 'a venue can have 300 bottles at most', code: 'P0001');
      await tapKey(tester, 'save-bottle');
      expect(inProblems('a venue can have 300 bottles at most'), findsOneWidget);
      expect(textOf(tester, 'field-price'), '195');
    });

    testWidgets('removing asks first; keeping changes nothing; removing takes it off the menu', (tester) async {
      tall(tester);
      setup.bottles.add(bottleRowJson('b1', 'Grey Goose'));
      await open(tester, editor());
      await tapKey(tester, 'remove-b1');
      expect(find.text('Remove Grey Goose?'), findsOneWidget);
      expect(find.textContaining('Past orders keep the name and price'), findsOneWidget);
      await tapKey(tester, 'keep');
      expect(setup.count('remove_venue_bottle'), 0);
      await tapKey(tester, 'remove-b1');
      await tapKey(tester, 'confirm-remove');
      expect(setup.bottles, isEmpty);
      expect(find.byKey(const Key('bottle-b1')), findsNothing);
      expect(find.text('Bottle removed.'), findsOneWidget);
    });
  });

  group('from the venue\'s Setup list', () {
    setUp(() {
      // The checklist as the database would report it: tables, menu and times are done once there is something saved.
      owner.handlers['venue_setup_status'] = (_) => [
            stepRow('profile', 'done'),
            stepRow('floor_plan', 'done'),
            stepRow('tables', setup.tables.isEmpty ? 'todo' : 'done'),
            stepRow('bottles', setup.bottles.isEmpty ? 'todo' : 'done'),
            stepRow('booking_rules', setup.slots.isEmpty ? 'todo' : 'done'),
            stepRow('team', 'todo', required: false),
            stepRow('payments', 'unavailable', required: false, detail: 'payment configuration is not available yet'),
            stepRow('notifications', 'unavailable', required: false),
          ];
    });

    Widget list() => host(const Scaffold(body: VenueSetupList(venueId: 'v1', orgId: 'o1')));

    testWidgets('only the steps this app can edit offer Edit (the team and the optional steps do not)', (tester) async {
      tall(tester);
      await open(tester, list());
      for (final step in ['profile', 'floor_plan', 'tables', 'bottles', 'booking_rules', 'payments']) {
        expect(find.byKey(Key('edit-step-$step')), findsOneWidget, reason: step);
      }
      for (final step in ['team']) {
        expect(find.byKey(Key('edit-step-$step')), findsNothing, reason: step);
      }
      expect(find.byKey(const Key('setup-footnote')), findsOneWidget);
      expect(find.textContaining('The venue profile, floor plans, tables, the bottle menu, booking times and how bottles are paid can be edited here'), findsOneWidget);
    });

    testWidgets('the payments step, which the database lists as "not available yet", opens the payment settings and says Settings, not Coming soon', (tester) async {
      tall(tester);
      await open(tester, list());
      expect(find.descendant(of: find.byKey(const Key('step-payments')), matching: find.text('Settings')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('step-payments')), matching: find.text('Coming soon')), findsNothing);
      await tapKey(tester, 'step-payments');
      expect(find.byKey(const Key('payment-settings')), findsOneWidget);
      expect(find.text('Payment settings'), findsOneWidget);
    });

    testWidgets('the notifications step stays "Coming soon": there is nothing behind it', (tester) async {
      tall(tester);
      await open(tester, list());
      expect(find.descendant(of: find.byKey(const Key('step-notifications')), matching: find.text('Coming soon')), findsOneWidget);
      expect(find.byKey(const Key('edit-step-notifications')), findsNothing);
    });

    testWidgets('adding the first table from the checklist marks that step done without reopening the screen', (tester) async {
      tall(tester);
      await open(tester, list());
      String statusOfTables() => ((tester.widget(find.descendant(of: find.byKey(const Key('step-tables')), matching: find.text('Done')))) as Text).data!;
      expect(find.descendant(of: find.byKey(const Key('step-tables')), matching: find.text('To do')), findsOneWidget);
      final reads = owner.count('venue_setup_status');

      await tapKey(tester, 'step-tables');
      expect(find.text('Tables'), findsWidgets);
      await tapKey(tester, 'add-table');
      await type(tester, 'field-name', 'Booth');
      await type(tester, 'field-max', '8');
      await type(tester, 'field-count', '2');
      await tapKey(tester, 'save-table');
      expect(owner.count('venue_setup_status'), greaterThan(reads));

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(statusOfTables(), 'Done');
    });

    testWidgets('a step with nothing to edit here does nothing when tapped', (tester) async {
      tall(tester);
      await open(tester, list());
      await tapKey(tester, 'step-team');
      expect(find.byType(TableTypesEditor), findsNothing);
      expect(find.byType(BottleMenuEditor), findsNothing);
      expect(find.byType(BookingTimesEditor), findsNothing);
    });

    testWidgets('each step opens its own editor, for this venue', (tester) async {
      tall(tester);
      await open(tester, list());
      for (final (step, type, fn) in [
        ('tables', TableTypesEditor, 'list_venue_table_types'),
        ('bottles', BottleMenuEditor, 'list_venue_bottles'),
        ('booking_rules', BookingTimesEditor, 'list_venue_time_slots'),
      ]) {
        await tapKey(tester, 'step-$step');
        expect(find.byType(type), findsOneWidget, reason: step);
        expect(setup.paramsOf(fn), [
          {'p_venue': 'v1'},
        ], reason: step);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('closing an editor and opening it again reads the list again, never a stale one', (tester) async {
      tall(tester);
      await open(tester, list());
      for (final (step, fn) in [('tables', 'list_venue_table_types'), ('bottles', 'list_venue_bottles'), ('booking_rules', 'list_venue_time_slots')]) {
        await tapKey(tester, 'step-$step');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tapKey(tester, 'step-$step');
        expect(setup.count(fn), 2, reason: step);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  });
}
