import 'package:bottles_up_vendor/core/ui/bu_coming_soon.dart';
import 'package:bottles_up_vendor/features/door/providers/door_providers.dart';
import 'package:bottles_up_vendor/features/door/screens/door_guests_screen.dart';
import 'package:bottles_up_vendor/features/vip/providers/vip_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../vip/fake_vip_backend.dart';
import 'fake_door_backend.dart';

// The door list's filters (brief section 18: "Filters: Tickets · Booth Guests · VIP · Invited · Special Guests"). Tickets is the real list and VIP opens the real VIP lookup. Booth guests,
// Invited and Special guests have no data behind them yet, so each says "Coming soon" instead of showing an empty list that would look like nobody is invited.

late FakeDoorBackend door;
late FakeVipBackend vip;

Future<void> open(WidgetTester tester, {String? venueId}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [doorServiceProvider.overrideWithValue(door.service), vipServiceProvider.overrideWithValue(vip.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: DoorGuestsScreen(membershipId: 'm1', venueId: venueId, debounce: const Duration(milliseconds: 10)))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    door = FakeDoorBackend();
    vip = FakeVipBackend();
    door.handlers['door_events'] = (_) => [eventRow()];
  });

  testWidgets('the five filters are there in the brief\'s order, and Tickets is the one in use', (tester) async {
    await open(tester, venueId: 'v1');
    final keys = ['door-filter-tickets', 'door-filter-booth', 'door-filter-vip', 'door-filter-invited', 'door-filter-special'];
    for (final k in keys) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    final xs = [for (final k in keys) tester.getTopLeft(find.byKey(Key(k))).dx];
    expect(xs, [...xs]..sort(), reason: 'in order, left to right');
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('door-filter-tickets'))).selected, isTrue);
  });

  testWidgets('Booth guests, Invited and Special guests say Coming soon, and say what they will be', (tester) async {
    await open(tester, venueId: 'v1');
    expect(find.descendant(of: find.byKey(const Key('door-filter-booth')), matching: find.byType(BuComingSoonPill)), findsOneWidget);
    for (final (key, title, words) in [
      ('door-filter-booth', 'Booth guests', 'checked in one by one'),
      ('door-filter-invited', 'Invited', 'who do not need a ticket'),
      ('door-filter-special', 'Special guests', 'Complimentary'),
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets, reason: key);
      expect(find.textContaining(words), findsOneWidget, reason: key);
      await tester.tap(find.byKey(const Key('coming-soon-close')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('VIP opens the VIP lookup where the club is known', (tester) async {
    await open(tester, venueId: 'v1');
    expect(find.descendant(of: find.byKey(const Key('door-filter-vip')), matching: find.byType(BuComingSoonPill)), findsNothing);
    await tester.tap(find.byKey(const Key('door-filter-vip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lookup-query')), findsOneWidget);
  });

  testWidgets('without a club, VIP says Coming soon instead of opening a lookup that cannot work', (tester) async {
    await open(tester);
    expect(find.descendant(of: find.byKey(const Key('door-filter-vip')), matching: find.byType(BuComingSoonPill)), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('door-filter-vip')));
    await tester.tap(find.byKey(const Key('door-filter-vip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coming-soon-close')), findsOneWidget);
    expect(find.byKey(const Key('lookup-query')), findsNothing);
  });

  testWidgets('the Guests screen shows "Inside now" where exits are tracked, and "checked in" where they are not', (tester) async {
    door.handlers['door_occupancy'] =
        (_) => [
          {'tracking': true, 'admitted': 5, 'exited': 1, 'inside': 4},
        ];
    await open(tester, venueId: 'v1');
    expect((tester.widget(find.byKey(const Key('occupancy-headline'))) as Text).data, 'Inside now: 4');

    door.handlers['door_occupancy'] =
        (_) => [
          {'tracking': false, 'admitted': 5, 'exited': 0, 'inside': 5},
        ];
    await open(tester, venueId: 'v1');
    expect((tester.widget(find.byKey(const Key('occupancy-headline'))) as Text).data, 'Total checked in: 5');
  });
}
