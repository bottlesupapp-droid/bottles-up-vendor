import 'dart:io';

import 'package:bottles_up_vendor/features/refunds/logic/refund_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_refund_backend.dart';

// The database decides every name, limit and sentence here; the app must not drift from them. These read the website's migration and edge function when they are checked out beside
// this app (the monorepo) and are skipped otherwise.
void main() {
  final migration = File('../bottles-up-website-main/supabase/migrations/20261023100000_refund_policy_and_requests.sql');
  final cancel = File('../bottles-up-website-main/supabase/functions/cancel-table-booking/index.ts');
  const why = 'website repo is not checked out next to this app';
  final present = migration.existsSync() && cancel.existsSync();

  group('agrees with the website', () {
    String sql() => migration.readAsStringSync();

    // Two functions were corrected after 20261023100000 was applied in production (a receipt photo must belong to its booking; the list returns the evidence): their current text is in the
    // correction, which is never an edit of the applied file.
    final correction = File('../bottles-up-website-main/supabase/migrations/20261028100000_refund_receipt_evidence.sql');

    String fn(String name) {
      for (final (text, pattern) in [(correction.existsSync() ? correction.readAsStringSync() : '', RegExp('create (or replace )?function public\\.$name\\(')), (sql(), RegExp('create function public\\.$name\\('))]) {
        final m = pattern.firstMatch(text);
        if (m == null) continue;
        final end = text.indexOf('\n\$\$;', m.start);
        return text.substring(m.start, end);
      }
      fail('function $name is in the website\'s migrations');
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
      final db = FakeRefundBackend();
      db.addBooking('b1', paid: 10000);
      db.addBooking('b2', paid: 10000);
      final svc = db.service;
      await svc.policy('v1');
      await svc.savePolicy('v1', const RefundPolicyForm(tiers: [TierForm(hours: '48', percent: '100')]));
      await svc.requests('v1');
      await svc.options('b1');
      final id = await svc.ask('b1', 'Guest is ill');
      final r = (await svc.requests('v1')).firstWhere((x) => x.requestId == id);
      await svc.decide(id, const DecisionForm(approve: true, amountText: '50', method: RefundMethod.club, note: 'Fine'), r, paidOnline: true);
      await svc.completeClubRefund(id, 'TERM-1');
      final seen = <String>{};
      for (final c in db.calls) {
        seen.add(c.$1);
        expect((c.$2 ?? const {}).keys.toList()..sort(), params(c.$1).toList()..sort(), reason: '${c.$1}: parameters sent vs the SQL');
      }
      expect(seen, {'venue_refund_policy', 'save_venue_refund_policy', 'desk_refund_requests', 'desk_refund_options', 'desk_request_refund', 'desk_decide_refund', 'desk_complete_club_refund'});
    }, skip: present ? false : why);

    test('the rows the fake answers with have exactly the columns the database returns', () async {
      final db = FakeRefundBackend();
      db.addBooking('b1');
      db.addRequest('b1');
      final policy = await db.call('venue_refund_policy', params: {'p_venue': 'v1'}) as List;
      expect((policy.first as Map).keys.toSet(), columns('venue_refund_policy').toSet());
      final list = await db.call('desk_refund_requests', params: {'p_venue': 'v1', 'p_status': null}) as List;
      expect((list.first as Map).keys.toSet(), columns('desk_refund_requests').toSet());
    }, skip: present ? false : why);

    test('the options answer carries the keys the app reads', () {
      final text = fn('desk_refund_options');
      for (final key in ['paid_cents', 'deposit_cents', 'available_cents', 'hours_to_arrival', 'checked_in', 'paid_online', 'status', 'policy_lines', 'percent', 'suggested_cents', 'why', 'open_request_id']) {
        expect(text, contains("'$key'"), reason: key);
      }
    }, skip: present ? false : why);

    test('the policy limits are the database\'s: 6 rules, 0 to 2160 hours, 0 to 100 percent, 300 characters of note, only the three keys', () {
      final t = fn('save_venue_refund_policy');
      expect(t, contains("array['tiers', 'no_refund_after_check_in', 'note']"));
      expect(t, contains('jsonb_array_length(v_tiers) > 6'));
      expect(t, contains("'the hours of notice', 0, 2160"));
      expect(t, contains("'the percent refunded', 0, 100"));
      expect(t, contains("'the note', 300"));
      expect(maxRefundRules, 6);
      expect(maxRefundHours, 2160);
      expect(maxPolicyNote, 300);
      expect(t, contains("array['hours', 'percent']"));
      expect(policyPayload(const RefundPolicyForm(tiers: [TierForm(hours: '1', percent: '1')])).keys.toSet(), {'tiers', 'no_refund_after_check_in', 'note'});
    }, skip: present ? false : why);

    test('the policy rules read the same: no duplicate hours, and more notice never gets less back', () {
      final t = fn('save_venue_refund_policy');
      expect(t, contains("'two refund rules cannot have the same hours of notice'"));
      expect(t, contains("'giving more notice cannot get less back: a rule with fewer hours cannot refund a larger percent'"));
      expect(t, contains('v_prev_p is not null and v_p > v_prev_p'));
    }, skip: present ? false : why);

    test('the words guests read are the database\'s, sentence by sentence', () {
      final t = fn('refund_policy_lines');
      for (final sentence in [
        'This venue has not set a refund policy: refunds are decided by the venue.',
        'The deposit is not refundable.',
        'Cancel any time before you arrive: ',
        'Cancel at least ',
        ' before you arrive: ',
        'the whole deposit is refunded.',
        'no refund.',
        '% of the deposit is refunded.',
        'Later than that: no refund.',
        'Once the guests have arrived there is no refund.',
      ]) {
        expect(t, contains(sentence), reason: sentence);
      }
      expect(t, contains("' day'"));
      expect(t, contains("' days'"));
      expect(t, contains("' hour'"));
      expect(t, contains("' hours'"));
      expect(t, contains('v_hours % 24 = 0'));
    }, skip: present ? false : why);

    test('the statuses and methods are the ones the database allows, in its order', () {
      final s = sql();
      final statuses = RegExp(r"status text not null default 'requested' check \(status in \(([^)]*)\)\)").firstMatch(s)!.group(1)!;
      expect(RegExp(r"'([a-z]+)'").allMatches(statuses).map((m) => m.group(1)!).toList(), [for (final v in RefundStatus.values) v.db]);
      final methods = RegExp(r"method text check \(method in \(([^)]*)\)\)").firstMatch(s)!.group(1)!;
      expect(RegExp(r"'([a-z]+)'").allMatches(methods).map((m) => m.group(1)!).toList(), [for (final v in RefundMethod.values) v.db]);
    }, skip: present ? false : why);

    test('who may do what: the policy is the editor\'s, requests and decisions are the club\'s manager', () {
      expect(fn('venue_refund_policy'), contains('public.require_venue_editor(p_venue)'));
      expect(fn('save_venue_refund_policy'), contains('public.require_venue_editor(p_venue)'));
      expect(fn('desk_refund_options'), contains("public.desk_booking_level(p_booking) is distinct from 'manager'"));
      expect(fn('desk_request_refund'), contains("public.desk_booking_level(p_booking) is distinct from 'manager'"));
      expect(fn('desk_refund_requests'), contains("public.desk_level(p_venue) is distinct from 'manager'"));
      expect(fn('desk_decide_refund'), contains("public.desk_level(r.venue_id) is distinct from 'manager'"));
      expect(fn('desk_complete_club_refund'), contains("public.desk_level(r.venue_id) is distinct from 'manager'"));
    }, skip: present ? false : why);

    test('the limits on a request and a decision, and their sentences, are the database\'s', () {
      expect(fn('desk_request_refund'), contains('char_length(v_reason) < 3 or char_length(v_reason) > 500'));
      expect(fn('desk_request_refund'), contains("'give a reason of 3 to 500 characters'"));
      expect(fn('desk_decide_refund'), contains('char_length(v_note) > 500'));
      expect(fn('desk_decide_refund'), contains("'say why the refund is declined, so the guest can be told'"));
      expect(fn('desk_decide_refund'), contains("'choose how it is paid back: online, or at the club'"));
      expect(fn('desk_decide_refund'), contains("'how much is refunded?'"));
      expect(fn('desk_decide_refund'), contains("'only % can still be refunded on this booking'"));
      expect(fn('desk_decide_refund'), contains("'there is no online payment on this booking to return; record a refund made at the club instead'"));
      expect(fn('desk_decide_refund'), contains("'this is more than the refund policy suggests (%): say why'"));
      expect(fn('desk_decide_refund'), contains('p_amount_cents > r.suggested_cents and (v_note is null or char_length(v_note) < 3)'));
      expect(fn('desk_complete_club_refund'), contains('char_length(v_ref) > 200'));
      expect(fn('desk_complete_club_refund'), contains("'add the terminal or receipt reference, or a photo of the receipt, as evidence'"));
      expect(fn('desk_complete_club_refund'), contains("'only an approved refund that is paid back at the club can be recorded here'"));
    }, skip: present ? false : why);

    test('the cancel function wants a booking id and a reason, and answers whether money was paid', () {
      final t = cancel.readAsStringSync();
      expect(t, contains('const { booking_id, reason } = await req.json();'));
      expect(t, contains("'A reason is required'"));
      expect(t, contains("'This booking is already cancelled'"));
      expect(t, contains("desk_may_cancel_booking"));
      expect(t, contains('success: true'));
      expect(t, contains('refund_suggested:'));
    }, skip: present ? false : why);
  });
}
