import 'dart:async';

import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/payment_review_screen.dart';
import 'package:bottles_up_vendor/features/table_service/services/receipt_service.dart';
import 'package:bottles_up_vendor/features/table_service/widgets/verify_dialog.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_backend.dart';

late FakeTableBackend db;
String? askedSummary;
String? answer;

const verifierWs = Workspace(
  membershipId: 'w1',
  orgId: 'o1',
  orgName: 'Club Co',
  orgKind: 'venue_owner',
  role: WorkspaceRole.verifier,
  venueId: 'v1',
  venueName: 'Club A',
);

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host({
  Workspace ws = verifierWs,
  bool realDialog = false,
  bool signFails = false,
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    tableServiceServiceProvider.overrideWithValue(db.service),
    receiptServiceProvider.overrideWithValue(
      ReceiptService(
        signer: (p) async {
          if (signFails) throw Exception('x');
          return 'https://signed.example/$p';
        },
      ),
    ),
  ],
  child: MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: PaymentReviewScreen(
        workspace: ws,
        clock: friday9pm,
        askVerify:
            realDialog
                ? (c, summary) => showVerifyDialog(c, summary: summary)
                : (c, summary) async {
                  askedSummary = summary;
                  return answer;
                },
      ),
    ),
  ),
);

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

/// What was sent to check a payment (the last call is the queue being read again).
Map<String, dynamic>? verifyCall() => db.params.lastWhere(
  (p) => p != null && p.containsKey('p_payment'),
  orElse: () => null,
);

