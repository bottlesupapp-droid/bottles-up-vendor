import 'dart:io';

import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:bottles_up_vendor/features/table_service/services/receipt_service.dart';
import 'package:flutter_test/flutter_test.dart';

// The database decides every one of these words, limits and rules; the app must not drift from them. These read the website's source
// when it is checked out beside this app (the monorepo) and are skipped otherwise.
void main() {
  final orders = File(
    '../bottles-up-website-main/supabase/migrations/20261014120000_desk_orders.sql',
  );
  final payments = File(
    '../bottles-up-website-main/supabase/migrations/20261014130000_desk_payments.sql',
  );
  final shapes = File(
    '../bottles-up-website-main/tests/db/prod_shapes/20261014120000_money_tables.sql',
  );
  final accepted = File(
    '../bottles-up-website-main/supabase/migrations/20261022100000_order_accepted_stage.sql',
  );
  const why = 'website repo is not checked out next to this app';
  final present =
      orders.existsSync() && payments.existsSync() && shapes.existsSync();

  group('agrees with the website', () {
    String sql() => orders.readAsStringSync() + payments.readAsStringSync();

    List<String> quotedList(String source, RegExp pattern) =>
        RegExp(r"'([a-z_]+)'")
            .allMatches(pattern.firstMatch(source)!.group(1)!)
            .map((m) => m.group(1)!)
            .toList();

    test(
      'the service states are the ones the database allows, in the order of service: the five production had, and Accepted from 20261022100000',
      () {
        final all = [for (final s in ServiceState.values) s.value];
        final withoutAccepted = [for (final v in all) if (v != 'accepted') v];
        final fromShape = quotedList(
          shapes.readAsStringSync(),
          RegExp(
            r"service_status text not null default 'awaiting_prep'\s*check \(service_status in \(([^)]*)\)\)",
          ),
        );
        // What production had before Accepted, and what the function said then.
        expect(withoutAccepted, fromShape);
        final fromFunction = quotedList(
          orders.readAsStringSync(),
          RegExp(r'p_status not in \(([^)]*)\) then'),
        );
        expect(withoutAccepted, fromFunction);
        // The migration that adds Accepted: its constraint and the function it replaces carry all six, in the same order.
        if (accepted.existsSync()) {
          final migration = accepted.readAsStringSync();
          final constraint = RegExp(r"check \(service_status = any \(array\[([^\]]*)\]\)\)").firstMatch(migration)!.group(1)!;
          expect(RegExp(r"'([a-z_]+)'").allMatches(constraint).map((m) => m.group(1)!).toList(), all);
          final allowed = RegExp(r"p_status is null or p_status not in \(([^)]*)\) then").firstMatch(migration)!.group(1)!;
          expect(RegExp(r"'([a-z_]+)'").allMatches(allowed).map((m) => m.group(1)!).toList(), all);
        }
      },
      skip: present ? false : why,
    );

    test(
      'the ways a line is paid are the ones production allows',
      () {
        final fromShape = quotedList(
          shapes.readAsStringSync(),
          RegExp(
            r"payment_status text not null default 'paid' check \(payment_status in \(([^)]*)\)\)",
          ),
        );
        expect([for (final p in LinePayment.values) p.value], fromShape);
      },
      skip: present ? false : why,
    );

    test(
      'the payment methods are the ones the database takes',
      () {
        final fromSql = quotedList(
          payments.readAsStringSync(),
          RegExp(r'p_payment_method not in \(([^)]*)\) then'),
        );
        expect([for (final m in PayMethod.values) m.value], fromSql);
        final fromShape = quotedList(
          shapes.readAsStringSync(),
          RegExp(
            r'payment_method text not null check \(payment_method in \(([^)]*)\)\)',
          ),
        );
        expect([for (final m in PayMethod.values) m.value], fromShape);
      },
      skip: present ? false : why,
    );

    test(
      'the verification states are the four the money answer can hold',
      () {
        final src = payments.readAsStringSync();
        final caseBlock =
            RegExp(
              r"'verification', case([\s\S]*?)end\s*\)",
            ).firstMatch(src)!.group(1)!;
        final states =
            RegExp(
                r"then '([a-z_]+)'",
              ).allMatches(caseBlock).map((m) => m.group(1)!).toList()
              ..add(
                RegExp(r"else '([a-z_]+)'").firstMatch(caseBlock)!.group(1)!,
              );
        expect(states.toSet(), {for (final v in Verification.values) v.value});
        // A dispute outranks a check, which outranks the guest's own confirmation: the order of the lines is the order of the app.
        expect(states, [
          'disputed',
          'verified',
          'customer_confirmed',
          'pending',
        ]);
      },
      skip: present ? false : why,
    );

    test(
      'the functions and their argument names are the ones the app sends',
      () {
        final all = sql();
        for (final signature in [
          'desk_orders(p_venue uuid, p_night date)',
          'desk_booking_orders(p_booking uuid)',
          'desk_set_service_status(p_line uuid, p_status text)',
          'desk_booking_money(p_booking uuid)',
          'desk_pending_verifications(p_venue uuid)',
          'desk_verify_payment(p_payment uuid, p_note text default null)',
          'desk_table_status(p_venue uuid, p_night date)',
          'desk_tonight(p_venue uuid, p_night date)',
        ]) {
          expect(
            all,
            contains('create function public.$signature'),
            reason: signature,
          );
        }
        expect(moveParams('l', ServiceState.ready).keys, [
          'p_line',
          'p_status',
        ]);
        expect(verifyParams('p', null).keys, ['p_payment', 'p_note']);
      },
      skip: present ? false : why,
    );

    test(
      'recording a payment sends exactly the arguments the database defines, in its order',
      () {
        final m = RegExp(
          r'create function public\.desk_record_payment\(([\s\S]*?)\)\s*returns jsonb',
        ).firstMatch(payments.readAsStringSync());
        expect(m, isNotNull);
        final fromSql =
            RegExp(
              r'(p_[a-z_]+) ',
            ).allMatches(m!.group(1)!).map((x) => x.group(1)!).toList();
        expect(
          recordPaymentParams('b', const PaymentInput()).keys.toList(),
          fromSql,
        );
      },
      skip: present ? false : why,
    );

    test(
      'every column the app reads is one the database returns',
      () {
        String table(String fn) {
          final m = RegExp(
            'create function public\\.$fn\\([^)]*\\)\\s*returns table \\(([\\s\\S]*?)\\)\\s*language',
          ).firstMatch(sql());
          expect(m, isNotNull, reason: fn);
          return m!.group(1)!;
        }

        final ordersTable = table('desk_orders');
        for (final c in [
          'line_id',
          'booking_id',
          'confirmation_code',
          'customer_name',
          'table_name',
          'guest_count',
          'bottle_name',
          'size',
          'quantity',
          'line_total_cents',
          'is_addon',
          'payment_status',
          'service_status',
          'ordered_at',
          'checked_in_at',
          'balance_due_cents',
          'server_membership_id',
          'server_is_me',
        ]) {
          expect(ordersTable, contains(c), reason: 'desk_orders.$c');
        }
        final lines = table('desk_booking_orders');
        for (final c in [
          'line_id',
          'bottle_name',
          'size',
          'quantity',
          'unit_price_cents',
          'line_total_cents',
          'is_addon',
          'payment_status',
          'service_status',
          'ordered_at',
          'cancelled_at',
          'cancellation_reason',
        ]) {
          expect(lines, contains(c), reason: 'desk_booking_orders.$c');
        }
        final pending = table('desk_pending_verifications');
        for (final c in [
          'payment_id',
          'booking_id',
          'confirmation_code',
          'customer_name',
          'table_name',
          'payment_method',
          'billed_amount_cents',
          'amount_paid_cents',
          'pos_reference',
          'receipt_photo_path',
          'missing_receipt_reason',
          'recorded_at',
          'recorded_by_name',
          'recorded_by_me',
          'customer_confirmation_status',
          'dispute_reason',
        ]) {
          expect(pending, contains(c), reason: 'desk_pending_verifications.$c');
        }
        final status = table('desk_table_status');
        for (final c in [
          'booking_id',
          'balance_due_cents',
          'items_open',
          'items_delivered',
          'payments_recorded',
          'payments_unchecked',
          'closed_out',
          'closeout_requested',
        ]) {
          expect(status, contains(c), reason: 'desk_table_status.$c');
        }
        final tonight = table('desk_tonight');
        for (final c in [
          'tables',
          'guests',
          'arrived',
          'without_server',
          'with_balance',
          'balance_due_cents',
          'orders_new',
          'orders_in_progress',
          'orders_delivered',
          'payments_to_check',
          'payments_disputed',
          'closeouts_requested',
          'requests_open',
        ]) {
          expect(tonight, contains(c), reason: 'desk_tonight.$c');
        }
      },
      skip: present ? false : why,
    );

    test(
      'every key the app reads from a table\'s money is one the database puts in it',
      () {
        final src = payments.readAsStringSync();
        final body =
            RegExp(
              r'create function public\.desk_booking_money[\s\S]*?\$\$;',
            ).firstMatch(src)!.group(0)!;
        for (final k in [
          'level',
          'confirmation_code',
          'customer_name',
          'table_name',
          'guest_count',
          'currency',
          'status',
          'amount_total_cents',
          'amount_paid_cents',
          'balance_due_cents',
          'closed_out',
          'closeout_requested',
          'payments',
          'id',
          'billed_amount_cents',
          'payment_method',
          'pos_reference',
          'receipt_photo_path',
          'missing_receipt_reason',
          'payer_name',
          'recorded_at',
          'recorded_by_me',
          'gratuity_cents',
          'manager_verified_note',
          'verification',
        ]) {
          expect(body, contains("'$k'"), reason: k);
        }
        expect(
          body,
          isNot(contains('payer_email')),
          reason: 'a guest\'s email is never sent to the app',
        );
      },
      skip: present ? false : why,
    );

    test('the limits on a payment are the database\'s', () {
      final src = payments.readAsStringSync();
      expect(src, contains('> $maxPaymentCents then'));
      expect(src, contains('char_length(v_pos) > $maxReceiptNumberLength'));
      expect(src, contains('char_length(v_name) > $maxPayerNameLength'));
      expect(src, contains('char_length(v_reason) > $maxReasonLength'));
      expect(src, contains('char_length(v_note) > $verifyNoteLimit'));
      expect(
        src,
        contains('length(p_split_breakdown::text) > $maxSplitBreakdownLength'),
      );
      expect(
        src,
        contains('keep the reason to $maxReasonLength characters or fewer'),
      );
      expect(
        src,
        contains('keep the note to $verifyNoteLimit characters or fewer'),
      );
    }, skip: present ? false : why);

    test(
      'a receipt photo is filed where the database and the storage policy expect it, in the private bucket',
      () {
        final src = payments.readAsStringSync();
        expect(src, contains("'^' || p_booking::text || '/[^/].*\$'"));
        final path = receiptStoragePath(
          '11111111-2222-3333-4444-555555555555',
          'jpg',
          'abc',
        );
        expect(
          RegExp(
            '^11111111-2222-3333-4444-555555555555/[^/].*\$',
          ).hasMatch(path),
          true,
        );
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.',
          ).hasMatch(path),
          true,
          reason: 'the storage policy reads the booking from the first segment',
        );
        expect(src, contains("bucket_id = 'club-payment-receipts'"));
        expect(ReceiptService.bucket, 'club-payment-receipts');
        expect(src, contains("p_receipt_photo_hash !~ '^[0-9a-f]{64}\$'"));
      },
      skip: present ? false : why,
    );

    test(
      'what the app says before the tap agrees with what the database enforces after it',
      () {
        final src = orders.readAsStringSync();
        // An item to be paid at the venue is held while the table owes money, and needs a recorded payment.
        expect(src, contains("v_line.payment_status = 'due_at_venue'"));
        expect(
          src,
          contains(
            'cannot mark delivered - this table still has a balance due at the venue',
          ),
        );
        expect(
          src,
          contains(
            'cannot mark delivered - no payment has been recorded for this table',
          ),
        );
        // A server cannot take a delivered item back.
        expect(
          src,
          contains("v_level = 'server' and v_line.service_status = 'served'"),
        );
        expect(
          src,
          contains('a delivered item can only be changed by a manager'),
        );
        // A server must attach a receipt photo; a manager may give a reason.
        final pay = payments.readAsStringSync();
        expect(
          pay,
          contains(
            "if v_level <> 'manager' then raise exception 'a receipt photo is required'",
          ),
        );
        expect(
          pay,
          contains('a reason is required when recording without a receipt'),
        );
        // Nobody verifies their own entry or a disputed one.
        expect(
          pay,
          contains(
            'you recorded this payment, so someone else has to verify it',
          ),
        );
        expect(pay, contains("v_p.customer_confirmation_status <> 'pending'"));
      },
      skip: present ? false : why,
    );

    test(
      'the fake database the screens are tested against raises only sentences the real one raises',
      () {
        final fake =
            File(
              'test/table_service/fake_table_backend.dart',
            ).readAsStringSync();
        final sentences =
            RegExp(
              r'''refuse\('([^']+)'\)|refuse\("([^"]+)"\)''',
            ).allMatches(fake).map((m) => m.group(1) ?? m.group(2)!).toSet();
        expect(sentences, isNotEmpty);
        // The fake's section for adding bottles and partial delivery is checked against its own migrations (and only when they are checked out: an older
        // website checkout does not have them).
        const from = '// --- partial delivery and adding bottles';
        const to = 'String _verification';
        final newSection = fake.substring(fake.indexOf(from), fake.indexOf(to));
        final newSentences = RegExp(r'''refuse\('([^']+)'\)''').allMatches(newSection).map((m) => m.group(1)!).toSet();
        final website = Platform.environment['WEBSITE_REPO'] ?? '../bottles-up-website-main';
        final addBottlesSql = File('$website/supabase/migrations/20261020150000_add_bottles_checks.sql');
        final partialSql = File('$website/supabase/migrations/20261020160000_partial_delivery.sql');
        final haveNew = addBottlesSql.existsSync() && partialSql.existsSync() && accepted.existsSync();
        final real = sql() + (haveNew ? addBottlesSql.readAsStringSync() + partialSql.readAsStringSync() + accepted.readAsStringSync() : '');
        for (final raw in sentences) {
          if (!haveNew && newSentences.contains(raw)) continue;
          // A sentence with a number in it is written with % in the SQL.
          final s = raw.replaceAll(RegExp(r'\$\{[^}]*\}'), '%');
          expect(
            real,
            contains(s.replaceAll("'", "''")),
            reason: 'the fake raises "$s" but the database does not',
          );
        }
      },
      skip: present ? false : why,
    );
  });
}
