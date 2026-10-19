import 'package:bottles_up_vendor/features/floor/providers/floor_providers.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/owner_home_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../floor/fake_floor_backend.dart';
import 'fake_owner_backend.dart';

late FakeOwnerBackend owner;
late FakeFloorBackend floor;
DateTime? picked;

const ownerWs = Workspace(membershipId: 'm-o', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget home() => ProviderScope(
      key: UniqueKey(),
      overrides: [ownerServiceProvider.overrideWithValue(owner.service), floorServiceProvider.overrideWithValue(floor.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: OwnerHomeScreen(workspace: ownerWs, clock: friday9pm, onOpenVenue: (c, m, v) {}, pickNight: (context, initial) async => picked)),
      ),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(home());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

String valueOf(WidgetTester t, String key) => ((t.widget(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first)) as Text).data!;
String labelOf(WidgetTester t, String key) => (t.widgetList(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).last as Text).data!;

void main() {
  setUp(() {
    owner = FakeOwnerBackend();
    floor = FakeFloorBackend();
    picked = null;
    owner.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A'), myVenue('v2', 'Club B', status: 'published')];
    owner.onVenueRows = (ids) => [
          {'id': 'v1', 'name': 'Club A', 'slug': 'club-a', 'status': 'draft', 'address': '1 Main St'},
          {'id': 'v2', 'name': 'Club B', 'slug': 'club-b', 'status': 'published', 'address': null},
        ];
    owner.handlers['venue_setup_status'] = (_) => partialSetup();
    floor.onList = (p) => p!['p_venue'] == 'v1' ? [bookingRow('a1', guests: 4), bookingRow('a2', guests: 2)] : [bookingRow('b1', guests: 6)];
  });

  testWidgets('starts on tonight, with the ready-made ranges the Floor has and the dates they cover', (tester) async {
    await open(tester);
    expect(find.text('Club Co · Friday Oct 9'), findsOneWidget);
    for (final id in ['tonight', 'next7', 'next30', 'last7']) {
      expect(find.byKey(Key('home-preset-$id')), findsOneWidget, reason: id);
    }
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('home-preset-tonight'))).selected, isTrue);
    expect(find.text('From Fri Oct 9'), findsOneWidget);
    expect(find.text('To Fri Oct 9'), findsOneWidget);
    expect(valueOf(tester, 'home-guests'), '12');
  });

  testWidgets('the next 7 nights: every venue is read for the whole range and the heading says which nights', (tester) async {
    await open(tester);
    await tapKey(tester, 'home-preset-next7');
    expect(find.text('Club Co · Fri Oct 9 to Thu Oct 15'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('home-preset-next7'))).selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('home-preset-tonight'))).selected, isFalse);
    final last = floor.params.reversed.take(2).toList();
    expect({for (final p in last) p!['p_venue']}, {'v1', 'v2'});
    for (final p in last) {
      expect([p!['p_from'], p['p_to']], ['2026-10-09', '2026-10-15']);
    }
    expect(valueOf(tester, 'home-bookings'), '3');
  });

  testWidgets('the next 30 nights and the last 7 are asked for as they are', (tester) async {
    await open(tester);
    await tapKey(tester, 'home-preset-next30');
    expect([floor.params.last!['p_from'], floor.params.last!['p_to']], ['2026-10-09', '2026-11-07']);
    await tapKey(tester, 'home-preset-last7');
    expect([floor.params.last!['p_from'], floor.params.last!['p_to']], ['2026-10-02', '2026-10-08']);
  });

  testWidgets('nights already gone say guests booked, not expected; today and later say expected', (tester) async {
    await open(tester);
    expect(labelOf(tester, 'home-guests'), 'Guests expected');
    await tapKey(tester, 'home-preset-last7');
    expect(labelOf(tester, 'home-guests'), 'Guests booked');
    await tapKey(tester, 'home-preset-next7');
    expect(labelOf(tester, 'home-guests'), 'Guests expected');
  });

  testWidgets('choosing a date: the range follows, no preset is selected, and the heading shows it', (tester) async {
    await open(tester);
    picked = DateTime(2026, 10, 12);
    await tapKey(tester, 'home-pick-to');
    expect(find.text('Club Co · Fri Oct 9 to Mon Oct 12'), findsOneWidget);
    for (final id in ['tonight', 'next7', 'next30', 'last7']) {
      expect(tester.widget<ChoiceChip>(find.byKey(Key('home-preset-$id'))).selected, isFalse, reason: id);
    }
    expect([floor.params.last!['p_from'], floor.params.last!['p_to']], ['2026-10-09', '2026-10-12']);
    picked = DateTime(2026, 10, 10);
    await tapKey(tester, 'home-pick-from');
    expect(find.text('Club Co · Sat Oct 10 to Mon Oct 12'), findsOneWidget);
  });

  testWidgets('cancelling the date picker changes nothing', (tester) async {
    await open(tester);
    final reads = floor.params.length;
    picked = null;
    await tapKey(tester, 'home-pick-from');
    expect(find.text('Club Co · Friday Oct 9'), findsOneWidget);
    expect(floor.params.length, reads);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('home-preset-tonight'))).selected, isTrue);
  });

  testWidgets('an end before the start is said in words, and nothing is read for it', (tester) async {
    await open(tester);
    final reads = floor.params.length;
    picked = DateTime(2026, 10, 7);
    await tapKey(tester, 'home-pick-to');
    expect(find.byKey(const Key('home-range-problem')), findsOneWidget);
    expect(find.text('The end date is before the start date.'), findsOneWidget);
    expect(floor.params.length, reads);
    expect(find.byKey(const Key('home-bookings')), findsNothing, reason: 'no totals for a range that makes no sense');
  });

  testWidgets('more than 93 nights is refused in words', (tester) async {
    await open(tester);
    picked = DateTime(2027, 3, 1);
    await tapKey(tester, 'home-pick-to');
    expect(find.text('Choose at most 93 nights at a time.'), findsOneWidget);
    expect(find.byKey(const Key('home-bookings')), findsNothing);
  });

  testWidgets('a range with too many bookings to total says so instead of adding up a short list', (tester) async {
    floor.onList = (p) => p!['p_venue'] == 'v1' ? [for (var i = 0; i < 1000; i++) bookingRow('a$i', guests: 2)] : [bookingRow('b1', guests: 6)];
    await open(tester);
    await tapKey(tester, 'home-preset-next30');
    expect(find.byKey(const Key('home-cut')), findsOneWidget);
    expect(find.text('One venue has more than 1000 bookings in these nights, so these totals are incomplete. Choose fewer nights.'), findsOneWidget);
    expect(find.text('More than 1000 bookings in these nights. Choose fewer nights.'), findsOneWidget);
    expect(valueOf(tester, 'home-guests'), '6', reason: 'only the venue that could be read completely is added up');
    expect(find.byKey(const Key('home-incomplete')), findsNothing);
  });

  testWidgets('999 bookings are not cut off', (tester) async {
    floor.onList = (p) => p!['p_venue'] == 'v1' ? [for (var i = 0; i < 999; i++) bookingRow('a$i', guests: 1)] : <Map<String, dynamic>>[];
    await open(tester);
    await tapKey(tester, 'home-preset-next30');
    expect(find.byKey(const Key('home-cut')), findsNothing);
    expect(valueOf(tester, 'home-guests'), '999');
  });

  testWidgets('a venue that cannot be read for a range says so in words that fit, and tonight keeps its own wording', (tester) async {
    floor.onList = (p) => p!['p_venue'] == 'v1' ? throw Exception('offline') : [bookingRow('b1', guests: 6)];
    await open(tester);
    expect(find.text("Tonight's bookings could not be loaded."), findsOneWidget);
    await tapKey(tester, 'home-preset-next7');
    expect(find.text('Bookings for these nights could not be loaded.'), findsOneWidget);
    expect(find.text("Tonight's bookings could not be loaded."), findsNothing);
    expect(find.byKey(const Key('home-incomplete')), findsOneWidget);
  });
}
