import 'package:bottles_up_vendor/features/walkin/logic/walkin_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row(String slot, String table, {String start = '21:00:00', String? label, int max = 6, int? min, String mode = 'flat', int deposit = 10000, int? rate, int? minHours, int inventory = 2, int booked = 0, int? available}) => {
      'slot_id': slot,
      'start_time': start,
      'slot_label': label,
      'table_type_id': table,
      'table_name': 'Table $table',
      'max_guests': max,
      'min_guests': min,
      'pricing_mode': mode,
      'deposit_cents': deposit,
      'hourly_rate_cents': rate,
      'min_hours': minHours,
      'inventory': inventory,
      'booked': booked,
      'available': available ?? (inventory - booked),
    };

const flat = WalkinTable(id: 't1', name: 'Booth', maxGuests: 6, minGuests: 2, hourly: false, depositCents: 10000, inventory: 2, booked: 0, available: 2);
const hourly = WalkinTable(id: 't2', name: 'Lounge', maxGuests: 10, hourly: true, depositCents: 0, hourlyRateCents: 5000, minHours: 2, inventory: 1, booked: 0, available: 1);

WalkinForm form({String name = 'Ann Guest', String email = 'ann@guest.example', String phone = '', int? guests = 4, int? hours, bool terms = true}) =>
    WalkinForm(name: name, email: email, phone: phone, guests: guests, hours: hours, terms: terms);

