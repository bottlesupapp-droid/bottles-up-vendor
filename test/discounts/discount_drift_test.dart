import 'dart:io';

import 'package:bottles_up_vendor/features/discounts/logic/discount_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_discount_backend.dart';

// The database decides every name, limit and sentence here; the app must not drift from them. These read the website's migration when it is checked out beside this app (the monorepo)
// and are skipped otherwise.
void main() {
  final migration = File('../bottles-up-website-main/supabase/migrations/20261024100000_staff_discounts_and_complimentary.sql');
  const why = 'website repo is not checked out next to this app';
  final present = migration.existsSync();

  group('agrees with the website', () {
    String sql() => migration.readAsStringSync();

    String fn(String name) {
      final s = sql();
      final start = s.indexOf('create function public.$name(');
      expect(start, isNot(-1), reason: 'function $name is in the website\'s migration');
      final end = s.indexOf('\n\$\$;', start);
      return s.substring(start, end);
    }

    List<String> params(String name) {
      final text = fn(name);
      final open = text.indexOf('(');
      var depth = 0;
      var close = open;
      for (var i = open; i < text.length; i++) {
        if (text[i] == '(') depth++;
        if (text[i] == ')') {
          depth--;
          if (depth == 0) {
            close = i;
            break;
          }
        }
      }
      final inside = text.substring(open + 1, close).trim();
      return inside.isEmpty ? const [] : [for (final p in inside.split(',')) p.trim().split(RegExp(r'\s+')).first];
    }

    List<String> columns(String name) {
      final m = RegExp(r'returns table \(([\s\S]*?)\)\s*language').firstMatch(fn(name))!;
      return [for (final c in m.group(1)!.split(',')) c.trim().split(RegExp(r'\s+')).first];
    }

    test('every function the app calls exists, and the app sends exactly its parameters, by name', () async {
      final db = FakeDiscountBackend()..role = 'owner';
      db.addBooking('b1');
      final svc = db.service;
      final l = await svc.limits('b1');
      await svc.given('b1');
      final menu = await svc.menu('b1');
      await svc.giveDiscount('b1', const DiscountForm(kind: DiscountKind.percent, valueText: '10', reason: 'Regular guest'), l, const []);
      await svc.giveFreeBottle('b1', FreeBottleForm(bottle: menu.first, reason: 'Birthday'), l);
      final waiting = db.addConcession('b1', status: 'pending');
      await svc.pending('v1');
      db.role = 'manager';
      await svc.decide(waiting.id, false, 'Too generous');
      await svc.takeBack(db.concessions.first.id, 'Mistake');
      db.role = 'owner';
      await svc.venueLimits('v1');
      await svc.saveLimits('v1', const LimitsForm());
      final seen = <String>{};
      for (final c in db.calls) {
        seen.add(c.$1);
        if (c.$1 == 'desk_bottle_menu') continue; // defined in 20261020150000, checked with the add-bottles tests
        expect((c.$2 ?? const {}).keys.toList()..sort(), params(c.$1).toList()..sort(), reason: '${c.$1}: parameters sent vs the SQL');
      }
      expect(seen, {
        'desk_concession_limits', 'desk_booking_concessions', 'desk_bottle_menu', 'desk_request_discount', 'desk_request_free_bottle', 'desk_pending_concessions',
        'desk_decide_concession', 'desk_void_concession', 'venue_discount_limits', 'save_venue_discount_limits',
      });
    }, skip: present ? false : why);

    test('the rows the fake answers with have exactly the columns the database returns', () async {
      final db = FakeDiscountBackend()..role = 'manager';
      db.limits = {'server_max_percent': 10, 'manager_max_percent': 25, 'server_free_bottles_per_night': 2, 'manager_free_bottles_per_night': 4, 'allow_stacking': false};
      db.addBooking('b1');
      db.addConcession('b1');
      for (final entry in {
        'desk_booking_concessions': {'p_booking': 'b1'},
        'desk_pending_concessions': {'p_venue': 'v1'},
        'venue_discount_limits': {'p_venue': 'v1'},
      }.entries) {
        final rows = await db.call(entry.key, params: entry.value) as List;
        expect(rows, isNotEmpty, reason: entry.key);
        expect((rows.first as Map).keys.toSet(), columns(entry.key).toSet(), reason: '${entry.key}: columns');
      }
    }, skip: present ? false : why);

    test('the limits answer carries the keys the app reads', () {
      final t = fn('desk_concession_limits');
      for (final key in ['role', 'limits_set', 'max_percent', 'free_bottles_allowed', 'free_bottles_used', 'allow_stacking', 'bottle_subtotal_cents', 'balance_due_cents', 'discounted_cents']) {
        expect(t, contains("'$key'"), reason: key);
      }
      expect(fn('desk_request_discount'), contains("jsonb_build_object('id', v_id, 'status', v_status, 'amount_cents', v_amount, 'percent', v_pct)"));
      expect(fn('desk_request_free_bottle'), contains("jsonb_build_object('id', v_id, 'status', v_status, 'value_cents'"));
    }, skip: present ? false : why);

    test('the limits the owner sets: only these five keys, within these ranges, and a server never above a manager', () {
      final t = fn('save_venue_discount_limits');
      expect(t, contains("array['server_max_percent', 'manager_max_percent', 'server_free_bottles_per_night', 'manager_free_bottles_per_night', 'allow_stacking']"));
      expect(t, contains("'the server''s discount limit', 0, 100"));
      expect(t, contains("'the manager''s discount limit', 0, 100"));
      expect(t, contains("'the server''s free bottles per night', 0, 100"));
      expect(t, contains("'the managers'' free bottles per night', 0, 500"));
      expect(t, contains("'a server cannot be allowed a bigger discount than a manager'"));
      expect(t, contains("'a server cannot be allowed more free bottles a night than the managers'' pool'"));
      expect(t, contains("can_access_venue(p_venue, array['owner'])"));
      expect(limitsPayload(const LimitsForm()).keys.toSet(), {'server_max_percent', 'manager_max_percent', 'server_free_bottles_per_night', 'manager_free_bottles_per_night', 'allow_stacking'});
      expect(validateLimits(const LimitsForm(managerBottles: '500')), isEmpty);
      expect(validateLimits(const LimitsForm(managerBottles: '501')), isNotEmpty);
    }, skip: present ? false : why);

    test('what a request must satisfy, and its sentences, are the database\'s', () {
      final d = fn('desk_request_discount');
      expect(d, contains('char_length(v_reason) < 3 or char_length(v_reason) > 300'));
      expect(d, contains("'give a reason of 3 to 300 characters'"));
      expect(d, contains("'a percent discount is between 1 and 100'"));
      expect(d, contains("'that discount is less than one cent'"));
      expect(d, contains("'how much is the discount?'"));
      expect(d, contains("'a discount cannot be more than the table''s bottles (%)'"));
      expect(d, contains("'a discount of % is more than this table still owes (%)'"));
      expect(d, contains("'this table already has a discount: discounts do not combine at this club'"));
      expect(d, contains("'there are no bottles on this table to discount'"));
      expect(d, contains("'discounts are not set up for this club yet: the owner sets the limits first'"));
      expect(d, contains("p_kind = 'percent'"));
      expect(d, contains("p_kind = 'amount'"));
      expect(d, contains('floor(v_base::numeric * p_value / 100)::int'));
      expect(d, contains('ceil(v_amount * 100.0 / v_base)::int'));
      final f = fn('desk_request_free_bottle');
      expect(f, contains("'how many bottles?'"));
      expect(f, contains('p_quantity < 1 or p_quantity > 100'));
      expect(maxFreeBottles, 100);
    }, skip: present ? false : why);

    test('who decides: never your own, a manager only within the manager\'s limit, the owner anything; declining needs a reason', () {
      final t = fn('desk_decide_concession');
      expect(t, contains("'you cannot approve your own request: another manager or the owner decides'"));
      expect(t, contains("'say why it is declined, so the person can be told'"));
      expect(t, contains("'this is more than a manager may approve: the owner decides'"));
      expect(t, contains("'this request has already been decided'"));
      expect(fn('desk_void_concession'), contains("'say why it is taken back'"));
      expect(fn('desk_void_concession'), contains("'that bottle has already been served, so it cannot be taken back'"));
      expect(fn('desk_pending_concessions'), contains('(c.requested_by <> auth.uid())'));
    }, skip: present ? false : why);

    test('the statuses are the four the database allows, in its order', () {
      final m = RegExp(r"status text not null check \(status in \(([^)]*)\)\)").firstMatch(sql())!.group(1)!;
      expect(RegExp(r"'([a-z_]+)'").allMatches(m).map((x) => x.group(1)!).toList(), [for (final s in ConcessionStatus.values) s.db]);
    }, skip: present ? false : why);

    test('who may do what: servers on their own table, managers and the owner for the club; the owner alone sets the limits', () {
      expect(sql(), contains("when public.can_access_venue(p_venue, array['owner']) then 'owner'"));
      expect(sql(), contains("when public.can_access_venue(p_venue, array['manager']) then 'manager'"));
      expect(sql(), contains("when p_booking is not null and public.desk_booking_level(p_booking) = 'server' then 'server'"));
      expect(fn('desk_pending_concessions'), contains("public.desk_level(p_venue) is distinct from 'manager'"));
      expect(fn('venue_discount_limits'), contains('public.require_venue_editor(p_venue)'));
    }, skip: present ? false : why);
  });
}
