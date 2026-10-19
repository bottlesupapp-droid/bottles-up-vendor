import 'package:bottles_up_vendor/features/inventory/logic/inventory_rules.dart';
import 'package:flutter_test/flutter_test.dart';

StockMovement mv(String id, {String bottle = 'b1', String kind = 'receive', int delta = 5, int? before = 10, int after = 15, String? reason}) =>
    StockMovement(id: id, bottleId: bottle, bottleName: 'Vodka', size: '750ml', kind: kind, delta: delta, beforeQty: before, afterQty: after, byName: 'Mia', byMe: false, reason: reason);

void main() {
  group('reading what the database sends', () {
    test('a stock row, tracked and untracked', () {
      final a = parseStockItem({'bottle_id': 'b1', 'name': 'Vodka', 'size': '750ml', 'tracked': true, 'quantity': 12, 'low_threshold': 5, 'is_low': false, 'is_sold_out': false})!;
      expect(a.title, 'Vodka · 750ml');
      expect(a.quantity, 12);
      final b = parseStockItem({'bottle_id': 'b2', 'name': 'Gin', 'tracked': false, 'quantity': null})!;
      expect(b.tracked, isFalse);
      expect(b.quantity, isNull);
      expect(b.title, 'Gin');
      expect(parseStockItem({'name': 'no id'}), isNull);
    });

    test('low is counted', () {
      final items = [
        parseStockItem({'bottle_id': '1', 'is_low': true, 'tracked': true, 'quantity': 1})!,
        parseStockItem({'bottle_id': '2', 'is_low': false, 'tracked': true, 'quantity': 9})!,
        parseStockItem({'bottle_id': '3', 'is_low': true, 'tracked': true, 'quantity': 0})!,
      ];
      expect(lowStockCount(items), 2);
    });

    test('a movement row', () {
      final m = parseMovement({'movement_id': 'm1', 'bottle_name': 'Vodka', 'kind': 'wastage', 'delta': -2, 'before_qty': 34, 'after_qty': 32, 'reason': 'dropped a case', 'by_name': 'Mia', 'by_me': true})!;
      expect(m.sentence, 'Wastage 2 (34 → 32): dropped a case');
      expect(parseMovement({'kind': 'receive'}), isNull);
    });
  });

  group('movements in words', () {
    test('each kind reads as a sentence', () {
      expect(mv('1').sentence, 'Received 5 (10 → 15)');
      expect(mv('2', kind: 'adjust', delta: -3, before: 32, after: 29, reason: 'miscounted').sentence, 'Adjusted -3 (32 → 29): miscounted');
      expect(mv('3', kind: 'adjust', delta: 1, before: 29, after: 30, reason: 'found one').sentence, 'Adjusted +1 (29 → 30): found one');
      expect(mv('4', kind: 'count', delta: -2, before: 30, after: 28).sentence, 'Counted 28 (30 → 28)');
      expect(mv('5', kind: 'count', delta: 0, before: null, after: 6).sentence, 'Counted 6 (first count)');
    });

    test('after a movement the person is told what happened', () {
      expect(moveOutcomeMessage(StockKind.receive, const MoveOutcome(changed: true, before: 10, after: 34), name: 'Vodka'), 'Delivery recorded. Vodka: 34 in stock.');
      expect(moveOutcomeMessage(StockKind.wastage, const MoveOutcome(changed: true, before: 41, after: 4, low: true), name: 'Vodka'), 'Wastage recorded. Vodka: 4 in stock. That is low.');
      expect(moveOutcomeMessage(StockKind.count, const MoveOutcome(changed: true, after: 6), name: 'Gin'), 'Count recorded. Gin: 6 in stock.');
      expect(moveOutcomeMessage(StockKind.receive, const MoveOutcome(changed: false), name: 'Vodka'), 'Already recorded. Nothing was added twice.');
    });
  });

  group('what the history says about changes outside it', () {
    test('movements that chain have no gap', () {
      expect(gapBetween(mv('new', before: 15, after: 20), mv('old', before: 10, after: 15)), isNull);
    });

    test('a lower start means orders took stock in between; a higher start means stock arrived', () {
      expect(gapBetween(mv('new', before: 20, after: 26), mv('old', before: 4, after: 24)), -4);
      expect(gapSentence(-4), '4 taken outside this list (orders)');
      expect(gapBetween(mv('new', before: 30, after: 31), mv('old', before: 4, after: 24)), 6);
      expect(gapSentence(6), '6 added outside this list');
    });

    test('different bottles never compare, and a first count has nothing to compare', () {
      expect(gapBetween(mv('new', bottle: 'b2', before: 20), mv('old', after: 24)), isNull);
      expect(gapBetween(mv('new', before: null, after: 6, kind: 'count'), mv('old', after: 24)), isNull);
    });
  });

  group('what was typed', () {
    test('a delivery is a positive whole number', () {
      expect(checkMovement(StockKind.receive, ' 24 ', '', current: 10).quantity, 24);
      expect(checkMovement(StockKind.receive, '0', '', current: 10).error, 'Enter how many arrived.');
      expect(checkMovement(StockKind.receive, '-5', '', current: 10).error, 'Enter how many arrived.');
      expect(checkMovement(StockKind.receive, 'abc', '', current: 10).error, 'Enter a whole number.');
      expect(checkMovement(StockKind.receive, '', '', current: 10).error, 'Enter a whole number.');
    });

    test('wastage needs a reason and cannot be more than there is', () {
      expect(checkMovement(StockKind.wastage, '2', '', current: 10).error, 'Say what happened to them.');
      expect(checkMovement(StockKind.wastage, '2', 'x', current: 10).error, 'Say what happened to them.');
      expect(checkMovement(StockKind.wastage, '11', 'a flood', current: 10).error, 'Only 10 in stock.');
      expect(checkMovement(StockKind.wastage, '10', 'a flood', current: 10).quantity, 10);
    });

    test('an adjustment takes a plus or a minus, needs a reason and cannot go below nothing', () {
      expect(checkMovement(StockKind.adjust, '+3', 'found some', current: 10).quantity, 3);
      expect(checkMovement(StockKind.adjust, '-3', 'miscounted', current: 10).quantity, -3);
      expect(checkMovement(StockKind.adjust, '0', 'nothing', current: 10).error, 'Enter the plus or minus amount.');
      expect(checkMovement(StockKind.adjust, '-11', 'miscounted', current: 10).error, 'Only 10 in stock.');
      expect(checkMovement(StockKind.adjust, '2', '', current: 10).error, 'Say why the level is being changed.');
    });

    test('a count is any whole number from 0, even for a bottle never counted', () {
      expect(checkMovement(StockKind.count, '0', '', current: 10).quantity, 0);
      expect(checkMovement(StockKind.count, '6', '', current: null).quantity, 6);
      expect(checkMovement(StockKind.count, '-1', '', current: 10).error, 'Enter the amount you counted (0 or more).');
      expect(checkMovement(StockKind.count, 'x', '', current: 10).error, 'Enter the amount you counted (0 or more).');
    });

    test('the others need the bottle to be counted first', () {
      for (final k in [StockKind.receive, StockKind.wastage, StockKind.adjust]) {
        expect(checkMovement(k, '1', 'a reason', current: null).error, 'Count this bottle first: its level is not known yet.', reason: k.id);
      }
    });

    test('nothing absurd, and a reason is not endless', () {
      expect(checkMovement(StockKind.receive, '100001', '', current: 1).error, 'That is more than can be recorded.');
      expect(checkMovement(StockKind.wastage, '1', 'x' * 201, current: 5).error, 'Keep the reason to 200 characters or fewer.');
    });

    test('a low-stock level', () {
      expect(checkThreshold('6'), (level: 6, clear: false, error: null));
      expect(checkThreshold('  ').clear, isTrue);
      expect(checkThreshold('-1').error, isNotNull);
      expect(checkThreshold('1.5').error, isNotNull);
      expect(checkThreshold('100001').error, isNotNull);
      expect(checkThreshold('0').level, 0);
    });
  });
}
