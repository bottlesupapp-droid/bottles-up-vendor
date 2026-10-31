import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/table_map/logic/table_map_rules.dart';
import 'package:bottles_up_vendor/features/table_map/providers/table_map_providers.dart';
import 'package:bottles_up_vendor/features/table_map/screens/deposit_terms_screen.dart';
import 'package:bottles_up_vendor/features/table_map/widgets/booking_terms_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_table_map_backend.dart';

// A deposit that is a combination: a reservation fee, a credit toward the minimum spend and admission, in whole percents that add up to 100 (website repo,
// 20261120100000_deposit_combination.sql and supabase/functions/_shared/depositAllocation.ts, tested there). Only the credit share counts toward the bottle bill.

const shares = DepositShares(reservationFeePct: 30, minimumSpendCreditPct: 50, admissionPct: 20);

Map<String, dynamic> comboJson({int fee = 30, int credit = 50, int admission = 20, String recipient = 'venue', int pct = 100}) => {
      'recipient': recipient,
      'venue_pct': pct,
      'purpose': 'combination',
      'parts': {'reservation_fee_pct': fee, 'minimum_spend_credit_pct': credit, 'admission_pct': admission},
    };

void main() {
  group('the shares', () {
    test('split a deposit like the server: the credit and the admission round down, the fee takes the rest', () {
      final x = shares.split(20000);
      expect((x.reservationFeeCents, x.minimumSpendCreditCents, x.admissionCents), (6000, 10000, 4000));
      final y = const DepositShares(reservationFeePct: 33, minimumSpendCreditPct: 33, admissionPct: 34).split(10001);
      expect((y.reservationFeeCents, y.minimumSpendCreditCents, y.admissionCents), (3301, 3300, 3400));
      final z = const DepositShares(reservationFeePct: 0, minimumSpendCreditPct: 50, admissionPct: 50).split(1);
      expect((z.reservationFeeCents, z.minimumSpendCreditCents, z.admissionCents), (1, 0, 0));
    });

    test('always add up to the deposit, never credit more than their share, and never go negative (every deposit up to 3,000 cents, every split)', () {
      for (var credit = 0; credit <= 100; credit += 7) {
        for (var admission = 0; admission <= 100 - credit; admission += 11) {
          final s = DepositShares(reservationFeePct: 100 - credit - admission, minimumSpendCreditPct: credit, admissionPct: admission);
          for (var d = 0; d <= 3000; d += 37) {
            final x = s.split(d);
            expect(x.reservationFeeCents + x.minimumSpendCreditCents + x.admissionCents, d);
            expect(x.reservationFeeCents, greaterThanOrEqualTo(0));
            expect(x.minimumSpendCreditCents * 100, lessThanOrEqualTo(d * credit));
            expect(x.admissionCents * 100, lessThanOrEqualTo(d * admission));
          }
        }
      }
    });

    test('a deposit below zero splits into nothing', () {
      final x = shares.split(-500);
      expect((x.reservationFeeCents, x.minimumSpendCreditCents, x.admissionCents), (0, 0, 0));
    });
  });

  group('reading the terms', () {
    test('a combination is read with its shares', () {
      final t = parseDepositTerms(comboJson())!;
      expect(t.purpose, DepositPurpose.combination);
      expect((t.shares!.reservationFeePct, t.shares!.minimumSpendCreditPct, t.shares!.admissionPct), (30, 50, 20));
    });

    test('a single purpose has no shares', () {
      expect(parseDepositTerms({'recipient': 'venue', 'venue_pct': 100, 'purpose': 'admission'})!.shares, isNull);
    });

    test('a combination the database could not have made is not read (and the booking says its terms were not recorded)', () {
      expect(parseDepositTerms({...comboJson(), 'parts': null}), isNull);
      expect(parseDepositTerms({...comboJson(), 'parts': 'x'}), isNull);
      expect(parseDepositTerms(comboJson(fee: 30, credit: 50, admission: 19)), isNull);
      expect(parseDepositTerms(comboJson(fee: 30, credit: 50, admission: 21)), isNull);
      expect(parseDepositTerms(comboJson(fee: -10, credit: 60, admission: 50)), isNull);
      expect(parseDepositTerms(comboJson(fee: -1, credit: 51, admission: 50)), isNull);
      expect(parseDepositTerms(comboJson(fee: 50, credit: 51, admission: -1)), isNull);
      expect(parseDepositTerms({...comboJson(), 'parts': {'reservation_fee_pct': 50, 'minimum_spend_credit_pct': 50}}), isNull);
    });
  });

  group('in words', () {
    test('the terms say each share, and leave out a share of 0', () {
      expect(depositTermsLine(parseDepositTerms(comboJson())!), 'The venue keeps the deposit, split into a reservation fee (30%), a credit toward the minimum spend (50%) and admission (20%).');
      expect(depositTermsLine(parseDepositTerms(comboJson(fee: 0, credit: 60, admission: 40, recipient: 'split', pct: 70))!),
          'The deposit is split: the venue 70%, the organizer 30%, split into a credit toward the minimum spend (60%) and admission (40%).');
    });

    test('a booking shows its own deposit worked out', () {
      expect(depositAllocationLine(shares, 20000), 'Of the deposit: reservation fee \$60.00, credit toward the minimum spend \$100.00, admission \$40.00.');
      expect(depositAllocationLine(const DepositShares(reservationFeePct: 0, minimumSpendCreditPct: 60, admissionPct: 40), 20000),
          'Of the deposit: credit toward the minimum spend \$120.00, admission \$80.00.');
    });

    test('the client\'s example: a \$200 deposit and a \$1,000 minimum', () {
      expect(depositExampleLines(shares), [
        'Example: a \$200.00 deposit on a table with a \$1,000.00 minimum spend.',
        'Reservation fee \$60.00: kept as a charge, not counted toward the minimum.',
        'Admission \$40.00: pays for entry, not counted toward the minimum.',
        'Credit \$100.00: counted toward the minimum, which leaves \$900.00 to spend.',
      ]);
      expect(depositExampleLines(const DepositShares(reservationFeePct: 50, minimumSpendCreditPct: 0, admissionPct: 50)).last, 'Nothing is counted toward the minimum: \$1,000.00 is still to spend.');
      // a credit larger than the minimum leaves nothing, never a negative
      expect(depositExampleLines(const DepositShares(reservationFeePct: 0, minimumSpendCreditPct: 100, admissionPct: 0), depositCents: 20000, minimumSpendCents: 5000).last, 'Credit \$200.00: counted toward the minimum, which leaves \$0.00 to spend.');
    });

    test('the booking card adds the worked deposit under the terms, only for a combination with a deposit', () {
      final terms = BookingTerms(depositCents: 20000, deposit: parseDepositTerms(comboJson()), includedAdmissions: 2, refundPolicySet: false, refundPolicyLines: const []);
      final lines = bookingTermsLines(terms);
      expect(lines[0], 'Deposit: \$200.00');
      expect(lines[2], 'Of the deposit: reservation fee \$60.00, credit toward the minimum spend \$100.00, admission \$40.00.');
      final single = BookingTerms(depositCents: 20000, deposit: parseDepositTerms({'recipient': 'venue', 'venue_pct': 100, 'purpose': 'admission'}), refundPolicySet: false, refundPolicyLines: const []);
      expect(bookingTermsLines(single).any((l) => l.startsWith('Of the deposit')), isFalse);
      final none = BookingTerms(depositCents: 0, deposit: parseDepositTerms(comboJson()), refundPolicySet: false, refundPolicyLines: const []);
      expect(bookingTermsLines(none).any((l) => l.startsWith('Of the deposit')), isFalse);
    });
  });

  group('checking what was typed', () {
    DepositTermsForm form({String fee = '30', String credit = '50', String admission = '20'}) =>
        DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.combination, feePctText: fee, creditPctText: credit, admissionPctText: admission);

    test('three shares that make 100, with the credit switched on, are fine', () {
      expect(validateDepositTerms(form(), depositIsCredit: true), isEmpty);
    });

    test('they have to be given, and be numbers', () {
      const need = 'Give a share between 0 and 100 for each of the three: the reservation fee, the credit toward the minimum spend and admission (0 for none).';
      expect(validateDepositTerms(form(fee: ''), depositIsCredit: true), [need]);
      expect(validateDepositTerms(form(credit: 'half'), depositIsCredit: true), [need]);
      expect(validateDepositTerms(form(admission: '20.5'), depositIsCredit: true), [need]);
      expect(validateDepositTerms(form(fee: '-10', credit: '60', admission: '50'), depositIsCredit: true), [need]);
      expect(validateDepositTerms(form(fee: '0', credit: '150', admission: '-50'), depositIsCredit: true), [need]);
    });

    test('they have to make 100, and say what they make', () {
      expect(validateDepositTerms(form(admission: '10'), depositIsCredit: true), ['The three shares have to add up to 100%. They add up to 90%.']);
      expect(validateDepositTerms(form(admission: '30'), depositIsCredit: true), ['The three shares have to add up to 100%. They add up to 110%.']);
    });

    test('at least two have to be above 0', () {
      expect(validateDepositTerms(form(fee: '0', credit: '100', admission: '0'), depositIsCredit: true), ['A combination needs at least two of the three above 0. For one purpose, choose it on its own.']);
    });

    test('the credit share follows BottlesUp\'s switch, both ways', () {
      expect(validateDepositTerms(form(), depositIsCredit: false), ['The credit toward the minimum spend is not switched on for this venue, so give it 0%. Ask the BottlesUp team if it should be switched on.']);
      expect(validateDepositTerms(form(fee: '50', credit: '0', admission: '50'), depositIsCredit: false), isEmpty);
      expect(validateDepositTerms(form(fee: '50', credit: '0', admission: '50'), depositIsCredit: true),
          ['The deposit is credited toward the bottle bill at this venue, so a combination needs a credit share above 0%. Ask the BottlesUp team if that should change.']);
    });

    test('other purposes are not asked for shares', () {
      expect(validateDepositTerms(const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.admission), depositIsCredit: false), isEmpty);
    });
  });

  group('saving', () {
    test('a combination goes to its own function with its own fields, the others as before', () {
      const combo = DepositTermsForm(recipient: DepositRecipient.split, venuePctText: '70', purpose: DepositPurpose.combination, feePctText: '30', creditPctText: '50', admissionPctText: '20');
      expect(depositSaveFunction(combo), 'save_venue_deposit_combination');
      expect(depositTermsPayload(combo), {'recipient': 'split', 'venue_pct': 70, 'reservation_fee_pct': 30, 'minimum_spend_credit_pct': 50, 'admission_pct': 20});
      const single = DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.admission);
      expect(depositSaveFunction(single), 'save_venue_deposit_terms');
      expect(depositTermsPayload(single), {'recipient': 'venue', 'venue_pct': 100, 'purpose': 'admission'});
    });

    test('the form is filled from what is saved, shares and all', () {
      final f = depositFormFrom(parseDepositTerms(comboJson(recipient: 'split', pct: 60)));
      expect((f.purpose, f.recipient, f.venuePctText, f.feePctText, f.creditPctText, f.admissionPctText), (DepositPurpose.combination, DepositRecipient.split, '60', '30', '50', '20'));
      expect(depositFormFrom(null).feePctText, '');
    });

    test('the service saves it and the database\'s sentences come back as they are', () async {
      final db = FakeTableMapBackend()
        ..role = 'manager'
        ..depositIsCredit = true;
      const ok = DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.combination, feePctText: '30', creditPctText: '50', admissionPctText: '20');
      await db.service.saveDepositTerms('v1', ok);
      expect(db.depositTerms, comboJson());
      expect(db.paramsOf('save_venue_deposit_combination').single, {'p_venue': 'v1', 'p_details': {'recipient': 'venue', 'venue_pct': 100, 'reservation_fee_pct': 30, 'minimum_spend_credit_pct': 50, 'admission_pct': 20}});
      expect(db.paramsOf('save_venue_deposit_terms'), isEmpty);
      await expectLater(
        db.service.saveDepositTerms('v1', const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.combination, feePctText: '40', creditPctText: '50', admissionPctText: '20')),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The three shares have to add up to 100 percent (they add up to 110 percent).')),
      );
      db.role = 'server';
      await expectLater(db.service.saveDepositTerms('v1', ok), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'You don\'t have access to do that.')));
    });
  });

  group('the screen', () {
    late FakeTableMapBackend db;
    setUp(() => db = FakeTableMapBackend()..role = 'manager');

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [tableMapServiceProvider.overrideWithValue(db.service)],
        child: MaterialApp(theme: ThemeData.dark(), home: const DepositTermsScreen(venueId: 'v1')),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    Future<void> typeIn(WidgetTester tester, String key, String text) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.enterText(find.byKey(Key(key)), text);
      await tester.pump();
    }

    bool has(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;
    String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('a combination is on offer whichever way the credit switch is set, and shares only show once it is chosen', (tester) async {
      await open(tester);
      expect(has('purpose-combination'), isTrue);
      expect(has('share-fee'), isFalse);
      db.depositIsCredit = true;
      await open(tester);
      expect(has('purpose-combination'), isTrue);
      expect(has('purpose-minimum_spend_credit'), isTrue);
      await tapKey(tester, 'purpose-combination');
      expect(has('share-fee') && has('share-credit') && has('share-admission'), isTrue);
    });

    testWidgets('shows the total as it is typed and the client\'s worked example when it makes 100', (tester) async {
      db.depositIsCredit = true;
      await open(tester);
      await tapKey(tester, 'purpose-combination');
      expect(textOf(tester, 'deposit-shares-total'), 'Give a share for each, 0 for none.');
      expect(has('deposit-example'), isFalse);
      await typeIn(tester, 'share-fee', '30');
      await typeIn(tester, 'share-credit', '50');
      await typeIn(tester, 'share-admission', '10');
      expect(textOf(tester, 'deposit-shares-total'), 'Together: 90%. They have to make 100%.');
      expect(has('deposit-example'), isFalse);
      await typeIn(tester, 'share-admission', '20');
      expect(textOf(tester, 'deposit-shares-total'), 'Together: 100%.');
      expect(find.text('Example: a \$200.00 deposit on a table with a \$1,000.00 minimum spend.'), findsOneWidget);
      expect(find.text('Credit \$100.00: counted toward the minimum, which leaves \$900.00 to spend.'), findsOneWidget);
    });

    testWidgets('saves a combination through its own function and keeps what was typed', (tester) async {
      db.depositIsCredit = true;
      await open(tester);
      await tapKey(tester, 'recipient-venue');
      await tapKey(tester, 'purpose-combination');
      await typeIn(tester, 'share-fee', '30');
      await typeIn(tester, 'share-credit', '50');
      await typeIn(tester, 'share-admission', '20');
      await tapKey(tester, 'deposit-terms-save');
      expect(db.depositTerms, comboJson());
      expect(db.paramsOf('save_venue_deposit_combination'), hasLength(1));
      expect(find.textContaining('Saved.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('share-credit'))).controller!.text, '50');
    });

    testWidgets('shows what is saved, shares and all, when it opens', (tester) async {
      db.depositIsCredit = true;
      db.depositTerms = comboJson(fee: 10, credit: 80, admission: 10);
      await open(tester);
      expect(textOf(tester, 'deposit-terms-now'), 'The venue keeps the deposit, split into a reservation fee (10%), a credit toward the minimum spend (80%) and admission (10%).');
      expect(tester.widget<TextField>(find.byKey(const Key('share-credit'))).controller!.text, '80');
    });

    testWidgets('does not ask the database when the shares are wrong, and says what is wrong', (tester) async {
      db.depositIsCredit = true;
      await open(tester);
      await tapKey(tester, 'recipient-venue');
      await tapKey(tester, 'purpose-combination');
      await typeIn(tester, 'share-fee', '30');
      await typeIn(tester, 'share-credit', '50');
      await typeIn(tester, 'share-admission', '10');
      await tapKey(tester, 'deposit-terms-save');
      expect(find.text('The three shares have to add up to 100%. They add up to 90%.'), findsOneWidget);
      expect(db.paramsOf('save_venue_deposit_combination'), isEmpty);
    });

    testWidgets('a venue whose credit is off cannot give the credit a share, and the screen says so', (tester) async {
      await open(tester);
      await tapKey(tester, 'recipient-venue');
      await tapKey(tester, 'purpose-combination');
      await typeIn(tester, 'share-fee', '30');
      await typeIn(tester, 'share-credit', '50');
      await typeIn(tester, 'share-admission', '20');
      await tapKey(tester, 'deposit-terms-save');
      expect(find.text('The credit toward the minimum spend is not switched on for this venue, so give it 0%. Ask the BottlesUp team if it should be switched on.'), findsOneWidget);
      await typeIn(tester, 'share-fee', '50');
      await typeIn(tester, 'share-credit', '0');
      await typeIn(tester, 'share-admission', '50');
      await tapKey(tester, 'deposit-terms-save');
      expect(db.depositTerms, comboJson(fee: 50, credit: 0, admission: 50));
    });

    testWidgets('the database\'s own refusal is shown as its sentence', (tester) async {
      db.depositIsCredit = true;
      await open(tester);
      await tapKey(tester, 'recipient-venue');
      await tapKey(tester, 'purpose-combination');
      await typeIn(tester, 'share-fee', '30');
      await typeIn(tester, 'share-credit', '50');
      await typeIn(tester, 'share-admission', '20');
      db.role = 'server';
      await tapKey(tester, 'deposit-terms-save');
      expect(find.text('You don\'t have access to do that.'), findsOneWidget);
    });
  });

  group('the booking card', () {
    testWidgets('shows the combination a booking was made under, worked out for its deposit', (tester) async {
      final db = FakeTableMapBackend()
        ..depositTerms = comboJson();
      final booking = db.addBooking(table: 't2', guests: 3);
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [tableMapServiceProvider.overrideWithValue(db.service)],
        child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: SingleChildScrollView(child: BookingTermsCard(bookingId: booking['id'] as String, canMove: false, onMoved: () {})))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Deposit: \$25.00'), findsOneWidget);
      expect(find.text('The venue keeps the deposit, split into a reservation fee (30%), a credit toward the minimum spend (50%) and admission (20%).'), findsOneWidget);
      // \$25.00 = 2500 cents: credit floor(1250) = \$12.50, admission floor(500) = \$5.00, the fee takes the rest, \$7.50
      expect(find.text('Of the deposit: reservation fee \$7.50, credit toward the minimum spend \$12.50, admission \$5.00.'), findsOneWidget);
    });
  });
}
