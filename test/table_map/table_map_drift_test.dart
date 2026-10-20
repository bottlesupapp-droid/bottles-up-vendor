import 'dart:io';

import 'package:bottles_up_vendor/features/table_map/logic/table_map_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_table_map_backend.dart';

// The database decides every name, limit and sentence here; the app must not drift from them. These read the website's migrations when they are checked out beside this app
// (the monorepo) and are skipped otherwise.
void main() {
  final floor = File('../bottles-up-website-main/supabase/migrations/20261021100000_floor_plan_and_table_states.sql');
  final refunds = File('../bottles-up-website-main/supabase/migrations/20261023100000_refund_policy_and_requests.sql');
  const why = 'website repo is not checked out next to this app';
  final present = floor.existsSync() && refunds.existsSync();

  group('agrees with the website', () {
    String sql() => floor.readAsStringSync() + refunds.readAsStringSync();

    /// The text of `create function public.<name>(...)` up to its closing `$$;`.
    String fn(String name) {
      final s = sql();
      final start = s.indexOf('create function public.$name(');
      expect(start, isNot(-1), reason: 'function $name is in the website\'s migration');
      final end = s.indexOf('\n\$\$;', start);
      return s.substring(start, end);
    }

    /// The parameter names of a function, in order.
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
      if (inside.isEmpty) return const [];
      return [for (final p in inside.split(',')) p.trim().split(RegExp(r'\s+')).first];
    }

    /// The columns of `returns table (...)`.
    List<String> columns(String name) {
      final text = fn(name);
      final m = RegExp(r'returns table \(([\s\S]*?)\)\s*language').firstMatch(text)!;
      return [for (final c in m.group(1)!.split(',')) c.trim().split(RegExp(r'\s+')).first];
    }

    test('every function the app calls exists, and the app sends exactly its parameters, by name', () async {
      final db = FakeTableMapBackend();
      final booking = db.addBooking(table: 't2', guests: 3);
      final svc = db.service;
      await svc.states('v1', '2026-10-19');
      await svc.blocks('v1', '2026-10-19');
      await svc.block(venueId: 'v1', night: '2026-10-19', tableTypeId: 't2', slotId: 's1', form: const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 60));
      await svc.release(db.blocks.single['id'] as String);
      await svc.moveOptions(booking['id'] as String);
      await svc.move(booking['id'] as String, 't1', 'Guest asked');
      await svc.moves(booking['id'] as String);
      await svc.bookingTerms(booking['id'] as String);
      await svc.layout('v1');
      await svc.place('v1', 't2', 'f1', const PlacedBox(x: 5, y: 5, w: 10, h: 10));
      await svc.unplace('v1', 't2');
      await svc.setIncludedAdmissions('v1', 't2', 2);
      await svc.depositSettings('v1');
      await svc.saveDepositTerms('v1', const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.reservationFee));
      final seen = <String>{};
      for (final c in db.calls) {
        seen.add(c.$1);
        expect((c.$2 ?? const {}).keys.toList()..sort(), (params(c.$1).toList()..sort()), reason: '${c.$1}: parameters sent vs the SQL');
      }
      expect(seen, {
        'desk_table_states', 'desk_table_blocks', 'desk_table_block', 'desk_table_release', 'desk_booking_move_options', 'desk_move_booking', 'desk_booking_moves',
        'desk_booking_terms', 'list_venue_table_layout', 'place_venue_table', 'unplace_venue_table', 'set_table_included_admissions', 'venue_deposit_terms', 'save_venue_deposit_terms',
      });
    }, skip: present ? false : why);

    test('the rows the fake answers with have exactly the columns the database returns, so the app reads what is really there', () async {
      final db = FakeTableMapBackend();
      final booking = db.addBooking(table: 't2', guests: 3);
      await db.service.block(venueId: 'v1', night: '2026-10-19', tableTypeId: 't2', slotId: 's1', form: const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 60));
      await db.service.move(booking['id'] as String, 't1', 'Guest asked');
      for (final entry in {
        'desk_table_states': {'p_venue': 'v1', 'p_night': 'n'},
        'desk_table_blocks': {'p_venue': 'v1', 'p_night': 'n'},
        'desk_booking_move_options': {'p_booking': booking['id']},
        'desk_booking_moves': {'p_booking': booking['id']},
        'list_venue_table_layout': {'p_venue': 'v1'},
        'venue_deposit_terms': {'p_venue': 'v1'},
      }.entries) {
        final rows = await db.call(entry.key, params: entry.value as Map<String, dynamic>) as List;
        expect(rows, isNotEmpty, reason: entry.key);
        expect((rows.first as Map).keys.toSet(), columns(entry.key).toSet(), reason: '${entry.key}: columns');
      }
    }, skip: present ? false : why);

    test('the json answers carry the keys the app reads', () {
      expect(fn('desk_table_block'), contains("jsonb_build_object('block_id', v_id, 'free_after', v_free - p_quantity)"));
      expect(fn('desk_move_booking'), contains("jsonb_build_object('move_id', v_id, 'from', f.name, 'to', t.name, 'price_difference_cents', v_diff)"));
      expect(fn('desk_booking_terms'), allOf(contains("'deposit_cents'"), contains("'deposit_terms'"), contains("'included_admissions'"), contains("'refund_policy_set'"), contains("'refund_policy_lines'")));
    }, skip: present ? false : why);

    test('a hold lasts what the database says: 5 minutes to 24 hours, and the choices are all inside it', () {
      expect(fn('desk_table_block'), contains('p_minutes < 5 or p_minutes > 1440'));
      expect(fn('desk_table_block'), contains("'a hold lasts between 5 minutes and 24 hours'"));
      expect(holdMinutesChoices.every((m) => m >= 5 && m <= 1440), isTrue);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'abc', minutes: 4), 1), isNotEmpty);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'abc', minutes: 5), 1), isEmpty);
    }, skip: present ? false : why);

    test('the blocks are Held or Unavailable, and a reason is 3 to 200 characters, as the database says', () {
      final t = fn('desk_table_block');
      expect(t, contains("p_kind not in ('held', 'unavailable')"));
      expect(t, contains('char_length(v_reason) < 3 or char_length(v_reason) > 200'));
      expect(t, contains("'give a reason of 3 to 200 characters'"));
      expect(t, contains("'how many tables?'"));
      expect(validateBlock(const BlockForm(kind: 'unavailable', quantity: 1, reason: 'ab'), 1), ['Give a reason of 3 to 200 characters.']);
      expect(validateBlock(const BlockForm(kind: 'unavailable', quantity: 0, reason: 'abc'), 1), ['How many tables?']);
    }, skip: present ? false : why);

    test('a move needs the same reason, and the database\'s own sentences are the ones the app shows for the refusals it knows', () {
      final t = fn('desk_move_booking');
      expect(t, contains('char_length(v_reason) < 3 or char_length(v_reason) > 200'));
      for (final sentence in [
        'only a confirmed booking can be moved',
        'the booking is already at that table',
        'that table seats up to % guests and this booking has %',
        'that table needs at least % guests and this booking has %',
        'no tables of that type are free for that time',
        'this night has been closed, so the booking cannot be moved',
      ]) {
        expect(t, contains(sentence));
      }
      expect(fn('desk_booking_move_options'), contains('b.guest_count <= t.max_guests and (t.min_guests is null or b.guest_count >= t.min_guests)'));
    }, skip: present ? false : why);

    test('placement: a table is at least 2 percent wide and high, fully inside the picture, and admissions are 0 to 100 and no more than the seats', () {
      final p = fn('place_venue_table');
      expect(p, contains('p_x < 0 or p_y < 0 or p_w < 2 or p_h < 2 or p_x + p_w > 100.01 or p_y + p_h > 100.01'));
      expect(minBoxPercent, 2);
      expect(p, contains('round(p_x, 2)'));
      final a = fn('set_table_included_admissions');
      expect(a, contains('p_count < 0 or p_count > 100'));
      expect(a, contains('p_count > v_max'));
      expect(validateIncludedAdmissions('101', 200), isNotNull);
      expect(validateIncludedAdmissions('100', 200), isNull);
    }, skip: present ? false : why);

    test('deposit terms: the recipients and purposes are the ones the database takes, the keys are the three it accepts, and the credit switch decides the purpose', () {
      final t = fn('save_venue_deposit_terms');
      expect(t, contains("array['recipient', 'venue_pct', 'purpose']"));
      expect(t, contains("v_recipient not in ('venue', 'organizer', 'split')"));
      expect(t, contains("v_purpose not in ('reservation_fee', 'minimum_spend_credit', 'admission')"));
      expect([for (final r in DepositRecipient.values) r.db], ['venue', 'organizer', 'split']);
      expect([for (final p in DepositPurpose.values) p.db], ['reservation_fee', 'minimum_spend_credit', 'admission']);
      expect(t, contains("if v_purpose = 'minimum_spend_credit' and not v_credit then"));
      expect(t, contains("if v_purpose <> 'minimum_spend_credit' and v_credit then"));
      expect(t, contains('v_pct is null or v_pct < 1 or v_pct > 99'));
      expect(depositTermsPayload(const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.admission)).keys.toSet(), {'recipient', 'venue_pct', 'purpose'});
    }, skip: present ? false : why);

    test('the states are counted in the five ways the map shows', () {
      expect(columns('desk_table_states'), containsAll(['booked', 'occupied', 'held', 'unavailable', 'available']));
      expect([for (final k in MapKind.values) k.label], ['Available', 'Held', 'Booked', 'Occupied', 'Unavailable']);
    }, skip: present ? false : why);

    test('the map shows from last night to 60 nights ahead, which is what the screen allows', () {
      expect(fn('desk_table_states'), contains('p_night < current_date - 1 or p_night > current_date + 60'));
      expect(fn('desk_table_block'), contains('p_night < current_date - 1 or p_night > current_date + 60'));
    }, skip: present ? false : why);

    test('who may do what: the map, blocks and moves are the club\'s manager; the terms are anyone who has the table; placement and deposit terms are the editor', () {
      for (final f in ['desk_table_states', 'desk_table_block', 'desk_table_blocks']) {
        expect(fn(f), contains("public.desk_level(p_venue) is distinct from 'manager'"), reason: f);
      }
      for (final f in ['desk_move_booking', 'desk_booking_moves', 'desk_booking_move_options']) {
        expect(fn(f), contains("public.desk_booking_level(p_booking) is distinct from 'manager'"), reason: f);
      }
      expect(fn('desk_booking_terms'), contains('public.desk_booking_level(p_booking) is null'));
      for (final f in ['list_venue_table_layout', 'place_venue_table', 'unplace_venue_table', 'set_table_included_admissions', 'venue_deposit_terms', 'save_venue_deposit_terms']) {
        expect(fn(f), contains('public.require_venue_editor(p_venue)'), reason: f);
      }
    }, skip: present ? false : why);
  });
}