void main() {
  group('parseWalkinOptions', () {
    test('groups the rows by arrival time, in the order the database gave them, with each table under its time', () {
      final slots = parseWalkinOptions([
        row('s1', 't1'),
        row('s1', 't2', mode: 'hourly', rate: 5000, minHours: 2, deposit: 0, inventory: 1),
        row('s2', 't1', start: '01:00:00', label: 'After hours'),
      ]);
      expect(slots.map((s) => s.id), ['s1', 's2']);
      expect(slots[0].tables.map((t) => t.id), ['t1', 't2']);
      expect(slots[1].tables.single.id, 't1');
      expect(slots[1].label, 'After hours');
      expect(slots[0].label, isNull);
    });

    test('reads seats, price and what is left', () {
      final t = parseWalkinOptions([row('s1', 't1', max: 8, min: 3, deposit: 25000, inventory: 5, booked: 2)]).single.tables.single;
      expect((t.maxGuests, t.minGuests, t.depositCents, t.inventory, t.booked, t.available), (8, 3, 25000, 5, 2, 3));
      expect(t.hourly, isFalse);
      expect(t.isFree, isTrue);
    });

    test('an hourly table is priced by rate and hours', () {
      final t = parseWalkinOptions([row('s1', 't2', mode: 'hourly', rate: 5000, minHours: 2, deposit: 0)]).single.tables.single;
      expect(t.hourly, isTrue);
      expect(t.depositFor(3), 15000);
      expect(t.depositFor(null), 10000, reason: 'with no hours given the minimum is used');
      expect(flat.depositFor(5), 10000, reason: 'a flat table does not change with hours');
    });

    test('a table with none left is shown as full, and a time with only full tables has no free table', () {
      final slots = parseWalkinOptions([row('s1', 't1', inventory: 1, booked: 1)]);
      expect(slots.single.tables.single.isFree, isFalse);
      expect(slots.single.hasFreeTable, isFalse);
    });

    test('numbers that arrive as text or decimals are still read', () {
      final t = parseWalkinOptions([
        {...row('s1', 't1'), 'max_guests': '6', 'deposit_cents': 10000.0, 'available': '1'},
      ]).single.tables.single;
      expect((t.maxGuests, t.depositCents, t.available), (6, 10000, 1));
    });

    test('rows missing a time, a table, a name or seats are dropped, and nothing breaks', () {
      final good = row('s1', 't1');
      expect(parseWalkinOptions([{...good}..remove('slot_id'), {...good}..remove('table_type_id'), {...good}..remove('start_time'), {...good}..remove('table_name'), {...good}..remove('max_guests')]), isEmpty);
      expect(parseWalkinOptions(const []), isEmpty);
      expect(parseWalkinOptions([good]).length, 1);
    });
  });

  group('words', () {
    test('slotTime in 12-hour time', () {
      expect(slotTime('21:00:00'), '9:00 PM');
      expect(slotTime('01:30:00'), '1:30 AM');
      expect(slotTime('00:00:00'), '12:00 AM');
      expect(slotTime('12:15:00'), '12:15 PM');
      expect(slotTime('nonsense'), 'nonsense');
    });

    test('slotLabel adds the name of the time when it has one', () {
      expect(slotLabel(WalkinSlot(id: 's', startTime: '21:00:00', tables: const [])), '9:00 PM');
      expect(slotLabel(WalkinSlot(id: 's', startTime: '23:00:00', label: 'Late', tables: const [])), '11:00 PM · Late');
    });

    test('tableLine says seats, price and what is left', () {
      expect(tableLine(flat), '2 to 6 guests · \$100.00 deposit · 2 left');
      expect(tableLine(hourly), 'up to 10 guests · \$50.00 an hour (at least 2 hours) · 1 left');
      expect(tableLine(const WalkinTable(id: 't', name: 'x', maxGuests: 4, hourly: false, depositCents: 0, inventory: 1, booked: 1, available: 0)), 'up to 4 guests · no deposit · fully booked');
    });

    test('the terms state the deposit is paid at the club and only recorded when the payment is', () {
      final terms = walkinTerms(flat, null);
      expect(terms.first, contains('\$100.00'));
      expect(terms.first, contains('paid at the club'));
      expect(terms.first, contains('only when you record the payment'));
      expect(walkinTerms(const WalkinTable(id: 't', name: 'x', maxGuests: 4, hourly: false, depositCents: 0, inventory: 1, booked: 0, available: 1), null).first, 'There is no deposit for this table.');
    });

    test('the terms of an hourly table state the hours and the price for them', () {
      final terms = walkinTerms(hourly, 3);
      expect(terms.first, contains('\$150.00'));
      expect(terms.any((l) => l.contains('3 hours')), isTrue);
    });
  });

  group('validateWalkin', () {
    test('a complete form has nothing wrong', () {
      expect(validateWalkin(form(), flat), isEmpty);
      expect(validateWalkin(form(phone: '555 0100'), flat), isEmpty);
      expect(validateWalkin(form(guests: 6), flat), isEmpty, reason: 'the largest party the table seats');
      expect(validateWalkin(form(guests: 2), flat), isEmpty, reason: 'the smallest party the table takes');
    });

    test('a name needs 2 to 120 characters, ignoring spaces around it', () {
      expect(validateWalkin(form(name: ''), flat).single, contains('name'));
      expect(validateWalkin(form(name: ' A '), flat).single, contains('name'));
      expect(validateWalkin(form(name: 'Al'), flat), isEmpty);
      expect(validateWalkin(form(name: 'x' * 120), flat), isEmpty);
      expect(validateWalkin(form(name: 'x' * 121), flat).single, contains('name'));
    });

    test('an e-mail address must look like one', () {
      for (final bad in ['', 'ann', 'ann@', '@guest.example', 'ann@guest', 'a nn@guest.example', 'ann@@guest.example']) {
        expect(validateWalkin(form(email: bad), flat).single, contains('email'), reason: bad);
      }
      expect(validateWalkin(form(email: '  ann@guest.example '), flat), isEmpty);
      expect(validateWalkin(form(email: '${'a' * 250}@b.co'), flat).single, contains('email'), reason: 'longer than 254');
    });

    test('a phone number is optional but not endless', () {
      expect(validateWalkin(form(phone: ''), flat), isEmpty);
      expect(validateWalkin(form(phone: '1' * 40), flat), isEmpty);
      expect(validateWalkin(form(phone: '1' * 41), flat).single, contains('phone'));
    });

    test('the party must fit the table', () {
      expect(validateWalkin(form(guests: 7), flat).single, 'This table seats up to 6 guests.');
      expect(validateWalkin(form(guests: 1), flat).single, 'This table needs at least 2 guests.');
      expect(validateWalkin(form(guests: 0), flat).single, 'How many guests?');
      expect(validateWalkin(form(guests: null), flat).single, 'How many guests?');
      expect(validateWalkin(form(guests: 1, hours: 2), hourly), isEmpty, reason: 'a table with no minimum party takes one guest');
    });

    test('an hourly table needs hours between its minimum and 24', () {
      expect(validateWalkin(form(hours: 2), hourly), isEmpty);
      expect(validateWalkin(form(hours: 24), hourly), isEmpty);
      expect(validateWalkin(form(hours: 1), hourly).single, 'This table needs between 2 and 24 hours.');
      expect(validateWalkin(form(hours: 25), hourly).single, 'This table needs between 2 and 24 hours.');
      expect(validateWalkin(form(hours: null), hourly).single, 'This table needs between 2 and 24 hours.');
      expect(validateWalkin(form(hours: null), flat), isEmpty, reason: 'a flat table has no hours');
    });

    test('the terms must be confirmed', () {
      expect(validateWalkin(form(terms: false), flat).single, contains('terms'));
    });

    test('every problem is listed, in the order the form reads', () {
      final out = validateWalkin(form(name: '', email: 'x', guests: 9, terms: false), flat);
      expect(out.length, 4);
      expect(out[0], contains('name'));
      expect(out[1], contains('email'));
      expect(out[2], contains('seats'));
      expect(out[3], contains('terms'));
    });
  });

  group('results', () {
    test('a booking result is read', () {
      final r = parseWalkinResult({'booking_id': 'b', 'confirmation_code': 'ABC123', 'deposit_cents': 10000, 'due_cents': 10000, 'arrival_date': '2026-10-19', 'tables_left': 1})!;
      expect((r.bookingId, r.code, r.depositCents, r.dueCents, r.arrivalDate, r.tablesLeft), ('b', 'ABC123', 10000, 10000, '2026-10-19', 1));
    });

    test('what is due is read from the due amount, not assumed to be the deposit', () {
      final r = parseWalkinResult({'booking_id': 'b', 'confirmation_code': 'ABC123', 'deposit_cents': 10000, 'due_cents': 4000, 'arrival_date': '2026-10-19', 'tables_left': 0})!;
      expect((r.depositCents, r.dueCents, r.tablesLeft), (10000, 4000, 0));
      final none = parseWalkinResult({'booking_id': 'b', 'confirmation_code': 'ABC123', 'deposit_cents': 10000})!;
      expect((none.dueCents, none.tablesLeft, none.arrivalDate), (0, 0, ''), reason: 'missing numbers are zero, never the deposit');
    });

    test('an answer without a booking or a code is not a booking', () {
      expect(parseWalkinResult({'confirmation_code': 'X'}), isNull);
      expect(parseWalkinResult({'booking_id': 'b'}), isNull);
      expect(parseWalkinResult({'booking_id': '', 'confirmation_code': 'X'}), isNull);
      expect(parseWalkinResult({'booking_id': 'b', 'confirmation_code': ''}), isNull);
    });

    test('only the database\'s "no tables left" sentence means the options are stale', () {
      expect(isSoldOutRefusal('no tables of this type are left for that time'), isTrue);
      expect(isSoldOutRefusal('No tables of this type are left for that time.'), isTrue);
      expect(isSoldOutRefusal('this guest already has a booking for that time'), isFalse);
      expect(isSoldOutRefusal('not allowed'), isFalse);
    });
  });
}
