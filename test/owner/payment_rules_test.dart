import 'dart:io';

import 'package:bottles_up_vendor/features/owner/logic/payment_rules.dart';
import 'package:bottles_up_vendor/features/owner/logic/setup_forms.dart';
import 'package:flutter_test/flutter_test.dart';

TableTypeRow table(String name, int deposit) => TableTypeRow(
      typeId: 't-$name', name: name, maxGuests: 6, minSpendCents: 0, depositCents: deposit, inventoryCount: 2, isFeatured: false, pricingMode: PricingMode.flat,
    );

void main() {
  group('the three ways to pay for bottles', () {
    test('are the three the database accepts, in the brief\'s order, with its words', () {
      expect([for (final m in BottlePaymentMode.values) m.db], ['pay_ahead', 'pay_at_club', 'both']);
      expect([for (final m in BottlePaymentMode.values) m.label], ['Pay ahead', 'Pay at the venue', 'Customer chooses']);
      for (final m in BottlePaymentMode.values) {
        expect(m.explanation, isNotEmpty);
      }
    });

    test('a stored value is understood, and one this app does not know is not shown as one of the three', () {
      expect(BottlePaymentMode.fromDb('pay_at_club'), BottlePaymentMode.payAtVenue);
      expect(BottlePaymentMode.fromDb('both'), BottlePaymentMode.customerChooses);
      expect(BottlePaymentMode.fromDb('on_credit'), isNull);
      expect(BottlePaymentMode.fromDb(null), isNull);
    });

    test('a row is read; a row without the mode is not a row', () {
      final r = parsePaymentRules({'bottle_payment_mode': 'both', 'deposit_is_credit': true})!;
      expect(r.mode, BottlePaymentMode.customerChooses);
      expect(r.depositIsCredit, isTrue);
      expect(parsePaymentRules({'bottle_payment_mode': 'weird', 'deposit_is_credit': false})!.mode, isNull);
      expect(parsePaymentRules({'bottle_payment_mode': 'both'})!.depositIsCredit, isFalse);
      expect(parsePaymentRules({'deposit_is_credit': true}), isNull);
    });

    test('Save is offered only when the choice differs from what is saved', () {
      const saved = PaymentRules(mode: BottlePaymentMode.payAhead, depositIsCredit: false);
      expect(paymentChanged(saved, null), isFalse);
      expect(paymentChanged(saved, BottlePaymentMode.payAhead), isFalse);
      expect(paymentChanged(saved, BottlePaymentMode.payAtVenue), isTrue);
      expect(paymentChanged(const PaymentRules(mode: null, depositIsCredit: false), BottlePaymentMode.payAhead), isTrue, reason: 'an unknown stored value can be replaced');
    });
  });

  group('deposits', () {
    test('each table says what it asks, or that it asks none', () {
      expect(depositLine(table('Booth', 10000)), 'Booth: \$100.00 deposit, paid online');
      expect(depositLine(table('Sofa', 0)), 'Sofa: no deposit');
    });

    test('the credit is explained both ways, and the note says why it is not changed here', () {
      expect(depositCreditLabel(true), contains('credited toward the bottle bill'));
      expect(depositCreditLabel(false), contains('not credited'));
      expect(depositCreditNote, contains('already exist'));
      expect(depositCreditNote, contains('Ask the team'));
    });

    test('payouts and paying at the venue are described honestly', () {
      expect(payoutNote, contains('set up and made by BottlesUp'));
      expect(payoutNote, contains('Settlements and payouts'));
      expect(atVenueNote, contains('manager checks it'));
    });
  });

  group('the same rules as the database (checked when the website is beside this app)', () {
    final file = File('../bottles-up-website-main/supabase/migrations/20261020100000_venue_payment_rules.sql');

    test('the three modes and the refusal of the deposit credit', () {
      if (!file.existsSync()) return;
      final sql = file.readAsStringSync();
      for (final m in BottlePaymentMode.values) {
        expect(sql, contains("'${m.db}'"), reason: m.db);
      }
      expect(sql, contains('save_venue_payment_rules(p_venue uuid, p_details jsonb)'));
      expect(sql, contains('venue_payment_rules(p_venue uuid)'));
      expect(sql, contains("'deposit_is_credit'"));
    });

    test('the function and argument names the service sends', () {
      if (!file.existsSync()) return;
      final sql = file.readAsStringSync();
      for (final name in ['p_venue', 'p_details', "'bottle_payment_mode'"]) {
        expect(sql, contains(name), reason: name);
      }
    });
  });
}
