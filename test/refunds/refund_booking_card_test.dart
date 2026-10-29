import 'dart:async';

import 'package:bottles_up_vendor/features/refunds/providers/refund_providers.dart';
import 'package:bottles_up_vendor/features/refunds/widgets/refund_booking_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_refund_backend.dart';

late FakeRefundBackend db;
int changed = 0;

Widget host({bool canCancel = true}) => ProviderScope(
      key: UniqueKey(),
      overrides: [refundServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: SingleChildScrollView(child: RefundBookingCard(bookingId: 'b1', canCancel: canCancel, onChanged: () => changed++))),
      ),
    );

Future<void> open(WidgetTester tester, {bool canCancel = true}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(canCancel: canCancel));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void main() {
  setUp(() {
    db = FakeRefundBackend();
    db.addBooking('b1', hours: 30);
    changed = 0;
  });

  group('what the card says', () {
    testWidgets('what was paid, what can be refunded, what the booking\'s policy says now, and when the guests arrive', (tester) async {
      await open(tester);
      expect(find.text('Cancel and refund'), findsOneWidget);
      expect(find.text('Paid \$100.00 · can still be refunded \$100.00'), findsOneWidget);
      expect(find.text('The policy refunds 50% of the deposit for this much notice.'), findsOneWidget);
      expect(find.text('The guests arrive in 30 hours.'), findsOneWidget);
      expect(find.byKey(const Key('cancel-booking')), findsOneWidget);
      expect(find.byKey(const Key('ask-refund')), findsOneWidget);
    });

    testWidgets('a booking made without a policy says the amount is the venue\'s decision', (tester) async {
      db.bookings['b1'] = FakeRefundBooking('b1', policy: null);
      await open(tester);
      expect(find.text('This booking was made without a refund policy, so the amount is the venue\'s decision.'), findsOneWidget);
    });

    testWidgets('a booking with nothing paid offers no refund, and says so', (tester) async {
      db.addBooking('b1', paid: 0);
      await open(tester);
      expect(find.byKey(const Key('ask-refund')), findsNothing);
      expect(find.byKey(const Key('refund-card-nothing')), findsOneWidget);
      expect(find.byKey(const Key('cancel-booking')), findsOneWidget);
    });

    testWidgets('an open request is shown and a second cannot be asked for', (tester) async {
      db.addRequest('b1');
      await open(tester);
      expect(find.byKey(const Key('refund-card-open')), findsOneWidget);
      expect(find.byKey(const Key('ask-refund')), findsNothing);
    });

    testWidgets('a cancelled booking says so, can still be refunded, and cannot be cancelled again', (tester) async {
      db.addBooking('b1', status: 'cancelled');
      await open(tester);
      expect(find.byKey(const Key('refund-card-cancelled')), findsOneWidget);
      expect(find.byKey(const Key('cancel-booking')), findsNothing);
      expect(find.byKey(const Key('ask-refund')), findsOneWidget);
    });

    testWidgets('without the right to cancel (a closed-out table) there is no cancel button', (tester) async {
      await open(tester, canCancel: false);
      expect(find.byKey(const Key('cancel-booking')), findsNothing);
      expect(find.byKey(const Key('ask-refund')), findsOneWidget);
    });

    testWidgets('a failed read says so, and can be tried again', (tester) async {
      db.beforeCall = (f) => throw Exception('boom');
      await open(tester);
      expect(find.byKey(const Key('refund-card-error')), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      db.beforeCall = null;
      await tapKey(tester, 'refund-card-retry');
      expect(find.byKey(const Key('refund-card-money')), findsOneWidget);
    });
  });

  group('asking for a refund', () {
    testWidgets('records the request with the reason; the policy\'s suggestion is shown; nothing is paid back', (tester) async {
      await open(tester);
      await tapKey(tester, 'ask-refund');
      expect(find.byKey(const Key('ask-sheet')), findsOneWidget);
      expect(find.text('Suggested by the policy: \$50.00'), findsOneWidget);
      await enter(tester, 'ask-reason', ' Guest is ill ');
      await tapKey(tester, 'ask-confirm');
      expect(db.paramsOf('desk_request_refund').single, {'p_booking': 'b1', 'p_reason': 'Guest is ill'});
      expect(find.text('Refund request recorded. Decide it under More > Refunds.'), findsOneWidget);
      expect(db.requests.single.status, 'requested');
      expect(db.bookings['b1']!.paid, 10000, reason: 'asking moves no money');
      expect(find.byKey(const Key('refund-card-open')), findsOneWidget);
      expect(find.byKey(const Key('ask-refund')), findsNothing);
    });

    testWidgets('a reason that is too short is said before anything is sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'ask-refund');
      await enter(tester, 'ask-reason', 'x');
      await tapKey(tester, 'ask-confirm');
      expect(find.text('Give a reason of 3 to 500 characters.'), findsOneWidget);
      expect(db.paramsOf('desk_request_refund'), isEmpty);
    });

    testWidgets('the database refusing is shown and the reason stays', (tester) async {
      await open(tester);
      await tapKey(tester, 'ask-refund');
      await enter(tester, 'ask-reason', 'Guest is ill');
      db.addRequest('b1');
      await tapKey(tester, 'ask-confirm');
      expect(find.text('A refund request for this booking is already open.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('ask-reason'))).controller!.text, 'Guest is ill');
      expect(db.requests, hasLength(1));
    });

    testWidgets('a second tap while the first is going asks once', (tester) async {
      await open(tester);
      await tapKey(tester, 'ask-refund');
      await enter(tester, 'ask-reason', 'Guest is ill');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.ensureVisible(find.byKey(const Key('ask-confirm')));
      await tester.tap(find.byKey(const Key('ask-confirm')));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('ask-confirm'))).onPressed, isNull);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.requests, hasLength(1));
    });

    testWidgets('closing the sheet records nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'ask-refund');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ask-sheet')), findsNothing);
      expect(db.requests, isEmpty);
    });
  });

  group('cancelling the booking', () {
    testWidgets('asks why, cancels through the website\'s function, tells the page, and when money was paid goes straight to the refund request', (tester) async {
      await open(tester);
      await tapKey(tester, 'cancel-booking');
      expect(find.text('Cancel this booking?'), findsOneWidget);
      await enter(tester, 'cancel-reason', ' Guest cannot come ');
      await tapKey(tester, 'cancel-confirm');
      expect(db.invocations.single.$1, 'cancel-table-booking');
      expect(db.invocations.single.$2, {'booking_id': 'b1', 'reason': 'Guest cannot come'});
      expect(db.bookings['b1']!.status, 'cancelled');
      expect(changed, 1);
      expect(find.byKey(const Key('ask-sheet')), findsOneWidget, reason: 'money was paid, so the refund is the next step');
      expect(find.text('Suggested by the policy: \$50.00'), findsOneWidget);
    });

    testWidgets('a booking with nothing paid is just cancelled', (tester) async {
      db.addBooking('b1', paid: 0);
      await open(tester);
      await tapKey(tester, 'cancel-booking');
      await enter(tester, 'cancel-reason', 'Guest cannot come');
      await tapKey(tester, 'cancel-confirm');
      expect(db.bookings['b1']!.status, 'cancelled');
      expect(find.byKey(const Key('ask-sheet')), findsNothing);
      expect(find.text('The booking is cancelled.'), findsOneWidget);
      expect(changed, 1);
    });

    testWidgets('Keep the booking changes nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'cancel-booking');
      await tapKey(tester, 'cancel-keep');
      expect(db.invocations, isEmpty);
      expect(changed, 0);
      expect(find.byKey(const Key('cancel-reason')), findsNothing);
    });

    testWidgets('a reason is needed before anything is sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'cancel-booking');
      await tapKey(tester, 'cancel-confirm');
      expect(find.text('Give a reason of 3 to 500 characters.'), findsOneWidget);
      expect(db.invocations, isEmpty);
    });

    testWidgets('a refusal is shown in the dialog and the reason stays', (tester) async {
      await open(tester);
      await tapKey(tester, 'cancel-booking');
      await enter(tester, 'cancel-reason', 'Guest cannot come');
      db.role = 'server';
      await tapKey(tester, 'cancel-confirm');
      expect(find.text('You don\'t have access to cancel this booking.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('cancel-reason'))).controller!.text, 'Guest cannot come');
      expect(changed, 0);
    });

    testWidgets('a call that got no answer says to look at the booking before trying again', (tester) async {
      await open(tester);
      await tapKey(tester, 'cancel-booking');
      await enter(tester, 'cancel-reason', 'Guest cannot come');
      db.failInvoke = Exception('socket closed');
      await tapKey(tester, 'cancel-confirm');
      expect(find.textContaining('Look at the booking before trying again'), findsOneWidget);
      expect(find.textContaining('socket'), findsNothing);
      expect(changed, 0);
    });

    testWidgets('a second tap while the first is going cancels once', (tester) async {
      await open(tester);
      await tapKey(tester, 'cancel-booking');
      await enter(tester, 'cancel-reason', 'Guest cannot come');
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.tap(find.byKey(const Key('cancel-confirm')));
      await tester.pump();
      expect(find.text('Cancelling...'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('cancel-confirm'))).onPressed, isNull);
      gate.complete();
      db.hold = null;
      await tester.pumpAndSettle();
      expect(db.invocations, hasLength(1));
    });

    testWidgets('already cancelled by someone else: the function\'s own words', (tester) async {
      await open(tester);
      await tapKey(tester, 'cancel-booking');
      await enter(tester, 'cancel-reason', 'Guest cannot come');
      db.bookings['b1']!.status = 'cancelled';
      await tapKey(tester, 'cancel-confirm');
      expect(find.text('This booking is already cancelled.'), findsOneWidget);
    });
  });
}
