import 'package:bottles_up_vendor/features/organizer_events/logic/event_tickets_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:flutter_test/flutter_test.dart';

OrgEvent event({DateTime? start, DateTime? end}) => OrgEvent(
      eventId: 'ev1',
      title: 'Friday Night',
      startDate: start ?? DateTime(2026, 12, 10, 20),
      endDate: end ?? DateTime(2026, 12, 11, 2),
      status: OrgEventStatus.draft,
      rawStatus: 'draft',
    );

OrgTier tier({String id = 't1', String name = 'General', int price = 2500, int capacity = 100, int sold = 0, bool hasSold = false}) =>
    OrgTier(tierId: id, name: name, priceCents: price, capacity: capacity, soldCount: sold, hasSold: hasSold);

TierForm good({String name = 'General', String price = '25', String capacity = '100', DateTime? starts, DateTime? ends}) =>
    TierForm(name: name, price: price, capacity: capacity, starts: starts, ends: ends);

List<String> problems(TierForm f, {OrgEvent? e, OrgTier? existing, List<OrgTier> others = const []}) => validateTierForm(f, event: e ?? event(), existing: existing, others: others);

void main() {
  group('reading a ticket type from the database', () {
    Map<String, dynamic> row([Map<String, dynamic> over = const {}]) => {
          'tier_id': 't1',
          'name': 'General',
          'price_cents': 2500,
          'currency': 'cad',
          'capacity': 100,
          'sold_count': 12,
          'sale_starts_at': '2026-12-05T19:00:00+00:00',
          'sale_ends_at': '2026-12-10T22:00:00Z',
          'has_sold': true,
          'has_orders': true,
          'requires_access_code': true,
          ...over,
        };

    test('reads every field, with the dates as instants', () {
      final t = parseOrgTier(row())!;
      expect([t.tierId, t.name, t.priceCents, t.currency, t.capacity, t.soldCount], ['t1', 'General', 2500, 'cad', 100, 12]);
      expect(t.saleStartsAt, DateTime.utc(2026, 12, 5, 19));
      expect(t.saleEndsAt, DateTime.utc(2026, 12, 10, 22));
      expect([t.hasSold, t.hasOrders, t.requiresAccessCode], [true, true, true]);
      expect(t.left, 88);
    });

    test('a type with no dates, no flags and a count above its capacity still reads sensibly', () {
      final t = parseOrgTier(row({'sale_starts_at': null, 'sale_ends_at': 'garbage', 'has_sold': null, 'has_orders': false, 'requires_access_code': null, 'sold_count': 150}))!;
      expect(t.saleStartsAt, isNull);
      expect(t.saleEndsAt, isNull);
      expect([t.hasSold, t.hasOrders, t.requiresAccessCode], [false, false, false]);
      expect(t.left, 0, reason: 'never negative');
    });

    test('a row without an id, a name or a good price is dropped', () {
      expect(parseOrgTier(row({'tier_id': null})), isNull);
      expect(parseOrgTier(row({'tier_id': ''})), isNull);
      expect(parseOrgTier(row({'name': null})), isNull);
      expect(parseOrgTier(row({'price_cents': null})), isNull);
      expect(parseOrgTier(row({'price_cents': -1})), isNull);
      expect(parseOrgTier(row({'price_cents': 'free'})), isNull);
      expect(parseOrgTier(row({'price_cents': 0}))!.isFree, isTrue);
    });
  });

  group('prices', () {
    test('as typed, in cents', () {
      expect(parsePriceCents('25'), 2500);
      expect(parsePriceCents('25.5'), 2550);
      expect(parsePriceCents('25.50'), 2550);
      expect(parsePriceCents('0'), 0);
      expect(parsePriceCents('0.05'), 5);
      expect(parsePriceCents('  12.99  '), 1299);
      expect(parsePriceCents('10000'), 1000000);
    });

    test('anything that is not an amount is nothing', () {
      for (final bad in ['', ' ', 'free', '-5', '+5', '25.555', '25.', '.5', '1,000', '\$25', '25 CAD', '1e3', '12345678']) {
        expect(parsePriceCents(bad), isNull, reason: '"$bad"');
      }
    });

    test('shown as dollars, or Free', () {
      expect(formatTierPrice(0), 'Free');
      expect(formatTierPrice(2500), '\$25.00');
      expect(formatTierPrice(1999), '\$19.99');
      expect(formatTierPrice(5), '\$0.05');
    });

    test('in the box when changing a type: whole dollars bare, otherwise two decimals', () {
      expect(priceBoxText(2500), '25');
      expect(priceBoxText(2550), '25.50');
      expect(priceBoxText(0), '0');
      expect(priceBoxText(5), '0.05');
    });
  });

  group('the form: what is said before anything is sent', () {
    test('a good form has no problems, and so does a free ticket and a quantity of one', () {
      expect(problems(good()), isEmpty);
      expect(problems(good(price: '0', capacity: '1')), isEmpty);
    });

    test('name: required, at most 60 characters, never twice in one event (capitals and spaces ignored), but a type may keep its own name', () {
      expect(problems(good(name: '   ')), ['Give the ticket type a name.']);
      expect(problems(good(name: 'x' * 61)), ['The name must be 60 characters or fewer.']);
      expect(problems(good(name: 'x' * 60)), isEmpty);
      expect(problems(good(name: '${'x' * 40}    ${'y' * 19}')), isEmpty, reason: 'spaces in a row count once: 60');
      final others = [tier(id: 'a', name: 'Early Bird'), tier(id: 'b', name: 'VIP')];
      expect(problems(good(name: 'early   BIRD'), others: others), ['This event already has a ticket type with that name.']);
      expect(problems(good(name: 'early bird'), others: [tier(id: 'c', name: 'Early    Bird')]), ['This event already has a ticket type with that name.'], reason: 'the other type\'s own spaces count once too');
      expect(problems(good(name: 'Early Bird'), existing: others[0], others: others), isEmpty);
      expect(problems(good(name: 'VIP'), existing: others[0], others: others), ['This event already has a ticket type with that name.']);
    });

    test('price: required (0 is free), an amount, at most 10,000.00', () {
      expect(problems(good(price: '')), ['Set a price. Use 0 for a free ticket.']);
      expect(problems(good(price: 'free')), ['The price must be an amount like 25 or 25.50.']);
      expect(problems(good(price: '-1')), ['The price must be an amount like 25 or 25.50.']);
      expect(problems(good(price: '25.555')), ['The price must be an amount like 25 or 25.50.']);
      expect(problems(good(price: '10000')), isEmpty);
      expect(problems(good(price: '10000.01')), ['The price can be at most \$10000.00.']);
    });

    test('quantity: required, a whole number from 1 to 100,000, and never below what has sold', () {
      expect(problems(good(capacity: '')), ['Say how many tickets there are.']);
      expect(problems(good(capacity: '0')), ['The quantity must be a whole number from 1 to 100000.']);
      expect(problems(good(capacity: '2.5')), ['The quantity must be a whole number from 1 to 100000.']);
      expect(problems(good(capacity: '-3')), ['The quantity must be a whole number from 1 to 100000.']);
      expect(problems(good(capacity: '100001')), ['The quantity must be a whole number from 1 to 100000.']);
      expect(problems(good(capacity: '100000')), isEmpty);
      final sold = tier(capacity: 100, sold: 40, hasSold: true);
      expect(problems(good(capacity: '39'), existing: sold, others: [sold]), ['The quantity cannot be lower than the 40 tickets already sold.']);
      expect(problems(good(capacity: '40'), existing: sold, others: [sold]), isEmpty);
      expect(problems(good(capacity: '500'), existing: sold, others: [sold]), isEmpty);
    });

    test('sale dates: the end after the start; sales cannot end after the event does or start once it has ended', () {
      final e = event(start: DateTime(2026, 12, 10, 20), end: DateTime(2026, 12, 11, 2));
      expect(problems(good(starts: DateTime(2026, 12, 5, 19), ends: DateTime(2026, 12, 10, 22)), e: e), isEmpty);
      expect(problems(good(starts: DateTime(2026, 12, 6), ends: DateTime(2026, 12, 5)), e: e), ['Sales must end after they start.']);
      expect(problems(good(starts: DateTime(2026, 12, 6), ends: DateTime(2026, 12, 6)), e: e), ['Sales must end after they start.']);
      expect(problems(good(ends: DateTime(2026, 12, 11, 2)), e: e), isEmpty, reason: 'ending exactly when the event ends is fine');
      expect(problems(good(ends: DateTime(2026, 12, 11, 2, 1)), e: e), ['Sales cannot end after the event ends.']);
      expect(problems(good(starts: DateTime(2026, 12, 11, 1, 59)), e: e), isEmpty);
      expect(problems(good(starts: DateTime(2026, 12, 11, 2)), e: e), ['Sales cannot start once the event has ended.'], reason: 'starting exactly when it ends is too late');
      expect(problems(good(starts: DateTime(2026, 12, 20), ends: DateTime(2026, 12, 21)), e: e), contains('Sales cannot end after the event ends.'));
    });

    test('an event with no end time ends 12 hours after it starts', () {
      final e = OrgEvent(eventId: 'ev', title: 'T', startDate: DateTime(2026, 12, 10, 20), status: OrgEventStatus.draft);
      expect(eventClosesAt(e), DateTime(2026, 12, 11, 8));
      expect(problems(good(ends: DateTime(2026, 12, 11, 8)), e: e), isEmpty);
      expect(problems(good(ends: DateTime(2026, 12, 11, 8, 1)), e: e), ['Sales cannot end after the event ends.']);
    });

    test('at most 20 types: the 21st is refused when adding, never when changing', () {
      final twenty = [for (var i = 0; i < 20; i++) tier(id: 'x$i', name: 'Type $i')];
      expect(problems(good(name: 'One more'), others: twenty), ['An event can have at most 20 ticket types.']);
      expect(problems(good(name: 'Type 3'), existing: twenty[3], others: twenty), isEmpty);
      expect(problems(good(name: 'One more'), others: twenty.take(19).toList()), isEmpty);
    });

    test('every problem is said at once', () {
      expect(problems(good(name: '', price: '', capacity: '')), ['Give the ticket type a name.', 'Set a price. Use 0 for a free ticket.', 'Say how many tickets there are.']);
    });
  });

  group('what is sent', () {
    test('the fields the form shows, tidied, with times as UTC instants and empty times as null (so they can be cleared)', () {
      final starts = DateTime(2026, 12, 5, 19);
      final p = tierPayload(good(name: '  Early    Bird ', price: '25.5', capacity: ' 50 ', starts: starts));
      expect(p.keys.toSet(), {'name', 'price_cents', 'capacity', 'sale_starts_at', 'sale_ends_at'});
      expect(p['name'], 'Early Bird');
      expect(p['price_cents'], 2550);
      expect(p['capacity'], 50);
      expect(p['sale_starts_at'], starts.toUtc().toIso8601String());
      expect(p['sale_starts_at'], endsWith('Z'));
      expect(p['sale_ends_at'], isNull);
    });

    test('changing a type starts the form from what it has', () {
      final f = tierFormFrom(OrgTier(
        tierId: 't1',
        name: 'General',
        priceCents: 2550,
        capacity: 80,
        saleStartsAt: DateTime.utc(2026, 12, 5, 19),
        saleEndsAt: null,
      ));
      expect([f.name, f.price, f.capacity], ['General', '25.50', '80']);
      expect(f.starts, DateTime.utc(2026, 12, 5, 19).toLocal());
      expect(f.ends, isNull);
      final g = tierFormFrom(OrgTier(tierId: 't2', name: 'Late', priceCents: 0, capacity: 5, saleEndsAt: DateTime.utc(2026, 12, 9, 22)));
      expect(g.starts, isNull);
      expect(g.ends, DateTime.utc(2026, 12, 9, 22).toLocal());
    });
  });

  group('what an event\'s tickets say about sales', () {
    final now = DateTime.utc(2026, 12, 7, 12);
    OrgTier t({DateTime? starts, DateTime? ends}) => OrgTier(tierId: 't', name: 'G', priceCents: 100, capacity: 10, saleStartsAt: starts, saleEndsAt: ends);

    test('no dates: on sale', () => expect(saleSummary(t(), now), 'On sale'));

    test('an end in the future: on sale until, and in the past: ended', () {
      expect(saleSummary(t(ends: DateTime.utc(2026, 12, 10, 22)), now), startsWith('On sale until '));
      expect(saleSummary(t(ends: DateTime.utc(2026, 12, 1)), now), startsWith('Sales ended '));
      expect(saleSummary(t(ends: now), now), startsWith('Sales ended '), reason: 'at the end moment it is closed');
    });

    test('a start in the future: sales open, with the end when there is one; at the start moment it is on sale', () {
      expect(saleSummary(t(starts: DateTime.utc(2026, 12, 20)), now), startsWith('Sales open '));
      expect(saleSummary(t(starts: DateTime.utc(2026, 12, 20), ends: DateTime.utc(2026, 12, 22)), now), contains(' to '));
      expect(saleSummary(t(starts: DateTime.utc(2026, 12, 20)), now), isNot(contains(' to ')));
      expect(saleSummary(t(starts: now), now), 'On sale');
    });

    test('the tickets of an event that has ended are locked, the moment it ends and not before', () {
      final e = event(start: DateTime(2026, 12, 10, 20), end: DateTime(2026, 12, 11, 2));
      expect(ticketsLocked(e, DateTime(2026, 12, 11, 1, 59)), isFalse);
      expect(ticketsLocked(e, DateTime(2026, 12, 11, 2)), isFalse);
      expect(ticketsLocked(e, DateTime(2026, 12, 11, 2, 1)), isTrue);
    });
  });
}
