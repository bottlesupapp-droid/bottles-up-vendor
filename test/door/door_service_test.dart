import 'package:bottles_up_vendor/features/door/logic/door_rules.dart';
import 'package:bottles_up_vendor/features/door/services/door_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_door_backend.dart';

void main() {
  late FakeDoorBackend db;
  setUp(() => db = FakeDoorBackend());

  group('events', () {
    test('asks for this workspace\'s events by membership and reads them', () async {
      db.handlers['door_events'] = (_) => [eventRow(), eventRow(id: 'e2', title: 'Saturday')];
      final events = await db.service.events('m-1');
      expect(db.paramsOf('door_events'), [
        {'p_membership': 'm-1'},
      ]);
      expect(events.map((e) => e.eventId), ['e1', 'e2']);
    });

    test('a row it cannot read is dropped, the rest are kept', () async {
      db.handlers['door_events'] = (_) => [
            {'title': 'no id', 'start_date': hoursFromNow(1)},
            eventRow(),
            'not a row',
          ];
      expect((await db.service.events('m')).map((e) => e.eventId), ['e1']);
    });

    test('no rows, or something that is not a list, is no events', () async {
      db.handlers['door_events'] = (_) => null;
      expect(await db.service.events('m'), isEmpty);
      db.handlers['door_events'] = (_) => {'oops': 1};
      expect(await db.service.events('m'), isEmpty);
    });

    test('a database without the door migration is "unavailable", which retrying cannot fix', () async {
      for (final code in ['42883', 'PGRST202', '42P01']) {
        db.handlers['door_events'] = (_) => throw PostgrestException(message: 'function does not exist', code: code);
        await expectLater(
          db.service.events('m'),
          throwsA(isA<DoorLoadException>().having((e) => e.unavailable, 'unavailable', true).having((e) => e.message, 'message', contains('not set up'))),
          reason: code,
        );
      }
    });

    test('"not authorized" is the person\'s access ending, not a fault', () async {
      db.handlers['door_events'] = (_) => throw const PostgrestException(message: 'not authorized', code: 'P0001');
      await expectLater(
        db.service.events('m'),
        throwsA(isA<DoorLoadException>().having((e) => e.accessEnded, 'accessEnded', true).having((e) => e.unavailable, 'unavailable', false)),
      );
    });

    test('any other failure is a plain "try again"', () async {
      db.handlers['door_events'] = (_) => throw Exception('socket closed');
      await expectLater(
        db.service.events('m'),
        throwsA(isA<DoorLoadException>().having((e) => e.unavailable || e.accessEnded, 'special', false).having((e) => e.message, 'message', contains('try again'))),
      );
    });
  });

  group('scanning', () {
    test('sends the cleaned-up code and the chosen event', () async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada', tier: 'General', quantity: 2)];
      final o = await db.service.scan('  T-123 \n', 'e1');
      expect(db.paramsOf('door_scan_ticket'), [
        {'p_ticket_code': 'T-123', 'p_event': 'e1'},
      ]);
      expect(o.admitted, isTrue);
      expect(o.customerName, 'Ada');
    });

    test('a code longer than 200 characters is cut before it is sent', () async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('not_found')];
      await db.service.scan('x' * 400, 'e1');
      expect((db.paramsOf('door_scan_ticket').single!['p_ticket_code'] as String).length, 200);
    });

    test('an empty code is a failed scan and never reaches the database', () async {
      final o = await db.service.scan('   ', 'e1');
      expect(o.result, DoorResult.scanError);
      expect(db.calls, isEmpty);
    });

    test('every database answer comes through as itself', () async {
      for (final word in ['ok', 'already_checked_in', 'not_paid', 'not_found', 'expired', 'code_required', 'wrong_event']) {
        db.handlers['door_scan_ticket'] = (_) => [scanRow(word)];
        expect((await db.service.scan('T', 'e1')).result.db, word);
      }
    });

    test('an empty answer is a failed scan, never an admission', () async {
      db.handlers['door_scan_ticket'] = (_) => <dynamic>[];
      expect((await db.service.scan('T', 'e1')).result, DoorResult.scanError);
      db.handlers['door_scan_ticket'] = (_) => null;
      expect((await db.service.scan('T', 'e1')).result, DoorResult.scanError);
    });

    test('it never throws: a failure becomes an outcome the person can act on', () async {
      db.handlers['door_scan_ticket'] = (_) => throw const PostgrestException(message: 'not authorized');
      expect((await db.service.scan('T', 'e1')).result, DoorResult.accessEnded);
      db.handlers['door_scan_ticket'] = (_) => throw Exception('offline');
      expect((await db.service.scan('T', 'e1')).result, DoorResult.scanError);
      db.handlers['door_scan_ticket'] = (_) => throw StateError('anything at all');
      expect((await db.service.scan('T', 'e1')).result, DoorResult.scanError);
    });
  });

  group('entry codes', () {
    test('sends the ticket, the trimmed code and the event, and reads the tries left', () async {
      db.handlers['door_verify_ticket_code'] = (_) => [scanRow('code_incorrect', name: 'Ada', attemptsRemaining: 2)];
      final o = await db.service.verifyCode(' T-1 ', ' 123456 ', 'e1');
      expect(db.paramsOf('door_verify_ticket_code'), [
        {'p_ticket_code': 'T-1', 'p_code': '123456', 'p_event': 'e1'},
      ]);
      expect(o.result, DoorResult.codeIncorrect);
      expect(o.attemptsRemaining, 2);
    });

    test('never throws, and an empty ticket never reaches the database', () async {
      db.handlers['door_verify_ticket_code'] = (_) => throw Exception('offline');
      expect((await db.service.verifyCode('T', '1', 'e1')).result, DoorResult.scanError);
      db.calls.clear();
      expect((await db.service.verifyCode('', '1', 'e1')).result, DoorResult.scanError);
      expect(db.calls, isEmpty);
    });
  });

  group('guests', () {
    test('searches by event and the typed text', () async {
      db.handlers['door_guests'] = (_) => [guestRow('Ada', 'T-1'), guestRow('Adam', 'T-2', needsCode: true)];
      final guests = await db.service.guests('e1', ' ad ');
      expect(db.paramsOf('door_guests'), [
        {'p_event': 'e1', 'p_query': 'ad'},
      ]);
      expect(guests.map((g) => g.name), ['Ada', 'Adam']);
      expect(guests.last.needsCode, isTrue);
    });

    test('fewer than two characters is no search, and does not call the database', () async {
      expect(await db.service.guests('e1', ''), isEmpty);
      expect(await db.service.guests('e1', ' a '), isEmpty);
      expect(db.calls, isEmpty);
    });

    test('a failed search is reported so the screen can say so', () async {
      db.handlers['door_guests'] = (_) => throw const PostgrestException(message: 'not allowed');
      await expectLater(db.service.guests('e1', 'ada'), throwsA(isA<DoorLoadException>()));
    });
  });
}
