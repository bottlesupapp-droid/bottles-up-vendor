import 'dart:io';

import 'package:bottles_up_vendor/core/ui/bu_coming_soon.dart';
import 'package:bottles_up_vendor/features/inventory/logic/stock_overview_rules.dart';
import 'package:bottles_up_vendor/features/inventory/providers/inventory_providers.dart';
import 'package:bottles_up_vendor/features/inventory/screens/inventory_screen.dart';
import 'package:bottles_up_vendor/features/inventory/screens/stock_overview_screen.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_inventory_backend.dart';

// The stock overview (website 20261122110000_stock_overview.sql; brief section 22: Available / Reserved / Low Stock, most-sold by period). Read only: nothing here may change a
// stock figure. Reserving and issuing by hand and package components are not built, and say so.

late FakeInventoryBackend db;

const owner = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

Map<String, dynamic> row(
  String id, {
  String name = 'Bottle',
  bool tracked = true,
  int? onHand = 10,
  int reserved = 0,
  int handed = 0,
  int? available,
  int sold = 0,
  int? low,
  bool isLow = false,
  bool soldOut = false,
}) => {
  'bottle_id': id,
  'name': name,
  'size': '750ml',
  'category': 'Spirits',
  'tracked': tracked,
  'on_hand': onHand,
  'reserved': reserved,
  'handed_over': handed,
  'available': available ?? (tracked ? (onHand ?? 0) - reserved - handed : null),
  'sold': sold,
  'low_threshold': low,
  'is_low': isLow,
  'is_sold_out': soldOut,
};

StockOverviewItem item(
  String id, {
  String name = 'Bottle',
  bool tracked = true,
  int? onHand = 10,
  int reserved = 0,
  int handed = 0,
  int? available,
  int sold = 0,
  int? low,
  bool isLow = false,
  bool soldOut = false,
}) => parseStockOverviewItem(row(id, name: name, tracked: tracked, onHand: onHand, reserved: reserved, handed: handed, available: available, sold: sold, low: low, isLow: isLow, soldOut: soldOut))!;

Widget host(Widget child) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    inventoryServiceProvider.overrideWithValue(db.service),
    ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published')]),
  ],
  child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
);

