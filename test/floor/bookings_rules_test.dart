import 'dart:io';

import 'package:bottles_up_vendor/features/floor/logic/bookings_rules.dart';
import 'package:flutter_test/flutter_test.dart';

BookingRow row({
  String id = 'b',
  String night = '2026-10-10',
  int guests = 4,
  String status = 'paid',
  DateTime? checkedInAt,
}) =>
    BookingRow(
      bookingId: id,
      nightDate: night,
      startTime: '21:00:00',
      tableName: 'VIP booth',
      guestCount: guests,
      customerName: 'Ada',
      customerEmail: 'ada@test.example',
      status: status,
      checkedInAt: checkedInAt,
      amountTotalCents: 10000,
      depositCents: 0,
      currency: 'cad',
    );

void main() {
  group('what a status means to a venue', () {
    for (final (status, label, tone, confirmed) in [
      ('paid', 'Confirmed', StatusTone.good, true),
      ('pending', 'Awaiting payment', StatusTone.wait, false),
      ('failed', 'Payment failed', StatusTone.bad, false),
      ('refunded', 'Refunded', StatusTone.neutral, false),
      ('cancelled', 'Cancelled', StatusTone.neutral, false),
    ]) {
      test('$status is "$label"', () {
        final info = statusInfo(status);
        expect([info.label, info.tone, info.confirmed], [label, tone, confirmed]);
      });
    }

    test('a status never seen is shown as it is and is never treated as confirmed', () {
      expect(statusInfo('on_hold').label, 'On_hold');
      expect(statusInfo('').label, 'Unknown');
      for (final s in ['on_hold', '', 'PAID', 'Paid', ' paid']) {
        expect(statusInfo(s).confirmed, isFalse, reason: '"$s"');
      }
    });

    test('only a paid booking is expected', () {
      final rows = [for (final (i, s) in ['paid', 'pending', 'failed', 'refunded', 'cancelled', 'weird'].indexed) row(id: '$i', status: s)];
      expect(applyFilter(rows, BookingFilter.confirmed).map((r) => r.status), ['paid']);
      expect(applyFilter(rows, BookingFilter.all), hasLength(6));
    });
  });

  group('grouping and counting', () {
    final rows = [
      row(id: '1', night: '2026-10-10', guests: 4),
      row(id: '2', night: '2026-10-10', guests: 2, status: 'pending'),
      row(id: '3', night: '2026-10-10', guests: 3, checkedInAt: DateTime(2026, 10, 10, 22)),
      row(id: '4', night: '2026-10-11', guests: 6, status: 'cancelled'),
      row(id: '5', night: '2026-10-11', guests: 5, status: 'refunded'),
      row(id: '6', night: '2026-10-12', guests: 8, status: 'failed'),
      row(id: '7', night: '2026-10-12', guests: 1),
    ];

    test('groups by night in the order sent, and names each night', () {
      final groups = groupByNight(rows);
      expect(groups.map((g) => (g.night, g.label, g.rows.length)), [
        ('2026-10-10', 'Saturday Oct 10', 3),
        ('2026-10-11', 'Sunday Oct 11', 2),
        ('2026-10-12', 'Monday Oct 12', 2),
      ]);
    });

    test('counts only the guests of confirmed bookings in a night (a cancelled party is not expected)', () {
      expect(groupByNight(rows).map((g) => g.guests), [7, 0, 1]);
    });

    test('summarises confirmed bookings, their guests, who has arrived, and unpaid ones separately', () {
      final s = summarize(rows);
      expect([s.bookings, s.guests, s.checkedIn, s.awaitingPayment], [3, 8, 1, 1]);
    });

    test('an empty list is zeros, not an error', () {
      final s = summarize(const []);
      expect([s.bookings, s.guests, s.checkedIn, s.awaitingPayment], [0, 0, 0, 0]);
      expect(groupByNight(const []), isEmpty);
    });

    test('a checked-in booking that was cancelled afterwards is not counted as arrived', () {
      expect(summarize([row(status: 'cancelled', checkedInAt: DateTime(2026, 10, 10, 22))]).checkedIn, 0);
    });
  });

  group('wording', () {
    test('nights', () {
      expect(formatNight('2026-10-10'), 'Saturday Oct 10');
      expect(formatNight('2028-02-29'), 'Tuesday Feb 29');
      expect(formatNight('nope'), 'nope');
      expect(formatNight('2026-02-30'), '2026-02-30');
    });

    test('the short form of a night, for a narrow button', () {
      expect(formatNightShort('2026-10-10'), 'Sat Oct 10');
      expect(formatNightShort('2026-10-12'), 'Mon Oct 12');
      expect(formatNightShort('nope'), 'nope');
    });

    test('arrival times', () {
      for (final (input, text) in [
        ('00:00:00', '12:00 AM'), ('00:30', '12:30 AM'), ('09:05:00', '9:05 AM'), ('11:59:00', '11:59 AM'),
        ('12:00:00', '12:00 PM'), ('13:00:00', '1:00 PM'), ('21:00:00', '9:00 PM'), ('23:59:00', '11:59 PM'),
      ]) {
        expect(formatTimeSlot(input), text, reason: input);
      }
      for (final bad in ['24:00:00', '12:60', 'later', '', '9pm']) {
        expect(formatTimeSlot(bad), bad, reason: bad);
      }
    });

    test('a phone number is made dialable, and a stray dash is not a number', () {
      expect(dialable('+1 555 0100'), '+15550100');
      expect(dialable('+1 (555) 010-0100'), '+15550100100');
      expect(dialable('416-555-0100'), '4165550100');
      expect(dialable(' +44 20 7946 0958 '), '+442079460958');
      expect(dialable('555'), isNull);
      expect(dialable('-'), isNull);
      expect(dialable(''), isNull);
      expect(dialable('call me'), isNull);
    });

    test('money is written as the website writes it', () {
      expect(formatMoney(120000, 'cad'), '\$1200.00 CAD');
      expect(formatMoney(5, 'usd'), '\$0.05 USD');
      expect(formatMoney(0, 'cad'), '\$0.00 CAD');
    });
  });

  group('dates', () {
    test('adds days across month, year and leap-day boundaries', () {
      expect(addDays('2026-10-31', 1), '2026-11-01');
      expect(addDays('2026-12-31', 1), '2027-01-01');
      expect(addDays('2028-02-28', 1), '2028-02-29');
      expect(addDays('2026-02-28', 1), '2026-03-01');
      expect(addDays('2026-03-01', -1), '2026-02-28');
      expect(addDays('2026-10-10', 0), '2026-10-10');
    });

    test('refuses something that is not a date, rather than inventing one', () {
      for (final bad in ['', '2026-13-01', '2026-02-30', 'tomorrow', '2026-1-1']) {
        expect(() => addDays(bad, 1), throwsArgumentError, reason: bad);
      }
    });

    test('counts nights with both ends included', () {
      expect(nightCount(const NightRange('2026-10-10', '2026-10-10')), 1);
      expect(nightCount(const NightRange('2026-10-10', '2026-10-16')), 7);
      expect(nightCount(const NightRange('2026-12-30', '2027-01-02')), 4);
      expect(nightCount(const NightRange('nope', '2026-10-10')), 0);
    });

    test('validates a range in plain words', () {
      expect(validateRange(const NightRange('2026-10-10', '2026-10-10')), isNull);
      expect(validateRange(const NightRange('', '2026-10-10')), 'Choose a start and an end date.');
      expect(validateRange(const NightRange('2026-10-10', '2026-02-30')), 'Choose a start and an end date.');
      expect(validateRange(const NightRange('2026-10-10', '2026-10-09')), 'The end date is before the start date.');
      expect(validateRange(NightRange('2026-10-10', addDays('2026-10-10', maxNights - 1))), isNull);
      expect(validateRange(NightRange('2026-10-10', addDays('2026-10-10', maxNights))), 'Choose at most $maxNights nights at a time.');
    });
  });

  group('the business night', () {
    test('the evening is that night', () {
      expect(currentNight(DateTime(2026, 10, 10, 21, 30)), '2026-10-10');
    });

    test('1:30 AM is still the previous night: Sunday 01:30 is Saturday night', () {
      expect(currentNight(DateTime(2026, 10, 11, 1, 30)), '2026-10-10');
    });

    test('05:59:59 is the old night and 06:00:00 the new one', () {
      expect(currentNight(DateTime(2026, 10, 11, 5, 59, 59)), '2026-10-10');
      expect(currentNight(DateTime(2026, 10, 11, 6)), '2026-10-11');
    });

    test('across a month and a year end', () {
      expect(currentNight(DateTime(2026, 11, 1, 2)), '2026-10-31');
      expect(currentNight(DateTime(2027, 1, 1, 2)), '2026-12-31');
      expect(currentNight(DateTime(2028, 3, 1, 2)), '2028-02-29');
    });

    test('for every day of a leap year, 01:30 belongs to the day before and 12:00 to the day itself (clock-change days included)', () {
      for (var i = 0; i < 366; i++) {
        final day = DateTime.utc(2028, 1, 1).add(Duration(days: i));
        final before = DateTime.utc(day.year, day.month, day.day - 1);
        final expectedBefore = isoDate(before);
        expect(currentNight(DateTime(day.year, day.month, day.day, 1, 30)), expectedBefore, reason: '$day 01:30');
        expect(currentNight(DateTime(day.year, day.month, day.day, 12)), isoDate(day), reason: '$day 12:00');
      }
    });

    test('ready-made ranges have the right number of nights and every one can be asked for', () {
      final p = {for (final x in presets(DateTime(2026, 10, 10, 21))) x.id: x.range};
      expect(nightCount(p[PresetId.tonight]!), 1);
      expect(nightCount(p[PresetId.next7]!), 7);
      expect(nightCount(p[PresetId.next30]!), 30);
      expect(p[PresetId.last7], const NightRange('2026-10-03', '2026-10-09'));
      for (final now in [DateTime(2026, 1, 31, 23), DateTime(2028, 2, 28, 3), DateTime(2026, 12, 31, 1)]) {
        for (final preset in presets(now)) {
          expect(validateRange(preset.range), isNull, reason: '${preset.id} at $now');
        }
      }
    });

    test('at 01:30 on Sunday "Tonight" is Saturday, and the next 7 nights start there', () {
      final p = presets(DateTime(2026, 10, 11, 1, 30));
      expect(p.first.range, const NightRange('2026-10-10', '2026-10-10'));
      expect(p[1].range.from, '2026-10-10');
    });
  });

  group('reading a row', () {
    final good = {
      'booking_id': 'b1', 'night_date': '2026-10-10', 'start_time': '21:00:00', 'slot_label': 'Evening', 'table_name': 'VIP booth',
      'guest_count': 4, 'customer_name': 'Ada', 'customer_email': 'ada@test.example', 'customer_phone': '+15550002',
      'status': 'paid', 'confirmation_code': 'AB12CD', 'checked_in_at': '2026-10-10T22:00:00Z', 'amount_total_cents': 120000,
      'deposit_cents': 30000, 'currency': 'cad',
    };

    test('a full row is read', () {
      final b = parseBookingRow(good)!;
      expect([b.bookingId, b.nightDate, b.tableName, b.guestCount, b.customerPhone, b.confirmationCode], ['b1', '2026-10-10', 'VIP booth', 4, '+15550002', 'AB12CD']);
      expect([b.amountTotalCents, b.depositCents, b.currency, b.slotLabel], [120000, 30000, 'cad', 'Evening']);
      expect(b.checkedInAt, isNotNull);
    });

    test('missing optional parts are left out, not invented', () {
      final b = parseBookingRow({...good, 'customer_phone': null, 'slot_label': '', 'confirmation_code': null, 'checked_in_at': null, 'currency': null})!;
      expect([b.customerPhone, b.slotLabel, b.confirmationCode, b.checkedInAt], [null, null, null, null]);
      expect(b.currency, 'cad');
    });

    test('numbers that are not numbers are zero, never a crash', () {
      final b = parseBookingRow({...good, 'guest_count': '4', 'amount_total_cents': null, 'deposit_cents': 'x'})!;
      expect([b.guestCount, b.amountTotalCents, b.depositCents], [0, 0, 0]);
    });

    test('a row without an id, or without a real night, is dropped', () {
      expect(parseBookingRow({...good, 'booking_id': null}), isNull);
      expect(parseBookingRow({...good, 'night_date': 'tomorrow'}), isNull);
      expect(parseBookingRow({...good, 'night_date': null}), isNull);
      expect(parseBookingRow({...good, 'night_date': '2026-02-30'}), isNull);
    });
  });

  // The app and the website must agree on the night rule, the limits and the words. These read the website repo's files when
  // it is checked out next to this app (the monorepo); on their own they are skipped.
  group('agrees with the website', () {
    final root = Directory('../bottles-up-website-main');
    final sql = File('${root.path}/supabase/migrations/20261011100000_venue_bookings.sql');
    final ts = File('${root.path}/src/lib/bookingsView.ts');
    const why = 'website repo is not checked out next to this app';

    test('the function and its arguments are the ones the database defines', () {
      final text = sql.readAsStringSync();
      expect(text, contains('create function public.list_venue_bookings(p_venue uuid, p_from date, p_to date)'));
    }, skip: sql.existsSync() ? false : why);

    test('the night cutoff, the 93-night limit and the 1000-row limit are the database\'s', () {
      final text = sql.readAsStringSync();
      expect(text, contains("p_start < time '$afterMidnightCutoff'"));
      expect(text, contains('if p_to - p_from > ${maxNights - 1} then'));
      expect(text, contains('at most $maxNights nights'));
      expect(text, contains('limit $rowLimit;'));
    }, skip: sql.existsSync() ? false : why);

    test('every status is worded and treated as the website does', () {
      final text = ts.readAsStringSync();
      final re = RegExp(r"case '(\w+)': return \{ label: '([^']*)', tone: '(\w+)', confirmed: (true|false) \};");
      final web = {for (final m in re.allMatches(text)) m.group(1)!: (m.group(2)!, m.group(3)!, m.group(4) == 'true')};
      expect(web.keys, containsAll(['paid', 'pending', 'failed', 'refunded', 'cancelled']));
      for (final entry in web.entries) {
        final info = statusInfo(entry.key);
        expect(info.label, entry.value.$1, reason: entry.key);
        expect(info.tone.name, entry.value.$2, reason: entry.key);
        expect(info.confirmed, entry.value.$3, reason: entry.key);
      }
    }, skip: ts.existsSync() ? false : why);

    test('the range messages and the ready-made range names are the website\'s', () {
      final text = ts.readAsStringSync();
      for (final sentence in ['Choose a start and an end date.', 'The end date is before the start date.']) {
        expect(text, contains(sentence));
      }
      expect(text, contains('Choose at most \${MAX_NIGHTS} nights at a time.'));
      for (final label in presets(DateTime(2026, 10, 10, 21)).map((p) => p.label)) {
        expect(text, contains("label: '$label'"));
      }
      expect(text, contains('MAX_NIGHTS = $maxNights'));
      expect(text, contains('ROW_LIMIT = $rowLimit'));
    }, skip: ts.existsSync() ? false : why);
  });
}
