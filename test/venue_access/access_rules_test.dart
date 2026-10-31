import 'package:bottles_up_vendor/features/night/logic/night_rules.dart';
import 'package:bottles_up_vendor/features/venue_access/logic/access_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_access_backend.dart';

// Reading what the database sends about what a club shares, and the organizer's report made from it.

EventSales sales({FakeAccessBackend? db, String event = 'e1'}) => parseEventSales((db ?? FakeAccessBackend()).sales(event))!;

Map<String, String> rows(ReportDocument d, String section) => {
      for (final r in d.sections.firstWhere((s) => s.title == section, orElse: () => throw StateError('no section "$section" in ${d.sections.map((s) => s.title).toList()}')).rows) r.label: r.value,
    };

void main() {
  group('the six things', () {
    test('are the brief\'s, in its order, each with a name and a sentence', () {
      expect(AccessKey.values.map((k) => k.value), accessKeys);
      expect(AccessKey.values.map((k) => k.label), ['Bar sales', 'Ticket check-ins', 'Capacity', 'Table sales', 'Operational chat', 'Settlement details']);
      for (final k in AccessKey.values) {
        expect(k.explanation.isNotEmpty, isTrue);
      }
      expect(AccessKey.parse('table_sales'), AccessKey.tableSales);
      expect(AccessKey.parse('the_cash_drawer'), isNull);
      expect(AccessKey.parse(null), isNull);
    });

    test('are described as shared, allowed but not available yet, or not shared', () {
      AccessGrant g(bool allowed, bool available) => AccessGrant(key: AccessKey.chat, allowed: allowed, available: available);
      expect(g(true, true).stateLabel, 'Shared');
      expect(g(true, false).stateLabel, 'Allowed, not available yet');
      expect(g(false, true).stateLabel, 'Not shared');
      expect(g(false, false).stateLabel, 'Not shared');
    });

    test('a thing the app does not know is left out, not guessed at', () {
      final r = parseAgreementGrants({
        'agreement_id': 'a1',
        'status': 'active',
        'side': 'venue',
        'in_force': true,
        'can_change': true,
        'grants': [
          {'key': 'chat', 'allowed': true, 'available': false},
          {'key': 'something_new', 'allowed': true, 'available': true},
          'junk',
        ],
      })!;
      expect(r.grants.map((g) => g.key), [AccessKey.chat]);
    });
  });

  group('one agreement', () {
    test('is read with its state, who may change it and each thing', () {
      final r = parseAgreementGrants({
        'agreement_id': 'a1',
        'status': 'active',
        'side': 'venue',
        'in_force': true,
        'can_change': true,
        'grants': [
          {'key': 'table_sales', 'allowed': true, 'available': true, 'granted_by_name': 'Mia', 'granted_at': '2026-10-09T18:00:00Z'},
        ],
      })!;
      expect(r.inForce, isTrue);
      expect(r.canChange, isTrue);
      expect(r.side, 'venue');
      expect(r.grants.single.grantedByName, 'Mia');
      expect(r.grants.single.grantedAt, DateTime.utc(2026, 10, 9, 18));
    });

    test('an answer with no agreement or no things is not an answer', () {
      expect(parseAgreementGrants({'status': 'active', 'grants': []}), isNull);
      expect(parseAgreementGrants({'agreement_id': 'a1', 'grants': []}), isNull);
    });

    test('what each status means for sharing', () {
      expect(accessStatusLine('active', true), 'Active');
      expect(accessStatusLine('changes_pending', true), 'Active (a newer version is waiting to be accepted)');
      expect(accessStatusLine('requested', false), 'Asked for: the club has not answered yet. Nothing is shared.');
      expect(accessStatusLine('negotiating', false), 'Being agreed. Nothing is shared until both sides accept.');
      expect(accessStatusLine('cancelled', false), 'Not active. Nothing is shared.');
    });

    test('a panel row names the event, the club and how many things are allowed', () {
      final row = parseVenueAccessRow({
        'agreement_id': 'a1',
        'event_id': 'e1',
        'event_title': 'Night One',
        'venue_name': 'Club A',
        'status': 'active',
        'in_force': true,
        'grants': [
          {'key': 'capacity', 'allowed': true, 'available': true},
          {'key': 'chat', 'allowed': false, 'available': false},
        ],
      })!;
      expect(row.allowedCount, 1);
      expect(row.eventTitle, 'Night One');
      expect(parseVenueAccessRow({'event_id': 'e1'}), isNull);
      expect(parseVenueAccessRow({'agreement_id': 'a1'}), isNull);
    });
  });

  group('the organizer\'s sales', () {
    test('are read: the event, the tickets by type and what each club shares', () {
      final s = sales();
      expect(s.eventTitle, 'Night One');
      expect(s.eventCapacity, 400);
      expect(s.tickets.ticketsSold, 6);
      expect(s.tickets.grossCents, 36000);
      expect(s.tickets.currency, 'CAD');
      expect(s.tickets.tiers.map((t) => '${t.name}:${t.sold}:${t.grossCents}'), ['General:3:9000', 'VIP:3:27000']);
      expect(s.clubs.map((c) => '${c.venueName}:${c.inForce}'), ['Club A:true', 'Club B:false']);
      expect(s.clubs.first.grants.firstWhere((g) => g.key == AccessKey.tableSales).data!['tables'], 3);
    });

    test('an answer that cannot be trusted is refused, not shown part way', () {
      expect(parseEventSales({'tickets': {}}), isNull);
      expect(parseEventSales({'event': {'title': 'x'}}), isNull);
      final bad = FakeAccessBackend().sales('e1');
      ((bad['tickets'] as Map)['by_tier'] as List).add({'price_cents': 1});
      expect(parseEventSales(bad), isNull, reason: 'a ticket type with no name would hide money');
      final noAgreement = FakeAccessBackend().sales('e1');
      (noAgreement['venues'] as List).add({'venue_name': 'Club Z'});
      expect(parseEventSales(noAgreement), isNull);
    });

    test('money is never added across currencies, whatever else the answer holds', () {
      final db = FakeAccessBackend()..mixedCurrency = true;
      final raw = db.sales('e1');
      (raw['tickets'] as Map)['gross_cents'] = 36000;
      (raw['tickets'] as Map)['currency'] = 'CAD';
      final s = parseEventSales(raw)!;
      expect(s.tickets.currencyMixed, isTrue);
      expect(s.tickets.grossCents, isNull);
      expect(s.tickets.currency, isNull);
    });
  });

  group('the report', () {
    test('title, the event and your tickets with their currency', () {
      final d = buildSalesDocument(sales());
      expect(d.title, 'Event report');
      expect(d.subtitle, 'Night One');
      expect(rows(d, 'Event')['Event'], 'Night One');
      expect(rows(d, 'Event')['Status'], 'Published');
      expect(rows(d, 'Event')['Capacity set on the event'], '400');
      expect(rows(d, 'Your tickets (CAD)'), {
        'Paid orders': '3',
        'Tickets sold': '6',
        'Checked in': '2',
        'Gross sales': r'$360.00',
        'Refunded': r'1 order · $30.00',
      });
    });

    test('by ticket type, each with its price, how many sold and the money', () {
      final r = rows(buildSalesDocument(sales()), 'By ticket type');
      expect(r['General · \$30.00 CAD · 3 of 500 sold, 2 in'], r'$90.00');
      expect(r['VIP · \$90.00 CAD · 3 of 50 sold, 0 in'], r'$270.00');
    });

    test('refunds are only mentioned when there were some', () {
      final raw = FakeAccessBackend().sales('e1');
      (raw['tickets'] as Map)['refunded_orders'] = 0;
      expect(rows(buildSalesDocument(parseEventSales(raw)!), 'Your tickets (CAD)').containsKey('Refunded'), isFalse);
      final two = FakeAccessBackend().sales('e1');
      (two['tickets'] as Map)['refunded_orders'] = 2;
      expect(rows(buildSalesDocument(parseEventSales(two)!), 'Your tickets (CAD)')['Refunded'], r'2 orders · $30.00');
    });

    test('mixed currencies: no gross, no amounts, and no label on the section', () {
      final db = FakeAccessBackend()..mixedCurrency = true;
      final d = buildSalesDocument(parseEventSales(db.sales('e1'))!);
      expect(rows(d, 'Your tickets')['Gross sales'], 'Not added: more than one currency');
      expect(rows(d, 'Your tickets')['Refunded'], '1 order · amount not added');
    });

    test('what a club shares comes in its own sections, with the night and the currency', () {
      final d = buildSalesDocument(sales());
      expect(rows(d, 'Table sales at Club A (CAD) · Friday Oct 9'), {'Tables booked': '3', 'Guests': '9', 'Booked total': r'$180.00', 'Paid so far': r'$158.00'});
      expect(rows(d, 'Capacity at Club A'), {'Agreed capacity': '250', 'Tickets sold': '6', 'Checked in': '2', 'Room left (agreed less checked in)': '248'});
    });

    test('what is not shared, or not available yet, says so instead of leaving a gap', () {
      final d = buildSalesDocument(sales());
      expect(rows(d, 'Not available from Club A'), {
        'Bar sales': 'Not shared',
        'Ticket check-ins': 'Not shared',
        'Operational chat': 'Not shared',
        'Settlement details': 'Not shared',
      });
      final db = FakeAccessBackend();
      db.agreements['a1']!.grants.addAll(['bar_sales', 'chat', 'ticket_checkins']);
      final d2 = buildSalesDocument(parseEventSales(db.sales('e1'))!);
      expect(rows(d2, 'Not available from Club A')['Bar sales'], 'Allowed, not available yet');
      expect(rows(d2, 'Not available from Club A')['Operational chat'], 'Allowed, not available yet');
      expect(rows(d2, 'Not available from Club A')['Settlement details'], 'Not shared');
      expect(rows(d2, 'Check-ins at Club A')['Checked in'], '2 of 6');
    });

    test('a club whose agreement is not active shares nothing, and says why', () {
      final d = buildSalesDocument(sales());
      expect(rows(d, 'Club B · not active'), {'Shared with you': 'Being agreed. Nothing is shared until both sides accept.'});
    });

    test('an event with no club says so', () {
      final db = FakeAccessBackend();
      db.agreements.removeWhere((_, a) => a.eventId == 'e2');
      final d = buildSalesDocument(parseEventSales(db.sales('e2'))!);
      expect(rows(d, 'Shared by the club'), {'Venue': 'No club is linked to this event yet'});
    });

    test('a capacity the agreement does not set is said, and no room left is worked out', () {
      final db = FakeAccessBackend();
      db.agreements['a1']!.agreedCapacity = null;
      final r = rows(buildSalesDocument(parseEventSales(db.sales('e1'))!), 'Capacity at Club A');
      expect(r['Agreed capacity'], 'Not set in the agreement');
      expect(r.containsKey('Room left (agreed less checked in)'), isFalse);
    });

    test('table sales in two currencies keep the counts and drop the money', () {
      final db = FakeAccessBackend()..mixedCurrency = true;
      final r = rows(buildSalesDocument(parseEventSales(db.sales('e1'))!), 'Table sales at Club A · Friday Oct 9');
      expect(r['Tables booked'], '3');
      expect(r['Money'], 'Not added: more than one currency');
      expect(r.containsKey('Booked total'), isFalse);
    });

    test('the status says only what the clubs chose to share is in it', () {
      expect(buildSalesDocument(sales()).statusLine, contains('Only what each club has chosen to share is included.'));
    });

    test('the file is named for the event and its date', () {
      expect(buildSalesDocument(sales()).fileName, matches(RegExp(r'^night-one-2026-10-\d\d-event-report\.pdf$')));
      final raw = FakeAccessBackend().sales('e1');
      (raw['event'] as Map)['title'] = '***';
      expect(buildSalesDocument(parseEventSales(raw)!).fileName, matches(RegExp(r'^event-2026-10-\d\d-event-report\.pdf$')));
    });

    test('nothing in the document can name a guest: every row is a label and a figure', () {
      final text = buildSalesDocument(sales()).sections.expand((s) => s.rows).map((r) => '${r.label} ${r.value}').join('\n');
      expect(text, isNot(contains('@')));
      expect(text.toLowerCase(), isNot(contains('ada')));
    });
  });
}
