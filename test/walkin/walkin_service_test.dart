import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/walkin/services/walkin_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_walkin_backend.dart';

late FakeWalkinBackend db;

Future<void> book({String table = 't1', String slot = 's1', int guests = 4, int? hours, String name = 'Ann Guest', String email = 'ann@guest.example', String phone = ''}) async {
  await db.service.create(venueId: 'v1', night: '2026-10-19', tableTypeId: table, slotId: slot, guests: guests, hours: hours, name: name, email: email, phone: phone);
}

Future<String> refusal(Future<void> Function() action) async {
  try {
    await action();
  } on OpsActionException catch (e) {
    return e.message;
  }
  fail('expected a refusal');
}

void main() {
  setUp(() => db = FakeWalkinBackend());

  group('options', () {
    test('asks for the venue and the night and reads every arrival time with its tables', () async {
      final slots = await db.service.options('v1', '2026-10-19');
      expect(db.paramsOf('desk_walkin_options').single, {'p_venue': 'v1', 'p_night': '2026-10-19'});
      expect(slots.map((s) => s.id), ['s1', 's2']);
      expect(slots.first.tables.map((t) => t.name), ['Booth 3', 'Lounge']);
      expect(slots.first.tables.first.available, 2);
    });

    test('what is left follows the bookings', () async {
      await book();
      final slots = await db.service.options('v1', '2026-10-19');
      expect(slots.first.tables.first.available, 1);
      expect(slots.last.tables.first.available, 2, reason: 'the other arrival time is untouched');
    });

    test('a failed read is a load failure, never a raw error', () async {
      db.failOptions = Exception('socket closed at 10.0.0.1:5432');
      await expectLater(db.service.options('v1', '2026-10-19'), throwsA(isA<OpsLoadException>()));
    });

    test('a database without the function is a load failure that says it is not set up', () async {
      db.failAll = PostgrestException(message: 'function desk_walkin_options does not exist', code: '42883');
      await expectLater(db.service.options('v1', '2026-10-19'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue).having((e) => e.accessEnded, 'accessEnded', isFalse)));
    });

    test('a person without the manager role, or signed out, is told their access has ended', () async {
      db.role = 'door';
      await expectLater(db.service.options('v1', '2026-10-19'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue).having((e) => e.unavailable, 'unavailable', isFalse)));
      db.role = 'none';
      await expectLater(db.service.options('v1', '2026-10-19'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });
  });

  group('create', () {
    test('sends the booking with the name trimmed, the e-mail lowercased, no phone when blank, and the terms confirmed', () async {
      await book(name: '  Ann Guest ', email: ' ANN@Guest.Example ', phone: '   ');
      expect(db.paramsOf('desk_create_walkin').single, {
        'p_venue': 'v1',
        'p_night': '2026-10-19',
        'p_table_type': 't1',
        'p_slot': 's1',
        'p_guests': 4,
        'p_hours': null,
        'p_name': 'Ann Guest',
        'p_email': 'ann@guest.example',
        'p_phone': null,
        'p_terms_confirmed': true,
      });
    });

    test('a phone number is sent trimmed, and hours are sent for an hourly table', () async {
      await book(table: 't2', hours: 3, phone: ' 555 0100 ');
      final p = db.paramsOf('desk_create_walkin').single;
      expect(p['p_phone'], '555 0100');
      expect(p['p_hours'], 3);
    });

    test('returns the booking: its id, its code and what is due at the club', () async {
      final r = await db.service.create(venueId: 'v1', night: '2026-10-19', tableTypeId: 't1', slotId: 's1', guests: 4, name: 'Ann', email: 'ann@guest.example');
      expect(r.bookingId, 'bk1');
      expect(r.code, 'WALK1');
      expect((r.depositCents, r.dueCents), (10000, 10000), reason: 'the deposit is due, not paid');
      expect(r.tablesLeft, 1);
    });

    test('an hourly booking is priced by the hours', () async {
      final r = await db.service.create(venueId: 'v1', night: '2026-10-19', tableTypeId: 't2', slotId: 's1', guests: 6, hours: 3, name: 'Ann', email: 'ann@guest.example');
      expect(r.dueCents, 15000);
      expect(r.tablesLeft, 0);
    });

    test('the last table is given once: the second try is refused in the database\'s own words', () async {
      await book(table: 't2', hours: 2);
      expect(await refusal(() => book(table: 't2', hours: 2, email: 'bob@guest.example')), 'No tables of this type are left for that time.');
      expect(db.count('t2', 's1'), 1);
    });

    test('the same guest booked twice for the same time is refused, whatever the case of the address', () async {
      await book();
      expect(await refusal(() => book(email: 'ANN@guest.example')), 'This guest already has a booking for that time.');
      expect(db.count('t1', 's1'), 1);
    });

    test('a refusal is a plain sentence, capitalised', () async {
      expect(await refusal(() => book(guests: 9)), 'This table seats up to 6 guests.');
      expect(await refusal(() => book(table: 't2', hours: 1)), 'This table needs between 2 and 24 hours.');
      expect(await refusal(() => book(email: 'nope')), 'Enter a valid email address for the guest.');
    });

    test('someone without the manager role is told they do not have access, not the database\'s code word', () async {
      db.role = 'door';
      expect(await refusal(book), "You don't have access to do that.");
      expect(db.booked, isEmpty);
    });

    test('a signed-out person is told the same', () async {
      db.role = 'none';
      expect(await refusal(book), "You don't have access to do that.");
    });

    test('a dropped connection becomes the generic sentence, which tells the manager to look on the Floor before booking again', () async {
      db.failCreate = Exception('SocketException: connection reset by peer');
      final message = await refusal(book);
      expect(message, isNot(contains('Socket')));
      expect(message, contains('Floor'));
      expect(message, contains('before booking again'));
    });

    test('an answer without a booking is not taken as success', () async {
      final service = WalkinService(caller: (function, {params}) async => {'something': 'else'});
      await expectLater(service.create(venueId: 'v1', night: '2026-10-19', tableTypeId: 't1', slotId: 's1', guests: 4, name: 'Ann', email: 'ann@guest.example'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('Check the table'))));
    });
  });
}
