import 'package:bottles_up_vendor/features/organizer_events/logic/event_tickets_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/services/organizer_events_service.dart';
import 'package:bottles_up_vendor/features/organizer_events/services/organizer_tiers_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_organizer_tiers_backend.dart';

OrgEvent event() => OrgEvent(eventId: 'ev1', title: 'Friday Night', startDate: DateTime(2031, 12, 10, 20), endDate: DateTime(2031, 12, 11, 2), status: OrgEventStatus.draft, rawStatus: 'draft');

void main() {
  late FakeOrganizerTiersBackend db;
  setUp(() => db = FakeOrganizerTiersBackend());

  group('listing', () {
    test('asks for the business and the event, and reads the rows', () async {
      db.seed(id: 'a', name: 'Early Bird', price: 1500, capacity: 50, sold: 10);
      db.seed(id: 'b', event: 'other', name: 'Not mine to see here');
      final tiers = await db.service.tiers('o1', 'ev1');
      expect(db.calls.single.$1, 'list_org_tiers');
      expect(db.calls.single.$2, {'p_org': 'o1', 'p_event': 'ev1'});
      expect(tiers.map((t) => t.name), ['Early Bird']);
      expect(tiers.single.soldCount, 10);
    });

    test('rows that cannot be read are dropped, and an answer that is not a list is nothing', () async {
      final service = OrganizerTiersService(rpc: (f, {params}) async => [{'tier_id': 'x'}, 'junk', null, {'tier_id': 'ok', 'name': 'A', 'price_cents': 100, 'capacity': 5}]);
      expect((await service.tiers('o1', 'ev1')).map((t) => t.tierId), ['ok']);
      expect(await OrganizerTiersService(rpc: (f, {params}) async => 'nope').tiers('o1', 'ev1'), isEmpty);
    });

    test('a failure is said as what the screen needs: not set up yet, access ended, or just failed', () async {
      Future<OrganizerEventsLoadException> failing(Object error) async {
        try {
          await OrganizerTiersService(rpc: (f, {params}) async => throw error).tiers('o1', 'ev1');
        } on OrganizerEventsLoadException catch (e) {
          return e;
        }
        throw StateError('did not fail');
      }

      expect((await failing(const PostgrestException(message: 'no function', code: '42883'))).unavailable, isTrue);
      expect((await failing(const PostgrestException(message: 'not allowed', code: 'P0001'))).accessEnded, isTrue);
      final other = await failing(StateError('socket closed'));
      expect([other.unavailable, other.accessEnded], [false, false]);
    });
  });

  group('saving', () {
    test('adds a type (no tier id) and returns its id; changes one (with its id)', () async {
      final id = await db.service.save('o1', 'ev1', null, {'name': 'VIP', 'price_cents': 8000, 'capacity': 20, 'sale_starts_at': null, 'sale_ends_at': null});
      expect(db.calls.last.$1, 'save_org_tier');
      expect(db.calls.last.$2, {'p_org': 'o1', 'p_event': 'ev1', 'p_tier': null, 'p_details': {'name': 'VIP', 'price_cents': 8000, 'capacity': 20, 'sale_starts_at': null, 'sale_ends_at': null}});
      expect(db.tiers.single['tier_id'], id);

      await db.service.save('o1', 'ev1', id, {'name': 'VIP', 'price_cents': 9000, 'capacity': 25, 'sale_starts_at': null, 'sale_ends_at': null});
      expect(db.calls.last.$2!['p_tier'], id);
      expect([db.tiers.single['price_cents'], db.tiers.single['capacity']], [9000, 25]);
    });

    test('a refusal is the database\'s sentence, as a sentence', () async {
      db.seed(id: 'a', name: 'General', price: 2500, sold: 5);
      Future<String> refused(String? tier, Map<String, dynamic> details) async {
        try {
          await db.service.save('o1', 'ev1', tier, details);
        } on OrganizerEventsActionException catch (e) {
          return e.message;
        }
        return 'NOT REFUSED';
      }

      expect(await refused('a', {'name': 'General', 'price_cents': 100, 'capacity': 50, 'sale_starts_at': null, 'sale_ends_at': null}), 'Tickets of this type have been sold, so its price cannot be changed. Add a new ticket type instead.');
      expect(await refused('a', {'name': 'General', 'price_cents': 2500, 'capacity': 3, 'sale_starts_at': null, 'sale_ends_at': null}), 'The capacity cannot be lower than the 5 tickets already sold.');
      expect(await refused(null, {'name': 'general', 'price_cents': 100, 'capacity': 5, 'sale_starts_at': null, 'sale_ends_at': null}), 'This event already has a ticket type with that name.');
    });

    test('"not allowed" says the person may not; a missing function says tickets are not set up; anything else is generic, never technical', () async {
      Future<String> refusedWith(Object error) async {
        try {
          await OrganizerTiersService(rpc: (f, {params}) async => throw error).save('o1', 'ev1', null, {});
        } on OrganizerEventsActionException catch (e) {
          return e.message;
        }
        return 'NOT REFUSED';
      }

      expect(await refusedWith(const PostgrestException(message: 'not allowed', code: 'P0001')), "You don't have access to do that.");
      expect(await refusedWith(const PostgrestException(message: 'function does not exist', code: '42883')), 'Tickets are not set up on this server yet. Try again later.');
      expect(await refusedWith(const PostgrestException(message: 'duplicate key value violates unique constraint "site_ticket_tiers_pkey"', code: '23505')), 'This could not be saved. Check your connection and try again.');
      expect(await refusedWith(StateError('boom')), 'This could not be saved. Check your connection and try again.');
    });

    test('an answer with no id is a failure, not a silent success', () async {
      for (final answer in <dynamic>[null, '', 5]) {
        await expectLater(OrganizerTiersService(rpc: (f, {params}) async => answer).save('o1', 'ev1', null, {}), throwsA(isA<OrganizerEventsActionException>()), reason: '$answer');
      }
    });
  });

  group('removing', () {
    test('asks for the business and the type, and it is gone', () async {
      db.seed(id: 'a');
      await db.service.remove('o1', 'a');
      expect(db.calls.last.$1, 'remove_org_tier');
      expect(db.calls.last.$2, {'p_org': 'o1', 'p_tier': 'a'});
      expect(db.tiers, isEmpty);
    });

    test('a type somebody has an order for is refused with the database\'s sentence', () async {
      db.seed(id: 'a', hasOrders: true);
      await expectLater(
        db.service.remove('o1', 'a'),
        throwsA(isA<OrganizerEventsActionException>().having((e) => e.message, 'message', 'People have bought or started to buy this ticket type, so it cannot be removed. Set its sales to end now instead.')),
      );
      expect(db.tiers, hasLength(1));
    });
  });

  group('the form\'s Save', () {
    test('says every problem before anything is sent', () async {
      final r = await submitTierForm(const TierForm(), orgId: 'o1', event: event(), service: db.service);
      expect(r.ok, isFalse);
      expect(r.problems, ['Give the ticket type a name.', 'Set a price. Use 0 for a free ticket.', 'Say how many tickets there are.']);
      expect(db.calls, isEmpty);
    });

    test('sends a good form as it is, and a refusal comes back as a problem to show (nothing typed is lost)', () async {
      final ok = await submitTierForm(const TierForm(name: 'General', price: '25', capacity: '100'), orgId: 'o1', event: event(), service: db.service);
      expect(ok.ok, isTrue);
      expect(db.tiers.single['price_cents'], 2500);

      db.seed(id: 'z', name: 'Locked', price: 1000, sold: 3);
      final refused = await submitTierForm(const TierForm(name: 'Locked', price: '5', capacity: '100'), orgId: 'o1', event: event(), service: db.service, existing: OrgTier(tierId: 'z', name: 'Locked', priceCents: 1000, capacity: 100, soldCount: 3));
      expect(refused.ok, isFalse);
      expect(refused.problems.single, contains('price cannot be changed'));
    });

    test('changing a type sends its id; adding does not', () async {
      db.seed(id: 'a', name: 'General', price: 2500);
      await submitTierForm(const TierForm(name: 'General', price: '30', capacity: '100'), orgId: 'o1', event: event(), service: db.service, existing: OrgTier(tierId: 'a', name: 'General', priceCents: 2500, capacity: 100), others: [OrgTier(tierId: 'a', name: 'General', priceCents: 2500, capacity: 100)]);
      expect(db.calls.last.$2!['p_tier'], 'a');
      await submitTierForm(const TierForm(name: 'New', price: '30', capacity: '100'), orgId: 'o1', event: event(), service: db.service);
      expect(db.calls.last.$2!['p_tier'], isNull);
    });
  });
}
