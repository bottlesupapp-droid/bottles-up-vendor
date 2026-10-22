import 'dart:math';

import 'package:bottles_up_vendor/features/door_sales/logic/door_sales_rules.dart';
import 'package:flutter_test/flutter_test.dart';

SaleOption opt({int price = 5000, int capacity = 10, int sold = 2, int? available, String name = 'General'}) => SaleOption(
      tierId: 't1',
      name: name,
      priceCents: price,
      currency: 'cad',
      capacity: capacity,
      soldCount: sold,
      available: available ?? (capacity - sold),
    );

String? check({
  SaleOption? option,
  int quantity = 1,
  DoorPayMethod? method = DoorPayMethod.cash,
  String name = 'Dana Door',
  String email = '',
  String phone = '',
  String reference = '',
}) =>
    validateSale(option: option, quantity: quantity, method: method, name: name, email: email, phone: phone, reference: reference);

void main() {
  group('a ticket type', () {
    test('is read from the database row, with what is left never below zero', () {
      final o = parseSaleOption({'tier_id': 't1', 'tier_name': ' General ', 'price_cents': 5000, 'currency': 'cad', 'capacity': 10, 'sold_count': 4, 'available': 6})!;
      expect([o.tierId, o.name, o.priceCents, o.capacity, o.soldCount, o.available], ['t1', 'General', 5000, 10, 4, 6]);
      expect(parseSaleOption({'tier_id': 't1', 'tier_name': 'X', 'price_cents': 0, 'available': -3})!.available, 0);
      expect(parseSaleOption({'tier_id': 't1', 'tier_name': 'X', 'price_cents': 0, 'capacity': 10, 'sold_count': 4})!.available, 6, reason: 'without the figure, capacity minus sold');
      expect(parseSaleOption({'tier_id': 't1', 'tier_name': 'X', 'price_cents': 0, 'capacity': 3, 'sold_count': 9})!.available, 0);
    });

    test('a row that cannot be used is dropped, never guessed', () {
      expect(parseSaleOption({'tier_name': 'X', 'price_cents': 100}), isNull);
      expect(parseSaleOption({'tier_id': 't1', 'price_cents': 100}), isNull);
      expect(parseSaleOption({'tier_id': 't1', 'tier_name': '  ', 'price_cents': 100}), isNull);
      expect(parseSaleOption({'tier_id': 't1', 'tier_name': 'X'}), isNull);
    });

    test('says what it costs and what is left', () {
      expect(opt().priceLabel, '\$50.00');
      expect(opt(price: 0).priceLabel, 'Free');
      expect(opt(price: 0).isFree, isTrue);
      expect(opt().leftLabel, '8 left');
      expect(opt(capacity: 2, sold: 2).leftLabel, 'Sold out');
      expect(opt(capacity: 2, sold: 2).soldOut, isTrue);
    });

    test('one sale is never more than what is left, nor more than the database allows at once', () {
      expect(opt(capacity: 10, sold: 7).maxQuantity, 3);
      expect(opt(capacity: 100, sold: 0).maxQuantity, maxTicketsPerSale);
      expect(opt(capacity: 100, sold: 0).maxQuantity, 20);
      expect(opt(capacity: 2, sold: 2).maxQuantity, 0);
      expect(opt(available: -1).maxQuantity, 0);
    });
  });

  group('how the guest paid', () {
    test('is cash or the club\'s own card machine, stored the way the database spells them', () {
      expect([for (final m in DoorPayMethod.values) m.db], ['cash', 'external_terminal']);
      expect([for (final m in DoorPayMethod.values) m.label], ['Cash', 'Card machine']);
      expect(DoorPayMethod.fromDb('cash'), DoorPayMethod.cash);
      expect(DoorPayMethod.fromDb('external_terminal'), DoorPayMethod.terminal);
      expect(DoorPayMethod.fromDb('card'), isNull);
      expect(DoorPayMethod.fromDb(null), isNull);
    });

    test('only the card machine needs its receipt number', () {
      expect(DoorPayMethod.terminal.needsReference, isTrue);
      expect(DoorPayMethod.cash.needsReference, isFalse);
    });
  });

  group('validating a sale, before the call', () {
    final o = opt();

    test('a good sale has nothing wrong', () {
      expect(check(option: o), isNull);
      expect(check(option: o, quantity: 8, email: 'dana@example.com', phone: '+1 555 0100'), isNull);
      expect(check(option: o, method: DoorPayMethod.terminal, reference: 'TERM-1'), isNull);
    });

    test('no ticket type, or a sold out one', () {
      expect(check(option: null), 'Choose a ticket type.');
      expect(check(option: opt(capacity: 2, sold: 2, name: 'VIP')), 'VIP is sold out.');
    });

    test('the number of tickets is between one and what is left', () {
      expect(check(option: o, quantity: 0), 'Choose between 1 and 8 tickets.');
      expect(check(option: o, quantity: 9), 'Choose between 1 and 8 tickets.');
      expect(check(option: opt(capacity: 10, sold: 9), quantity: 2), 'Only 1 ticket can be sold.');
      expect(check(option: opt(capacity: 100, sold: 0), quantity: 21), 'Choose between 1 and 20 tickets.');
      expect(check(option: opt(capacity: 100, sold: 0), quantity: 20), isNull);
    });

    test('the guest\'s name is needed, and not one letter, and not a novel', () {
      expect(check(option: o, name: ''), 'Enter the guest\'s name (at least 2 letters).');
      expect(check(option: o, name: ' X '), 'Enter the guest\'s name (at least 2 letters).');
      expect(check(option: o, name: '    '), 'Enter the guest\'s name (at least 2 letters).');
      expect(check(option: o, name: 'Xy'), isNull);
      expect(check(option: o, name: 'A' * 120), isNull);
      expect(check(option: o, name: 'A' * 121), 'The guest\'s name is too long.');
    });

    test('an email is optional, but one that is typed must look like one', () {
      expect(check(option: o, email: ''), isNull);
      expect(check(option: o, email: '   '), isNull);
      for (final bad in ['nope', 'a@b', 'a b@c.com', '@c.com', 'a@@c.com']) {
        expect(check(option: o, email: bad), 'That email address does not look right. Fix it, or leave it empty.', reason: bad);
      }
      expect(check(option: o, email: '${'a' * 250}@b.co'), isNotNull, reason: 'longer than 254');
      expect(check(option: o, email: ' dana@example.com '), isNull, reason: 'blanks around it are ignored');
    });

    test('a phone number is optional and not endless', () {
      expect(check(option: o, phone: ''), isNull);
      expect(check(option: o, phone: '1' * 40), isNull);
      expect(check(option: o, phone: '1' * 41), 'That phone number is too long.');
    });

    test('how it was paid must be chosen', () {
      expect(check(option: o, method: null), 'Choose how the guest paid: cash, or the card machine.');
    });

    test('the card machine needs its receipt number, of a sensible length', () {
      expect(check(option: o, method: DoorPayMethod.terminal), 'Enter the card machine\'s receipt number.');
      expect(check(option: o, method: DoorPayMethod.terminal, reference: '   '), 'Enter the card machine\'s receipt number.');
      expect(check(option: o, method: DoorPayMethod.terminal, reference: 'ab'), 'The receipt number needs 3 to 120 characters.');
      expect(check(option: o, method: DoorPayMethod.terminal, reference: '9' * 121), 'The receipt number needs 3 to 120 characters.');
      expect(check(option: o, method: DoorPayMethod.terminal, reference: 'abc'), isNull);
    });

    test('the first problem is the one given, in the order the form is filled in', () {
      expect(check(option: null, name: '', method: null), 'Choose a ticket type.');
      expect(check(option: o, name: '', method: null), 'Enter the guest\'s name (at least 2 letters).');
      expect(check(option: o, name: 'Dana', email: 'bad', method: null), 'That email address does not look right. Fix it, or leave it empty.');
      expect(check(option: o, name: 'Dana', method: null), 'Choose how the guest paid: cash, or the card machine.');
    });
  });

  group('what a sale comes to', () {
    test('is the price times the number, and is read back in one line', () {
      expect(saleTotalCents(opt(), 3), 15000);
      expect(saleSummaryLine(opt(), 2, DoorPayMethod.cash), '2 × General · \$100.00 · Cash');
      expect(saleSummaryLine(opt(price: 0, name: 'Free Entry'), 3, DoorPayMethod.cash), '3 × Free Entry · Free · Cash');
      expect(saleSummaryLine(opt(name: 'VIP', price: 12000), 1, DoorPayMethod.terminal), '1 × VIP · \$120.00 · Card machine');
    });
  });

  group('the key of a sale', () {
    test('is long enough and short enough for the database, and different every time', () {
      final keys = {for (var i = 0; i < 200; i++) newSaleKey()};
      expect(keys.length, 200);
      for (final k in keys) {
        expect(k.length, inInclusiveRange(saleKeyMin, saleKeyMax), reason: k);
        expect(k, startsWith('ds-'));
      }
    });

    test('can be made repeatable for a test', () {
      expect(newSaleKey(random: Random(1), now: DateTime.utc(2026, 10, 24)), newSaleKey(random: Random(1), now: DateTime.utc(2026, 10, 24)));
    });

    test('the same sale has the same fingerprint, and any change to it does not', () {
      String f({String event = 'e1', String tier = 't1', int q = 2, DoorPayMethod m = DoorPayMethod.cash, String name = 'Dana', String email = 'd@e.co', String phone = '1', String ref = ''}) =>
          saleFingerprint(eventId: event, tierId: tier, quantity: q, method: m, name: name, email: email, phone: phone, reference: ref);
      expect(f(), f());
      expect(f(name: ' Dana '), f(), reason: 'blanks do not make a different sale');
      expect(f(email: ' D@E.CO '), f(), reason: 'nor does the case of an email');
      for (final other in [f(event: 'e2'), f(tier: 't2'), f(q: 3), f(m: DoorPayMethod.terminal), f(name: 'Dan'), f(email: 'x@e.co'), f(phone: '2'), f(ref: 'TERM-1')]) {
        expect(other, isNot(f()));
      }
    });
  });

  group('the answer to a sale', () {
    test('is read, with the ticket code to show', () {
      final s = parseDoorSale({'order_id': 'o1', 'ticket_code': 'BU-ABCD2345', 'quantity': 2, 'amount_cents': 10000, 'currency': 'cad', 'tier_name': 'General', 'available': 6, 'repeated': false})!;
      expect([s.orderId, s.ticketCode, s.quantity, s.amountCents, s.tierName, s.available, s.repeated], ['o1', 'BU-ABCD2345', 2, 10000, 'General', 6, false]);
      expect(parseDoorSale({'order_id': 'o1', 'ticket_code': 'BU-X', 'quantity': 1, 'amount_cents': 0, 'repeated': true})!.repeated, isTrue);
    });

    test('is not guessed when it is missing a part', () {
      expect(parseDoorSale({'ticket_code': 'BU-X', 'quantity': 1, 'amount_cents': 0}), isNull);
      expect(parseDoorSale({'order_id': 'o1', 'quantity': 1, 'amount_cents': 0}), isNull);
      expect(parseDoorSale({'order_id': 'o1', 'ticket_code': 'BU-X', 'amount_cents': 0}), isNull);
      expect(parseDoorSale({'order_id': 'o1', 'ticket_code': 'BU-X', 'quantity': 1}), isNull);
    });
  });

  group('the shift summary', () {
    final full = {
      'event_title': 'Friday Night',
      'guests_admitted': 7,
      'scans_accepted': 5,
      'sales': [
        {'method': 'cash', 'sales': 4, 'tickets': 7, 'amount_cents': 20000},
        {'method': 'external_terminal', 'sales': 1, 'tickets': 1, 'amount_cents': 12000},
      ],
      'first_sale_at': '2026-10-24T19:01:00Z',
      'last_sale_at': '2026-10-24T23:30:00Z',
    };

    test('is read, with the cash and the card machine kept apart', () {
      final s = parseShiftSummary(full)!;
      expect(s.eventTitle, 'Friday Night');
      expect([s.guestsAdmitted, s.scansAccepted], [7, 5]);
      expect([s.cash!.sales, s.cash!.tickets, s.cash!.amountCents], [4, 7, 20000]);
      expect([s.terminal!.sales, s.terminal!.tickets, s.terminal!.amountCents], [1, 1, 12000]);
      expect([s.salesCount, s.ticketsSold, s.totalCents], [5, 8, 32000]);
      expect(s.hasSales, isTrue);
      expect(s.firstSaleAt, isNotNull);
      expect(s.lastSaleAt!.isAfter(s.firstSaleAt!), isTrue);
    });

    test('a shift with no sales is empty, not an error', () {
      final s = parseShiftSummary({'event_title': 'X', 'guests_admitted': 0, 'scans_accepted': 0, 'sales': [], 'first_sale_at': null, 'last_sale_at': null})!;
      expect(s.hasSales, isFalse);
      expect([s.cash, s.terminal, s.totalCents, s.firstSaleAt], [null, null, 0, null]);
    });

    test('a method it does not know, or a broken row, is left out and never counted as cash', () {
      final s = parseShiftSummary({
        ...full,
        'sales': [
          {'method': 'bitcoin', 'sales': 9, 'tickets': 9, 'amount_cents': 99900},
          {'method': 'cash', 'sales': 'x', 'tickets': 1, 'amount_cents': 1},
          {'method': 'cash', 'sales': 1, 'tickets': 1, 'amount_cents': 5000},
        ],
      })!;
      expect(s.sales.length, 1);
      expect(s.totalCents, 5000);
    });

    test('an answer whose sales are not a list is not trusted', () {
      expect(parseShiftSummary({...full, 'sales': 'many'}), isNull);
    });

    test('says sales and tickets with the right plural, and times as a person reads them', () {
      expect(salesTicketsLine(1, 1), '1 sale · 1 ticket');
      expect(salesTicketsLine(3, 5), '3 sales · 5 tickets');
      expect(shiftTime(DateTime(2026, 10, 24, 0, 5)), '12:05 am');
      expect(shiftTime(DateTime(2026, 10, 24, 12, 0)), '12:00 pm');
      expect(shiftTime(DateTime(2026, 10, 24, 19, 9)), '7:09 pm');
      expect(shiftTime(DateTime(2026, 10, 24, 23, 59)), '11:59 pm');
    });
  });

  test('the window the database sells in is the one the door\'s own event list uses', () {
    expect(salesOpenBefore, const Duration(hours: 24));
    expect(salesOpenAfter, const Duration(hours: 3));
    expect(salesClosedMessage, contains('a day before'));
    expect(salesClosedMessage, contains('three hours after'));
  });
}
