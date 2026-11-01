import 'dart:io';

import 'package:bottles_up_vendor/features/table_map/logic/table_map_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// The database and the server decide how a combination is saved and worked out; the app must not drift from them. These read the website's files when they are checked out beside
// this app (the monorepo) and are skipped otherwise.
void main() {
  final migration = File('../bottles-up-website-main/supabase/migrations/20261120100000_deposit_combination.sql');
  final allocation = File('../bottles-up-website-main/supabase/functions/_shared/depositAllocation.ts');
  const why = 'website repo is not checked out next to this app';
  final present = migration.existsSync() && allocation.existsSync();

  group('agrees with the website', () {
    test('the combination has its own function, taking exactly the fields the app sends', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains('create function public.save_venue_deposit_combination(p_venue uuid, p_details jsonb)'));
      expect(sql, contains("array['recipient', 'venue_pct', 'reservation_fee_pct', 'minimum_spend_credit_pct', 'admission_pct']"));
      const form = DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.combination, feePctText: '30', creditPctText: '50', admissionPctText: '20');
      expect(depositTermsPayload(form).keys.toSet(), {'recipient', 'venue_pct', 'reservation_fee_pct', 'minimum_spend_credit_pct', 'admission_pct'});
      expect(depositSaveFunction(form), 'save_venue_deposit_combination');
    }, skip: present ? false : why);

    test('it is stored under the purpose and the part names the app reads', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains("'purpose', 'combination'"));
      expect(sql, contains("'parts', jsonb_build_object('reservation_fee_pct', v_fee, 'minimum_spend_credit_pct', v_credit_pct, 'admission_pct', v_adm)"));
      expect(DepositPurpose.combination.db, 'combination');
      expect(parseDepositTerms({'recipient': 'venue', 'venue_pct': 100, 'purpose': 'combination', 'parts': {'reservation_fee_pct': 30, 'minimum_spend_credit_pct': 50, 'admission_pct': 20}}), isNotNull);
    }, skip: present ? false : why);

    test('the rules are the same: shares add up to 100, at least two above 0, and the credit follows BottlesUp\'s switch both ways', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains('v_fee + v_credit_pct + v_adm <> 100'));
      expect(sql, contains(') < 2 then'));
      expect(sql, contains('if v_credit_pct > 0 and not v_credit then'));
      expect(sql, contains('if v_credit_pct = 0 and v_credit then'));
      expect(sql, contains("'reservation_fee_pct', 'the reservation fee share', 0, 100"));
    }, skip: present ? false : why);

    test('the cents are worked out the way the server does: the credit and the admission round down, the fee takes the rest', () {
      final ts = allocation.readAsStringSync();
      expect(ts, contains('Math.floor((deposit * parts.minimumSpendCreditPct) / 100)'));
      expect(ts, contains('Math.floor((deposit * parts.admissionPct) / 100)'));
      expect(ts, contains('reservationFeeCents: deposit - minimumSpendCreditCents - admissionCents'));
      // the same worked examples as the server's own tests (tests/edge/depositAllocation.test.ts)
      final a = const DepositShares(reservationFeePct: 30, minimumSpendCreditPct: 50, admissionPct: 20).split(20000);
      expect((a.reservationFeeCents, a.minimumSpendCreditCents, a.admissionCents), (6000, 10000, 4000));
      final b = const DepositShares(reservationFeePct: 33, minimumSpendCreditPct: 33, admissionPct: 34).split(10001);
      expect((b.reservationFeeCents, b.minimumSpendCreditCents, b.admissionCents), (3301, 3300, 3400));
    }, skip: present ? false : why);
  });
}
