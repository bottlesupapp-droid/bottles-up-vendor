import 'package:bottles_up_vendor/features/floor/logic/bookings_rules.dart';
import 'package:bottles_up_vendor/features/floor/services/floor_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_floor_backend.dart';

void main() {
  late FakeFloorBackend db;
  const range = NightRange('2026-10-09', '2026-10-11');
  setUp(() => db = FakeFloorBackend());

  test('asks the database for this venue and these nights, by the names the website defines', () async {
    db.onList = (_) => [bookingRow('b1')];
    final rows = await db.service.bookings('v-1', range);
    expect(db.params, [
      {'p_venue': 'v-1', 'p_from': '2026-10-09', 'p_to': '2026-10-11'},
    ]);
    expect(rows.single.bookingId, 'b1');
  });

  test('a row it cannot read is dropped and the rest kept', () async {
    db.onList = (_) => [
          {'night_date': '2026-10-09'},
          bookingRow('b2'),
          'not a row',
          bookingRow('b3', night: 'tomorrow'),
        ];
    expect((await db.service.bookings('v', range)).map((r) => r.bookingId), ['b2']);
  });

  test('no rows, or something that is not a list, is no bookings', () async {
    db.onList = (_) => null;
    expect(await db.service.bookings('v', range), isEmpty);
    db.onList = (_) => {'oops': 1};
    expect(await db.service.bookings('v', range), isEmpty);
  });

  test('a range the database would refuse never leaves the phone', () async {
    for (final bad in [
      const NightRange('2026-10-11', '2026-10-09'),
      const NightRange('', '2026-10-09'),
      NightRange('2026-10-09', addDays('2026-10-09', maxNights)),
    ]) {
      await expectLater(db.service.bookings('v', bad), throwsArgumentError, reason: '$bad');
    }
    expect(db.calls, isEmpty);
  });

  test('the longest allowed range is sent as it is', () async {
    db.onList = (_) => <dynamic>[];
    await db.service.bookings('v', NightRange('2026-10-09', addDays('2026-10-09', maxNights - 1)));
    expect(db.calls, hasLength(1));
  });

  group('failures', () {
    Matcher unavailable() => throwsA(isA<FloorLoadException>().having((e) => e.unavailable, 'unavailable', true).having((e) => e.message, 'message', contains('not set up')));

    test('a database without the bookings migration is "unavailable", which retrying cannot fix', () async {
      for (final code in ['42883', 'PGRST202', '42P01']) {
        db.onList = (_) => throw PostgrestException(message: 'function does not exist', code: code);
        await expectLater(db.service.bookings('v', range), unavailable(), reason: code);
      }
    });

    test('"not allowed" and "not authorized" are the person no longer managing the venue', () async {
      for (final m in ['not allowed', 'not authorized', 'not authenticated']) {
        db.onList = (_) => throw PostgrestException(message: m, code: 'P0001');
        await expectLater(
          db.service.bookings('v', range),
          throwsA(isA<FloorLoadException>().having((e) => e.accessEnded, 'accessEnded', true).having((e) => e.unavailable, 'unavailable', false)),
          reason: m,
        );
      }
    });

    test('anything else is a plain "try again"', () async {
      db.onList = (_) => throw Exception('socket closed');
      await expectLater(
        db.service.bookings('v', range),
        throwsA(isA<FloorLoadException>().having((e) => e.unavailable || e.accessEnded, 'special', false).having((e) => e.message, 'message', contains('try again'))),
      );
    });
  });
}
