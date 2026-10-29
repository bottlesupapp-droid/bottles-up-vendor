import 'dart:async';

import 'package:bottles_up_vendor/features/owner/logic/venue_profile_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/table_map/logic/table_map_rules.dart';
import 'package:bottles_up_vendor/features/table_map/providers/table_map_providers.dart';
import 'package:bottles_up_vendor/features/table_map/screens/placement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_map_backend.dart';

late FakeTableMapBackend db;

const main1 = FloorRow(floorId: 'f1', label: 'Main room', imageUrl: '');
const terrace = FloorRow(floorId: 'f2', label: 'Terrace', imageUrl: '');

Widget host({FloorRow floor = main1}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        tableMapServiceProvider.overrideWithValue(db.service),
        floorsProvider.overrideWith((ref, venueId) async => const [main1, terrace]),
        venueSetupProvider.overrideWith((ref, venueId) async => const []),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlacementScreen(venueId: 'v1', floor: floor))),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> open(WidgetTester tester, {FloorRow floor = main1, double height = 3600}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(floor: floor));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// A finger down on [key], a frame later it moves in steps, then lifts: how a person drags (the test's own drag moves diagonally first, which no one does on purpose).
Future<void> dragBy(WidgetTester tester, String key, Offset by) async {
  final g = await tester.startGesture(tester.getCenter(find.byKey(Key(key))));
  await tester.pump(const Duration(milliseconds: 20));
  const steps = 8;
  for (var i = 0; i < steps; i++) {
    await g.moveBy(by / steps.toDouble());
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

String status(WidgetTester tester, String table) => tester.widget<Text>(find.byKey(Key('placement-status-$table'))).data!;
String numbers(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('placement-numbers'))).data!;
bool saveEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('placement-save'))).onPressed != null;

