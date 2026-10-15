import 'dart:typed_data';

import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/record_payment_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:bottles_up_vendor/features/table_service/services/receipt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_backend.dart';

late FakeTableBackend db;

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host({String? signedUrl, bool signFails = false}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    tableServiceServiceProvider.overrideWithValue(db.service),
    receiptServiceProvider.overrideWithValue(
      ReceiptService(
        signer: (path) async {
          if (signFails) throw Exception('expired');
          return signedUrl ?? 'https://signed.example/$path';
        },
        uploader: (p, b, t) async {},
      ),
    ),
    receiptPhotoPickerProvider.overrideWithValue(
      (context, {required camera}) async =>
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]),
    ),
  ],
  child: MaterialApp(
    theme: ThemeData.dark(),
    home: TableDetailScreen(
      bookingId: 'b1',
      title: 'VIP booth · Ada Lovelace',
      clock: friday9pm,
    ),
  ),
);

Future<void> open(WidgetTester tester, Widget w, {double height = 3000}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    db = FakeTableBackend()..role = 'manager';
    db.now = DateTime(2026, 10, 9, 21);
    db.addBooking(
      'b1',
      name: 'Ada Lovelace',
      code: 'AB12CD',
      total: 10000,
      paid: 6000,
      guests: 4,
    );
    db.assignments['b1'] = 'm-me';
    db.addLine('b1', 'Patron', lineId: 'l1', minutesAgo: 40);
    db.addLine(
      'b1',
      'Grey Goose',
      lineId: 'l2',
      pay: 'due_at_venue',
      state: 'preparing',
      minutesAgo: 25,
      qty: 2,
    );
    db.addLine(
      'b1',
      'Hennessy',
      lineId: 'l3',
      cancelled: true,
      reason: 'guest changed their mind',
      minutesAgo: 30,
    );
    db.addLine(
      'b1',
      'Dom Perignon',
      lineId: 'l4',
      pay: 'pending_payment',
      minutesAgo: 5,
    );
  });

  testWidgets(
    'shows who the table is, what it was charged, what was collected and what is still due',
    (tester) async {
      await open(tester, host());
      expect(
        find.text('VIP booth · Ada Lovelace'),
        findsOneWidget,
      ); // the page title
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('VIP booth · 4 guests'), findsOneWidget);
      expect(find.text('AB12CD'), findsOneWidget);
      expect(find.text('\$100.00'), findsWidgets);
      expect(find.byKey(const Key('money-total')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('money-total'))).data,
        '\$100.00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('money-paid'))).data,
        '\$60.00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('money-due'))).data,
        '\$40.00',
      );
      expect(db.functions.first, 'desk_booking_money');
    },
  );

  testWidgets(
    'lists the table\'s bottle orders, a cancelled one with its reason, and none that are still being paid online',
    (tester) async {
      await open(tester, host());
      expect(find.text('Bottle orders'), findsOneWidget);
      expect(find.byKey(const Key('order-l1')), findsOneWidget);
      expect(find.byKey(const Key('order-l2')), findsOneWidget);
      expect(find.byKey(const Key('order-l3')), findsOneWidget);
      expect(find.byKey(const Key('order-l4')), findsNothing);
      expect(find.text('Cancelled: guest changed their mind'), findsOneWidget);
      expect(
        find.byKey(const Key('move-l3')),
        findsNothing,
        reason: 'a cancelled line cannot be moved',
      );
      expect(
        find.byKey(const Key('table-link-l1')),
        findsNothing,
        reason: 'the page already is the table',
      );
      final params = db.params.firstWhere(
        (p) =>
            p != null &&
            p.length == 1 &&
            p.containsKey('p_booking') &&
            db.calls[db.params.indexOf(p)].$1 == 'desk_booking_orders',
      );
      expect(params, {'p_booking': 'b1'});
    },
  );

  testWidgets(
    'moving an order here works and shows the table\'s balance rule',
    (tester) async {
      await open(tester, host());
      expect(
        find.byKey(const Key('blocked-l2')),
        findsOneWidget,
        reason: 'the table owes \$40 and this item is paid at the venue',
      );
      await tester.tap(find.byKey(const Key('move-l1')));
      await tester.pumpAndSettle();
      expect(db.line('l1').state, 'preparing');
    },
  );

  testWidgets('a table with no bottle orders says so', (tester) async {
    db.lines.clear();
    await open(tester, host());
    expect(find.byKey(const Key('detail-orders-empty')), findsOneWidget);
  });

  testWidgets(
    'a move here is shown at once: the card goes on to the next step',
    (tester) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('move-l1')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('move-l1')),
          matching: find.text('Mark ready'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a colleague got there first: the person is told it was already so',
    (tester) async {
      db.beforeCall = (f) {
        if (f == 'desk_set_service_status') db.line('l1').state = 'preparing';
      };
      await open(tester, host());
      await tester.tap(find.byKey(const Key('move-l1')));
      await tester.pumpAndSettle();
      expect(find.text('It was already preparing.'), findsOneWidget);
    },
  );

  testWidgets('a manager is not told "no server" on a table\'s own page', (
    tester,
  ) async {
    db.assignments.clear();
    await open(tester, host());
    expect(find.byKey(const Key('no-server-l1')), findsNothing);
  });

  testWidgets(
    'a table that is closed out shows only that, not "closing asked for" as well',
    (tester) async {
      db.bookings['b1']!.reconciled = true;
      db.bookings['b1']!.closeoutRequested = true;
      await open(tester, host());
      expect(find.byKey(const Key('closed-out')), findsOneWidget);
      expect(find.byKey(const Key('closeout-requested')), findsNothing);
    },
  );

  testWidgets(
    'a payment whose bill differs from what was collected shows the bill, and a tip is shown; otherwise neither',
    (tester) async {
      db.addPayment('b1', 3000, paymentId: 'p1', billed: 3500, tip: 500);
      db.addPayment('b1', 1000, paymentId: 'p2');
      await open(tester, host());
      final p1 = find.byKey(const Key('payment-p1'));
      final p2 = find.byKey(const Key('payment-p2'));
      expect(
        find.descendant(of: p1, matching: find.text('Bill \$35.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: p1, matching: find.text('Tip \$5.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: p2, matching: find.textContaining('Bill')),
        findsNothing,
      );
      expect(
        find.descendant(of: p2, matching: find.textContaining('Tip')),
        findsNothing,
      );
    },
  );

  group('payments', () {
    testWidgets('a table with none says so', (tester) async {
      await open(tester, host());
      expect(find.byKey(const Key('detail-payments-empty')), findsOneWidget);
    });

    testWidgets(
      'each payment says how, how much, when, on what evidence and where it stands',
      (tester) async {
        db.addPayment(
          'b1',
          3000,
          paymentId: 'p1',
          path: 'b1/r.jpg',
          pos: 'POS-1',
          by: 'u-me',
          payer: 'Ada L',
          at: db.now.subtract(const Duration(minutes: 12)),
          method: 'debit',
        );
        db.addPayment(
          'b1',
          1000,
          paymentId: 'p2',
          reason: 'printer broke',
          by: 'u-other',
          at: db.now.subtract(const Duration(minutes: 5)),
        );
        await open(tester, host());
        expect(find.text('Debit · \$30.00'), findsOneWidget);
        expect(find.text('Cash · \$10.00'), findsOneWidget);
        expect(
          find.textContaining('Recorded 12 min ago by you · Ada L'),
          findsOneWidget,
        );
        expect(find.textContaining('Recorded 5 min ago'), findsOneWidget);
        expect(find.text('Receipt no. POS-1'), findsOneWidget);
        expect(find.byKey(const Key('receipt-p1')), findsOneWidget);
        expect(find.byKey(const Key('no-receipt-p2')), findsOneWidget);
        expect(find.text('No receipt: printer broke'), findsOneWidget);
        expect(find.text('Recorded - verification pending'), findsNWidgets(2));
      },
    );

    testWidgets(
      'a checked payment reads verified with the checker\'s note; a disputed one says so; a guest-confirmed one too',
      (tester) async {
        final p1 = db.addPayment('b1', 3000, paymentId: 'p1', verified: true);
        p1.note = 'matches the till';
        db.addPayment('b1', 1000, paymentId: 'p2', status: 'disputed');
        db.addPayment('b1', 500, paymentId: 'p3', status: 'confirmed');
        await open(tester, host());
        expect(find.text('Verified'), findsOneWidget);
        expect(find.text('Checked: matches the till'), findsOneWidget);
        expect(find.text('Disputed by the guest'), findsOneWidget);
        expect(find.text('Confirmed by the guest'), findsOneWidget);
        expect(find.text('Recorded - verification pending'), findsNothing);
      },
    );

    testWidgets('viewing a receipt opens it through a short-lived address', (
      tester,
    ) async {
      db.addPayment('b1', 3000, paymentId: 'p1', path: 'b1/r.jpg');
      await open(tester, host());
      await tester.tap(find.byKey(const Key('receipt-p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('receipt-image')), findsOneWidget);
      final image = tester.widget<Image>(
        find.byKey(const Key('receipt-image')),
      );
      expect(
        ((image.image) as NetworkImage).url,
        'https://signed.example/b1/r.jpg',
      );
      await tester.tap(find.byKey(const Key('receipt-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('receipt-image')), findsNothing);
    });

    testWidgets('a receipt that cannot be opened says so in a sentence', (
      tester,
    ) async {
      db.addPayment('b1', 3000, paymentId: 'p1', path: 'b1/r.jpg');
      await open(tester, host(signFails: true));
      await tester.tap(find.byKey(const Key('receipt-p1')));
      await tester.pumpAndSettle();
      expect(
        find.text('The receipt photo could not be opened.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('receipt-image')), findsNothing);
    });

    testWidgets('a guest\'s email address is never on the page', (
      tester,
    ) async {
      db.addPayment('b1', 3000, paymentId: 'p1', path: 'b1/r.jpg');
      await open(tester, host());
      expect(find.textContaining('@'), findsNothing);
    });
  });

  group('recording one', () {
    testWidgets(
      'a manager is offered the button; it opens the form with the balance filled in',
      (tester) async {
        await open(tester, host());
        expect(find.byKey(const Key('record-payment')), findsOneWidget);
        await tester.tap(find.byKey(const Key('record-payment')));
        await tester.pumpAndSettle();
        expect(find.text('Record a payment'), findsWidgets);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('pay-billed')))
              .controller!
              .text,
          '40.00',
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('pay-collected')))
              .controller!
              .text,
          '40.00',
        );
        expect(find.byKey(const Key('pay-still-due')), findsOneWidget);
      },
    );

    testWidgets('the table\'s server is offered it too; a verifier is not', (
      tester,
    ) async {
      db.role = 'server';
      await open(tester, host());
      expect(find.byKey(const Key('record-payment')), findsOneWidget);
      db.role = 'verifier';
      db.calls.clear();
      await open(tester, host());
      expect(find.byKey(const Key('record-payment')), findsNothing);
      expect(
        find.byKey(const Key('money-card')),
        findsOneWidget,
        reason: 'a verifier can see the money',
      );
      expect(
        find.text('Bottle orders'),
        findsNothing,
        reason: 'but not the orders',
      );
      expect(
        db.functions,
        isNot(contains('desk_booking_orders')),
        reason: 'and nothing asks for them',
      );
    });

    testWidgets(
      'a closed-out table says nothing more can be recorded or changed',
      (tester) async {
        db.bookings['b1']!.reconciled = true;
        await open(tester, host());
        expect(find.byKey(const Key('record-payment')), findsNothing);
        expect(find.byKey(const Key('closed-note')), findsOneWidget);
        expect(find.byKey(const Key('closed-out')), findsOneWidget);
      },
    );

    testWidgets('a table with a closing asked for says so', (tester) async {
      db.bookings['b1']!.closeoutRequested = true;
      await open(tester, host());
      expect(find.byKey(const Key('closeout-requested')), findsOneWidget);
      expect(find.byKey(const Key('closed-out')), findsNothing);
    });

    testWidgets('a booking that is not confirmed offers no payment', (
      tester,
    ) async {
      db.bookings['b1']!.status = 'pending';
      await open(tester, host());
      expect(find.byKey(const Key('record-payment')), findsNothing);
    });

    testWidgets(
      'after a payment is recorded the page shows it, and says what is still due',
      (tester) async {
        await open(tester, host());
        await tester.tap(find.byKey(const Key('record-payment')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('method-cash')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('receipt-none')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('receipt-reason')),
          'printer broke',
        );
        await tester.enterText(find.byKey(const Key('pay-collected')), '15');
        await tester.ensureVisible(find.byKey(const Key('pay-submit')));
        await tester.tap(find.byKey(const Key('pay-submit')));
        await tester.pumpAndSettle();
        expect(
          find.text('Payment recorded. \$25.00 still due.'),
          findsOneWidget,
        );
        expect(db.payments, hasLength(1));
        expect(find.text('Cash · \$15.00'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('money-due'))).data,
          '\$25.00',
        );
      },
    );

    testWidgets('a payment that settles the table says it is paid up', (
      tester,
    ) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('record-payment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('method-cash')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('receipt-none')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('receipt-reason')),
        'printer broke',
      );
      await tester.ensureVisible(find.byKey(const Key('pay-submit')));
      await tester.tap(find.byKey(const Key('pay-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Payment recorded. The table is paid up.'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('money-due'))).data,
        '\$0.00',
      );
    });
  });

  group('when it goes wrong', () {
    testWidgets(
      'a table the person may not open says their access does not cover it, with a retry',
      (tester) async {
        db.role = 'server';
        db.assignments.clear();
        await open(tester, host());
        expect(
          find.text('Your access has ended, or you are signed out.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('detail-retry')), findsOneWidget);
      },
    );

    testWidgets(
      'a database without the migration says so, with nothing to retry',
      (tester) async {
        db.failAll = PostgrestException(message: 'no function', code: '42883');
        await open(tester, host());
        expect(
          find.text('Payments are not set up on this server yet.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('detail-retry')), findsNothing);
      },
    );

    testWidgets('a dropped connection can be tried again', (tester) async {
      db.failAll = Exception('offline');
      await open(tester, host());
      expect(
        find.text(
          'Payments could not be loaded. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      db.failAll = null;
      await tester.tap(find.byKey(const Key('detail-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('money-card')), findsOneWidget);
    });

    testWidgets('if the orders cannot be loaded the money still shows', (
      tester,
    ) async {
      db.failOn['desk_booking_orders'] = Exception('offline');
      await open(tester, host());
      expect(find.byKey(const Key('money-card')), findsOneWidget);
      expect(find.byKey(const Key('detail-orders-error')), findsOneWidget);
      expect(
        find.text(
          'Orders could not be loaded. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('pulling down reads the table again', (tester) async {
      await open(tester, host(), height: 600);
      expect(db.count('desk_booking_money'), 1);
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(db.count('desk_booking_money'), 2);
    });

    testWidgets(
      'a move the database refuses shows its sentence, and the table is read again',
      (tester) async {
        await open(tester, host());
        db.line('l1').state = 'served';
        db.role = 'server';
        await tester.tap(find.byKey(const Key('move-l1')));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });
}
