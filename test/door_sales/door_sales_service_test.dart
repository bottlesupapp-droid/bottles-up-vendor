import 'package:bottles_up_vendor/features/door_sales/logic/door_sales_rules.dart';
import 'package:bottles_up_vendor/features/door_sales/services/door_sales_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_door_sales_backend.dart';

late FakeDoorSalesBackend db;

Future<DoorSale> sell(
  FakeDoorSalesBackend d, {
  String tier = 't-gen',
  int quantity = 2,
  DoorPayMethod method = DoorPayMethod.cash,
  String name = 'Dana Door',
  String email = '',
  String phone = '',
  String reference = '',
  String key = 'key-0000001',
}) =>
    d.service.sell(eventId: 'e1', tierId: tier, quantity: quantity, method: method, name: name, email: email, phone: phone, reference: reference, key: key);

void main() {
  setUp(() => db = FakeDoorSalesBackend());

  group('what can be sold', () {
    test('asks for the event and answers the ticket types, cheapest first, with what is left', () async {
      final r = await db.service.options('e1');
      expect(db.calls.single.$1, 'door_sale_options');
      expect(db.calls.single.$2, {'p_event': 'e1'});
      expect(r.closed, isFalse);
      expect([for (final o in r.options) '${o.name}:${o.priceCents}:${o.available}'], ['Sold Out:3000:0', 'General:5000:8', 'VIP:12000:3']);
    });

    test('a type that needs an access code is not offered', () async {
      db.tiers.add(FakeDoorSalesBackend.tier('t-gated', 'Invited Only', 8000, 5, 0, gated: true));
      expect([for (final o in (await db.service.options('e1')).options) o.name], isNot(contains('Invited Only')));
    });

    test('selling not being open is an answer, not a failure', () async {
      db.windowOpen = false;
      final r = await db.service.options('e1');
      expect(r.closed, isTrue);
      expect(r.options, isEmpty);
    });

    test('a person without the door role for the event is told their access has ended', () async {
      db.role = 'none';
      await expectLater(db.service.options('e1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue).having((e) => e.message, 'message', contains('access has ended'))));
    });

    test('a server without door sales yet is "not set up", which no retry can fix', () async {
      db.failAll = PostgrestException(message: 'function public.door_sale_options does not exist', code: '42883');
      await expectLater(db.service.options('e1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    });

    test('a dropped connection is a load failure to try again, not a closed event', () async {
      db.failAll = Exception('socket closed');
      await expectLater(db.service.options('e1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable || e.accessEnded, 'cannot be fixed', isFalse).having((e) => e.message, 'message', contains('could not be loaded'))));
    });

    test('rows the app cannot read are dropped, the others kept', () async {
      final service = DoorSalesService(caller: (fn, {params}) async => [
            {'tier_id': 't1', 'tier_name': 'General', 'price_cents': 5000, 'capacity': 10, 'sold_count': 0, 'available': 10},
            {'tier_name': 'No id', 'price_cents': 100},
            'not a row',
          ]);
      final r = await service.options('e1');
      expect([for (final o in r.options) o.name], ['General']);
    });
  });

  group('selling', () {
    test('sends exactly what the database takes, and leaves the optional parts null when they are empty', () async {
      await sell(db, email: '  ', phone: '', reference: '');
      final p = db.callsOf('door_sell_ticket').single;
      expect(p, {
        'p_event': 'e1',
        'p_tier': 't-gen',
        'p_quantity': 2,
        'p_method': 'cash',
        'p_name': 'Dana Door',
        'p_email': null,
        'p_phone': null,
        'p_reference': null,
        'p_client_key': 'key-0000001',
      });
    });

    test('sends the email, phone and the card machine\'s receipt number trimmed', () async {
      await sell(db, method: DoorPayMethod.terminal, name: '  Dana Door ', email: ' dana@example.com ', phone: ' +1 555 0100 ', reference: ' TERM-8841 ', key: 'key-0000002');
      final p = db.callsOf('door_sell_ticket').single;
      expect([p['p_method'], p['p_name'], p['p_email'], p['p_phone'], p['p_reference']], ['external_terminal', 'Dana Door', 'dana@example.com', '+1 555 0100', 'TERM-8841']);
    });

    test('the answer carries the ticket code, the amount and what is left', () async {
      final s = await sell(db, quantity: 2);
      expect([s.ticketCode, s.quantity, s.amountCents, s.tierName, s.available, s.repeated], ['BU-FAKE0001', 2, 10000, 'General', 6, false]);
      expect(db.soldOf('t-gen'), 4);
    });

    test('the same key again is the same sale, marked as a repeat, and nothing is sold twice', () async {
      final first = await sell(db);
      final again = await sell(db);
      expect(again.orderId, first.orderId);
      expect(again.ticketCode, first.ticketCode);
      expect(again.repeated, isTrue);
      expect(db.orderCount, 1);
      expect(db.soldOf('t-gen'), 4);
    });

    test('a refusal is the database\'s own sentence, as a sentence', () async {
      await expectLater(sell(db, tier: 't-vip', quantity: 4), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'Only 3 of these tickets are left.')));
      await expectLater(sell(db, name: 'X', key: 'key-0000003'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The guest\'s name needs 2 to 120 characters.')));
      await expectLater(sell(db, method: DoorPayMethod.terminal, key: 'key-0000004'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'Add the terminal\'s receipt number.')));
      expect(db.orderCount, 0);
    });

    test('no access is said as such, not as a database sentence', () async {
      db.role = 'none';
      await expectLater(sell(db), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'You don\'t have access to do that.')));
    });

    test('a lost connection says the same sale will not be made twice', () async {
      db.failAll = Exception('socket closed');
      await expectLater(sell(db), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', allOf(contains('Check your connection'), contains('will not be made twice')))));
    });

    test('an answer the app cannot read is not shown as a success', () async {
      for (final odd in <dynamic>[{'weird': true}, null, <dynamic>[], 'ok']) {
        final service = DoorSalesService(caller: (fn, {params}) async => odd);
        await expectLater(
          service.sell(eventId: 'e1', tierId: 't', quantity: 1, method: DoorPayMethod.cash, name: 'Dana', email: '', phone: '', reference: '', key: 'key-0000009'),
          throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('will not be made twice'))),
          reason: '$odd',
        );
      }
    });
  });

  group('the shift', () {
    test('is asked for by the event and read back with the sales by method', () async {
      await sell(db, quantity: 2, key: 'key-1111111');
      await sell(db, quantity: 1, tier: 't-vip', method: DoorPayMethod.terminal, reference: 'TERM-1', key: 'key-2222222');
      db.guestsAdmitted = 4;
      db.scansAccepted = 3;
      final s = await db.service.summary('e1');
      expect(db.callsOf('door_shift_summary').single, {'p_event': 'e1'});
      expect([s.eventTitle, s.guestsAdmitted, s.scansAccepted], ['Friday Night', 4, 3]);
      expect([s.cash!.amountCents, s.terminal!.amountCents, s.totalCents, s.ticketsSold], [10000, 12000, 22000, 3]);
    });

    test('no access, a missing function and a dropped connection are each said differently', () async {
      db.role = 'none';
      await expectLater(db.service.summary('e1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      db.role = 'door';
      db.failAll = PostgrestException(message: 'nope', code: '42883');
      await expectLater(db.service.summary('e1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
      db.failAll = Exception('socket');
      await expectLater(db.service.summary('e1'), throwsA(isA<OpsLoadException>().having((e) => e.message, 'message', contains('shift could not be loaded'))));
    });
  });
}

