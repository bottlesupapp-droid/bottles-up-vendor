import 'dart:async';

import 'package:bottles_up_vendor/features/owner/logic/venue_profile_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/table_map/logic/table_map_rules.dart';
import 'package:bottles_up_vendor/features/table_map/providers/table_map_providers.dart';
import 'package:bottles_up_vendor/features/table_map/screens/table_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_map_backend.dart';

late FakeTableMapBackend db;
List<FloorRow> floors = const [FloorRow(floorId: 'f1', label: 'Main room', imageUrl: '')];
Object? floorsFailure;

Widget host({String night = '2026-10-19', String tonight = '2026-10-19'}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        tableMapServiceProvider.overrideWithValue(db.service),
        floorsProvider.overrideWith((ref, venueId) async {
          final broken = floorsFailure;
          if (broken != null) throw broken;
          return floors;
        }),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: TableMapScreen(venueId: 'v1', venueName: 'Club A', night: night, tonight: tonight)),
    );

Future<void> open(WidgetTester tester, {String night = '2026-10-19', String tonight = '2026-10-19'}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(night: night, tonight: tonight));
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

String counts(WidgetTester tester, String table) => tester.widget<Text>(find.byKey(Key('map-counts-$table'))).data!;

const heldForm = BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 60);

void main() {
  setUp(() {
    db = FakeTableMapBackend();
    floors = const [FloorRow(floorId: 'f1', label: 'Main room', imageUrl: '')];
    floorsFailure = null;
  });

  testWidgets('shows the first arrival time with every table, its state counts and the key', (tester) async {
    db.addBooking(table: 't2');
    await open(tester);
    expect(find.text('Club A'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    expect(find.text('11:30 PM · Late'), findsOneWidget);
    expect(counts(tester, 't1'), '1 available · seats up to 6');
    expect(counts(tester, 't2'), '2 available · 1 booked · seats up to 4');
    expect(counts(tester, 't3'), '2 available · seats up to 8');
    expect(find.byKey(const Key('map-legend')), findsOneWidget);
    for (final k in ['Available', 'Held', 'Booked', 'Occupied', 'Unavailable']) {
      expect(find.descendant(of: find.byKey(const Key('map-legend')), matching: find.text(k)), findsOneWidget);
    }
    expect(db.paramsOf('desk_table_states').single, {'p_venue': 'v1', 'p_night': '2026-10-19'});
    expect(db.paramsOf('desk_table_blocks').single, {'p_venue': 'v1', 'p_night': '2026-10-19'});
  });

  testWidgets('only tables placed on the floor are drawn on it; the others are in the list below', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('floor-canvas')), findsOneWidget);
    expect(find.byKey(const Key('box-t1')), findsOneWidget);
    expect(find.byKey(const Key('box-t2')), findsNothing);
    expect(find.byKey(const Key('map-table-t2')), findsOneWidget);
    expect(find.byKey(const Key('map-unplaced-note')), findsNothing);
  });

  testWidgets('with nothing placed the list is all there is, and it says how to place tables', (tester) async {
    db.table('t1')['floor_id'] = null;
    db.table('t1')['pos_x'] = null;
    await open(tester);
    expect(find.byKey(const Key('floor-canvas')), findsNothing);
    expect(find.byKey(const Key('map-unplaced-note')), findsOneWidget);
    expect(find.byKey(const Key('map-table-t1')), findsOneWidget);
  });

  testWidgets('the list still works when the floor pictures cannot be read', (tester) async {
    floorsFailure = Exception('boom');
    await open(tester);
    expect(find.byKey(const Key('floor-canvas')), findsNothing);
    expect(find.byKey(const Key('map-table-t2')), findsOneWidget);
  });

  testWidgets('two floors with tables get a chooser, and each shows its own tables', (tester) async {
    floors = const [FloorRow(floorId: 'f1', label: 'Main room', imageUrl: ''), FloorRow(floorId: 'f2', label: 'Terrace', imageUrl: '')];
    db.table('t3')
      ..['floor_id'] = 'f2'
      ..['pos_x'] = 5.0
      ..['pos_y'] = 5.0
      ..['width'] = 10.0
      ..['height'] = 10.0;
    await open(tester);
    expect(find.byKey(const Key('map-floor-f1')), findsOneWidget);
    expect(find.byKey(const Key('box-t1')), findsOneWidget);
    expect(find.byKey(const Key('box-t3')), findsNothing);
    await tapKey(tester, 'map-floor-f2');
    expect(find.byKey(const Key('box-t3')), findsOneWidget);
    expect(find.byKey(const Key('box-t1')), findsNothing);
  });

  testWidgets('a floor with no tables placed on it for this arrival time is not offered', (tester) async {
    floors = const [FloorRow(floorId: 'f1', label: 'Main room', imageUrl: ''), FloorRow(floorId: 'f2', label: 'Terrace', imageUrl: '')];
    await open(tester);
    expect(find.byKey(const Key('map-floor-f1')), findsNothing, reason: 'one floor needs no chooser');
    expect(find.byKey(const Key('map-floor-f2')), findsNothing);
  });

  testWidgets('choosing another arrival time shows its counts', (tester) async {
    db.addBooking(table: 't2', slot: 's2');
    await open(tester);
    expect(counts(tester, 't2'), '3 available · seats up to 4');
    await tapKey(tester, 'map-slot-s2');
    expect(counts(tester, 't2'), '2 available · 1 booked · seats up to 4');
  });

  testWidgets('tapping a table on the map selects its card', (tester) async {
    await open(tester);
    await tapKey(tester, 'box-t1');
    final card = tester.widget<Card>(find.byKey(const Key('map-table-t1')));
    expect(card.shape, isA<RoundedRectangleBorder>());
    final other = tester.widget<Card>(find.byKey(const Key('map-table-t2')));
    expect(other.shape, isNull);
  });

  group('holds and tables out of use', () {
    testWidgets('a manager holds a table: the sheet asks how many, for how long and why, and the map shows it held', (tester) async {
      await open(tester);
      await tapKey(tester, 'map-block-t2');
      expect(find.byKey(const Key('block-sheet')), findsOneWidget);
      await tapKey(tester, 'block-more');
      expect(find.text('2'), findsWidgets);
      await tapKey(tester, 'hold-120');
      await enter(tester, 'block-reason', 'VIP party');
      await tapKey(tester, 'block-confirm');
      expect(db.paramsOf('desk_table_block').single, {
        'p_venue': 'v1',
        'p_night': '2026-10-19',
        'p_type': 't2',
        'p_slot': 's1',
        'p_kind': 'held',
        'p_quantity': 2,
        'p_reason': 'VIP party',
        'p_minutes': 120,
      });
      expect(find.byKey(const Key('block-sheet')), findsNothing);
      expect(find.text('2 × Pair table held for 2 hours. 1 left to sell.'), findsOneWidget);
      expect(counts(tester, 't2'), '1 available · 2 held · seats up to 4');
      expect(find.textContaining('Held: 2 × Pair table at 9:00 PM until'), findsOneWidget);
      expect(find.textContaining('VIP party · by Mo Manager'), findsOneWidget);
    });

    testWidgets('a table taken out of use sends no length and is listed until reopened', (tester) async {
      await open(tester);
      await tapKey(tester, 'map-block-t3');
      await tapKey(tester, 'block-kind');
      await tester.tap(find.text('Out of use'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hold-60')), findsNothing, reason: 'there is no length to choose');
      await enter(tester, 'block-reason', 'Broken leg');
      await tapKey(tester, 'block-confirm');
      expect(db.paramsOf('desk_table_block').single['p_kind'], 'unavailable');
      expect(db.paramsOf('desk_table_block').single['p_minutes'], isNull);
      expect(find.text('1 × Sofa taken out of use until you reopen it. 1 left to sell.'), findsOneWidget);
      expect(counts(tester, 't3'), '1 available · 1 unavailable · seats up to 8');
      expect(find.text('Unavailable: 1 × Sofa at 9:00 PM until reopened'), findsOneWidget);
    });

    testWidgets('a reason that is too short is said before anything is sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'map-block-t2');
      await enter(tester, 'block-reason', 'x');
      await tapKey(tester, 'block-confirm');
      expect(find.text('Give a reason of 3 to 200 characters.'), findsOneWidget);
      expect(db.paramsOf('desk_table_block'), isEmpty);
      expect(find.byKey(const Key('block-sheet')), findsOneWidget);
    });

    testWidgets('the quantity cannot go past what is free', (tester) async {
      await open(tester);
      await tapKey(tester, 'map-block-t3');
      await tapKey(tester, 'block-more');
      expect(tester.widget<IconButton>(find.byKey(const Key('block-more'))).onPressed, isNull);
      expect(tester.widget<Text>(find.byKey(const Key('block-quantity'))).data, '2');
    });

    testWidgets('a table that is not free cannot be held: the button is off', (tester) async {
      db.addBooking(table: 't1');
      await open(tester);
      expect(tester.widget<TextButton>(find.byKey(const Key('map-block-t1'))).onPressed, isNull);
    });

    testWidgets('someone else booked the table first: the refusal is shown in the sheet, what was typed stays, and the map is read again', (tester) async {
      await open(tester);
      await tapKey(tester, 'map-block-t1');
      await enter(tester, 'block-reason', 'VIP party');
      db.addBooking(table: 't1', slot: 's1');
      await tapKey(tester, 'block-confirm');
      expect(find.text('Only 0 of these tables are free for that time; tables that are already booked or held cannot be blocked.'), findsOneWidget);
      expect(find.byKey(const Key('block-sheet')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('block-reason'))).controller!.text, 'VIP party');
      expect(db.blocks, isEmpty);
    });

    testWidgets('a connection failure keeps the sheet and what was typed, in plain words', (tester) async {
      await open(tester);
      await tapKey(tester, 'map-block-t2');
      await enter(tester, 'block-reason', 'VIP party');
      db.failBlock = Exception('socket closed at 10.0.0.1');
      await tapKey(tester, 'block-confirm');
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('socket'), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('block-reason'))).controller!.text, 'VIP party');
    });

    testWidgets('a second tap while the first is going changes nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'map-block-t2');
      await enter(tester, 'block-reason', 'VIP party');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.ensureVisible(find.byKey(const Key('block-confirm')));
      await tester.tap(find.byKey(const Key('block-confirm')));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('block-confirm'))).onPressed, isNull);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_table_block'), hasLength(1));
      expect(db.blocks, hasLength(1));
    });

    testWidgets('reopening a hold gives the tables back', (tester) async {
      await db.service.block(venueId: 'v1', night: '2026-10-19', tableTypeId: 't1', slotId: 's1', form: heldForm);
      await open(tester);
      expect(counts(tester, 't1'), '1 held · seats up to 6');
      expect(tester.widget<TextButton>(find.byKey(const Key('map-block-t1'))).onPressed, isNull);
      await tapKey(tester, 'reopen-${db.blocks.single['id']}');
      expect(find.text('Reopened: 1 × Booth.'), findsOneWidget);
      expect(counts(tester, 't1'), '1 available · seats up to 6');
      expect(find.byKey(const Key('blocks-empty')), findsOneWidget);
    });

    testWidgets('reopening something that had already ended says so', (tester) async {
      await db.service.block(venueId: 'v1', night: '2026-10-19', tableTypeId: 't1', slotId: 's1', form: heldForm);
      await open(tester);
      db.blocks.single['released'] = true;
      await tapKey(tester, 'reopen-${db.blocks.single['id']}');
      expect(find.text('That had already ended.'), findsOneWidget);
    });

    testWidgets('a second tap on Reopen while the first is going is ignored', (tester) async {
      await db.service.block(venueId: 'v1', night: '2026-10-19', tableTypeId: 't1', slotId: 's1', form: heldForm);
      await open(tester);
      final gate = Completer<void>();
      db.hold = gate.future;
      final key = Key('reopen-${db.blocks.single['id']}');
      await tester.tap(find.byKey(key));
      await tester.pump();
      expect(find.text('Reopening...'), findsOneWidget);
      await tester.tap(find.byKey(key), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.paramsOf('desk_table_release'), hasLength(1));
    });

    testWidgets('a refusal to reopen is shown as a sentence', (tester) async {
      await db.service.block(venueId: 'v1', night: '2026-10-19', tableTypeId: 't1', slotId: 's1', form: heldForm);
      await open(tester);
      db.role = 'server';
      await tapKey(tester, 'reopen-${db.blocks.single['id']}');
      expect(find.text('You don\'t have access to do that.'), findsOneWidget);
    });
  });

  group('the night', () {
    testWidgets('going to the next night reads that night', (tester) async {
      await open(tester);
      await tapKey(tester, 'night-next');
      expect(db.paramsOf('desk_table_states').last['p_night'], '2026-10-20');
      expect(find.text('Tuesday Oct 20'), findsOneWidget);
    });

    testWidgets('nights past 60 days ahead, or before last night, are not read; the screen says why', (tester) async {
      await open(tester, night: '2026-12-18', tonight: '2026-10-19');
      final before = db.paramsOf('desk_table_states').length;
      await tapKey(tester, 'night-next');
      expect(find.text('You can look at the tables from last night to 60 nights ahead.'), findsOneWidget);
      expect(db.paramsOf('desk_table_states').length, before);
      expect(find.text('Friday Dec 18'), findsOneWidget);
    });

    testWidgets('last night can be looked at, the night before it cannot', (tester) async {
      await open(tester);
      await tapKey(tester, 'night-prev');
      expect(db.paramsOf('desk_table_states').last['p_night'], '2026-10-18');
      final reads = db.paramsOf('desk_table_states').length;
      await tapKey(tester, 'night-prev');
      expect(find.text('You can look at the tables from last night to 60 nights ahead.'), findsOneWidget);
      expect(db.paramsOf('desk_table_states').length, reads);
    });

    testWidgets('another night starts on its first arrival time again', (tester) async {
      await open(tester);
      await tapKey(tester, 'map-slot-s2');
      await tapKey(tester, 'night-next');
      final chip = tester.widget<ChoiceChip>(find.byKey(const Key('map-slot-s1')));
      expect(chip.selected, isTrue);
    });
  });

  group('when it cannot be shown', () {
    testWidgets('a club with no arrival times says what to do', (tester) async {
      db.slots.clear();
      await open(tester);
      expect(find.byKey(const Key('map-none')), findsOneWidget);
    });

    testWidgets('a failed read says so, with Try again, and trying again works', (tester) async {
      db.failStates = Exception('boom');
      await open(tester);
      expect(find.byKey(const Key('map-error')), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      db.failStates = null;
      await tapKey(tester, 'map-retry');
      expect(find.byKey(const Key('map-error')), findsNothing);
      expect(find.byKey(const Key('map-table-t1')), findsOneWidget);
    });

    testWidgets('a server without the manager role is told their access has ended, with no retry', (tester) async {
      db.role = 'server';
      await open(tester);
      expect(find.byKey(const Key('map-error')), findsOneWidget);
      expect(find.byKey(const Key('map-retry')), findsNothing);
      expect(find.byKey(const Key('map-table-t1')), findsNothing);
    });

    testWidgets('a server without the function says it is not set up on this server', (tester) async {
      db.failAll = PostgrestException(message: 'function desk_table_states does not exist', code: '42883');
      await open(tester);
      expect(find.textContaining('not set up'), findsOneWidget);
      expect(find.byKey(const Key('map-retry')), findsNothing);
    });

    testWidgets('holds that cannot be read are said so while the map still shows', (tester) async {
      db.beforeCall = (f) {
        if (f == 'desk_table_blocks') throw Exception('boom');
      };
      await open(tester);
      expect(find.byKey(const Key('blocks-error')), findsOneWidget);
      expect(find.byKey(const Key('map-table-t1')), findsOneWidget);
    });
  });
}