void main() {
  setUp(() => db = FakeTableMapBackend());

  testWidgets('lists every table with where it is, draws the placed ones, and has nothing to save yet', (tester) async {
    await open(tester);
    expect(find.text('Place tables · Main room'), findsOneWidget);
    expect(status(tester, 't1'), 'On this floor');
    expect(status(tester, 't2'), 'Not on a floor plan');
    expect(find.byKey(const Key('box-t1')), findsOneWidget);
    expect(find.byKey(const Key('box-t2')), findsNothing);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('a table on another floor says which, and can be moved here', (tester) async {
    db.table('t3')
      ..['floor_id'] = 'f2'
      ..['pos_x'] = 5.0
      ..['pos_y'] = 5.0
      ..['width'] = 10.0
      ..['height'] = 10.0;
    await open(tester);
    expect(status(tester, 't3'), 'On Terrace');
    expect(find.byKey(const Key('box-t3')), findsNothing);
    await tapKey(tester, 'place-t3');
    expect(find.byKey(const Key('box-t3')), findsOneWidget);
    expect(status(tester, 't3'), 'On this floor (not saved yet)');
    await tapKey(tester, 'placement-save');
    expect(db.paramsOf('place_venue_table').single['p_floor'], 'f1');
    expect(db.table('t3')['floor_id'], 'f1');
  });

  testWidgets('putting a table on the floor draws it and Save places it with the numbers shown', (tester) async {
    await open(tester);
    await tapKey(tester, 'place-t2');
    expect(find.byKey(const Key('box-t2')), findsOneWidget);
    expect(status(tester, 't2'), 'On this floor (not saved yet)');
    expect(saveEnabled(tester), isTrue);
    expect(db.paramsOf('place_venue_table'), isEmpty, reason: 'nothing is sent until Save');
    await tapKey(tester, 'placement-save');
    final sent = db.paramsOf('place_venue_table').single;
    expect([sent['p_venue'], sent['p_type'], sent['p_floor']], ['v1', 't2', 'f1']);
    final box = defaultBox(1);
    expect([sent['p_x'], sent['p_y'], sent['p_w'], sent['p_h']], [box.x, box.y, box.w, box.h], reason: 'one table was already on the floor, so this is the second default spot');
    expect(find.text('Saved: 1 table placed.'), findsOneWidget);
    expect(status(tester, 't2'), 'On this floor');
    expect(saveEnabled(tester), isFalse);
    expect(db.table('t2')['floor_id'], 'f1');
  });

  testWidgets('the nudge buttons move and resize the selected table a step at a time, and Save sends exactly the numbers shown', (tester) async {
    await open(tester);
    await tapKey(tester, 'box-t1');
    expect(numbers(tester), 'Booth: 10% across, 20% down, 12% wide, 10% high');
    await tapKey(tester, 'nudge-right');
    await tapKey(tester, 'nudge-right');
    await tapKey(tester, 'nudge-down');
    await tapKey(tester, 'wider');
    await tapKey(tester, 'taller');
    expect(numbers(tester), 'Booth: 12% across, 21% down, 13% wide, 11% high');
    await tapKey(tester, 'nudge-left');
    await tapKey(tester, 'nudge-up');
    await tapKey(tester, 'narrower');
    await tapKey(tester, 'shorter');
    expect(numbers(tester), 'Booth: 11% across, 20% down, 12% wide, 10% high');
    await tapKey(tester, 'nudge-right');
    await tapKey(tester, 'placement-save');
    final sent = db.paramsOf('place_venue_table').single;
    expect([sent['p_x'], sent['p_y'], sent['p_w'], sent['p_h']], [12.0, 20.0, 12.0, 10.0]);
  });

  testWidgets('moving a table back to where it was leaves nothing to save, and Save then changes nothing', (tester) async {
    await open(tester);
    await tapKey(tester, 'box-t1');
    await tapKey(tester, 'nudge-right');
    await tapKey(tester, 'nudge-left');
    expect(saveEnabled(tester), isTrue, reason: 'it was touched');
    await tapKey(tester, 'placement-save');
    expect(find.text('Nothing changed.'), findsOneWidget);
    expect(db.paramsOf('place_venue_table'), isEmpty);
    expect(saveEnabled(tester), isFalse);
  });

  testWidgets('dragging a selected table moves it, and only a selected one', (tester) async {
    await open(tester);
    await dragBy(tester, 'box-t1', const Offset(120, 0));
    expect(saveEnabled(tester), isFalse, reason: 'an unselected table is not moved by accident while scrolling');
    await tapKey(tester, 'box-t1');
    await dragBy(tester, 'box-t1', const Offset(120, 0));
    expect(saveEnabled(tester), isTrue);
    final n = RegExp(r'(\d+)% across, (\d+)% down').firstMatch(numbers(tester))!;
    expect(int.parse(n.group(1)!), greaterThan(10));
    expect(int.parse(n.group(2)!), 20);
  });

  testWidgets('a mostly downward drag moves the table and does not scroll the page', (tester) async {
    await open(tester, height: 800);
    await tapKey(tester, 'box-t1');
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final before = scroll.position.pixels;
    await dragBy(tester, 'box-t1', const Offset(30, 160));
    expect(scroll.position.pixels, before);
    final n = RegExp(r'(\d+)% across, (\d+)% down').firstMatch(numbers(tester))!;
    expect(int.parse(n.group(1)!), greaterThanOrEqualTo(10));
    expect(int.parse(n.group(2)!), greaterThan(20));
  });

  testWidgets('pulling the handle resizes the selected table', (tester) async {
    await open(tester);
    await tapKey(tester, 'box-t1');
    await dragBy(tester, 'resize-t1', const Offset(80, 40));
    final n = RegExp(r'(\d+)% wide, (\d+)% high').firstMatch(numbers(tester))!;
    expect(int.parse(n.group(1)!), greaterThan(12));
    expect(int.parse(n.group(2)!), greaterThan(10));
  });

  testWidgets('a table can be dragged only as far as the picture goes', (tester) async {
    await open(tester);
    await tapKey(tester, 'box-t1');
    await dragBy(tester, 'box-t1', const Offset(-2000, -2000));
    expect(numbers(tester), startsWith('Booth: 0% across, 0% down'));
    await dragBy(tester, 'box-t1', const Offset(5000, 5000));
    expect(numbers(tester), 'Booth: 88% across, 90% down, 12% wide, 10% high');
  });

  testWidgets('after the drag the page scrolls again', (tester) async {
    await open(tester);
    await tapKey(tester, 'box-t1');
    await dragBy(tester, 'box-t1', const Offset(40, 0));
    final list = tester.widget<ListView>(find.byKey(const Key('placement')));
    expect(list.physics, isNot(isA<NeverScrollableScrollPhysics>()));
  });

  testWidgets('taking a table off the floor and saving unplaces it', (tester) async {
    await open(tester);
    await tapKey(tester, 'unplace-t1');
    expect(find.byKey(const Key('box-t1')), findsNothing);
    expect(status(tester, 't1'), 'Taken off (not saved yet)');
    await tapKey(tester, 'placement-save');
    expect(db.paramsOf('unplace_venue_table').single, {'p_venue': 'v1', 'p_type': 't1'});
    expect(db.table('t1')['floor_id'], isNull);
    expect(status(tester, 't1'), 'Not on a floor plan');
  });

  testWidgets('taking a table off and putting it back where it was is no change at all', (tester) async {
    await open(tester);
    await tapKey(tester, 'unplace-t1');
    await tapKey(tester, 'place-t1');
    await tapKey(tester, 'placement-save');
    expect(db.paramsOf('unplace_venue_table'), isEmpty);
    expect(db.paramsOf('place_venue_table').single['p_type'], 't1', reason: 'it came back at a default spot, not where it was');
  });

  testWidgets('leaving with unsaved changes asks first; Keep editing stays, Leave goes', (tester) async {
    await open(tester);
    await tapKey(tester, 'place-t2');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tapKey(tester, 'placement-stay');
    expect(find.byKey(const Key('placement')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapKey(tester, 'placement-leave');
    expect(find.byKey(const Key('placement')), findsNothing);
    expect(find.byKey(const Key('open')), findsOneWidget);
    expect(db.paramsOf('place_venue_table'), isEmpty);
  });

  testWidgets('leaving with nothing changed does not ask', (tester) async {
    await open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsNothing);
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('when one of several changes is refused, the others are saved and the refused one stays with its reason', (tester) async {
    await open(tester);
    await tapKey(tester, 'place-t2');
    await tapKey(tester, 'place-t3');
    db.beforeCall = (f) {
      if (f == 'place_venue_table' && db.paramsOf('place_venue_table').last['p_type'] == 't3') throw PostgrestException(message: 'the table must be at least 2 percent wide and high and fully inside the floor plan', code: 'P0001');
    };
    await tapKey(tester, 'placement-save');
    expect(db.table('t2')['floor_id'], 'f1');
    expect(db.table('t3')['floor_id'], isNull);
    expect(find.text('Sofa: The table must be at least 2 percent wide and high and fully inside the floor plan.'), findsOneWidget);
    expect(status(tester, 't2'), 'On this floor');
    expect(status(tester, 't3'), 'On this floor (not saved yet)');
    expect(saveEnabled(tester), isTrue);
    expect(find.text('Saved: 1 table placed.'), findsNothing);
  });

  testWidgets('a connection failure keeps every change and says what to do', (tester) async {
    await open(tester);
    await tapKey(tester, 'place-t2');
    db.failAll = Exception('socket closed');
    await tapKey(tester, 'placement-save');
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.textContaining('socket'), findsNothing);
    expect(status(tester, 't2'), 'On this floor (not saved yet)');
  });

  testWidgets('a second tap on Save while the first is going saves once', (tester) async {
    await open(tester);
    await tapKey(tester, 'place-t2');
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.tap(find.byKey(const Key('placement-save')));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    gate.complete();
    db.hold = null;
    await tester.pumpAndSettle();
    expect(db.paramsOf('place_venue_table'), hasLength(1));
  });

  testWidgets('leaving while it is saving does not ask and does not lose the save', (tester) async {
    await open(tester);
    await tapKey(tester, 'place-t2');
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.tap(find.byKey(const Key('placement-save')));
    await tester.pump();
    gate.complete();
    db.hold = null;
    await tester.pumpAndSettle();
    expect(db.table('t2')['floor_id'], 'f1');
  });

  testWidgets('a club with no tables says to add them first', (tester) async {
    db.tables.clear();
    await open(tester);
    expect(find.byKey(const Key('placement-none')), findsOneWidget);
  });

  testWidgets('a failed read says so with Try again; someone without access gets no retry', (tester) async {
    db.failLayout = Exception('boom');
    await open(tester);
    expect(find.byKey(const Key('placement-error')), findsOneWidget);
    db.failLayout = null;
    await tapKey(tester, 'placement-retry');
    expect(find.byKey(const Key('placement')), findsOneWidget);
  });

  testWidgets('a server is told their access has ended', (tester) async {
    db.role = 'server';
    await open(tester);
    expect(find.byKey(const Key('placement-error')), findsOneWidget);
    expect(find.byKey(const Key('placement-retry')), findsNothing);
  });
}
