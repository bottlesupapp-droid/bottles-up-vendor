import 'dart:io';

import 'package:bottles_up_vendor/features/owner/logic/setup_forms.dart';
import 'package:flutter_test/flutter_test.dart';

TableTypeRow tableRow({
  PricingMode mode = PricingMode.flat,
  int? rate,
  int? hours,
  int spend = 150000,
  int deposit = 50000,
  String? description,
  int? minGuests,
  String? badge,
  bool featured = false,
}) =>
    TableTypeRow(
      typeId: 't1', name: 'VIP booth', description: description, maxGuests: 6, minGuests: minGuests, minSpendCents: spend, depositCents: deposit,
      inventoryCount: 3, badgeLabel: badge, isFeatured: featured, pricingMode: mode, hourlyRateCents: rate, minHours: hours,
    );

TableTypeForm goodTable({String? name, String? max, String? count, String? min, String? spend, String? deposit, PricingMode? mode, String? rate, String? hours, String? badge, String? description}) =>
    TableTypeForm(
      name: name ?? 'Booth', maxGuests: max ?? '6', inventoryCount: count ?? '1', minGuests: min ?? '', minSpend: spend ?? '', deposit: deposit ?? '',
      pricingMode: mode ?? PricingMode.flat, hourlyRate: rate ?? '', minHours: hours ?? '', badgeLabel: badge ?? '', description: description ?? '',
    );

