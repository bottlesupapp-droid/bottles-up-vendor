import 'dart:io';

import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/venue_access/logic/access_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_access_backend.dart';

// The calls to the website's venue access functions (website repo, 20261117100000_agreement_access.sql).

void main() {
  late FakeAccessBackend db;
  setUp(() => db = FakeAccessBackend());

  Future<void> expectRefusal(Future<Object?> f, String message) => expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));

  group('the club\'s side', () {
    test('reads one agreement\'s six things as the club, with who allowed them', () async {
      final g = await db.service.grants('a1', side: 'venue');
      expect(db.calledWith('agreement_grants').single, {'p_agreement': 'a1', 'p_side': 'venue'});
      expect(g.canChange, isTrue);
      expect(g.inForce, isTrue);
      expect(g.grants.map((x) => '${x.key.value}:${x.allowed}'), ['bar_sales:false', 'ticket_checkins:false', 'capacity:true', 'table_sales:true', 'chat:false', 'settlement:false']);
      expect(g.grants.firstWhere((x) => x.key == AccessKey.tableSales).grantedByName, 'Staff member');
    });

    test('allows and withdraws one thing by name, and says whether anything changed', () async {
      expect(await db.service.setGrant('a1', AccessKey.ticketCheckins, true), isTrue);
      expect(db.calledWith('set_agreement_grant').last, {'p_agreement': 'a1', 'p_grant': 'ticket_checkins', 'p_allowed': true});
      expect(await db.service.setGrant('a1', AccessKey.ticketCheckins, true), isFalse);
      expect(await db.service.setGrant('a1', AccessKey.ticketCheckins, false), isTrue);
      expect(await db.service.setGrant('a1', AccessKey.ticketCheckins, false), isFalse);
    });

    test('an agreement that is not active shares nothing, in the database\'s words', () async {
      await expectRefusal(db.service.setGrant('a2', AccessKey.capacity, true), 'The agreement has to be active before you can share anything under it.');
      await expectRefusal(db.service.setGrant('a3', AccessKey.capacity, true), 'The agreement has to be active before you can share anything under it.');
    });

    test('the organizer cannot change it, and a refusal is "no access"', () async {
      db.role = 'organizer';
      await expectRefusal(db.service.setGrant('a1', AccessKey.capacity, false), 'You don\'t have access to do that.');
      expect(db.agreements['a1']!.grants, contains('capacity'));
    });

    test('a dropped connection is a plain sentence', () async {
      db.offline = true;
      await expectRefusal(db.service.setGrant('a1', AccessKey.capacity, false), 'That could not be saved. Check your connection and try again.');
    });
  });

  group('the organizer\'s side', () {
    setUp(() => db.role = 'organizer');

    test('reads the same list as the organizer, which cannot be changed', () async {
      final g = await db.service.grants('a1', side: 'organizer');
      expect(g.side, 'organizer');
      expect(g.canChange, isFalse);
      expect(g.grants.every((x) => x.grantedByName == null), isTrue);
    });

    test('the panel lists the business\'s open agreements, each with the six', () async {
      final rows = await db.service.venueAccess('o1');
      expect(db.calledWith('organizer_venue_access').single, {'p_org': 'o1'});
      expect(rows.map((r) => '${r.eventTitle}@${r.venueName}:${r.status}'), ['Night One@Club A:active', 'Night One@Club B:negotiating', 'Late Night@Club A:requested']);
      expect(rows.first.allowedCount, 2);
      expect(rows[1].allowedCount, 0);
      expect(rows.every((r) => r.grants.length == 6), isTrue);
    });

    test('the sales of an event are asked for by event', () async {
      final s = await db.service.eventSales('e1');
      expect(db.calledWith('organizer_event_sales').single, {'p_event': 'e1'});
      expect(s.tickets.ticketsSold, 6);
    });

    test('someone else\'s event is a load failure with nothing to retry', () async {
      await expectLater(db.service.eventSales('e9'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue).having((e) => e.what, 'what', 'the sales')));
    });
  });

  group('who is who', () {
    test('a club cannot open the organizer\'s panel or sales; a stranger cannot read anything', () async {
      await expectLater(db.service.venueAccess('o1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      await expectLater(db.service.eventSales('e1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      db.role = 'stranger';
      await expectLater(db.service.grants('a1', side: 'venue'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });

    test('a backend without the functions says it is not available yet; a dropped connection says to try again', () async {
      db.role = 'organizer';
      db.missing = true;
      await expectLater(db.service.venueAccess('o1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
      db.missing = false;
      db.offline = true;
      await expectLater(db.service.eventSales('e1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
    });

    test('an answer it cannot trust is a load failure, not half a report', () async {
      final bad = db.sales('e1');
      (bad['venues'] as List).add({'venue_name': 'Club Z'});
      await expectLater(FakeAccessBackendWith(bad).service.eventSales('e1'), throwsA(isA<OpsLoadException>()));
    });
  });

  group('agrees with the website', () {
    final migration = File('../bottles-up-website-main/supabase/migrations/20261117100000_agreement_access.sql');
    const why = 'the venue access migration is not in the website checkout beside this app (its branch is not merged yet)';

    test('every function, its parameters and who may call it', () async {
      final sql = migration.readAsStringSync();
      for (final fn in [
        'set_agreement_grant(p_agreement uuid, p_grant text, p_allowed boolean)',
        'agreement_grants(p_agreement uuid, p_side text default null)',
        'organizer_venue_access(p_org uuid)',
        'organizer_event_sales(p_event uuid)',
      ]) {
        expect(sql, contains('create function public.$fn'));
      }
      expect(sql, contains('to authenticated, service_role'));
      await db.service.grants('a1', side: 'venue');
      await db.service.setGrant('a1', AccessKey.capacity, true);
      db.role = 'organizer';
      await db.service.venueAccess('o1');
      await db.service.eventSales('e1');
      final keys = {for (final c in db.calls) c.function: c.params!.keys.toList()};
      expect(keys['agreement_grants'], ['p_agreement', 'p_side']);
      expect(keys['set_agreement_grant'], ['p_agreement', 'p_grant', 'p_allowed']);
      expect(keys['organizer_venue_access'], ['p_org']);
      expect(keys['organizer_event_sales'], ['p_event']);
    }, skip: migration.existsSync() ? false : why);

    test('the six things, their order, and which exist today are the database\'s', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains("array['bar_sales', 'ticket_checkins', 'capacity', 'table_sales', 'chat', 'settlement']"));
      expect(sql, contains("grant_key in ('bar_sales', 'ticket_checkins', 'capacity', 'table_sales', 'chat', 'settlement')"));
      expect(sql, contains("select p_key in ('ticket_checkins', 'capacity', 'table_sales')"));
      expect(accessKeys, AccessKey.values.map((k) => k.value).toList());
      expect(availableKeys, {'ticket_checkins', 'capacity', 'table_sales'});
    }, skip: migration.existsSync() ? false : why);

    test('the sentences the app relies on are the database\'s', () {
      final sql = migration.readAsStringSync();
      for (final s in [
        "raise exception 'choose one of the things a club can share'",
        "raise exception 'say whether to share it, yes or no'",
        "raise exception 'the agreement has to be active before you can share anything under it'",
        "raise exception 'not allowed'",
        "status in ('active', 'changes_pending')",
      ]) {
        expect(sql, contains(s));
      }
    }, skip: migration.existsSync() ? false : why);

    test('every key the app reads of the sales is one the database makes', () {
      final sql = migration.readAsStringSync();
      for (final k in ['orders', 'tickets_sold', 'checked_in', 'refunded_orders', 'refunded_cents', 'currency_mixed', 'currency', 'gross_cents', 'by_tier', 'tier', 'price_cents', 'capacity', 'sold', 'generated_at',
        'event', 'venues', 'agreement_id', 'venue_name', 'in_force', 'grants', 'allowed', 'available', 'data', 'night', 'tables', 'guests', 'booked_cents', 'paid_cents', 'agreed', 'last_check_in_at']) {
        expect(sql, contains("'$k'"), reason: 'the database does not make "$k"');
      }
    }, skip: migration.existsSync() ? false : why);
  });
}

/// A backend whose sales answer is the one given, for the case where the database sends something the app cannot use.
class FakeAccessBackendWith extends FakeAccessBackend {
  FakeAccessBackendWith(this.fixed) : super(role: 'organizer');

  final Map<String, dynamic> fixed;

  @override
  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async => function == 'organizer_event_sales' ? fixed : super.call(function, params: params);
}
