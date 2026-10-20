import 'dart:io';

import 'package:bottles_up_vendor/features/payouts/logic/payout_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_payout_backend.dart';

// The database decides every name, status and rule here; the app must not drift from them. These read the website's migration when it is checked out beside this app (the monorepo)
// and are skipped otherwise.
void main() {
  final migration = File('../bottles-up-website-main/supabase/migrations/20261025100000_payout_settings_and_ledger.sql');
  const why = 'website repo is not checked out next to this app';
  final present = migration.existsSync();

  group('agrees with the website', () {
    String sql() => migration.readAsStringSync();

    String fn(String name) {
      final s = sql();
      final start = s.indexOf('create function public.$name(');
      expect(start, isNot(-1), reason: 'function $name is in the website\'s migration');
      return s.substring(start, s.indexOf('\n\$\$;', start));
    }

    List<String> statuses(String pattern) {
      final m = RegExp(pattern).firstMatch(sql())!.group(1)!;
      return RegExp(r"'([a-z_]+)'").allMatches(m).map((x) => x.group(1)!).toList();
    }

    test('the app calls my_payouts with the business, as the database takes it', () async {
      final db = FakePayoutBackend();
      await db.service.mine('o1');
      expect(db.calls.single.$1, 'my_payouts');
      expect(db.calls.single.$2!.keys.toList(), ['p_org']);
      expect(fn('my_payouts'), contains('create function public.my_payouts(p_org uuid)'));
    }, skip: present ? false : why);

    test('the answer carries the keys the app reads', () {
      final t = fn('my_payouts');
      for (final key in [
        'org_kind', 'account', 'status', 'account_holder', 'masked_account', 'note', 'settings', 'payout_method', 'commission_set', 'commission_bps', 'payout_weekday', 'hold_days',
        'next_payout_on', 'own_arrangement', 'waiting', 'bookings', 'gross_cents', 'items', 'id', 'period_start', 'period_end', 'commission_cents', 'adjustments_cents', 'adjustment_note',
        'net_cents', 'expected_on', 'reference', 'paid_at', 'failure_note',
      ]) {
        expect(t, contains("'$key'"), reason: key);
      }
    }, skip: present ? false : why);

    test('the account statuses and the payout statuses are the database\'s', () {
      expect([for (final s in PayoutAccountStatus.values) s.db], statuses(r"site_payout_accounts \(\s*org_id[\s\S]*?status text not null default 'incomplete' check \(status in \(([^)]*)\)\)"));
      final all = statuses(r"status text not null default 'pending' check \(status in \(([^)]*)\)\)");
      expect([for (final s in PayoutItemStatus.values) s.db], [for (final s in all) if (s != 'cancelled') s], reason: 'the app shows every status except Cancelled, which my_payouts never returns');
      expect(fn('my_payouts'), contains("status <> 'cancelled'"));
    }, skip: present ? false : why);

    test('only the business\'s owner and an organizer may read it, and a venue business gets the waiting figure', () {
      final t = fn('my_payouts');
      expect(t, contains("m.role in ('owner', 'organizer')"));
      expect(t, contains("case when v_kind = 'venue_owner' then jsonb_build_object('bookings'"));
    }, skip: present ? false : why);

    test('the account is only ever masked, and the weekday and hold are in the ranges the app accepts', () {
      expect(sql(), contains("masked_account !~ '[0-9]{7,}'"));
      expect(sql(), contains('payout_weekday int not null default 3 check (payout_weekday between 0 and 6)'));
      expect(sql(), contains('0 Sunday ... 6 Saturday'));
      expect(weekdayNames.first, 'Sunday');
      expect(weekdayNames.last, 'Saturday');
    }, skip: present ? false : why);

    test('a payout is Paid only with a reference', () {
      expect(sql(), contains("constraint site_payout_items_paid_check check (status <> 'paid' or (reference is not null and paid_at is not null))"));
    }, skip: present ? false : why);
  });
}