void main() {
  setUp(() {
    db = FakeTableBackend()..role = 'verifier';
    db.now = DateTime(2026, 10, 9, 21);
    askedSummary = null;
    answer = 'matches the till';
    db.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD');
    db.addBooking('b2', name: 'Grace Hopper', code: 'EF34GH', table: 'Corner');
    db.addBooking('bx', name: 'Elsewhere Ed', venue: 'v2');
    db.addPayment(
      'b1',
      3000,
      paymentId: 'p1',
      path: 'b1/r.jpg',
      pos: 'POS-1',
      method: 'debit',
      at: db.now.subtract(const Duration(minutes: 30)),
    );
    db.addPayment(
      'b2',
      1500,
      paymentId: 'p2',
      reason: 'printer broke',
      at: db.now.subtract(const Duration(minutes: 10)),
    );
    db.addPayment(
      'b1',
      700,
      paymentId: 'p3',
      status: 'disputed',
      dispute: 'I only paid \$5',
      path: 'b1/r3.jpg',
      at: db.now.subtract(const Duration(minutes: 5)),
    );
    db.addPayment(
      'b1',
      900,
      paymentId: 'p4',
      by: 'u-me',
      path: 'b1/r4.jpg',
      at: db.now.subtract(const Duration(minutes: 2)),
    );
    db.addPayment('b1', 400, paymentId: 'done', verified: true);
    db.addPayment('b1', 300, paymentId: 'conf', status: 'confirmed');
    db.addPayment('bx', 800, paymentId: 'other');
  });

  testWidgets(
    'lists what needs a person: the disputed payment first, then the oldest, and none that are checked, confirmed or at another club',
    (tester) async {
      await open(tester, host());
      expect(db.calls.first.$1, 'desk_pending_verifications');
      expect(db.params.first, {'p_venue': 'v1'});
      expect(find.text('Payments to check'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(find.text('4 payments waiting'), findsOneWidget);
      final order = [
        for (final id in ['p3', 'p1', 'p2', 'p4'])
          tester.getTopLeft(find.byKey(Key('review-$id'))).dy,
      ];
      expect(order, [...order]..sort());
      for (final id in ['done', 'conf', 'other']) {
        expect(find.byKey(Key('review-$id')), findsNothing, reason: id);
      }
    },
  );

  testWidgets(
    'a payment shows the table, the bill, what was collected, how, who recorded it and when',
    (tester) async {
      await open(tester, host());
      final card = find.byKey(const Key('review-p1'));
      expect(
        find.descendant(of: card, matching: find.text('Ada Lovelace')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('VIP booth · AB12CD')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Debit · collected \$30.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Till receipt no. POS-1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Recorded 30 min ago by Sam Server'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Pending')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Check it against the till'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the bill is shown only when it differs from what was collected',
    (tester) async {
      db.addPayment(
        'b2',
        2000,
        paymentId: 'p5',
        billed: 2500,
        at: db.now.subtract(const Duration(minutes: 1)),
      );
      await open(tester, host());
      expect(
        find.descendant(
          of: find.byKey(const Key('review-p5')),
          matching: find.text('Bill \$25.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('review-p1')),
          matching: find.textContaining('Bill'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the guest\'s reason is shown only for a disputed payment, and only if there is one',
    (tester) async {
      db.addPayment('b2', 100, paymentId: 'p6', status: 'disputed');
      db.addPayment('b2', 100, paymentId: 'p7', dispute: 'a stray reason');
      await open(tester, host());
      expect(
        find.byKey(const Key('dispute-p6')),
        findsNothing,
        reason: 'disputed with no reason given',
      );
      expect(
        find.byKey(const Key('dispute-p7')),
        findsNothing,
        reason: 'not disputed',
      );
      expect(find.byKey(const Key('dispute-p3')), findsOneWidget);
    },
  );

  testWidgets('a payment with no receipt shows the reason given', (
    tester,
  ) async {
    await open(tester, host());
    expect(find.text('No receipt: printer broke'), findsOneWidget);
    expect(find.byKey(const Key('review-receipt-p2')), findsNothing);
  });

  testWidgets('a receipt can be opened to compare it', (tester) async {
    await open(tester, host());
    await tester.tap(find.byKey(const Key('review-receipt-p1')));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byKey(const Key('receipt-image')));
    expect(
      (image.image as NetworkImage).url,
      'https://signed.example/b1/r.jpg',
    );
  });

  testWidgets('a receipt that cannot be opened says so', (tester) async {
    await open(tester, host(signFails: true));
    await tester.tap(find.byKey(const Key('review-receipt-p1')));
    await tester.pumpAndSettle();
    expect(find.text('The receipt photo could not be opened.'), findsOneWidget);
  });

  testWidgets(
    'a disputed payment shows the guest\'s reason and has no check button',
    (tester) async {
      await open(tester, host());
      expect(find.byKey(const Key('verify-p3')), findsNothing);
      expect(find.text('Guest says: I only paid \$5'), findsOneWidget);
      expect(
        find.text(
          'The guest disputed this payment. A manager has to settle it.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('review-p3')),
          matching: find.text('Disputed'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('your own entry has no check button and says why', (
    tester,
  ) async {
    await open(tester, host());
    expect(find.byKey(const Key('verify-p4')), findsNothing);
    expect(
      find.text('You recorded this payment, so someone else has to verify it.'),
      findsOneWidget,
    );
    expect(find.text('Recorded 2 min ago by you'), findsOneWidget);
  });

  group('checking one', () {
    testWidgets(
      'asks for a note, then marks it checked, and it leaves the queue',
      (tester) async {
        await open(tester, host());
        await tester.tap(find.byKey(const Key('verify-p1')));
        await tester.pumpAndSettle();
        expect(askedSummary, 'VIP booth · Ada Lovelace: \$30.00 by debit');
        expect(verifyCall(), {'p_payment': 'p1', 'p_note': 'matches the till'});
        expect(
          db.payments.firstWhere((p) => p.id == 'p1').verifiedAt,
          isNotNull,
        );
        expect(find.text('Payment marked as checked.'), findsOneWidget);
        expect(find.byKey(const Key('review-p1')), findsNothing);
        expect(find.text('3 payments waiting'), findsOneWidget);
      },
    );

    testWidgets('backing out of the question checks nothing', (tester) async {
      answer = null;
      await open(tester, host());
      await tester.tap(find.byKey(const Key('verify-p1')));
      await tester.pumpAndSettle();
      expect(db.functions, isNot(contains('desk_verify_payment')));
      expect(find.byKey(const Key('review-p1')), findsOneWidget);
    });

    testWidgets('an empty note is allowed and is sent as none', (tester) async {
      answer = '';
      await open(tester, host());
      await tester.tap(find.byKey(const Key('verify-p1')));
      await tester.pumpAndSettle();
      expect(verifyCall(), {'p_payment': 'p1', 'p_note': null});
    });

    testWidgets(
      'someone else checked it first: the database\'s sentence is shown and the queue is read again',
      (tester) async {
        db.beforeCall = (f) {
          if (f == 'desk_verify_payment') {
            db.payments.firstWhere((p) => p.id == 'p1').verifiedAt = db.now;
          }
        };
        await open(tester, host());
        await tester.tap(find.byKey(const Key('verify-p1')));
        await tester.pumpAndSettle();
        expect(find.text('This payment was already verified.'), findsOneWidget);
        expect(db.count('desk_pending_verifications'), 2);
        expect(find.byKey(const Key('review-p1')), findsNothing);
      },
    );

    testWidgets(
      'the button waits while the check is on its way, so a second tap cannot send it twice',
      (tester) async {
        final gate = Completer<void>();
        await open(tester, host());
        db.hold = gate.future;
        await tester.tap(find.byKey(const Key('verify-p1')));
        await tester.pump();
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('verify-p1')))
              .onPressed,
          isNull,
        );
        await tester.tap(
          find.byKey(const Key('verify-p1')),
          warnIfMissed: false,
        );
        db.hold = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(db.count('desk_verify_payment'), 1);
      },
    );

    testWidgets(
      'the real question: a note that is too long is refused before anything is sent, and a good one goes',
      (tester) async {
        await open(tester, host(realDialog: true));
        await tester.tap(find.byKey(const Key('verify-p1')));
        await tester.pumpAndSettle();
        expect(find.text('Mark this payment as checked'), findsOneWidget);
        expect(
          find.text('VIP booth · Ada Lovelace: \$30.00 by debit'),
          findsOneWidget,
        );
        await tester.enterText(find.byKey(const Key('verify-note')), 'n' * 301);
        await tester.tap(find.byKey(const Key('verify-confirm')));
        await tester.pump();
        expect(
          find.text('Keep the note to 300 characters or fewer.'),
          findsOneWidget,
        );
        expect(db.functions, isNot(contains('desk_verify_payment')));
        await tester.enterText(
          find.byKey(const Key('verify-note')),
          '  looks right  ',
        );
        await tester.pump();
        expect(
          find.text('Keep the note to 300 characters or fewer.'),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('verify-confirm')));
        await tester.pumpAndSettle();
        expect(verifyCall(), {'p_payment': 'p1', 'p_note': 'looks right'});
      },
    );

    testWidgets('the real question: going back checks nothing', (tester) async {
      await open(tester, host(realDialog: true));
      await tester.tap(find.byKey(const Key('verify-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verify-back')));
      await tester.pumpAndSettle();
      expect(db.functions, isNot(contains('desk_verify_payment')));
    });
  });

  group('who sees it', () {
    testWidgets('a manager sees the same queue', (tester) async {
      db.role = 'manager';
      const ws = Workspace(
        membershipId: 'w2',
        orgId: 'o1',
        orgName: 'Club Co',
        orgKind: 'venue_owner',
        role: WorkspaceRole.manager,
        venueId: 'v1',
        venueName: 'Club A',
      );
      await open(tester, host(ws: ws));
      expect(find.text('4 payments waiting'), findsOneWidget);
    });

    testWidgets(
      'a server is refused by the database and told their access does not cover it',
      (tester) async {
        db.role = 'server';
        await open(tester, host());
        expect(
          find.text('Your access has ended, or you are signed out.'),
          findsOneWidget,
        );
      },
    );
  });

  group('when there is nothing, or it goes wrong', () {
    testWidgets('nothing waiting says so', (tester) async {
      db.payments.clear();
      await open(tester, host());
      expect(find.byKey(const Key('review-empty')), findsOneWidget);
    });

    testWidgets(
      'a database without the migration says so, with nothing to retry',
      (tester) async {
        db.failAll = PostgrestException(message: 'no function', code: '42883');
        await open(tester, host());
        expect(
          find.text('Payments are not set up on this server yet.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('review-retry')), findsNothing);
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
      await tester.tap(find.byKey(const Key('review-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review-p1')), findsOneWidget);
    });

    testWidgets(
      'a workspace that is not tied to a club shows nothing and asks for nothing',
      (tester) async {
        const ws = Workspace(
          membershipId: 'w9',
          orgId: 'o1',
          orgName: 'Club Co',
          orgKind: 'venue_owner',
          role: WorkspaceRole.verifier,
        );
        await open(tester, host(ws: ws));
        expect(find.byKey(const Key('review-no-venue')), findsOneWidget);
        expect(db.calls, isEmpty);
      },
    );
  });
}
