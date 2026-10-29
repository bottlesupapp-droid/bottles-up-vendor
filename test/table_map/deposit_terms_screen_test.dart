import 'dart:async';

import 'package:bottles_up_vendor/features/table_map/logic/table_map_rules.dart';
import 'package:bottles_up_vendor/features/table_map/providers/table_map_providers.dart';
import 'package:bottles_up_vendor/features/table_map/screens/deposit_terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_table_map_backend.dart';

late FakeTableMapBackend db;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [tableMapServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: const DepositTermsScreen(venueId: 'v1')),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

DepositRecipient? recipient(WidgetTester tester) => tester.widget<RadioGroup<DepositRecipient>>(find.byType(RadioGroup<DepositRecipient>)).groupValue;
DepositPurpose? purpose(WidgetTester tester) => tester.widget<RadioGroup<DepositPurpose>>(find.byType(RadioGroup<DepositPurpose>)).groupValue;

String now(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('deposit-terms-now'))).data!;

void main() {
  setUp(() => db = FakeTableMapBackend());

  testWidgets('before anything is chosen it says what bookings get, and offers a reservation fee or admission when the deposit is not credited', (tester) async {
    await open(tester);
    expect(now(tester), 'You have not chosen yet. Until you do, the venue keeps the deposit as a reservation fee.');
    expect(find.byKey(const Key('purpose-reservation_fee')), findsOneWidget);
    expect(find.byKey(const Key('purpose-admission')), findsOneWidget);
    expect(find.byKey(const Key('purpose-minimum_spend_credit')), findsNothing);
    expect(find.byKey(const Key('deposit-credit-explained')), findsOneWidget);
    expect(db.paramsOf('venue_deposit_terms').single, {'p_venue': 'v1'});
  });

  testWidgets('when the deposit is credited toward the bottle bill the only purpose is a minimum spend credit', (tester) async {
    db.depositIsCredit = true;
    await open(tester);
    expect(now(tester), contains('as a credit toward the minimum spend'));
    expect(find.byKey(const Key('purpose-minimum_spend_credit')), findsOneWidget);
    expect(find.byKey(const Key('purpose-reservation_fee')), findsNothing);
    expect(find.byKey(const Key('purpose-admission')), findsNothing);
  });

  testWidgets('the saved terms are shown and pre-selected', (tester) async {
    db.depositTerms = {'recipient': 'split', 'venue_pct': 60, 'purpose': 'admission'};
    await open(tester);
    expect(now(tester), 'The deposit is split: the venue 60%, the organizer 40%, as admission.');
    expect(recipient(tester), DepositRecipient.split);
    expect(purpose(tester), DepositPurpose.admission);
    expect(tester.widget<TextField>(find.byKey(const Key('deposit-venue-pct'))).controller!.text, '60');
    expect(find.text('The organizer gets 40%.'), findsOneWidget);
  });

  testWidgets('the share box only appears for a split, and says what the organizer gets as it is typed', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('deposit-venue-pct')), findsNothing);
    await tapKey(tester, 'recipient-split');
    expect(find.byKey(const Key('deposit-venue-pct')), findsOneWidget);
    expect(find.text('Between 1 and 99. The organizer gets the rest.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('deposit-venue-pct')), '70');
    await tester.pump();
    expect(find.text('The organizer gets 30%.'), findsOneWidget);
    await tapKey(tester, 'recipient-venue');
    expect(find.byKey(const Key('deposit-venue-pct')), findsNothing);
  });

  testWidgets('choosing the venue and a reservation fee saves exactly that', (tester) async {
    await open(tester);
    await tapKey(tester, 'recipient-venue');
    await tapKey(tester, 'purpose-reservation_fee');
    await tapKey(tester, 'deposit-terms-save');
    expect(db.paramsOf('save_venue_deposit_terms').single, {
      'p_venue': 'v1',
      'p_details': {'recipient': 'venue', 'venue_pct': 100, 'purpose': 'reservation_fee'},
    });
    expect(find.textContaining('Saved. It applies to bookings made from now on'), findsOneWidget);
    expect(db.depositTerms, {'recipient': 'venue', 'venue_pct': 100, 'purpose': 'reservation_fee'});
    expect(now(tester), 'The venue keeps the deposit, as a reservation fee.');
  });

  testWidgets('a split saves the share typed, and it is still there after saving', (tester) async {
    await open(tester);
    await tapKey(tester, 'recipient-split');
    await tester.enterText(find.byKey(const Key('deposit-venue-pct')), '60');
    await tapKey(tester, 'purpose-admission');
    await tapKey(tester, 'deposit-terms-save');
    expect(db.paramsOf('save_venue_deposit_terms').single['p_details'], {'recipient': 'split', 'venue_pct': 60, 'purpose': 'admission'});
    expect(tester.widget<TextField>(find.byKey(const Key('deposit-venue-pct'))).controller!.text, '60');
    expect(now(tester), 'The deposit is split: the venue 60%, the organizer 40%, as admission.');
  });

  testWidgets('what is wrong is said before anything is sent', (tester) async {
    await open(tester);
    await tapKey(tester, 'deposit-terms-save');
    expect(find.text('Choose who receives the deposit: the venue, the approved organizer, or a split.'), findsOneWidget);
    expect(find.text('Choose what the deposit is for.'), findsOneWidget);
    await tapKey(tester, 'recipient-split');
    await tapKey(tester, 'purpose-admission');
    await tapKey(tester, 'deposit-terms-save');
    expect(find.text('For a split, give the venue\'s share between 1 and 99 percent. The organizer gets the rest.'), findsOneWidget);
    expect(db.paramsOf('save_venue_deposit_terms'), isEmpty);
  });

  testWidgets('the database refusing is shown, and what was chosen stays', (tester) async {
    await open(tester);
    await tapKey(tester, 'recipient-organizer');
    await tapKey(tester, 'purpose-admission');
    db.depositIsCredit = true;
    await tapKey(tester, 'deposit-terms-save');
    expect(find.textContaining('credited toward the bottle bill at this venue'), findsWidgets);
    expect(recipient(tester), DepositRecipient.organizer);
    expect(purpose(tester), DepositPurpose.admission);
    expect(db.depositTerms, isNull);
  });

  testWidgets('a connection failure keeps the choice and says what to do', (tester) async {
    await open(tester);
    await tapKey(tester, 'recipient-venue');
    await tapKey(tester, 'purpose-admission');
    db.beforeCall = (f) {
      if (f == 'save_venue_deposit_terms') throw Exception('socket closed');
    };
    await tapKey(tester, 'deposit-terms-save');
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.textContaining('socket'), findsNothing);
    expect(recipient(tester), DepositRecipient.venue);
    expect(purpose(tester), DepositPurpose.admission);
  });

  testWidgets('a second tap on Save while the first is going saves once', (tester) async {
    await open(tester);
    await tapKey(tester, 'recipient-venue');
    await tapKey(tester, 'purpose-admission');
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.ensureVisible(find.byKey(const Key('deposit-terms-save')));
    await tester.tap(find.byKey(const Key('deposit-terms-save')));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('deposit-terms-save'))).onPressed, isNull);
    gate.complete();
    db.hold = null;
    await tester.pumpAndSettle();
    expect(db.paramsOf('save_venue_deposit_terms'), hasLength(1));
  });

  testWidgets('a failed read says so with Try again; someone without access gets no retry', (tester) async {
    db.beforeCall = (f) => throw Exception('boom');
    await open(tester);
    expect(find.byKey(const Key('deposit-terms-error')), findsOneWidget);
    db.beforeCall = null;
    await tapKey(tester, 'deposit-terms-retry');
    expect(find.byKey(const Key('deposit-terms')), findsOneWidget);
    db.role = 'server';
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-terms-error')), findsOneWidget);
    expect(find.byKey(const Key('deposit-terms-retry')), findsNothing);
  });
}
