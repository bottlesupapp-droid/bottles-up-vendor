import 'package:bottles_up_vendor/features/inventory/logic/inventory_rules.dart';
import 'package:bottles_up_vendor/features/inventory/providers/inventory_providers.dart';
import 'package:bottles_up_vendor/features/inventory/screens/inventory_screen.dart';
import 'package:bottles_up_vendor/features/inventory/screens/stock_ledger_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_inventory_backend.dart';

late FakeInventoryBackend db;

const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

DateTime fridayNight() => DateTime(2026, 10, 9, 22, 0);

Widget host(Widget child) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        inventoryServiceProvider.overrideWithValue(db.service),
        ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')]),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child, {double height = 3000}) async {
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

Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String levelOf(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('stock-level-$id'))).data!;

Widget inventory([Workspace w = manager]) => InventoryScreen(workspace: w, clock: fridayNight);

void main() {
  setUp(() {
    db = FakeInventoryBackend();
    db.bottles
      ..add(FakeBottle('b1', 'Vodka', size: '750ml', stock: 10, threshold: 5))
      ..add(FakeBottle('b2', 'Gin'))
      ..add(FakeBottle('b3', 'Rum', size: '1L', stock: 2, threshold: 3, soldOut: true));
  });

  group('The stock', () {
    testWidgets('lists the bottles, low ones first, with levels and what is not counted yet', (tester) async {
      await open(tester, inventory());
      expect(db.calledWith('stock_list').first, {'p_venue': 'v1'});
      expect(levelOf(tester, 'b1'), 'In stock: 10 · low at 5');
      expect(levelOf(tester, 'b2'), 'Not counted yet');
      expect(levelOf(tester, 'b3'), 'In stock: 2 · low at 3');
      expect(find.byKey(const Key('stock-low-b3')), findsOneWidget);
      expect(find.byKey(const Key('stock-low-b1')), findsNothing);
      expect(find.byKey(const Key('stock-soldout-b3')), findsNothing, reason: 'low is shown instead');
      expect(tester.getTopLeft(find.byKey(const Key('stock-b3'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('stock-b1'))).dy));
      expect(tester.widget<Text>(find.byKey(const Key('inventory-summary'))).data, '1 bottle is low.');
    });

    testWidgets('an empty menu, a missing backend and a person without access are said in words', (tester) async {
      db.bottles.clear();
      await open(tester, inventory());
      expect(find.byKey(const Key('inventory-empty')), findsOneWidget);
      db.missing = true;
      await open(tester, inventory());
      expect(find.byKey(const Key('inventory-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.role = 'server';
      await open(tester, inventory());
      expect(find.byKey(const Key('inventory-error')), findsOneWidget);
    });
  });

  group('Recording a movement', () {
    testWidgets('a delivery: the amount is checked, then sent with a key, and the level and the message update', (tester) async {
      await open(tester, inventory());
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-receive');
      expect(tester.widget<Text>(find.byKey(const Key('movement-current'))).data, 'In stock now: 10');
      await tapKey(tester, 'movement-save');
      expect(find.text('Enter a whole number.'), findsOneWidget);
      expect(db.calledWith('stock_move'), isEmpty);
      await typeIn(tester, 'movement-quantity', '24');
      await tapKey(tester, 'movement-save');
      expect(find.text('Delivery recorded. Vodka: 34 in stock.'), findsOneWidget);
      final sent = db.calledWith('stock_move').single;
      expect(sent['p_kind'], 'receive');
      expect(sent['p_quantity'], 24);
      expect(sent['p_night'], '2026-10-09');
      expect((sent['p_client_key'] as String).isNotEmpty, isTrue);
      expect(levelOf(tester, 'b1'), 'In stock: 34 · low at 5');
    });

    testWidgets('wastage needs a reason and cannot be more than there is', (tester) async {
      await open(tester, inventory());
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-wastage');
      await typeIn(tester, 'movement-quantity', '11');
      await typeIn(tester, 'movement-reason', 'a flood');
      await tapKey(tester, 'movement-save');
      expect(find.text('Only 10 in stock.'), findsOneWidget);
      await typeIn(tester, 'movement-quantity', '6');
      await typeIn(tester, 'movement-reason', '');
      await tapKey(tester, 'movement-save');
      expect(find.text('Say what happened to them.'), findsOneWidget);
      await typeIn(tester, 'movement-reason', 'dropped a case');
      await tapKey(tester, 'movement-save');
      expect(find.text('Wastage recorded. Vodka: 4 in stock. That is low.'), findsOneWidget);
      expect(db.calledWith('stock_move').single['p_reason'], 'dropped a case');
      expect(find.byKey(const Key('stock-low-b1')), findsOneWidget);
    });

    testWidgets('an adjustment takes a minus sign', (tester) async {
      await open(tester, inventory());
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-adjust');
      await typeIn(tester, 'movement-quantity', '-3');
      await typeIn(tester, 'movement-reason', 'miscounted last week');
      await tapKey(tester, 'movement-save');
      expect(db.calledWith('stock_move').single['p_quantity'], -3);
      expect(levelOf(tester, 'b1'), 'In stock: 7 · low at 5');
    });

    testWidgets('the first count starts tracking a bottle that had no level', (tester) async {
      await open(tester, inventory());
      await tapKey(tester, 'stock-b2');
      await tapKey(tester, 'stock-action-count');
      expect(tester.widget<Text>(find.byKey(const Key('movement-current'))).data, 'Not counted yet.');
      await typeIn(tester, 'movement-quantity', '6');
      await tapKey(tester, 'movement-save');
      expect(find.text('Count recorded. Gin: 6 in stock.'), findsOneWidget);
      expect(levelOf(tester, 'b2'), 'In stock: 6');
    });

    testWidgets('an uncounted bottle cannot be received into until it has been counted', (tester) async {
      await open(tester, inventory());
      await tapKey(tester, 'stock-b2');
      await tapKey(tester, 'stock-action-receive');
      await typeIn(tester, 'movement-quantity', '5');
      await tapKey(tester, 'movement-save');
      expect(find.text('Count this bottle first: its level is not known yet.'), findsOneWidget);
      expect(db.calledWith('stock_move'), isEmpty);
    });

    testWidgets('backing out records nothing', (tester) async {
      await open(tester, inventory());
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-receive');
      await tapKey(tester, 'movement-back');
      expect(db.calledWith('stock_move'), isEmpty);
    });

    testWidgets('a lost connection offers Try again, and trying again with the same key never adds it twice', (tester) async {
      await open(tester, inventory());
      db.loseNextAnswer = true;
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-receive');
      await typeIn(tester, 'movement-quantity', '12');
      await tapKey(tester, 'movement-save');
      expect(find.text('That could not be recorded. Check your connection and try again.'), findsOneWidget);
      expect(db.bottle('b1').stock, 22, reason: 'it did arrive, though the answer was lost');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(db.bottle('b1').stock, 22, reason: 'still 22: the retry carried the same key');
      expect(db.movements, hasLength(1));
      expect(db.calledWith('stock_move').map((c) => c['p_client_key']).toSet(), hasLength(1));
      expect(find.text('Already recorded. Nothing was added twice.'), findsOneWidget);
    });

    testWidgets('setting and clearing a low-stock level', (tester) async {
      await open(tester, inventory());
      await tapKey(tester, 'stock-b2');
      await tapKey(tester, 'stock-action-threshold');
      await typeIn(tester, 'text-field', 'many');
      await tapKey(tester, 'dialog-confirm');
      expect(find.textContaining('Enter a whole number from 0 to 100000'), findsOneWidget);
      await typeIn(tester, 'text-field', '4');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Low-stock level saved.'), findsOneWidget);
      expect(db.bottle('b2').threshold, 4);
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-threshold');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Level cleared.'), findsOneWidget);
      expect(db.bottle('b1').threshold, isNull);
    });
  });

  group('The history', () {
    testWidgets('shows each change with who made it and why, and says when stock moved outside the list', (tester) async {
      await open(tester, inventory());
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-receive');
      await typeIn(tester, 'movement-quantity', '5');
      await tapKey(tester, 'movement-save');
      db.bottle('b1').stock = 8;
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-wastage');
      await typeIn(tester, 'movement-quantity', '1');
      await typeIn(tester, 'movement-reason', 'spilt at the bar');
      await tapKey(tester, 'movement-save');
      await tapKey(tester, 'stock-b1');
      await tapKey(tester, 'stock-action-history');
      expect(find.text('Wastage 1 (8 → 7): spilt at the bar'), findsOneWidget);
      expect(find.text('Received 5 (10 → 15)'), findsOneWidget);
      expect(find.textContaining('You ·'), findsNWidgets(2));
      expect(find.text('7 taken outside this list (orders)'), findsOneWidget, reason: '15 became 8 between the two');
      expect(db.calledWith('stock_movements').last['p_bottle'], 'b1');
    });

    testWidgets('the club\'s whole history names the bottle on each line; empty is said in words', (tester) async {
      await tester.pumpWidget(host(const StockLedgerScreen(venueId: 'v1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ledger-empty')), findsOneWidget);
      await db.service.move('v1', 'b1', StockKind.receive, 5, clientKey: 'a');
      await tester.pumpWidget(host(const StockLedgerScreen(venueId: 'v1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Vodka · 750ml: Received 5'), findsOneWidget);
    });

    testWidgets('a long history loads earlier entries a page at a time', (tester) async {
      for (var i = 0; i < 60; i++) {
        await db.service.move('v1', 'b1', StockKind.receive, 1, clientKey: 'k$i');
      }
      await open(tester, const StockLedgerScreen(venueId: 'v1', bottleId: 'b1', title: 'Vodka'), height: 14000);
      expect(find.byKey(const Key('ledger-more')), findsOneWidget);
      expect(find.byKey(const Key('movement-m0')), findsNothing);
      await tapKey(tester, 'ledger-more');
      expect(find.byKey(const Key('movement-m0')), findsOneWidget);
      expect(find.byKey(const Key('ledger-more')), findsNothing);
    });

    testWidgets('a failed history load says so and can be retried', (tester) async {
      db.offline = true;
      await open(tester, const StockLedgerScreen(venueId: 'v1'));
      expect(find.byKey(const Key('ledger-error')), findsOneWidget);
      db.offline = false;
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('ledger-empty')), findsOneWidget);
    });
  });

  group('The owner', () {
    testWidgets('chooses a club first, then sees its stock, and can change club', (tester) async {
      await open(tester, inventory(owner));
      expect(find.byKey(const Key('inventory-pick-club')), findsOneWidget);
      expect(db.calledWith('stock_list'), isEmpty);
      await tapKey(tester, 'inventory-club-v2');
      expect(db.calledWith('stock_list').first, {'p_venue': 'v2'});
      expect(find.byKey(const Key('inventory-list')), findsOneWidget);
      await tapKey(tester, 'inventory-change-club');
      expect(find.byKey(const Key('inventory-pick-club')), findsOneWidget);
    });
  });
}