Future<void> open(WidgetTester tester, Widget child, {double height = 3200}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openOverview(WidgetTester tester) async {
  await open(tester, InventoryScreen(workspace: manager, clock: () => DateTime(2026, 10, 9, 22)));
  await tapKey(tester, 'stock-overview-open');
}

List<String> rowIds(WidgetTester tester) => [
  for (final e in find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('overview-row-')).evaluate())
    (e.widget.key as ValueKey<String>).value.substring('overview-row-'.length),
];

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  group('Reading a row', () {
    test('a complete row is read as it is', () {
      final i = parseStockOverviewItem(row('b1', name: 'Vodka', onHand: 10, reserved: 2, handed: 3, sold: 7, low: 5))!;
      expect(i.title, 'Vodka · 750ml');
      expect([i.onHand, i.reserved, i.handedOver, i.available, i.sold, i.lowThreshold], [10, 2, 3, 5, 7, 5]);
      expect(i.tracked, isTrue);
      expect(i.category, 'Spirits');
    });

    test('a bottle nobody counted has no on-hand and no available figure, whatever else is in the row', () {
      final i = parseStockOverviewItem({...row('b1', tracked: false, onHand: null), 'on_hand': 4, 'available': 4})!;
      expect(i.tracked, isFalse);
      expect(i.onHand, isNull);
      expect(i.available, isNull);
    });

    test('a row without a bottle is dropped, and a missing figure is zero, never a crash', () {
      expect(parseStockOverviewItem({'name': 'x'}), isNull);
      final i = parseStockOverviewItem({'bottle_id': 'b1', 'tracked': true, 'on_hand': 3})!;
      expect([i.reserved, i.handedOver, i.sold], [0, 0, 0]);
      expect(i.name, 'Bottle');
    });
  });

  group('What each tab lists', () {
    final vodka = item('b1', name: 'Vodka', onHand: 10, reserved: 2, handed: 3, sold: 7); // available 5
    final gin = item('b2', name: 'Gin', tracked: false, onHand: null); // never counted
    final rum = item('b3', name: 'Rum', onHand: 2, reserved: 1, handed: 1, low: 3, isLow: true, soldOut: true); // available 0, sold out
    final whisky = item('b4', name: 'Whisky', onHand: 8, reserved: 4, low: 2); // available 4
    final tequila = item('b5', name: 'Tequila', onHand: 1, reserved: 0, low: 1, isLow: true); // available 1, low
    final brandy = item('b6', name: 'Brandy', onHand: 5, reserved: 5); // available 0, not sold out
    final hidden = item('b7', name: 'Hidden', onHand: 6, soldOut: true); // stock left, but taken off sale by hand
    final all = [vodka, gin, rum, whisky, tequila, brandy, hidden];

    test('Available lists what can still be sold, most first, the uncounted last; not what is sold out or has none left', () {
      expect(itemsFor(OverviewTab.available, all).map((i) => i.name), ['Vodka', 'Whisky', 'Tequila', 'Gin']);
    });

    test('Available breaks a tie by name', () {
      final a = item('x1', name: 'Beta', onHand: 4);
      final b = item('x2', name: 'alpha', onHand: 4);
      final c = item('x3', name: 'Zed', tracked: false, onHand: null);
      final d = item('x4', name: 'Another', tracked: false, onHand: null);
      expect(itemsFor(OverviewTab.available, [a, c, b, d]).map((i) => i.name), ['alpha', 'Beta', 'Another', 'Zed']);
    });

    test('Reserved lists what is promised and not handed over, most first, by name on a tie', () {
      expect(itemsFor(OverviewTab.reserved, all).map((i) => i.name), ['Brandy', 'Whisky', 'Vodka', 'Rum']);
    });

    test('Low stock lists only those at or below their level, the fewest on hand first', () {
      expect(itemsFor(OverviewTab.low, all).map((i) => i.name), ['Tequila', 'Rum']);
    });

    test('choosing for a tab does not change the list it is given', () {
      final before = [...all];
      for (final tab in OverviewTab.values) {
        itemsFor(tab, all);
      }
      expect(all, before);
      expect(itemsFor(OverviewTab.reserved, const []), isEmpty);
    });

    test('each line says what it is, and what is not counted says to count it', () {
      expect(overviewLine(OverviewTab.available, vodka), '5 available to sell · 10 in stock');
      expect(overviewLine(OverviewTab.available, gin), 'Not counted yet. Count it to see how many are left.');
      expect(overviewLine(OverviewTab.reserved, vodka), '2 reserved, not handed over yet · 3 handed over');
      expect(overviewLine(OverviewTab.low, tequila), '1 in stock · low at 1');
    });

    test('an empty tab says why, in words', () {
      expect(overviewEmpty(OverviewTab.available), 'Nothing is available to sell right now.');
      expect(overviewEmpty(OverviewTab.reserved), 'Nothing is reserved. Every bottle sold to a table has been handed over.');
      expect(overviewEmpty(OverviewTab.low), 'Nothing is low.');
    });

    test('the sentence at the top counts reserved bottles and low ones', () {
      expect(overviewSummary(all), '12 bottles are reserved for tables, 2 bottles are low.');
      expect(overviewSummary([item('a', reserved: 1)]), '1 bottle is reserved for tables, nothing is low.');
      expect(overviewSummary([item('a', onHand: 1, low: 1, isLow: true)]), 'Nothing is reserved, 1 bottle is low.');
      expect(overviewSummary([item('a')]), 'Nothing is reserved, nothing is low.');
    });

    test('tabs and periods are found by their label, and an unknown label falls back to the first or the middle one', () {
      expect(OverviewTab.byLabel('Reserved'), OverviewTab.reserved);
      expect(OverviewTab.byLabel('Low stock'), OverviewTab.low);
      expect(OverviewTab.byLabel('nope'), OverviewTab.available);
      expect(SoldPeriod.byLabel('7 days'), SoldPeriod.week);
      expect(SoldPeriod.byLabel('90 days'), SoldPeriod.quarter);
      expect(SoldPeriod.byLabel('nope'), SoldPeriod.month);
    });
  });

  group('Most sold', () {
    test('lists what sold, most first, ties by name, never more than five, and nothing that sold nothing', () {
      final items = [
        item('a', name: 'A', sold: 3),
        item('b', name: 'B', sold: 9),
        item('c', name: 'C', sold: 0),
        item('d', name: 'D', sold: 3),
        item('e', name: 'E', sold: 5),
        item('f', name: 'F', sold: 1),
        item('g', name: 'G', sold: 2),
      ];
      expect(mostSold(items).map((i) => i.name), ['B', 'E', 'A', 'D', 'G']);
      expect(mostSold(items, limit: 2).map((i) => i.name), ['B', 'E']);
      expect(mostSold([item('z')]), isEmpty);
    });

    test('a period is a number of days back from now, and says so', () {
      expect(SoldPeriod.values.map((p) => p.days), [7, 30, 90]);
      final now = DateTime.utc(2026, 11, 16, 12);
      expect(SoldPeriod.week.from(now), DateTime.utc(2026, 11, 9, 12));
      expect(SoldPeriod.quarter.from(now), DateTime.utc(2026, 8, 18, 12));
      expect(soldLine(item('a', sold: 4), SoldPeriod.week), '4 sold in the last 7 days');
    });
  });

  group('The service', () {
    setUp(() => db = FakeInventoryBackend());

    test('asks for the club and the period, and reads the answer', () async {
      db.bottles.add(FakeBottle('b1', 'Vodka', size: '750ml', stock: 10, reserved: 2, handed: 3));
      final from = DateTime.utc(2026, 10, 1);
      final to = DateTime.utc(2026, 10, 31);
      final items = await db.service.overview('v1', from: from, to: to);
      expect(db.calledWith('stock_overview').single, {'p_venue': 'v1', 'p_from': from.toIso8601String(), 'p_to': to.toIso8601String()});
      expect(items.single.available, 5);
    });

    test('with no period it sends none, and the database chooses the last 30 days', () async {
      db.bottles.add(FakeBottle('b1', 'Vodka', stock: 3));
      await db.service.overview('v1');
      expect(db.calledWith('stock_overview').single, {'p_venue': 'v1', 'p_from': null, 'p_to': null});
    });

    test('a server without the function is "not set up", anything else is a load failure, and a refusal never becomes a figure', () async {
      db.missing = true;
      await expectLater(
        db.service.overview('v1'),
        throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', true).having((e) => e.message, 'message', 'The stock figures are not set up on this server yet.')),
      );
      db.missing = false;
      db.offline = true;
      await expectLater(db.service.overview('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', false)));
      db.offline = false;
      db.role = 'server';
      await expectLater(db.service.overview('v1'), throwsA(isA<OpsLoadException>()));
    });
  });

  group('The screen', () {
    setUp(() {
      db = FakeInventoryBackend();
      db.bottles
        ..add(FakeBottle('b1', 'Vodka', size: '750ml', stock: 10, threshold: 5, reserved: 2, handed: 3, soldIn: {7: 2, 30: 5, 90: 9}))
        ..add(FakeBottle('b2', 'Gin'))
        ..add(FakeBottle('b3', 'Rum', size: '1L', stock: 2, threshold: 3, soldOut: true, reserved: 1, handed: 1, soldIn: {30: 2}))
        ..add(FakeBottle('b4', 'Whisky', stock: 8, threshold: 2, reserved: 4, soldIn: {7: 4, 30: 4, 90: 4}));
    });

    testWidgets('Inventory has an Overview button; it opens Available, with the figures from the database and the sentence at the top', (tester) async {
      await openOverview(tester);
      expect(db.calledWith('stock_overview'), hasLength(1));
      expect(db.calledWith('stock_overview').single['p_venue'], 'v1');
      expect(find.descendant(of: find.byType(StockOverviewScreen), matching: find.text('Club A')), findsOneWidget, reason: 'the club is named');
      expect(rowIds(tester), ['b1', 'b4', 'b2'], reason: 'Vodka 5 available, Whisky 4, the uncounted Gin last; Rum is sold out');
    });

    testWidgets('an owner chooses a club first, and the overview is for that club', (tester) async {
      await open(tester, InventoryScreen(workspace: owner, clock: () => DateTime(2026, 10, 9, 22)));
      expect(find.byKey(const Key('stock-overview-open')), findsNothing, reason: 'no club chosen yet');
      await tapKey(tester, 'inventory-club-v1');
      await tapKey(tester, 'stock-overview-open');
      expect(db.calledWith('stock_overview').single['p_venue'], 'v1');
      expect(find.byKey(const Key('overview-row-b1')), findsOneWidget);
    });

    testWidgets('the tabs list what the database counted', (tester) async {
      await openOverview(tester);
      expect(textOf(tester, 'overview-summary'), '7 bottles are reserved for tables, 1 bottle is low.');
      await tapKey(tester, 'overview-tab-Reserved');
      expect(rowIds(tester), ['b4', 'b1', 'b3']);
      expect(find.text('2 reserved, not handed over yet · 3 handed over'), findsOneWidget);
      expect(find.byKey(const Key('overview-soldout-b3')), findsOneWidget, reason: 'Rum is sold out as well as low');
      expect(find.byKey(const Key('overview-soldout-b1')), findsNothing);
      await tapKey(tester, 'overview-tab-Low stock');
      expect(rowIds(tester), ['b3']);
      expect(find.byKey(const Key('overview-low-b3')), findsOneWidget);
      await tapKey(tester, 'overview-tab-Available');
      expect(find.byKey(const Key('overview-row-b3')), findsNothing, reason: 'sold out');
    });

    testWidgets('a tab with nothing says so in words', (tester) async {
      db.bottles
        ..clear()
        ..add(FakeBottle('b1', 'Vodka', stock: 10, threshold: 5));
      await openOverview(tester);
      await tapKey(tester, 'overview-tab-Reserved');
      expect(textOf(tester, 'overview-tab-empty'), 'Nothing is reserved. Every bottle sold to a table has been handed over.');
      await tapKey(tester, 'overview-tab-Low stock');
      expect(textOf(tester, 'overview-tab-empty'), 'Nothing is low.');
    });

    testWidgets('Most sold follows the period: it asks again with the span, and lists what sold in it', (tester) async {
      await openOverview(tester);
      expect(find.byKey(const Key('overview-sold-b1')), findsOneWidget);
      expect(find.text('5 sold in the last 30 days'), findsOneWidget);
      final first = db.calledWith('stock_overview').last;
      expect(DateTime.parse(first['p_to'] as String).difference(DateTime.parse(first['p_from'] as String)).inDays, 30);

      await tapKey(tester, 'overview-period-7 days');
      final week = db.calledWith('stock_overview').last;
      expect(DateTime.parse(week['p_to'] as String).difference(DateTime.parse(week['p_from'] as String)).inDays, 7);
      expect(find.text('2 sold in the last 7 days'), findsOneWidget);
      expect(find.text('4 sold in the last 7 days'), findsOneWidget);
      expect(find.byKey(const Key('overview-sold-b3')), findsNothing);

      await tapKey(tester, 'overview-period-90 days');
      expect(find.text('9 sold in the last 90 days'), findsOneWidget);
    });

    testWidgets('pulling the page down reads the figures again', (tester) async {
      // A short window: the page is pulled down by a quarter of its height to refresh, so a very tall one would need an enormous pull.
      await open(tester, const StockOverviewScreen(venueId: 'v1'), height: 700);
      final before = db.calledWith('stock_overview').length;
      db.bottle('b1').reserved = 5;
      await tester.drag(find.byKey(const Key('overview-list')), const Offset(0, 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(db.calledWith('stock_overview').length, greaterThan(before));
      expect(textOf(tester, 'overview-summary'), '10 bottles are reserved for tables, 1 bottle is low.', reason: 'Vodka now has 5 reserved: 5 + 1 + 4');
    });

    testWidgets('a period in which nothing sold says so', (tester) async {
      for (final b in db.bottles) {
        b.soldIn = {};
      }
      await openOverview(tester);
      expect(textOf(tester, 'overview-sold-empty'), 'Nothing was sold in the last 30 days.');
    });

    testWidgets('the tab chosen stays chosen when the period changes', (tester) async {
      await openOverview(tester);
      await tapKey(tester, 'overview-tab-Reserved');
      await tapKey(tester, 'overview-period-7 days');
      expect(rowIds(tester), ['b4', 'b1', 'b3']);
    });

    testWidgets('Reserve, Issue and Package components say Coming soon and what they will be; none sends anything', (tester) async {
      await openOverview(tester);
      final before = db.calls.length;
      for (final (key, title, words) in [
        ('overview-soon-reserve', 'Reserve', 'Set bottles aside by hand'),
        ('overview-soon-issue', 'Issue', 'take them off the shelf count'),
        ('overview-soon-packages', 'Package components', 'Packages that reserve and issue their parts'),
      ]) {
        expect(find.descendant(of: find.byKey(Key(key)), matching: find.byType(BuComingSoonPill)), findsOneWidget, reason: key);
        await tapKey(tester, key);
        expect(find.text(title), findsWidgets, reason: key);
        expect(find.textContaining(words), findsOneWidget, reason: key);
        await tester.tap(find.byKey(const Key('coming-soon-close')));
        await tester.pumpAndSettle();
      }
      expect(db.calls.length, before, reason: 'nothing was sent');
    });

    testWidgets('looking at the overview changes nothing: only the stock list and the overview are ever asked for', (tester) async {
      await openOverview(tester);
      for (final k in ['overview-tab-Reserved', 'overview-tab-Low stock', 'overview-tab-Available', 'overview-period-7 days', 'overview-period-90 days']) {
        await tapKey(tester, k);
      }
      expect(db.calls.map((c) => c.function).toSet().difference({'stock_list', 'stock_overview'}), isEmpty);
      expect(db.bottle('b1').stock, 10);
    });

    testWidgets('an empty menu, a missing backend, a lost connection and a person without access are said in words', (tester) async {
      db.bottles.clear();
      await open(tester, const StockOverviewScreen(venueId: 'v1', venueName: 'Club A'));
      expect(find.byKey(const Key('overview-empty')), findsOneWidget);

      db.missing = true;
      await open(tester, const StockOverviewScreen(venueId: 'v1'));
      expect(textOf(tester, 'overview-error'), 'The stock figures are not set up on this server yet.');
      expect(find.byKey(const Key('ops-retry')), findsNothing, reason: 'nothing the person can do');

      db.missing = false;
      db.offline = true;
      await open(tester, const StockOverviewScreen(venueId: 'v1'));
      expect(find.byKey(const Key('overview-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsOneWidget);
      db.offline = false;
      db.bottles.add(FakeBottle('b1', 'Vodka', stock: 4));
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('overview-row-b1')), findsOneWidget);

      db.role = 'server';
      await open(tester, const StockOverviewScreen(venueId: 'v1'));
      expect(find.byKey(const Key('overview-error')), findsOneWidget);
    });

    testWidgets('the club\'s name is shown when it is known', (tester) async {
      await open(tester, const StockOverviewScreen(venueId: 'v1', venueName: 'Club A'));
      expect(find.text('Club A'), findsOneWidget);
    });
  });

  // The app calls the database by the names the migration defines. This reads the website repo's file when it is checked out next to this one (the monorepo); on its own it is skipped.
  group('agrees with the website', () {
    final website = Platform.environment['WEBSITE_REPO'] ?? '../bottles-up-website-main';
    final sql = File('$website/supabase/migrations/20261122110000_stock_overview.sql');

    test('the function, its arguments and every column the app reads are defined by the migration', () {
      final text = sql.readAsStringSync();
      expect(text, contains('create function public.stock_overview(p_venue uuid, p_from timestamptz default null, p_to timestamptz default null)'));
      final table = RegExp(r'returns table \(([^)]*)\)', dotAll: true).firstMatch(text)!.group(1)!;
      final columns = RegExp(r'\b([a-z_]+) (?:uuid|text|boolean|int)\b').allMatches(table).map((m) => m.group(1)!).toSet();
      for (final read in ['bottle_id', 'name', 'size', 'category', 'tracked', 'on_hand', 'reserved', 'handed_over', 'available', 'sold', 'low_threshold', 'is_low', 'is_sold_out']) {
        expect(columns, contains(read), reason: read);
      }
      // ...and every key the parser reads is one the fake sends, so the fake cannot drift from what the app reads.
      final fakeKeys = row('x').keys.toSet();
      expect(fakeKeys, columns);
    }, skip: sql.existsSync() ? false : 'website repo is not checked out next to this app');

    test('the app sends exactly the arguments the migration names', () async {
      db = FakeInventoryBackend()..bottles.add(FakeBottle('b1', 'Vodka'));
      await db.service.overview('v1');
      final text = sql.readAsStringSync();
      for (final arg in db.calledWith('stock_overview').single.keys) {
        expect(text, contains(arg), reason: arg);
      }
    }, skip: sql.existsSync() ? false : 'website repo is not checked out next to this app');
  });
}
