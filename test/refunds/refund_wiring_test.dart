import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/payment_settings_editor.dart';
import 'package:bottles_up_vendor/features/refunds/providers/refund_providers.dart';
import 'package:bottles_up_vendor/features/table_map/providers/table_map_providers.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:bottles_up_vendor/features/walkin/providers/walkin_providers.dart';
import 'package:bottles_up_vendor/features/walkin/screens/walkin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../owner/fake_setup_backend.dart';
import '../table_map/fake_table_map_backend.dart';
import '../table_service/fake_table_backend.dart';
import '../walkin/fake_walkin_backend.dart';
import 'fake_refund_backend.dart';

late FakeRefundBackend refunds;
late FakeSetupBackend setup;
late FakeTableMapBackend map;
late FakeTableBackend desk;
late FakeWalkinBackend walkin;

Widget host(Widget home) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        refundServiceProvider.overrideWithValue(refunds.service),
        venueSetupServiceProvider.overrideWithValue(setup.service),
        tableMapServiceProvider.overrideWithValue(map.service),
        tableServiceServiceProvider.overrideWithValue(desk.service),
        walkinServiceProvider.overrideWithValue(walkin.service),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: home),
    );

Future<void> open(WidgetTester tester, Widget w, {double height = 3600}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(w));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    refunds = FakeRefundBackend();
    setup = FakeSetupBackend();
    map = FakeTableMapBackend();
    desk = FakeTableBackend()..role = 'manager';
    desk.now = DateTime(2026, 10, 9, 21);
    walkin = FakeWalkinBackend();
  });

  group('payment settings', () {
    testWidgets('say where the refund policy stands and open the editor', (tester) async {
      refunds.stored = {
        'tiers': [
          {'hours': 48, 'percent': 100},
        ],
        'no_refund_after_check_in': true,
        'note': null,
      };
      await open(tester, const PaymentSettingsEditor(venueId: 'v1', orgId: 'o1'));
      expect(find.text('Refund policy: Cancel at least 2 days before you arrive: the whole deposit is refunded.'), findsOneWidget);
      await tapKey(tester, 'refund-policy-open');
      expect(find.byKey(const Key('refund-policy')), findsOneWidget);
    });

    testWidgets('a venue with none yet says refunds are decided case by case, and after saving one the line is updated', (tester) async {
      await open(tester, const PaymentSettingsEditor(venueId: 'v1', orgId: 'o1'));
      expect(find.text('Refund policy: not set yet (refunds are decided case by case).'), findsOneWidget);
      await tapKey(tester, 'refund-policy-open');
      await tapKey(tester, 'policy-save');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Refund policy: Cancel at least 2 days before you arrive: the whole deposit is refunded.'), findsOneWidget);
    });

    testWidgets('when the policy cannot be read the rest of the settings still show', (tester) async {
      refunds.beforeCall = (f) => throw Exception('boom');
      await open(tester, const PaymentSettingsEditor(venueId: 'v1', orgId: 'o1'));
      expect(find.byKey(const Key('refund-policy-load-failed')), findsOneWidget);
      expect(find.byKey(const Key('payment-settings')), findsOneWidget);
    });
  });

  group('a booking\'s page', () {
    Widget detail() => const TableDetailScreen(bookingId: 'b1', title: 'VIP booth · Ada Lovelace');

    void seed({String status = 'paid', bool reconciled = false}) {
      desk.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD', status: status, total: 10000, paid: 6000, guests: 4);
      desk.bookings['b1']!.reconciled = reconciled;
      map.bookings.add({'id': 'b1', 'table': 't2', 'slot': 's1', 'guests': 3, 'status': 'paid', 'seated': false, 'name': 'Ada Lovelace'});
      refunds.addBooking('b1', hours: 30);
    }

    testWidgets('a manager can cancel the booking and ask for a refund from its page', (tester) async {
      seed();
      await open(tester, detail());
      expect(find.byKey(const Key('refund-card')), findsOneWidget);
      expect(find.byKey(const Key('cancel-booking')), findsOneWidget);
      expect(find.byKey(const Key('ask-refund')), findsOneWidget);
    });

    testWidgets('cancelling re-reads the booking, so the page shows it cancelled', (tester) async {
      seed();
      await open(tester, detail());
      final reads = desk.calls.where((c) => c.$1 == 'desk_booking_money').length;
      await tapKey(tester, 'cancel-booking');
      await tester.enterText(find.byKey(const Key('cancel-reason')), 'Guest cannot come');
      await tester.pump();
      await tapKey(tester, 'cancel-confirm');
      expect(refunds.bookings['b1']!.status, 'cancelled');
      expect(desk.calls.where((c) => c.$1 == 'desk_booking_money').length, greaterThan(reads));
    });

    testWidgets('the server of the table does not see the refund card', (tester) async {
      seed();
      desk.role = 'server';
      desk.assignments['b1'] = desk.myMembership;
      map.role = 'server';
      await open(tester, detail());
      expect(find.byKey(const Key('terms-card')), findsOneWidget);
      expect(find.byKey(const Key('refund-card')), findsNothing);
    });

    testWidgets('a table that has been closed out can be refunded but not cancelled', (tester) async {
      seed(reconciled: true);
      await open(tester, detail());
      expect(find.byKey(const Key('cancel-booking')), findsNothing);
      expect(find.byKey(const Key('ask-refund')), findsOneWidget);
    });

    testWidgets('if the refund details cannot be read the money and the payments still show', (tester) async {
      seed();
      refunds.beforeCall = (f) => throw Exception('boom');
      await open(tester, detail());
      expect(find.byKey(const Key('refund-card-error')), findsOneWidget);
      expect(find.byKey(const Key('money-card')), findsOneWidget);
    });
  });

  group('the walk-in terms', () {
    Future<void> pickTable(WidgetTester tester) async {
      await open(tester, const WalkinScreen(venueId: 'v1', venueName: 'Club A', night: '2026-10-19'), height: 3200);
      await tapKey(tester, 'walkin-slot-s1');
      await tapKey(tester, 'walkin-table-t1');
    }

    testWidgets('read out the club\'s refund policy with the other terms, so the guest hears it before booking', (tester) async {
      refunds.stored = {
        'tiers': [
          {'hours': 48, 'percent': 100},
          {'hours': 24, 'percent': 50},
        ],
        'no_refund_after_check_in': true,
        'note': null,
      };
      await pickTable(tester);
      expect(find.byKey(const Key('walkin-refund-title')), findsOneWidget);
      expect(find.text('• Cancel at least 2 days before you arrive: the whole deposit is refunded.'), findsOneWidget);
      expect(find.text('• Once the guests have arrived there is no refund.'), findsOneWidget);
      expect(find.byKey(const Key('walkin-terms')), findsOneWidget);
    });

    testWidgets('a club with no policy says refunds are decided by the venue', (tester) async {
      await pickTable(tester);
      expect(find.text('• This venue has not set a refund policy: refunds are decided by the venue.'), findsOneWidget);
    });

    testWidgets('when the policy cannot be read the terms are the same as before', (tester) async {
      refunds.beforeCall = (f) => throw Exception('boom');
      await pickTable(tester);
      expect(find.byKey(const Key('walkin-refund-title')), findsNothing);
      expect(find.byKey(const Key('walkin-terms')), findsOneWidget);
    });
  });
}
