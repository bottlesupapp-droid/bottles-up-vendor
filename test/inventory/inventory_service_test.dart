import 'package:bottles_up_vendor/features/inventory/logic/inventory_rules.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_inventory_backend.dart';

void main() {
  late FakeInventoryBackend db;
  setUp(() {
    db = FakeInventoryBackend();
    db.bottles
      ..add(FakeBottle('b1', 'Vodka', size: '750ml', stock: 10))
      ..add(FakeBottle('b2', 'Gin'))
      ..add(FakeBottle('b3', 'Rum', stock: 2, threshold: 3));
  });

  Future<void> expectRefusal(Future<Object?> f, String message) =>
      expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));

  test('the stock of a club, low ones first', () async {
    final items = await db.service.list('v1');
    expect(db.calledWith('stock_list').single, {'p_venue': 'v1'});
    expect(items.map((i) => i.name), ['Rum', 'Gin', 'Vodka']);
    expect(items.first.isLow, isTrue);
    expect(items.firstWhere((i) => i.name == 'Gin').tracked, isFalse);
  });

  test('a movement sends the club, the bottle, the kind, the amount, the trimmed reason and the key', () async {
    final o = await db.service.move('v1', 'b1', StockKind.wastage, 2, reason: ' dropped a case ', clientKey: 'k1', night: '2026-10-09');
    expect(db.calledWith('stock_move').single, {
      'p_venue': 'v1',
      'p_bottle': 'b1',
      'p_kind': 'wastage',
      'p_quantity': 2,
      'p_reason': 'dropped a case',
      'p_note': null,
      'p_client_key': 'k1',
      'p_night': '2026-10-09',
    });
    expect((o.changed, o.before, o.after), (true, 10, 8));
  });

  test('the same key twice is one movement', () async {
    await db.service.move('v1', 'b1', StockKind.receive, 12, clientKey: 'k1');
    final again = await db.service.move('v1', 'b1', StockKind.receive, 12, clientKey: 'k1');
    expect(again.changed, isFalse);
    expect(db.bottle('b1').stock, 22);
    expect(db.movements, hasLength(1));
  });

  test('a lost answer then a retry with the same key does not add it twice', () async {
    db.loseNextAnswer = true;
    await expectRefusal(db.service.move('v1', 'b1', StockKind.receive, 12, clientKey: 'k1'), 'That could not be recorded. Check your connection and try again.');
    expect(db.bottle('b1').stock, 22, reason: 'it did arrive');
    final retry = await db.service.move('v1', 'b1', StockKind.receive, 12, clientKey: 'k1');
    expect(retry.changed, isFalse);
    expect(db.bottle('b1').stock, 22);
  });

  test('refusals are the database\'s own sentences', () async {
    await expectRefusal(db.service.move('v1', 'b1', StockKind.wastage, 11, reason: 'a flood', clientKey: 'k'), 'Only 10 in stock.');
    await expectRefusal(db.service.move('v1', 'b2', StockKind.receive, 5, clientKey: 'k'), 'This bottle has not been counted yet: count it first.');
    await expectRefusal(db.service.move('v1', 'b1', StockKind.adjust, 2, clientKey: 'k'), 'Say why the level is being changed.');
    await expectRefusal(db.service.move('v1', 'nope', StockKind.receive, 5, clientKey: 'k'), "You don't have access to do that.");
    db.role = 'server';
    await expectRefusal(db.service.move('v1', 'b1', StockKind.receive, 5, clientKey: 'k'), "You don't have access to do that.");
    await expectLater(db.service.list('v1'), throwsA(isA<OpsLoadException>()));
  });

  test('a count starts tracking a bottle', () async {
    final o = await db.service.move('v1', 'b2', StockKind.count, 6, clientKey: 'k');
    expect((o.before, o.after), (null, 6));
    expect(db.bottle('b2').stock, 6);
  });

  test('a low-stock level is set and cleared', () async {
    await db.service.setThreshold('v1', 'b1', 5);
    expect(db.bottle('b1').threshold, 5);
    expect(db.calledWith('stock_set_threshold').single, {'p_venue': 'v1', 'p_bottle': 'b1', 'p_threshold': 5});
    await db.service.setThreshold('v1', 'b1', null);
    expect(db.bottle('b1').threshold, isNull);
    await expectRefusal(db.service.setThreshold('v1', 'b1', -1), 'Enter a low-stock level from 0 to 100000.');
  });

  test('the history: a bottle\'s, or the club\'s, newest first, paged by time', () async {
    await db.service.move('v1', 'b1', StockKind.receive, 1, clientKey: 'a');
    await db.service.move('v1', 'b3', StockKind.receive, 1, clientKey: 'b');
    await db.service.move('v1', 'b1', StockKind.receive, 1, clientKey: 'c');
    final all = await db.service.movements('v1');
    expect(all.map((m) => m.id), ['m2', 'm1', 'm0']);
    final one = await db.service.movements('v1', bottleId: 'b1');
    expect(db.calledWith('stock_movements').last['p_bottle'], 'b1');
    expect(one.map((m) => m.id), ['m2', 'm0']);
    final older = await db.service.movements('v1', before: all[1].createdAt);
    expect(older.map((m) => m.id), ['m0']);
    expect(db.calledWith('stock_movements').last['p_before'], all[1].createdAt!.toUtc().toIso8601String());
  });

  test('a backend without stock says it is not available yet; a dropped connection says to try again', () async {
    db.missing = true;
    await expectLater(db.service.list('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    db.missing = false;
    db.offline = true;
    await expectLater(db.service.movements('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
  });
}
