import 'package:bottles_up_vendor/features/table_service/logic/bottle_orders_rules.dart';
import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const patron = MenuBottle(id: 'b1', name: 'Patron', size: '750ml', category: 'Tequila', priceCents: 25000, leftCount: 5);
const goose = MenuBottle(id: 'b2', name: 'Grey Goose', priceCents: 18000);
const gone = MenuBottle(id: 'b3', name: 'Hennessy', priceCents: 30000, leftCount: 0);
const menu = [patron, goose, gone];

OrderLine line({int qty = 5, int delivered = 0, bool known = true, ServiceState state = ServiceState.ready, LinePayment pay = LinePayment.paid, bool cancelled = false}) => OrderLine(
      lineId: 'l1',
      bookingId: 'bk',
      bottleName: 'Patron',
      size: '750ml',
      quantity: qty,
      unitPriceCents: 1000,
      lineTotalCents: 1000 * qty,
      isAddon: false,
      payment: pay,
      state: state,
      orderedAt: DateTime(2026, 10, 9, 20),
      cancelledAt: cancelled ? DateTime(2026, 10, 9, 21) : null,
      deliveredQuantity: delivered,
      deliveryKnown: known,
    );

void main() {
  group('the menu', () {
    test('a row is read: name, size, category, price and how many are left', () {
      final m = parseMenuBottle({'bottle_id': 'b1', 'name': 'Patron', 'size': '750ml', 'category': 'Tequila', 'price_cents': 25000, 'left_count': 5})!;
      expect((m.id, m.title, m.category, m.priceCents, m.leftCount), ('b1', 'Patron 750ml', 'Tequila', 25000, 5));
    });

    test('a bottle the club does not count has no number; one with none left is sold out by count', () {
      expect(parseMenuBottle({'bottle_id': 'b', 'name': 'x', 'price_cents': 100, 'left_count': null})!.leftCount, isNull);
      expect(goose.soldOutByCount, isFalse);
      expect(gone.soldOutByCount, isTrue);
      expect(patron.soldOutByCount, isFalse);
    });

    test('a row without an id, a name or a price is dropped, and so is a negative price', () {
      expect(parseMenuBottle({'name': 'x', 'price_cents': 100}), isNull);
      expect(parseMenuBottle({'bottle_id': 'b', 'price_cents': 100}), isNull);
      expect(parseMenuBottle({'bottle_id': 'b', 'name': 'x'}), isNull);
      expect(parseMenuBottle({'bottle_id': 'b', 'name': 'x', 'price_cents': -1}), isNull);
      expect(parseMenuBottle({'bottle_id': '', 'name': 'x', 'price_cents': 1}), isNull);
    });

    test('the most that can be chosen is what is left, or 99 when the club does not count', () {
      expect(patron.most, 5);
      expect(goose.most, maxPerBottle);
      expect(gone.most, 0);
      expect(const MenuBottle(id: 'x', name: 'x', priceCents: 1, leftCount: 500).most, maxPerBottle);
      expect(const MenuBottle(id: 'x', name: 'x', priceCents: 1, leftCount: -3).most, 0);
    });
  });

  group('the basket', () {
    test('counts only positive amounts and prices them before tax', () {
      final b = {'b1': 2, 'b2': 1, 'b3': 0};
      expect(basketCount(b), 3);
      expect(basketSubtotalCents(menu, b), 2 * 25000 + 18000);
      expect(basketCount({'b1': -2}), 0);
      expect(basketSubtotalCents(menu, {'unknown': 4}), 0);
    });

    test('setting a quantity keeps it between 0 and what the menu allows, and 0 removes it', () {
      expect(withQuantity(menu, {}, 'b1', 3), {'b1': 3});
      expect(withQuantity(menu, {}, 'b1', 9), {'b1': 5});
      expect(withQuantity(menu, {'b1': 3}, 'b1', 0), isEmpty);
      expect(withQuantity(menu, {'b1': 3}, 'b1', -4), isEmpty);
      expect(withQuantity(menu, {}, 'b3', 1), isEmpty, reason: 'none left');
      expect(withQuantity(menu, {}, 'nope', 1), isEmpty, reason: 'not on the menu');
      expect(withQuantity(menu, {}, 'b2', 500), {'b2': maxPerBottle});
    });

    test('after the menu is read again, what is gone is dropped and what is short is cut to what is left', () {
      const fresh = [MenuBottle(id: 'b1', name: 'Patron', priceCents: 25000, leftCount: 2), MenuBottle(id: 'b2', name: 'Grey Goose', priceCents: 18000)];
      expect(pruneBasket(fresh, {'b1': 4, 'b2': 1, 'b3': 2}), {'b1': 2, 'b2': 1});
      expect(pruneBasket(fresh, {'b1': 0}), isEmpty);
    });

    test('what is wrong with a basket, in words', () {
      expect(basketProblem(menu, {}), 'Choose at least one bottle.');
      expect(basketProblem(menu, {'b1': 0}), 'Choose at least one bottle.');
      expect(basketProblem(menu, {'b1': 6}), 'Only 5 of Patron 750ml are left.');
      expect(basketProblem([const MenuBottle(id: 'b1', name: 'Patron', priceCents: 1, leftCount: 1)], {'b1': 2}), 'Only 1 of Patron is left.');
      expect(basketProblem(menu, {'zzz': 1}), 'One of the chosen bottles is no longer on the menu.');
      expect(basketProblem(menu, {'b1': 5, 'b2': 40}), isNull);
    });

    test('the request holds only what was chosen, in the menu\'s order, with the table', () {
      expect(basketRequest(menu, {'b2': 1, 'b1': 2, 'b3': 0}), [
        {'bottle_id': 'b1', 'quantity': 2},
        {'bottle_id': 'b2', 'quantity': 1},
      ]);
      expect(addBottlesBody('bk', menu, {'b2': 3}), {
        'booking_id': 'bk',
        'bottles': [
          {'bottle_id': 'b2', 'quantity': 3},
        ],
      });
    });
  });

  group('a failed add says what happened in plain words', () {
    test('a refusal is the function\'s own sentence, with a full stop', () {
      expect(addBottlesFailure(status: 409, message: 'this table has already been closed out'), 'This table has already been closed out.');
      expect(addBottlesFailure(status: 409, message: 'Not enough "Patron" left in stock'), 'Not enough "Patron" left in stock.');
      expect(addBottlesFailure(status: 400, message: 'One of the selected bottles is no longer available'), 'One of the selected bottles is no longer available.');
      expect(addBottlesFailure(status: 409, message: 'Already stops.'), 'Already stops.');
      expect(addBottlesFailure(status: 409), 'The bottles could not be added.');
    });

    test('no access, signed out and not found have their own sentences', () {
      expect(addBottlesFailure(status: 403, message: 'Forbidden'), "You don't have access to add bottles to this table.");
      expect(addBottlesFailure(status: 401), startsWith('Your sign-in has ended.'));
      expect(addBottlesFailure(status: 404, message: 'Booking not found'), 'This booking could not be found.');
    });

    test('no answer, or a server failure, says the bottles may be on the table and to look before trying again', () {
      for (final s in [addBottlesFailure(), addBottlesFailure(status: 500, message: 'Failed to add bottles'), addBottlesFailure(status: 502)]) {
        expect(s, contains('table\'s orders'));
        expect(s, contains('nothing is added twice'));
        expect(s, isNot(contains('Failed')));
      }
    });

    test('the outcome is unknown only when nothing answered or the server failed; a refusal happened before anything was added', () {
      expect(addBottlesOutcomeUnknown(null), isTrue);
      expect(addBottlesOutcomeUnknown(500), isTrue);
      expect(addBottlesOutcomeUnknown(503), isTrue);
      for (final s in [400, 401, 403, 404, 409]) {
        expect(addBottlesOutcomeUnknown(s), isFalse, reason: '$s');
      }
    });

    test('a refusal about stock or an unavailable bottle means the menu is out of date', () {
      expect(refusalMeansStaleMenu('One of the selected bottles is no longer available.'), isTrue);
      expect(refusalMeansStaleMenu('Not enough "Patron" left in stock.'), isTrue);
      expect(refusalMeansStaleMenu('This table has already been closed out.'), isFalse);
    });

    test('the confirmation says how many, that it is due at the club, and the price before tax', () {
      expect(addedMessage(3, 54000), 'Added 3 bottles. They are due at the club (\$540.00 before tax).');
      expect(addedMessage(1, 25000), 'Added 1 bottle. It is due at the club (\$250.00 before tax).');
    });
  });

  group('partial delivery', () {
    test('how many are left to hand over, never below zero', () {
      expect(remainingToDeliver(line(qty: 5, delivered: 2)), 3);
      expect(remainingToDeliver(line(qty: 5, delivered: 5)), 0);
      expect(remainingToDeliver(line(qty: 5, delivered: 9)), 0);
    });

    test('Deliver some is offered on a Ready or On the way line with at least two bottles still to hand over', () {
      expect(canDeliverPart(line()), isTrue);
      expect(canDeliverPart(line(state: ServiceState.pickedUp)), isTrue);
      expect(canDeliverPart(line(qty: 5, delivered: 3)), isTrue, reason: 'two left');
      expect(canDeliverPart(line(qty: 5, delivered: 4)), isFalse, reason: 'one left is the ordinary Delivered button');
      expect(canDeliverPart(line(qty: 1)), isFalse);
      expect(canDeliverPart(line(qty: 2)), isTrue);
    });

    test('...not before it is ready, not once delivered, not when cancelled or unpaid online', () {
      expect(canDeliverPart(line(state: ServiceState.awaitingPrep)), isFalse);
      expect(canDeliverPart(line(state: ServiceState.preparing)), isFalse);
      expect(canDeliverPart(line(state: ServiceState.served)), isFalse);
      expect(canDeliverPart(line(cancelled: true)), isFalse);
      expect(canDeliverPart(line(pay: LinePayment.pendingPayment)), isFalse);
    });

    test('...and never when the database did not give the delivered count (nothing is guessed)', () {
      expect(canDeliverPart(line(known: false)), isFalse);
    });

    test('the delivered count is shown while a line is part way, never when nothing was delivered, it is done, or the count is unknown', () {
      expect(deliveredLabel(line(delivered: 2)), '2 of 5 delivered');
      expect(deliveredLabel(line(delivered: 0)), isNull);
      expect(deliveredLabel(line(delivered: 5, state: ServiceState.served)), isNull);
      expect(deliveredLabel(line(delivered: 2, known: false)), isNull);
      expect(deliveredLabel(line(delivered: 2, cancelled: true)), isNull);
    });

    test('a line given a count is the same line with that count, known; a negative count is zero', () {
      final l = line(known: false).withDelivered(3);
      expect((l.deliveredQuantity, l.deliveryKnown, l.lineId, l.quantity, l.state), (3, true, 'l1', 5, ServiceState.ready));
      expect(l.payment, LinePayment.paid);
      expect(line().withDelivered(-2).deliveredQuantity, 0);
    });

    test('the call carries the line, how many, and how many the person saw delivered', () {
      expect(deliverPartParams('l1', 2, 3), {'p_line': 'l1', 'p_quantity': 2, 'p_already': 3});
    });

    test('the answer is read, and anything else is not an answer', () {
      final r = parseDeliveryResult({'delivered': 3, 'quantity': 5, 'service_status': 'picked_up'})!;
      expect((r.delivered, r.quantity, r.state, r.complete), (3, 5, ServiceState.pickedUp, false));
      expect(parseDeliveryResult({'delivered': 5, 'quantity': 5, 'service_status': 'served'})!.complete, isTrue);
      expect(parseDeliveryResult(null), isNull);
      expect(parseDeliveryResult('ok'), isNull);
      expect(parseDeliveryResult({'delivered': 3, 'quantity': 5}), isNull);
      expect(parseDeliveryResult({'delivered': 3, 'quantity': 0, 'service_status': 'served'}), isNull);
      expect(parseDeliveryResult({'delivered': -1, 'quantity': 5, 'service_status': 'served'}), isNull);
      expect(parseDeliveryResult({'delivered': 3, 'quantity': 5, 'service_status': 'nonsense'}), isNull);
    });

    test('what is said after a hand-over', () {
      final l = line();
      expect(deliveryOutcomeMessage(l, const DeliveryResult(delivered: 2, quantity: 5, state: ServiceState.pickedUp)), '2 of 5 Patron delivered.');
      expect(deliveryOutcomeMessage(l, const DeliveryResult(delivered: 5, quantity: 5, state: ServiceState.served)), 'All 5 of Patron delivered.');
    });
  });
}
