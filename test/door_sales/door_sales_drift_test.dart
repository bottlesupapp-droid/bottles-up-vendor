import 'dart:io';

import 'package:bottles_up_vendor/features/door_sales/logic/door_sales_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_door_sales_backend.dart';

// The database decides every limit, sentence and name here; the app and the fake used in its tests must not drift from them. These read the website's migration when it is checked out
// beside this app (the monorepo) and are skipped otherwise.
void main() {
  final migration = File('../bottles-up-website-main/supabase/migrations/20261026100000_door_sales.sql');
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

    test('the three functions the app calls take the arguments it sends, by name and in order', () {
      expect(fn('door_sale_options'), contains('create function public.door_sale_options(p_event uuid)'));
      expect(fn('door_shift_summary'), contains('create function public.door_shift_summary(p_event uuid)'));
      expect(
        fn('door_sell_ticket'),
        contains('p_event uuid, p_tier uuid, p_quantity int, p_method text, p_name text, p_email text, p_phone text, p_reference text, p_client_key text'),
      );
    }, skip: present ? false : why);

    test('the fake database takes exactly the parameters the real functions take', () async {
      final db = FakeDoorSalesBackend();
      await db.service.options('e1');
      await db.service.sell(eventId: 'e1', tierId: 't-gen', quantity: 1, method: DoorPayMethod.cash, name: 'Dana', email: '', phone: '', reference: '', key: 'key-0000001');
      await db.service.summary('e1');
      for (final c in db.calls) {
        final params = c.$2!.keys.toList();
        final declared = RegExp('create function public\\.${c.$1}\\(([^)]*)\\)').firstMatch(sql())!.group(1)!;
        final names = RegExp(r'(p_[a-z_]+) ').allMatches(declared).map((m) => m.group(1)!).toList();
        expect(params.toList()..sort(), names.toList()..sort(), reason: c.$1);
      }
    }, skip: present ? false : why);

    test('the limits the app checks first are the database\'s', () {
      final sell = fn('door_sell_ticket');
      expect(sell, contains('char_length(v_name) < $guestNameMin or char_length(v_name) > $guestNameMax'));
      expect(sell, contains('the guest\'\'s name needs $guestNameMin to $guestNameMax characters'));
      expect(sell, contains('char_length(v_ref) < $receiptMin or char_length(v_ref) > $receiptMax'));
      expect(sell, contains('the receipt number needs $receiptMin to $receiptMax characters'));
      expect(sell, contains('char_length(v_phone) > $phoneMax'));
      expect(sell, contains('char_length(v_email) > $emailMax'));
      expect(sell, contains('p_quantity < 1 or p_quantity > $maxTicketsPerSale'));
      expect(sell, contains('how many tickets? between 1 and $maxTicketsPerSale'));
      expect(sell, contains('char_length(v_key) < $saleKeyMin or char_length(v_key) > $saleKeyMax'));
      expect(sell, contains('a sale needs its own key of $saleKeyMin to $saleKeyMax characters'));
    }, skip: present ? false : why);

    test('an email is judged by the same shape on both sides', () {
      expect(fn('door_sell_ticket'), contains(r"'^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'"));
      // the app's shape: the same pieces
      expect(validateSale(option: const SaleOption(tierId: 't', name: 'G', priceCents: 1, currency: 'cad', capacity: 5, soldCount: 0, available: 5), quantity: 1, method: DoorPayMethod.cash, name: 'Dana', email: 'a@b.co', phone: '', reference: ''), isNull);
      expect(validateSale(option: const SaleOption(tierId: 't', name: 'G', priceCents: 1, currency: 'cad', capacity: 5, soldCount: 0, available: 5), quantity: 1, method: DoorPayMethod.cash, name: 'Dana', email: 'a@b', phone: '', reference: ''), isNotNull);
    }, skip: present ? false : why);

    test('the payment methods are the two the database accepts, and a terminal needs its number', () {
      final s = sql();
      expect(s, contains("door_payment_method in ('cash', 'external_terminal')"));
      expect(fn('door_sell_ticket'), contains("p_method not in ('cash', 'external_terminal')"));
      expect(fn('door_sell_ticket'), contains("p_method = 'external_terminal' and v_ref is null"));
      expect(s, contains("(door_payment_method = 'cash' or door_reference is not null)"));
      expect([for (final m in DoorPayMethod.values) m.db], ['cash', 'external_terminal']);
    }, skip: present ? false : why);

    test('selling is open from a day before the event to three hours after it, and is closed with a sentence the app recognises', () {
      final w = fn('door_sale_window_open');
      expect(w, contains("interval '${salesOpenAfter.inHours} hours'"));
      expect(w, contains("interval '${salesOpenBefore.inHours} hours'"));
      expect(w, contains("e.status = 'published'"));
      expect(fn('door_sale_options'), contains('ticket sales at the door are not open for this event'));
      expect(fn('door_sell_ticket'), contains('ticket sales at the door are not open for this event'));
      // the service recognises that sentence as "closed", not as a failure
      expect(File('lib/features/door_sales/services/door_sales_service.dart').readAsStringSync(), contains("'not open for this event'"));
    }, skip: present ? false : why);

    test('every refusal the fake gives is a sentence the database really raises', () {
      final f = File('test/door_sales/fake_door_sales_backend.dart').readAsStringSync();
      final sell = fn('door_sell_ticket') + fn('door_sale_options');
      final fakeSentences = RegExp(r"refuse\('((?:[^'\\]|\\.)*)'\)").allMatches(f).map((m) => m.group(1)!.replaceAll(r"\'", "''")).toSet();
      expect(fakeSentences, isNotEmpty);
      for (final s in fakeSentences) {
        if (s.contains(r'$')) continue; // only the "only N of these tickets are left" sentence has a value in it
        expect(sell, contains(s), reason: 'the fake says "$s"');
      }
      expect(sell, contains('only % of these tickets are left'));
    }, skip: present ? false : why);

    test('a ticket type that needs an access code is not offered or sold at the door', () {
      expect(fn('door_sale_options'), contains('not t.requires_access_code'));
      expect(fn('door_sell_ticket'), contains('if t.requires_access_code then raise exception \'that ticket type is not sold at the door\''));
    }, skip: present ? false : why);

    test('the answers carry the keys the app reads', () {
      final opts = fn('door_sale_options');
      for (final k in ['tier_id', 'tier_name', 'price_cents', 'currency', 'capacity', 'sold_count', 'available']) {
        expect(opts, contains(k), reason: k);
      }
      final sell = fn('door_sell_ticket');
      for (final k in ['order_id', 'ticket_code', 'quantity', 'amount_cents', 'currency', 'tier_name', 'available', 'repeated']) {
        expect(sell, contains("'$k'"), reason: k);
      }
      final shift = fn('door_shift_summary');
      for (final k in ['event_title', 'guests_admitted', 'scans_accepted', 'sales', 'method', 'tickets', 'amount_cents', 'first_sale_at', 'last_sale_at']) {
        expect(shift, contains("'$k'"), reason: k);
      }
    }, skip: present ? false : why);

    test('a sale is paid, checked in once, recorded as a door sale and counted against the tier, in one step', () {
      final sell = fn('door_sell_ticket');
      expect(sell, contains("'paid'"));
      expect(sell, contains('checked_in_at, checked_in_by'));
      expect(sell, contains("'door', p_method"));
      expect(sell, contains('for update'));
      expect(sell, contains('update public.site_ticket_tiers set sold_count = sold_count + p_quantity'));
      expect(sell, contains('insert into public.site_order_admissions'));
      expect(sell, contains("'BU-'"));
    }, skip: present ? false : why);

    test('only a door person who covers the event may use any of it, and visitors may not call it', () {
      for (final name in ['door_sale_options', 'door_sell_ticket', 'door_shift_summary']) {
        expect(fn(name), contains('public.has_door_role()'), reason: name);
        expect(fn(name), contains('public.can_scan_event(p_event)'), reason: name);
      }
      final s = sql();
      expect(s, contains('revoke all on function public.door_sale_window_open(uuid) from public, anon, authenticated;'));
      expect(s, contains('from public, anon;'));
    }, skip: present ? false : why);
  });
}
