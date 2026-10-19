import 'package:bottles_up_vendor/features/booking_detail/providers/booking_detail_providers.dart';
import 'package:bottles_up_vendor/features/booking_detail/services/booking_detail_service.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../table_service/fake_table_backend.dart';

late FakeTableBackend tables;
final List<(String, Map<String, dynamic>?)> calls = [];
Object? guestsFailure;
Object? activityFailure;
Map<String, dynamic> guestsAnswer = {};
List<Map<String, dynamic>> activityAnswer = [];

Map<String, dynamic> theGuests({List<Map<String, dynamic>>? guests, int left = 2}) => {
      'holder_name': 'Ada Lovelace',
      'holder_checked_in_at': '2026-10-09T21:30:00Z',
      'party_size': 4,
      'max_guests': 6,
      'table_name': 'VIP booth',
      'guests': guests ??
          [
            {'id': 'g1', 'name': 'Gia Guest', 'ticket_sent': false, 'checked_in_at': null},
            {'id': 'g2', 'name': 'Gus Guest', 'ticket_sent': true, 'checked_in_at': '2026-10-09T22:15:00Z'},
          ],
      'guests_issued': 2,
      'guests_in': 1,
      'guests_left': left,
    };

Map<String, dynamic> act(String at, String action, String actor, {String kind = 'audit', Map<String, dynamic> details = const {}}) =>
    {'at': at, 'kind': kind, 'action': action, 'actor': actor, 'details': details};

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        tableServiceServiceProvider.overrideWithValue(tables.service),
        bookingDetailServiceProvider.overrideWithValue(BookingDetailService(caller: (fn, {params}) async {
          calls.add((fn, params));
          if (fn == 'desk_booking_guests') {
            if (guestsFailure != null) throw guestsFailure!;
            return guestsAnswer;
          }
          if (fn == 'desk_booking_activity') {
            if (activityFailure != null) throw activityFailure!;
            return activityAnswer;
          }
          throw StateError('unexpected $fn');
        })),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: TableDetailScreen(bookingId: 'b1', title: 'VIP booth · Ada Lovelace', clock: () => DateTime(2026, 10, 9, 21))),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> tab(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(Tab, name));
  await tester.pumpAndSettle();
}

List<String> tabNames(WidgetTester tester) => [for (final t in tester.widgetList<Tab>(find.byType(Tab))) t.text!];