void main() {
  group('money is typed in dollars and kept in whole cents, without floating point', () {
    test('what people type', () {
      for (final (input, cents) in [
        ('150', 15000), ('150.5', 15050), ('150.50', 15050), ('\$90', 9000), ('  \$1,250.50 ', 125050), ('0', 0), ('0.07', 7), ('19.99', 1999),
        ('1,000,000', 100000000), ('0.1', 10),
      ]) {
        expect(parseMoney(input), cents, reason: input);
      }
    });

    test('what is not an amount', () {
      for (final bad in ['', '  ', '-5', '5.', '.5', '1.234', 'abc', '12abc', '1e3', '1.2.3', '\$', '1 000', '--1', '+5', '.', '١٢٣']) {
        expect(parseMoney(bad), isNull, reason: '"$bad"');
      }
    });

    test('19.99 is exactly 1999 cents, and a third decimal is refused, never rounded', () {
      expect(parseMoney('19.99'), 1999);
      expect(parseMoney('4.35'), 435);
      expect(parseMoney('1.005'), isNull);
    });

    test('what a box shows can be typed back unchanged', () {
      for (var c = 0; c <= 6000; c++) {
        expect(parseMoney(moneyInput(c)), c);
      }
      for (final c in [99999, 100000, 123456, 999999, 12345678, 100000000]) {
        expect(parseMoney(moneyInput(c)), c);
      }
      expect(moneyInput(null), '');
      expect(moneyInput(0), '0.00');
    });

    test('dollars for reading', () {
      expect(formatDollars(150000), '\$1,500.00');
      expect(formatDollars(5), '\$0.05');
      expect(formatDollars(0), '\$0.00');
      expect(formatDollars(100000000), '\$1,000,000.00');
      expect(formatDollars(123456789), '\$1,234,567.89');
    });

    test('whole numbers', () {
      expect([parseWhole('12'), parseWhole(' 7 '), parseWhole('0'), parseWhole('100')], [12, 7, 0, 100]);
      for (final bad in ['', '1.5', '-2', '1e3', '12abc', 'abc', '1,000', '9999999999']) {
        expect(parseWhole(bad), isNull, reason: bad);
      }
    });
  });

  group('arrival times', () {
    ArrivalTime t(int day, String time, {String? id}) => ArrivalTime(slotId: id ?? '$day-$time', dayOfWeek: day, startTime: time);

    test('how a time reads', () {
      for (final (input, text) in [
        ('00:00:00', '12:00 AM'), ('00:30', '12:30 AM'), ('09:05:00', '9:05 AM'), ('11:59:00', '11:59 AM'), ('12:00:00', '12:00 PM'),
        ('13:00:00', '1:00 PM'), ('21:00:00', '9:00 PM'), ('23:59:00', '11:59 PM'),
      ]) {
        expect(formatSlotTime(input), text, reason: input);
      }
      for (final bad in ['24:00:00', '12:60', 'later', '', '9pm']) {
        expect(formatSlotTime(bad), bad, reason: bad);
      }
    });

    test('grouped by day, Monday first and Sunday last, earliest first, with every day present', () {
      final groups = groupByDay([t(0, '21:00:00'), t(5, '23:00:00'), t(5, '21:00:00'), t(1, '20:00:00')]);
      expect(groups.map((g) => g.label), ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']);
      expect(groups.firstWhere((g) => g.day == 5).times.map((x) => x.startTime), ['21:00:00', '23:00:00']);
      expect(groups.firstWhere((g) => g.day == 2).times, isEmpty);
      expect(groups.firstWhere((g) => g.day == 0).times, hasLength(1));
      expect(([...dayOrder]..sort()), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('every stored time lands in exactly one day', () {
      final all = [for (final d in [0, 1, 2, 3, 4, 5, 6]) ...[t(d, '20:00:00'), t(d, '22:00:00')]];
      expect(groupByDay(all).expand((g) => g.times), hasLength(14));
    });

    test('days are named as the database numbers them: 0 is Sunday', () {
      expect([dayLabels[0], dayLabels[6], dayShort[0], dayShort[6]], ['Sunday', 'Saturday', 'Sun', 'Sat']);
    });

    test('the add form says what is wrong in plain words', () {
      expect(validateSlotForm(days: [5], time: '21:00', label: ''), isEmpty);
      expect(validateSlotForm(days: [], time: '21:00', label: ''), ['Choose at least one day.']);
      expect(validateSlotForm(days: [5], time: '', label: ''), ['Choose an arrival time.']);
      expect(validateSlotForm(days: [5], time: '24:00', label: ''), ['Choose an arrival time.']);
      expect(validateSlotForm(days: [7], time: '21:00', label: ''), ['Choose days from the list.']);
      expect(validateSlotForm(days: [5], time: '21:00', label: 'x' * 61), ['The note must be 60 characters or fewer.']);
      expect(validateSlotForm(days: [], time: '', label: ''), hasLength(2));
    });

    test('a batch of adds is summarised: added, already there, failed', () {
      var s = summarizeSlotAttempts([const SlotAttempt(5, null)]);
      expect([s.title, s.description, s.failed], ['Arrival time added', null, false]);
      expect(summarizeSlotAttempts([const SlotAttempt(5, null), const SlotAttempt(6, null)]).title, '2 arrival times added');
      s = summarizeSlotAttempts([const SlotAttempt(5, null), const SlotAttempt(6, 'that arrival time is already added')]);
      expect([s.title, s.description, s.failed], ['Arrival time added', 'Saturday already had it.', false]);
      s = summarizeSlotAttempts([const SlotAttempt(5, 'that arrival time is already added')]);
      expect([s.title, s.description, s.failed], ['Already added', 'Friday already has that arrival time.', false]);
      s = summarizeSlotAttempts([const SlotAttempt(5, null), const SlotAttempt(6, "You don't have access to do that.")]);
      expect([s.title, s.description, s.failed], ['Added 1, but some could not be added', "Saturday: You don't have access to do that.", true]);
      expect(summarizeSlotAttempts([const SlotAttempt(0, 'boom')]).title, 'Could not add that arrival time');
    });

    test('a list_venue_time_slots row is read; one without an id, a real day or a time is dropped', () {
      final a = parseArrivalTime({'slot_id': 's1', 'day_of_week': 5, 'start_time': '21:00:00', 'label': 'Late', 'booking_count': 2})!;
      expect([a.slotId, a.dayOfWeek, a.startTime, a.label, a.bookingCount], ['s1', 5, '21:00:00', 'Late', 2]);
      expect(parseArrivalTime({'day_of_week': 5, 'start_time': '21:00:00'}), isNull);
      expect(parseArrivalTime({'slot_id': 's', 'day_of_week': 7, 'start_time': '21:00:00'}), isNull);
      expect(parseArrivalTime({'slot_id': 's', 'day_of_week': -1, 'start_time': '21:00:00'}), isNull);
      expect(parseArrivalTime({'slot_id': 's', 'day_of_week': 5}), isNull);
      expect(parseArrivalTime({'slot_id': 's', 'day_of_week': 5, 'start_time': '21:00:00', 'label': ''})!.label, isNull);
    });
  });

  group('table type form', () {
    test('a new form is not valid until it has a name and a capacity, and says so', () {
      expect(validateTableTypeForm(const TableTypeForm()), ['Give the table a name.', 'Maximum guests must be a whole number from 1 to 100.']);
    });

    test('the smallest valid form needs only a name, a capacity and a count; this is what is sent (no photo, no floor position)', () {
      expect(validateTableTypeForm(goodTable()), isEmpty);
      expect(tableTypePayload(goodTable()), {
        'name': 'Booth', 'description': null, 'max_guests': 6, 'min_guests': null, 'inventory_count': 1, 'min_spend_cents': 0, 'deposit_cents': 0,
        'pricing_mode': 'flat', 'hourly_rate_cents': null, 'min_hours': null, 'badge_label': null, 'is_featured': false,
      });
    });

    test('every refusal, in plain words', () {
      for (final (form, message) in [
        (goodTable(name: '   '), 'Give the table a name.'),
        (goodTable(name: 'x' * 121), 'The name must be 120 characters or fewer.'),
        (goodTable(description: 'x' * 2001), 'The description must be 2000 characters or fewer.'),
        (goodTable(max: '0'), 'Maximum guests must be a whole number from 1 to 100.'),
        (goodTable(max: '101'), 'Maximum guests must be a whole number from 1 to 100.'),
        (goodTable(max: '4.5'), 'Maximum guests must be a whole number from 1 to 100.'),
        (goodTable(min: '0'), 'Minimum guests must be a whole number from 1 to 100, or left empty.'),
        (goodTable(min: 'two'), 'Minimum guests must be a whole number from 1 to 100, or left empty.'),
        (goodTable(min: '7'), 'Minimum guests cannot be more than maximum guests.'),
        (goodTable(count: ''), 'The number of tables must be a whole number from 0 to 500.'),
        (goodTable(count: '501'), 'The number of tables must be a whole number from 0 to 500.'),
        (goodTable(spend: 'lots'), 'Minimum spend must be an amount like 150 or 150.50.'),
        (goodTable(spend: '-1'), 'Minimum spend must be an amount like 150 or 150.50.'),
        (goodTable(spend: '1000001'), 'Minimum spend is too large.'),
        (goodTable(deposit: '12.345'), 'Deposit must be an amount like 150 or 150.50.'),
        (goodTable(badge: 'x' * 41), 'The badge must be 40 characters or fewer.'),
        (goodTable(mode: PricingMode.hourly), 'Enter the hourly rate, for example 200.'),
        (goodTable(mode: PricingMode.hourly, rate: '0'), 'Enter the hourly rate, for example 200.'),
        (goodTable(mode: PricingMode.hourly, rate: '200', hours: '25'), 'Minimum hours must be a whole number from 1 to 24.'),
        (goodTable(mode: PricingMode.hourly, rate: '200', hours: '1.5'), 'Minimum hours must be a whole number from 1 to 24.'),
      ]) {
        expect(validateTableTypeForm(form), contains(message), reason: message);
      }
    });

    test('zero tables stops new bookings and is allowed; so are no minimum guests and a minimum equal to the maximum', () {
      expect(validateTableTypeForm(goodTable(count: '0')), isEmpty);
      expect(validateTableTypeForm(goodTable(min: '')), isEmpty);
      expect(validateTableTypeForm(goodTable(min: '6')), isEmpty);
    });

    test('hourly fields are ignored while the price is flat, and checked once it is hourly', () {
      expect(validateTableTypeForm(goodTable(rate: 'junk', hours: 'junk')), isEmpty);
      expect(validateTableTypeForm(goodTable(mode: PricingMode.hourly, rate: '200')), isEmpty);
    });

    test('hourly pricing sends the rate and defaults to one minimum hour; flat pricing sends nothing hourly', () {
      final hourly = tableTypePayload(goodTable(mode: PricingMode.hourly, rate: '200', spend: '1000'));
      expect([hourly['pricing_mode'], hourly['hourly_rate_cents'], hourly['min_hours'], hourly['min_spend_cents']], ['hourly', 20000, 1, 100000]);
      final flat = tableTypePayload(goodTable(rate: '200', hours: '3'));
      expect([flat['pricing_mode'], flat['hourly_rate_cents'], flat['min_hours']], ['flat', null, null]);
    });

    test('text is trimmed and a blank optional field is sent as "none", so it can be cleared', () {
      final p = tableTypePayload(goodTable(name: '  Booth  ', description: '   ', badge: ' '));
      expect([p['name'], p['description'], p['badge_label']], ['Booth', null, null]);
    });

    test('opening a saved table and saving it unchanged sends the same values back', () {
      final row = tableRow(description: 'By the DJ', minGuests: 2, badge: 'Popular', featured: true, mode: PricingMode.hourly, rate: 20050, hours: 2);
      final form = tableTypeFormFrom(row);
      expect(validateTableTypeForm(form), isEmpty);
      expect(tableTypePayload(form), {
        'name': 'VIP booth', 'description': 'By the DJ', 'max_guests': 6, 'min_guests': 2, 'inventory_count': 3, 'min_spend_cents': 150000, 'deposit_cents': 50000,
        'pricing_mode': 'hourly', 'hourly_rate_cents': 20050, 'min_hours': 2, 'badge_label': 'Popular', 'is_featured': true,
      });
    });

    test('what a guest pays, in one line', () {
      expect(describeTablePrice(tableRow()), 'min spend \$1,500.00 · deposit \$500.00');
      expect(describeTablePrice(tableRow(spend: 0, deposit: 0)), 'No minimum spend or deposit');
      expect(describeTablePrice(tableRow(mode: PricingMode.hourly, rate: 20000, hours: 3, spend: 0)), '\$200.00 per hour, 3 hour minimum · deposit \$500.00');
      expect(describeTablePrice(tableRow(mode: PricingMode.hourly, rate: 20000, hours: 1, spend: 0, deposit: 0)), '\$200.00 per hour');
    });

    test('a flat table that still carries an old hourly rate does not show it', () {
      expect(describeTablePrice(tableRow(rate: 20000, hours: 3, spend: 0, deposit: 0)), 'No minimum spend or deposit');
    });

    test('a list_venue_table_types row is read; one without an id, name or capacity is dropped', () {
      final r = parseTableType({
        'type_id': 't1', 'name': 'VIP', 'max_guests': 6, 'min_guests': null, 'min_spend_cents': 150000, 'deposit_cents': 0, 'inventory_count': 3,
        'is_featured': true, 'pricing_mode': 'hourly', 'hourly_rate_cents': 20000, 'min_hours': 2, 'floor_id': 'f1', 'booking_count': 4,
      })!;
      expect([r.typeId, r.name, r.maxGuests, r.minGuests, r.isFeatured, r.pricingMode, r.hourlyRateCents, r.floorId, r.bookingCount], ['t1', 'VIP', 6, null, true, PricingMode.hourly, 20000, 'f1', 4]);
      expect(parseTableType({'name': 'VIP', 'max_guests': 6}), isNull);
      expect(parseTableType({'type_id': 't', 'max_guests': 6}), isNull);
      expect(parseTableType({'type_id': 't', 'name': 'VIP'}), isNull);
      expect(parseTableType({'type_id': 't', 'name': 'VIP', 'max_guests': 6, 'pricing_mode': 'weird'})!.pricingMode, PricingMode.flat);
    });
  });

  group('bottle form', () {
    const good = BottleForm(name: 'Grey Goose', price: '195');

    test('needs a name and a price, and says so', () {
      expect(validateBottleForm(const BottleForm()), ['Give the bottle a name.', 'Enter the price as an amount like 195 or 195.50.']);
      expect(validateBottleForm(good), isEmpty);
    });

    test('every refusal, in plain words', () {
      for (final (form, message) in [
        (good.copyWith(name: 'x' * 121), 'The name must be 120 characters or fewer.'),
        (good.copyWith(size: 'x' * 41), 'The size must be 40 characters or fewer.'),
        (good.copyWith(category: 'x' * 41), 'The category must be 40 characters or fewer.'),
        (good.copyWith(description: 'x' * 1001), 'The description must be 1000 characters or fewer.'),
        (good.copyWith(price: '-1'), 'Enter the price as an amount like 195 or 195.50.'),
        (good.copyWith(price: '19.5.0'), 'Enter the price as an amount like 195 or 195.50.'),
        (good.copyWith(price: '100001'), 'The price is too large.'),
        (good.copyWith(stock: '-3'), 'Stock must be a whole number, or left empty if you do not track it.'),
        (good.copyWith(stock: '2.5'), 'Stock must be a whole number, or left empty if you do not track it.'),
        (good.copyWith(stock: '100001'), 'Stock must be a whole number, or left empty if you do not track it.'),
      ]) {
        expect(validateBottleForm(form), contains(message), reason: message);
      }
    });

    test('a free bottle and a bottle with no stock tracking are allowed', () {
      expect(validateBottleForm(good.copyWith(price: '0')), isEmpty);
      expect(validateBottleForm(good.copyWith(stock: '0')), isEmpty);
    });

    test('what is sent: trimmed, blanks cleared, an empty stock meaning "not tracked"', () {
      expect(bottlePayload(good.copyWith(size: ' 750ml ', category: '', stock: '')), {
        'name': 'Grey Goose', 'size': '750ml', 'category': null, 'description': null, 'price_cents': 19500, 'stock_quantity': null,
        'is_available': true, 'is_sold_out': false,
      });
      expect(bottlePayload(good.copyWith(stock: '0'))['stock_quantity'], 0);
    });

    test('a blank size is sent as "none", so it can be cleared', () {
      expect(bottlePayload(good.copyWith(size: '   '))['size'], isNull);
      expect(bottlePayload(good.copyWith(size: '')).containsKey('size'), isTrue);
    });

    test('opening a saved bottle and saving it unchanged sends the same values back', () {
      const row = BottleRow(bottleId: 'b1', name: 'Don Julio', size: '750ml', description: 'Tequila', priceCents: 62050, category: 'Tequila', isAvailable: true, isSoldOut: true, stockQuantity: 4);
      final form = bottleFormFrom(row);
      expect(validateBottleForm(form), isEmpty);
      expect(bottlePayload(form), {
        'name': 'Don Julio', 'size': '750ml', 'category': 'Tequila', 'description': 'Tequila', 'price_cents': 62050, 'stock_quantity': 4,
        'is_available': true, 'is_sold_out': true,
      });
    });

    test('what a guest sees: off the menu hides it, whatever the sold-out flag says', () {
      BottleRow r(bool available, bool sold) => BottleRow(bottleId: 'b', name: 'x', priceCents: 1, isAvailable: available, isSoldOut: sold);
      expect(bottleState(r(true, false)), BottleState.available);
      expect(bottleState(r(true, true)), BottleState.soldOut);
      expect(bottleState(r(false, false)), BottleState.offMenu);
      expect(bottleState(r(false, true)), BottleState.offMenu);
    });

    test('a list_venue_bottles row is read; missing availability means on the menu, never sold out', () {
      final b = parseBottle({'bottle_id': 'b1', 'name': 'Vodka', 'price_cents': 9000})!;
      expect([b.isAvailable, b.isSoldOut, b.stockQuantity, b.size], [true, false, null, null]);
      expect(parseBottle({'name': 'Vodka', 'price_cents': 9000}), isNull);
      expect(parseBottle({'bottle_id': 'b', 'price_cents': 9000}), isNull);
      expect(parseBottle({'bottle_id': 'b', 'name': 'Vodka'}), isNull);
    });
  });

  // The forms and the database must agree on which fields exist: the database refuses a key it does not know, so a field added
  // to a form and forgotten in the SQL would fail for every owner. These read the website repo's migration when it is checked
  // out next to this app (the monorepo); on their own they are skipped.
  group('agrees with the website', () {
    final sql = File('../bottles-up-website-main/supabase/migrations/20261010100000_venue_setup.sql');
    const why = 'website repo is not checked out next to this app';

    List<String> allowedKeys(String fn) {
      final body = RegExp('create function public\\.$fn\\([\\s\\S]*?setup_only_keys\\(p_details, array\\[([\\s\\S]*?)\\]\\)').firstMatch(sql.readAsStringSync())?.group(1) ?? '';
      return [for (final m in RegExp(r"'(\w+)'").allMatches(body)) m.group(1)!];
    }

    test('finds the whitelists it compares against (so this cannot pass by checking nothing)', () {
      expect(allowedKeys('save_venue_table_type').length, greaterThan(10));
      expect(allowedKeys('save_venue_bottle').length, greaterThan(8));
    }, skip: sql.existsSync() ? false : why);

    test('every table type field the form sends is one the database accepts; the rest are the photo and the order', () {
      final sent = tableTypePayload(goodTable()).keys.toList();
      final allowed = allowedKeys('save_venue_table_type');
      expect(allowed, containsAll(sent));
      expect(allowed.where((k) => !sent.contains(k)).toSet(), {'image_url', 'sort_order'});
    }, skip: sql.existsSync() ? false : why);

    test('every bottle field the form sends is one the database accepts; the rest are the photo and the order', () {
      final sent = bottlePayload(const BottleForm(name: 'x', price: '1')).keys.toList();
      final allowed = allowedKeys('save_venue_bottle');
      expect(allowed, containsAll(sent));
      expect(allowed.where((k) => !sent.contains(k)).toSet(), {'image_url', 'sort_order'});
    }, skip: sql.existsSync() ? false : why);

    test('the function and argument names the service uses are the ones the database defines', () {
      final text = sql.readAsStringSync();
      for (final signature in [
        'list_venue_time_slots(p_venue uuid)',
        'add_venue_time_slot(p_venue uuid, p_day int, p_start time, p_label text default null)',
        'remove_venue_time_slot(p_venue uuid, p_slot uuid)',
        'list_venue_table_types(p_venue uuid)',
        'save_venue_table_type(p_venue uuid, p_type uuid, p_details jsonb)',
        'remove_venue_table_type(p_venue uuid, p_type uuid)',
        'list_venue_bottles(p_venue uuid)',
        'save_venue_bottle(p_venue uuid, p_bottle uuid, p_details jsonb)',
        'remove_venue_bottle(p_venue uuid, p_bottle uuid)',
      ]) {
        expect(text, contains('create function public.$signature'), reason: signature);
      }
    }, skip: sql.existsSync() ? false : why);

    test('the limits on the forms are the database limits', () {
      final text = sql.readAsStringSync();
      for (final limit in [
        "'minimum spend', 0, 100000000", "'price', 0, 10000000", "'maximum guests', 1, 100", "'number of tables', 0, 500",
        "'minimum hours', 1, 24", "'stock', 0, 100000", "'name', 120", "'description', 2000", "'badge', 40", "'description', 1000", 'length(v_label) > 60',
      ]) {
        expect(text, contains(limit), reason: limit);
      }
      expect(validateTableTypeForm(goodTable(spend: '1000000')), isEmpty);
      expect(validateTableTypeForm(goodTable(spend: '1000000.01')), isNotEmpty);
      expect(validateBottleForm(const BottleForm(name: 'x', price: '100000')), isEmpty);
      expect(validateBottleForm(const BottleForm(name: 'x', price: '100000.01')), isNotEmpty);
    }, skip: sql.existsSync() ? false : why);
  });
}
