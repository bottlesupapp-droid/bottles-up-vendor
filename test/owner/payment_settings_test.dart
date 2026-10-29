import 'package:bottles_up_vendor/features/owner/logic/payment_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/payment_settings_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_setup_backend.dart';

late FakeSetupBackend setup;
var editTables = 0;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [venueSetupServiceProvider.overrideWithValue(setup.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: PaymentSettingsEditor(venueId: 'v1', orgId: 'o1', onEditTables: () => editTables++),
      ),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
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

BottlePaymentMode? _group(WidgetTester tester) => tester.widget<RadioGroup<BottlePaymentMode>>(find.byType(RadioGroup<BottlePaymentMode>)).groupValue;

void main() {
  setUp(() {
    setup = FakeSetupBackend();
    editTables = 0;
    setup.tables.addAll([
      {'type_id': 't1', 'name': 'Booth', 'max_guests': 6, 'min_spend_cents': 50000, 'deposit_cents': 10000, 'inventory_count': 3, 'is_featured': false, 'pricing_mode': 'flat', 'booking_count': 0},
      {'type_id': 't2', 'name': 'Sofa', 'max_guests': 4, 'min_spend_cents': 0, 'deposit_cents': 0, 'inventory_count': 2, 'is_featured': false, 'pricing_mode': 'flat', 'booking_count': 0},
    ]);
  });

  testWidgets('shows the current way bottles are paid, the three options, and nothing to save yet', (tester) async {
    await open(tester);
    expect(find.text('Pay ahead'), findsOneWidget);
    expect(find.text('Pay at the venue'), findsOneWidget);
    expect(find.text('Customer chooses'), findsOneWidget);
    expect(_group(tester), BottlePaymentMode.payAhead);
    expect(tester.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed, isNull);
  });

  testWidgets('a new choice is saved, says what it applies to, and the screen shows it as the saved one', (tester) async {
    await open(tester);
    await tapKey(tester, 'mode-both');
    expect(tester.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed, isNotNull);
    await tapKey(tester, 'payment-save');
    expect(setup.calls.where((c) => c.$1 == 'save_venue_payment_rules').single.$2, {'p_venue': 'v1', 'p_details': {'bottle_payment_mode': 'both'}});
    expect(setup.bottleMode, 'both');
    expect(find.textContaining('Saved: Customer chooses'), findsOneWidget);
    expect(find.textContaining('existing bookings keep how they were made'), findsWidgets);
    expect(_group(tester), BottlePaymentMode.customerChooses);
    expect(tester.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed, isNull, reason: 'nothing left to save');
  });

  testWidgets('if saving fails the choice is kept and the reason is in plain words', (tester) async {
    await open(tester);
    await tapKey(tester, 'mode-pay_at_club');
    setup.beforeCall = (fn) {
      if (fn == 'save_venue_payment_rules') throw const SocketLikeFailure();
    };
    await tapKey(tester, 'payment-save');
    expect(find.byKey(const Key('payment-problem')), findsOneWidget);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
    expect(_group(tester), BottlePaymentMode.payAtVenue, reason: 'what was picked is kept');
    expect(tester.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed, isNotNull, reason: 'and can be tried again');
    setup.beforeCall = null;
    await tapKey(tester, 'payment-save');
    expect(setup.bottleMode, 'pay_at_club');
    expect(find.byKey(const Key('payment-problem')), findsNothing);
  });

  testWidgets('a refusal from the database is shown in its own words', (tester) async {
    await open(tester);
    await tapKey(tester, 'mode-both');
    setup.beforeCall = (fn) {
      if (fn == 'save_venue_payment_rules') throw PostgrestException(message: 'not allowed', code: 'P0001');
    };
    await tapKey(tester, 'payment-save');
    expect(find.byKey(const Key('payment-problem')), findsOneWidget);
  });

  testWidgets('an answer with no row is a failure to load, never a screen with made-up settings', (tester) async {
    setup.noPaymentRow = true;
    await open(tester);
    expect(find.byKey(const Key('editor-error')), findsOneWidget);
    expect(find.byKey(const Key('payment-settings')), findsNothing);
  });

  testWidgets('while a save is going the choice cannot be changed under it', (tester) async {
    await open(tester);
    await tapKey(tester, 'mode-both');
    setup.hold = Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('payment-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mode-pay_at_club')), warnIfMissed: false);
    await tester.pump();
    expect(_group(tester), BottlePaymentMode.customerChooses);
    await tester.pumpAndSettle();
    expect(setup.bottleMode, 'both');
  });

  testWidgets('a second tap while saving does not save twice', (tester) async {
    await open(tester);
    await tapKey(tester, 'mode-both');
    final gate = Future<void>.delayed(const Duration(milliseconds: 200));
    setup.hold = gate;
    await tester.tap(find.byKey(const Key('payment-save')));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('payment-save'))).onPressed, isNull);
    await tester.pumpAndSettle();
    expect(setup.calls.where((c) => c.$1 == 'save_venue_payment_rules').length, 1);
  });

  testWidgets('each table\'s deposit is listed, and the tables editor is one tap away', (tester) async {
    await open(tester);
    expect(find.text('Booth: \$100.00 deposit, paid online'), findsOneWidget);
    expect(find.text('Sofa: no deposit'), findsOneWidget);
    await tapKey(tester, 'deposit-edit-tables');
    expect(editTables, 1);
  });

  testWidgets('whether the deposit counts toward bottles is shown, explained, and cannot be changed here', (tester) async {
    setup.depositIsCredit = true;
    await open(tester);
    expect(find.textContaining('credited toward the bottle bill'), findsOneWidget);
    expect(find.byKey(const Key('deposit-credit-note')), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('payouts say BottlesUp makes them and where to see them', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('payout-note')), findsOneWidget);
    expect(find.textContaining('set up and made by BottlesUp'), findsOneWidget);
    expect(find.textContaining('Settlements and payouts'), findsOneWidget);
  });

  testWidgets('a setting the app does not know is said, and nothing is pre-selected', (tester) async {
    setup.bottleMode = 'on_credit';
    await open(tester);
    expect(find.byKey(const Key('mode-unknown')), findsOneWidget);
    expect(_group(tester), isNull);
  });

  testWidgets('if the settings cannot be read the person is told, with Try again', (tester) async {
    setup.failAll = StateError('relation "site_venues" does not exist');
    await open(tester);
    expect(find.byKey(const Key('editor-error')), findsOneWidget);
    expect(find.textContaining('relation'), findsNothing);
    expect(find.byKey(const Key('editor-retry')), findsOneWidget);
    setup.failAll = null;
    await tapKey(tester, 'editor-retry');
    expect(find.text('Pay ahead'), findsOneWidget);
  });

  testWidgets('if the tables cannot be listed the settings still work and say so', (tester) async {
    setup.beforeCall = (fn) {
      if (fn == 'list_venue_table_types') throw StateError('x');
    };
    await open(tester);
    expect(find.byKey(const Key('deposit-load-failed')), findsOneWidget);
    expect(find.text('Pay ahead'), findsOneWidget);
  });

  testWidgets('with no tables yet it says where to add them', (tester) async {
    setup.tables.clear();
    await open(tester);
    expect(find.byKey(const Key('deposit-none')), findsOneWidget);
  });
}

class SocketLikeFailure implements Exception {
  const SocketLikeFailure();
  @override
  String toString() => 'SocketException: Failed host lookup';
}