void main() {
  setUp(() {
    tables = FakeTableBackend()..role = 'manager';
    tables.now = DateTime(2026, 10, 9, 21);
    tables.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD', total: 10000, paid: 6000, guests: 4);
    tables.assignments['b1'] = 'm-me';
    calls.clear();
    guestsFailure = null;
    activityFailure = null;
    guestsAnswer = theGuests();
    activityAnswer = [];
  });

  group('which tabs a person gets (brief section 14: Overview | Orders | Payments | Guests | Activity)', () {
    testWidgets('a manager or owner gets all five, in that order', (tester) async {
      await open(tester);
      expect(tabNames(tester), ['Overview', 'Orders', 'Payments', 'Guests', 'Activity']);
    });

    testWidgets('the server of the table gets all but Activity', (tester) async {
      tables.role = 'server';
      await open(tester);
      expect(tabNames(tester), ['Overview', 'Orders', 'Payments', 'Guests']);
    });

    testWidgets('a payment verifier gets only the money: Overview and Payments', (tester) async {
      tables.role = 'verifier';
      await open(tester);
      expect(tabNames(tester), ['Overview', 'Payments']);
      expect(calls, isEmpty, reason: 'nothing about guests or activity is even asked for');
    });

    testWidgets('it opens on Overview with the money, and nothing about guests is read until its tab is opened', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('money-card')), findsOneWidget);
      expect(calls, isEmpty);
    });

    testWidgets('the booking\'s name, table and code stay above every tab', (tester) async {
      await open(tester);
      await tab(tester, 'Guests');
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('VIP booth · 4 guests'), findsOneWidget);
      expect(find.text('AB12CD'), findsOneWidget);
    });
  });

  group('Guests', () {
    testWidgets('shows the party, the limit and how many more can be invited, and who is in', (tester) async {
      await open(tester);
      await tab(tester, 'Guests');
      expect(calls.single.$1, 'desk_booking_guests');
      expect(calls.single.$2, {'p_booking': 'b1'});
      expect(find.text('Party of 4 · table limit 6 · 2 more guests can be invited'), findsOneWidget);
      expect(find.byKey(const Key('guests-admission-note')), findsOneWidget);
      expect(find.byKey(const Key('holder-in')), findsOneWidget);
      expect(find.text('1 of 2 guests in'), findsOneWidget);
      expect(find.byKey(const Key('guest-g1')), findsOneWidget);
      expect(find.byKey(const Key('guest-not-in-g1')), findsOneWidget);
      expect(find.byKey(const Key('guest-in-g2')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('guest-g1')), matching: find.text('Ticket not e-mailed yet')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('guest-g2')), matching: find.text('Ticket e-mailed')), findsOneWidget);
    });

    testWidgets('no contact details are on the page', (tester) async {
      await open(tester);
      await tab(tester, 'Guests');
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('contact details are not shown'), findsOneWidget);
    });

    testWidgets('a holder who is not in yet says so', (tester) async {
      guestsAnswer = {...theGuests(), 'holder_checked_in_at': null};
      await open(tester);
      await tab(tester, 'Guests');
      expect(find.byKey(const Key('holder-not-in')), findsOneWidget);
      expect(find.byKey(const Key('holder-in')), findsNothing);
    });

    testWidgets('with nobody invited it says so and the whole limit is open', (tester) async {
      guestsAnswer = theGuests(guests: [], left: 5);
      await open(tester);
      await tab(tester, 'Guests');
      expect(find.text('No guests invited yet.'), findsOneWidget);
      expect(find.text('Party of 4 · table limit 6 · 5 more guests can be invited'), findsOneWidget);
    });

    testWidgets('a full table says no more guests can be invited', (tester) async {
      guestsAnswer = theGuests(left: 0);
      await open(tester);
      await tab(tester, 'Guests');
      expect(find.text('Party of 4 · table limit 6 · no more guests can be invited'), findsOneWidget);
    });

    testWidgets('a failed read is plain, has Try again, and is not shown as "no guests"', (tester) async {
      guestsFailure = StateError('relation "guest_tickets" does not exist');
      await open(tester);
      await tab(tester, 'Guests');
      expect(find.byKey(const Key('guests-error')), findsOneWidget);
      expect(find.textContaining('relation'), findsNothing);
      expect(find.text('No guests invited yet.'), findsNothing);
      guestsFailure = null;
      await tester.tap(find.byKey(const Key('guests-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guest-g1')), findsOneWidget);
    });

    testWidgets('a database without the migration says so, with nothing to retry', (tester) async {
      guestsFailure = PostgrestException(message: 'Could not find the function public.desk_booking_guests', code: 'PGRST202');
      await open(tester);
      await tab(tester, 'Guests');
      expect(find.textContaining('not set up on this server yet'), findsOneWidget);
      expect(find.byKey(const Key('guests-retry')), findsNothing);
    });
  });

  group('Payments', () {
    testWidgets('the Payments tab offers Record a payment to the people who may record one, and it opens the form', (tester) async {
      await open(tester);
      await tab(tester, 'Payments');
      expect(find.byKey(const Key('record-payment-payments')), findsOneWidget);
      await tester.tap(find.byKey(const Key('record-payment-payments')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pay-submit')), findsOneWidget, reason: 'the payment form opened');
    });

    testWidgets('a payment verifier is offered no button there', (tester) async {
      tables.role = 'verifier';
      await open(tester);
      await tab(tester, 'Payments');
      expect(find.byKey(const Key('record-payment-payments')), findsNothing);
    });
  });

  group('Activity', () {
    testWidgets('lists what happened in sentences, newest first as the database sent it, with who and when', (tester) async {
      activityAnswer = [
        act('2026-10-09T23:10:00Z', 'scan.ok', 'Door Dan', kind: 'scan', details: {'guest': true}),
        act('2026-10-09T22:40:00Z', 'booking.estimate_set', 'Sam Server', details: {'from_minutes': 10, 'to_minutes': 25}),
        act('2026-10-09T21:05:00Z', 'table_booking.club_payment_recorded', 'Sam Server', details: {'amount_paid_cents': 6000, 'payment_method': 'cash'}),
      ];
      await open(tester);
      await tab(tester, 'Activity');
      expect(calls.single.$1, 'desk_booking_activity');
      expect(calls.single.$2, {'p_booking': 'b1', 'p_limit': 100});
      expect(find.text('A guest was scanned in at the door'), findsOneWidget);
      expect(find.text('The service estimate was set to 25 minutes'), findsOneWidget);
      expect(find.text('\$60.00 recorded as cash'), findsOneWidget);
      expect(find.textContaining('Door Dan ·'), findsOneWidget);
      expect(find.textContaining('Sam Server ·'), findsNWidgets(2));
      final tops = [for (var i = 0; i < 3; i++) tester.getTopLeft(find.byKey(Key('activity-$i'))).dy];
      expect(tops, [...tops]..sort());
      expect(find.textContaining('Nothing is removed from this history'), findsOneWidget);
    });

    testWidgets('an action this version does not know is still listed', (tester) async {
      activityAnswer = [act('2026-10-09T23:10:00Z', 'table_booking.refund_issued', 'Mia Manager')];
      await open(tester);
      await tab(tester, 'Activity');
      expect(find.text('Table booking refund issued'), findsOneWidget);
    });

    testWidgets('an empty history says so', (tester) async {
      await open(tester);
      await tab(tester, 'Activity');
      expect(find.byKey(const Key('activity-empty')), findsOneWidget);
    });

    testWidgets('a failed read is plain, has Try again, and is not shown as an empty history', (tester) async {
      activityFailure = StateError('permission denied for table audit_log');
      await open(tester);
      await tab(tester, 'Activity');
      expect(find.byKey(const Key('activity-error')), findsOneWidget);
      expect(find.textContaining('audit_log'), findsNothing);
      expect(find.byKey(const Key('activity-empty')), findsNothing);
      activityFailure = null;
      activityAnswer = [act('2026-10-09T23:10:00Z', 'booking.seated', 'Sam Server')];
      await tester.tap(find.byKey(const Key('activity-retry')));
      await tester.pumpAndSettle();
      expect(find.text('The guest was seated'), findsOneWidget);
    });

    testWidgets('a database without the migration says so, with nothing to retry', (tester) async {
      activityFailure = PostgrestException(message: 'Could not find the function public.desk_booking_activity', code: 'PGRST202');
      await open(tester);
      await tab(tester, 'Activity');
      expect(find.textContaining('not set up on this server yet'), findsOneWidget);
      expect(find.byKey(const Key('activity-retry')), findsNothing);
    });

    testWidgets('no e-mail address is on the page', (tester) async {
      activityAnswer = [act('2026-10-09T23:10:00Z', 'booking.seated', 'Staff member')];
      await open(tester);
      await tab(tester, 'Activity');
      expect(find.textContaining('@'), findsNothing);
    });
  });
}
