import 'package:bottles_up_vendor/features/table_service/logic/bottle_orders_rules.dart';
import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:bottles_up_vendor/features/table_service/services/table_service_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_backend.dart';

late FakeTableBackend db;

Future<TableServiceActionException> refused(Future<void> Function() action) async {
  try {
    await action();
  } on TableServiceActionException catch (e) {
    return e;
  }
  fail('expected a refusal');
}

void main() {
  setUp(() {
    db = FakeTableBackend()..role = 'manager';
    db.now = DateTime(2026, 10, 9, 21);
    db.addBooking('b1', total: 10000, paid: 10000);
    db.menu.addAll([
      FakeBottle('p', 'Patron', 25000, category: 'Tequila', stock: 10),
      FakeBottle('g', 'Grey Goose', 18000),
      FakeBottle('hidden', 'Hidden Gin', 7000, available: false),
      FakeBottle('out', 'Sold Out Rum', 9000, soldOut: true),
    ]);
  });

  group('the menu', () {
    test('asks for the booking and lists what is on sale with the number left', () async {
      final m = await db.service.bottleMenu('b1');
      expect(db.params.single, {'p_booking': 'b1'});
      expect(m.map((x) => x.id), ['p', 'g']);
      expect(m.first.leftCount, 10);
      expect(m.last.leftCount, isNull);
    });

    test('what is already on confirmed bookings counts against what is left', () async {
      db.addLine('b1', 'Patron', bottleId: 'p', qty: 3, pay: 'paid');
      db.addLine('b1', 'Patron', bottleId: 'p', qty: 2, pay: 'due_at_venue');
      db.addLine('b1', 'Patron', bottleId: 'p', qty: 4, pay: 'pending_payment');
      expect((await db.service.bottleMenu('b1')).first.leftCount, 5);
    });

    test('a closed table, a closed night, an unconfirmed booking: the database\'s own sentence, as a refusal', () async {
      db.bookings['b1']!.reconciled = true;
      expect((await refused(() => db.service.bottleMenu('b1'))).message, 'This table has already been closed out.');
      db.bookings['b1']!.reconciled = false;
      db.bookings['b1']!.nightClosed = true;
      expect((await refused(() => db.service.bottleMenu('b1'))).message, 'This night has been closed, so no bottles can be added.');
      db.bookings['b1']!.nightClosed = false;
      db.bookings['b1']!.status = 'pending';
      expect((await refused(() => db.service.bottleMenu('b1'))).message, 'Only a confirmed booking can have bottles added.');
    });

    test('someone who may not is a load failure that says their access ended, not a refusal sentence', () async {
      db.role = 'verifier';
      await expectLater(db.service.bottleMenu('b1'), throwsA(isA<TableServiceLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });

    test('a database without the function is a load failure that says it is not set up', () async {
      db.failOn['desk_bottle_menu'] = PostgrestException(message: 'function desk_bottle_menu does not exist', code: '42883');
      await expectLater(db.service.bottleMenu('b1'), throwsA(isA<TableServiceLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    });

    test('a dropped connection is a load failure, never a raw error', () async {
      db.failOn['desk_bottle_menu'] = Exception('socket closed');
      await expectLater(db.service.bottleMenu('b1'), throwsA(isA<TableServiceLoadException>().having((e) => e.message, 'message', isNot(contains('socket')))));
    });
  });

  group('adding bottles', () {
    Future<List<MenuBottle>> menu() => db.service.bottleMenu('b1');

    test('sends the booking and only what was chosen to the add-bottles function', () async {
      final m = await menu();
      await db.service.addBottles('b1', m, {'g': 2, 'p': 1});
      final (name, body) = db.invocations.single;
      expect(name, 'add-table-booking-bottles');
      expect(body, {
        'booking_id': 'b1',
        'bottles': [
          {'bottle_id': 'p', 'quantity': 1},
          {'bottle_id': 'g', 'quantity': 2},
        ],
      });
    });

    test('the bottles are on the table, due at the club, marked as added, and the table\'s total went up', () async {
      final m = await menu();
      await db.service.addBottles('b1', m, {'p': 2});
      final added = db.lines.single;
      expect((added.name, added.qty, added.pay, added.addon, added.state), ('Patron', 2, 'due_at_venue', true, 'awaiting_prep'));
      expect(db.bookings['b1']!.total, 10000 + 50000);
      expect((await db.service.money('b1')).balanceDueCents, 50000);
    });

    test('an empty basket never leaves the phone', () async {
      final m = await menu();
      expect((await refused(() => db.service.addBottles('b1', m, {}))).message, 'Choose at least one bottle.');
      expect(db.invocations, isEmpty);
    });

    test('more than are left never leaves the phone either', () async {
      final m = await menu();
      expect((await refused(() => db.service.addBottles('b1', m, {'p': 11}))).message, 'Only 10 of Patron 750ml are left.');
      expect(db.invocations, isEmpty);
    });

    test('stock taken meanwhile: the function\'s sentence, with a full stop, and no bottles are added', () async {
      final m = await menu();
      db.addLine('b1', 'Patron', bottleId: 'p', qty: 9, pay: 'paid');
      final e = await refused(() => db.service.addBottles('b1', m, {'p': 2}));
      expect(e.message, 'Not enough "Patron" left in stock.');
      expect(e.outcomeUnknown, isFalse, reason: 'a refusal happened before anything was added');
      expect(db.lines.length, 1);
    });

    test('a bottle taken off the menu meanwhile is refused', () async {
      final m = await menu();
      db.menu.first.soldOut = true;
      final e = await refused(() => db.service.addBottles('b1', m, {'p': 1}));
      expect(e.message, 'One of the selected bottles is no longer available.');
      expect(db.lines, isEmpty);
    });

    test('a table closed meanwhile is refused with the database\'s sentence', () async {
      final m = await menu();
      db.bookings['b1']!.nightClosed = true;
      final e = await refused(() => db.service.addBottles('b1', m, {'g': 1}));
      expect(e.message, 'This night has been closed, so no bottles can be added.');
      expect(db.lines, isEmpty);
    });

    test('a person who may not is told they have no access', () async {
      final m = await menu();
      db.role = 'verifier';
      expect((await refused(() => db.service.addBottles('b1', m, {'g': 1}))).message, "You don't have access to add bottles to this table.");
    });

    test('no answer at all says the bottles may be on the table, and marks the outcome unknown', () async {
      final m = await menu();
      db.failInvoke = Exception('SocketException: connection reset');
      final e = await refused(() => db.service.addBottles('b1', m, {'g': 1}));
      expect(e.outcomeUnknown, isTrue);
      expect(e.message, contains('table\'s orders'));
      expect(e.message, isNot(contains('Socket')));
    });

    test('a server failure (500) is unknown too, and never shows the function\'s own text', () async {
      final m = await menu();
      db.failInvoke = FunctionException(status: 500, details: {'error': 'Failed to add bottles'});
      final e = await refused(() => db.service.addBottles('b1', m, {'g': 1}));
      expect(e.outcomeUnknown, isTrue);
      expect(e.message, isNot(contains('Failed to add')));
    });

    test('an error body that is plain text is still used, and one with no body gets a generic sentence', () async {
      final m = await menu();
      db.failInvoke = FunctionException(status: 409, details: 'This table is busy');
      expect((await refused(() => db.service.addBottles('b1', m, {'g': 1}))).message, 'This table is busy.');
      db.failInvoke = FunctionException(status: 409);
      expect((await refused(() => db.service.addBottles('b1', m, {'g': 1}))).message, 'The bottles could not be added.');
    });
  });

  group('handing over part of an order', () {
    setUp(() {
      db.addLine('b1', 'Patron', lineId: 'l1', qty: 5, state: 'ready');
    });

    Future<OrderLine> only() async => (await db.service.tableOrders('b1')).single;
    Future<void> partOf(int n) async {
      await db.service.deliverPart(await only(), n);
    }

    test('a table\'s orders carry how many of each were delivered, known', () async {
      db.line('l1').delivered = 2;
      final l = await only();
      expect((l.deliveredQuantity, l.deliveryKnown), (2, true));
      expect(db.functions, ['desk_booking_orders', 'desk_booking_deliveries']);
    });

    test('without the delivered count (the migration is not there, or the read failed) the orders still load and partial delivery is not offered', () async {
      db.failOn['desk_booking_deliveries'] = PostgrestException(message: 'function desk_booking_deliveries does not exist', code: '42883');
      final l = await only();
      expect(l.deliveryKnown, isFalse);
      expect(canDeliverPart(l), isFalse);
      db.failOn['desk_booking_deliveries'] = Exception('dropped');
      expect((await only()).deliveryKnown, isFalse);
    });

    test('a table with no lines does not ask for counts', () async {
      db.lines.clear();
      expect(await db.service.tableOrders('b1'), isEmpty);
      expect(db.functions, ['desk_booking_orders']);
    });

    test('hands over some and says where the line stands: part way keeps it On the way', () async {
      final r = await db.service.deliverPart(await only(), 2);
      expect((r.delivered, r.quantity, r.state, r.complete), (2, 5, ServiceState.pickedUp, false));
      expect(db.params.last, {'p_line': 'l1', 'p_quantity': 2, 'p_already': 0});
      expect((db.line('l1').delivered, db.line('l1').state), (2, 'picked_up'));
    });

    test('the call carries how many were delivered when the person looked, so a second hand-over is based on the new count', () async {
      await db.service.deliverPart(await only(), 2);
      final r = await db.service.deliverPart(await only(), 3);
      expect(db.params.last, {'p_line': 'l1', 'p_quantity': 3, 'p_already': 2});
      expect((r.complete, r.state), (true, ServiceState.served));
      expect(db.line('l1').state, 'served');
    });

    test('a repeated tap (the same call again) is refused by the database and nothing is counted twice', () async {
      final seen = await only();
      await db.service.deliverPart(seen, 2);
      final e = await refused(() => db.service.deliverPart(seen, 2));
      expect(e.message, 'Someone else has just changed this item, look at it again.');
      expect(db.line('l1').delivered, 2);
    });

    test('more than is left names how many are left', () async {
      expect((await refused(() => partOf(6))).message, 'Only 5 of this item are left to deliver.');
    });

    test('not before it is ready, and not on a closed table', () async {
      db.line('l1').state = 'preparing';
      expect((await refused(() => partOf(1))).message, 'This item is not ready to be delivered yet.');
      db.line('l1').state = 'ready';
      db.bookings['b1']!.reconciled = true;
      expect((await refused(() => partOf(1))).message, 'This table has already been closed out.');
    });

    test('an item to be paid at the club is not handed over while the table owes money', () async {
      db.line('l1').pay = 'due_at_venue';
      db.bookings['b1']!.paid = 4000;
      expect((await refused(() => partOf(1))).message, 'Cannot mark delivered - this table still has a balance due at the venue.');
    });

    test('someone who may not is told they have no access', () async {
      final seen = await only();
      db.role = 'verifier';
      expect((await refused(() => db.service.deliverPart(seen, 1))).message, "You don't have access to do that.");
    });

    test('a dropped connection is a plain sentence that is safe to retry (the count protects it)', () async {
      final seen = await only();
      db.failOn['desk_deliver_part'] = Exception('connection reset');
      final e = await refused(() => db.service.deliverPart(seen, 1));
      expect(e.message, 'The delivery could not be recorded. Check your connection and try again.');
      expect(e.message, isNot(contains('connection reset')));
    });

    test('an answer that is not a delivery is not taken as one', () async {
      final service = TableServiceService(rpc: (f, {params}) async => 'ok');
      final e = await refused(() => service.deliverPart(OrderLine(lineId: 'l1', bookingId: 'b1', bottleName: 'x', size: null, quantity: 3, unitPriceCents: 1, lineTotalCents: 3, isAddon: false, payment: LinePayment.paid, state: ServiceState.ready, orderedAt: DateTime(2026)).withDelivered(0), 1));
      expect(e.message, contains('could not be confirmed'));
    });
  });
}
