import 'dart:typed_data';

import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:bottles_up_vendor/features/table_service/services/receipt_service.dart';
import 'package:bottles_up_vendor/features/table_service/services/table_service_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_backend.dart';

void main() {
  late FakeTableBackend db;
  setUp(() {
    db = FakeTableBackend()..role = 'manager';
    db.addBooking(
      'b1',
      code: 'AB12CD',
      name: 'Ada Lovelace',
      total: 10000,
      paid: 6000,
    );
    db.addLine('b1', 'Patron', lineId: 'l1', minutesAgo: 30);
    db.addLine(
      'b1',
      'Grey Goose',
      lineId: 'l2',
      pay: 'due_at_venue',
      minutesAgo: 20,
    );
  });

  Matcher loadFailure({
    bool unavailable = false,
    bool accessEnded = false,
    String? what,
  }) => throwsA(
    isA<TableServiceLoadException>()
        .having((e) => e.unavailable, 'unavailable', unavailable)
        .having((e) => e.accessEnded, 'accessEnded', accessEnded)
        .having((e) => what == null ? what : e.what, 'what', what),
  );

  Matcher actionFailure(String message) => throwsA(
    isA<TableServiceActionException>().having(
      (e) => e.message,
      'message',
      message,
    ),
  );

  const photoForm = PaymentInput(
    billed: '40',
    collected: '40',
    method: PayMethod.cash,
    hasReceiptPhoto: true,
    receiptReadable: true,
  );

  group('a night\'s orders', () {
    test(
      'asks for one club and one night by the argument names the database defines, and reads the rows',
      () async {
        final lines = await db.service.orders('v1', '2026-10-09');
        expect(db.functions, ['desk_orders']);
        expect(db.params, [
          {'p_venue': 'v1', 'p_night': '2026-10-09'},
        ]);
        expect(lines.map((l) => l.lineId), ['l1', 'l2']);
        expect(lines.first.state, ServiceState.awaitingPrep);
      },
    );

    test('a night that is not a date never leaves the phone', () async {
      for (final bad in ['', 'tonight', '2026-02-30', '09/10/2026']) {
        expect(
          () => db.service.orders('v1', bad),
          throwsArgumentError,
          reason: bad,
        );
      }
      expect(db.calls, isEmpty);
    });

    test(
      'a row it cannot read is dropped and the rest kept; nothing, or not a list, is no orders',
      () async {
        final svc = TableServiceService(
          rpc:
              (f, {params}) async => [
                {'line_id': 'x'},
                'not a row',
                {
                  'line_id': 'l9',
                  'service_status': 'ready',
                  'payment_status': 'paid',
                  'ordered_at': '2026-10-09T21:00:00Z',
                },
              ],
        );
        expect((await svc.orders('v1', '2026-10-09')).map((l) => l.lineId), [
          'l9',
        ]);
        expect(
          await TableServiceService(
            rpc: (f, {params}) async => null,
          ).orders('v1', '2026-10-09'),
          isEmpty,
        );
        expect(
          await TableServiceService(
            rpc: (f, {params}) async => {'oops': 1},
          ).orders('v1', '2026-10-09'),
          isEmpty,
        );
      },
    );

    test(
      'a database without the migration is "unavailable", which retrying cannot fix',
      () async {
        for (final code in ['42883', 'PGRST202', '42P01']) {
          db.failAll = PostgrestException(
            message: 'function does not exist',
            code: code,
          );
          await expectLater(
            db.service.orders('v1', '2026-10-09'),
            loadFailure(unavailable: true, what: 'orders'),
            reason: code,
          );
        }
        db.failAll = PostgrestException(message: 'x', code: '42883');
        try {
          await db.service.orders('v1', '2026-10-09');
        } on TableServiceLoadException catch (e) {
          expect(e.message, 'Orders are not set up on this server yet.');
        }
      },
    );

    test(
      'a person who lost their access is told so, and a dropped connection is a plain failure',
      () async {
        for (final m in [
          'not allowed',
          'not authenticated',
          'Your access has ended',
        ]) {
          db.failAll = PostgrestException(message: m, code: 'P0001');
          await expectLater(
            db.service.orders('v1', '2026-10-09'),
            loadFailure(accessEnded: true),
            reason: m,
          );
        }
        db.failAll = Exception('SocketException: connection lost');
        await expectLater(db.service.orders('v1', '2026-10-09'), loadFailure());
      },
    );

    test(
      'a verifier is refused by the database and the service says their access does not cover it',
      () async {
        db.role = 'verifier';
        await expectLater(
          db.service.orders('v1', '2026-10-09'),
          loadFailure(accessEnded: true),
        );
      },
    );
  });

  group('one table\'s orders', () {
    test(
      'asks for the booking and keeps the balance it was read with',
      () async {
        final lines = await db.service.tableOrders('b1', balanceDueCents: 4000);
        expect(db.functions, ['desk_booking_orders', 'desk_booking_deliveries'], reason: 'the second is how many of each line were handed over');
        expect(db.params, [
          {'p_booking': 'b1'},
          {'p_booking': 'b1'},
        ]);
        expect(lines.map((l) => l.lineId), ['l1', 'l2']);
        expect(
          lines.every((l) => l.bookingId == 'b1' && l.balanceDueCents == 4000),
          true,
        );
        expect(lines.first.unitPriceCents, 5000);
      },
    );

    test('a table the person may not open is "access ended"', () async {
      db.role = 'server';
      await expectLater(
        db.service.tableOrders('b1'),
        loadFailure(accessEnded: true),
      );
    });
  });

  group('moving an order', () {
    test(
      'sends the line and the state by the argument names the database defines',
      () async {
        expect(await db.service.moveOrder('l1', ServiceState.preparing), true);
        expect(db.params.single, {'p_line': 'l1', 'p_status': 'preparing'});
        expect(db.line('l1').state, 'preparing');
      },
    );

    test('a repeated move answers false and changes nothing', () async {
      await db.service.moveOrder('l1', ServiceState.preparing);
      expect(await db.service.moveOrder('l1', ServiceState.preparing), false);
    });

    test('the database\'s own sentence is what the person reads', () async {
      await expectLater(
        db.service.moveOrder('l2', ServiceState.served),
        actionFailure(
          'Cannot mark delivered - this table still has a balance due at the venue.',
        ),
      );
    });

    test(
      'a refusal that is not a sentence from the database is a generic one',
      () async {
        db.failAll = Exception('SocketException');
        await expectLater(
          db.service.moveOrder('l1', ServiceState.ready),
          actionFailure(
            'The order could not be moved. Check your connection and try again.',
          ),
        );
      },
    );

    test('losing access is said as such', () async {
      db.role = 'none';
      await expectLater(
        db.service.moveOrder('l1', ServiceState.ready),
        actionFailure("You don't have access to do that."),
      );
    });

    test('an answer that is not true is "no change"', () async {
      final svc = TableServiceService(rpc: (f, {params}) async => null);
      expect(await svc.moveOrder('l1', ServiceState.ready), false);
    });
  });

  group('a table\'s money', () {
    test('asks for the booking and reads the answer', () async {
      db.addPayment('b1', 3000, status: 'pending', by: 'u-me');
      final m = await db.service.money('b1');
      expect(db.params.single, {'p_booking': 'b1'});
      expect(m.level, 'manager');
      expect(m.balanceDueCents, 4000);
      expect(m.payments.single.recordedByMe, true);
    });

    test(
      'an answer that is not a table\'s money is a failure, not an empty table',
      () async {
        for (final data in [
          null,
          <dynamic>[],
          'x',
          {'oops': 1},
        ]) {
          final svc = TableServiceService(rpc: (f, {params}) async => data);
          await expectLater(
            svc.money('b1'),
            loadFailure(what: 'payments'),
            reason: '$data',
          );
        }
      },
    );

    test('failures are told apart', () async {
      db.failAll = PostgrestException(message: 'x', code: '42883');
      await expectLater(db.service.money('b1'), loadFailure(unavailable: true));
      db.failAll = PostgrestException(message: 'not allowed', code: 'P0001');
      await expectLater(db.service.money('b1'), loadFailure(accessEnded: true));
      db.failAll = Exception('offline');
      await expectLater(db.service.money('b1'), loadFailure());
    });
  });

  group('recording a payment', () {
    test(
      'a form with problems never leaves the phone, and says the first one',
      () async {
        await expectLater(
          db.service.recordPayment('b1', const PaymentInput(), manager: true),
          actionFailure('Enter the bill total.'),
        );
        await expectLater(
          db.service.recordPayment(
            'b1',
            const PaymentInput(
              billed: '10',
              collected: '10',
              method: PayMethod.cash,
            ),
            manager: false,
          ),
          actionFailure('Take a photo of the receipt.'),
        );
        expect(db.calls, isEmpty);
      },
    );

    test(
      'sends everything the database defines, and reads the answer',
      () async {
        final r = await db.service.recordPayment(
          'b1',
          photoForm,
          manager: true,
          receiptPath: 'b1/r.jpg',
          receiptHash: 'a' * 64,
        );
        expect(db.functions, ['desk_record_payment']);
        expect(db.params.single!.keys.toSet(), {
          'p_booking',
          'p_billed_amount_cents',
          'p_amount_paid_cents',
          'p_payment_method',
          'p_split_breakdown',
          'p_pos_reference',
          'p_receipt_photo_path',
          'p_payer_name',
          'p_payer_email',
          'p_bottle_subtotal_cents',
          'p_discount_cents',
          'p_tax_cents',
          'p_gratuity_cents',
          'p_receipt_photo_hash',
          'p_device_id',
          'p_missing_receipt_reason',
        });
        expect(r.duplicate, false);
        expect(
          r.balanceDueCents,
          0,
          reason: 'the balance was 4000 and 4000 was collected',
        );
        expect(db.bookings['b1']!.paid, 10000);
      },
    );

    test(
      'the same receipt sent again is a repeat, not a second payment',
      () async {
        db.role = 'manager';
        final first = await db.service.recordPayment(
          'b1',
          photoForm,
          manager: true,
          receiptPath: 'b1/r.jpg',
          receiptHash: 'a' * 64,
        );
        final again = await db.service.recordPayment(
          'b1',
          photoForm,
          manager: true,
          receiptPath: 'b1/r.jpg',
          receiptHash: 'a' * 64,
        );
        expect(again.duplicate, true);
        expect(again.paymentId, first.paymentId);
        expect(db.payments, hasLength(1));
      },
    );

    test('the database\'s own sentence is what the person reads', () async {
      db.addPayment('b1', 100, pos: 'POS-9', by: 'u-other');
      final form = PaymentInput(
        billed: '40',
        collected: '40',
        method: PayMethod.cash,
        posReference: 'POS-9',
        hasReceiptPhoto: true,
        receiptReadable: true,
      );
      await expectLater(
        db.service.recordPayment(
          'b1',
          form,
          manager: true,
          receiptPath: 'b1/r.jpg',
        ),
        actionFailure(
          'This POS receipt number has already been recorded for another payment at this venue.',
        ),
      );
    });

    test('a table the person does not have is refused', () async {
      db.role = 'server';
      await expectLater(
        db.service.recordPayment(
          'b1',
          photoForm,
          manager: false,
          receiptPath: 'b1/r.jpg',
        ),
        actionFailure("You don't have access to do that."),
      );
    });

    test('an answer that is not a recorded payment is a failure', () async {
      for (final data in [
        null,
        {'success': false},
        {'success': true},
        'ok',
      ]) {
        final svc = TableServiceService(rpc: (f, {params}) async => data);
        await expectLater(
          svc.recordPayment(
            'b1',
            photoForm,
            manager: true,
            receiptPath: 'b1/r.jpg',
          ),
          actionFailure('The payment could not be recorded.'),
          reason: '$data',
        );
      }
    });

    test('a dropped connection is a generic sentence', () async {
      db.failAll = Exception('offline');
      await expectLater(
        db.service.recordPayment(
          'b1',
          photoForm,
          manager: true,
          receiptPath: 'b1/r.jpg',
        ),
        actionFailure(
          'The payment could not be recorded. Check your connection and try again.',
        ),
      );
    });
  });

  group('the checking queue', () {
    test('asks for a club\'s payments and reads them', () async {
      db.addPayment('b1', 3000, paymentId: 'p1');
      final rows = await db.service.pendingPayments('v1');
      expect(db.params.single, {'p_venue': 'v1'});
      expect(rows.single.paymentId, 'p1');
    });

    test('a server is refused', () async {
      db.role = 'server';
      await expectLater(
        db.service.pendingPayments('v1'),
        loadFailure(accessEnded: true, what: 'payments'),
      );
    });

    test('checking a payment sends it with its note', () async {
      db.addPayment('b1', 3000, paymentId: 'p1');
      await db.service.verify('p1', note: '  matches  ');
      expect(db.params.last, {'p_payment': 'p1', 'p_note': 'matches'});
      expect(db.payments.single.verifiedAt, isNotNull);
    });

    test('a note that is too long never leaves the phone', () async {
      await expectLater(
        db.service.verify('p1', note: 'n' * 301),
        actionFailure('Keep the note to 300 characters or fewer.'),
      );
      expect(db.calls, isEmpty);
    });

    test(
      'the database refuses your own entry, a second check and a disputed payment in its own words',
      () async {
        db.addPayment('b1', 3000, paymentId: 'mine', by: 'u-me');
        db.addPayment('b1', 3000, paymentId: 'done', verified: true);
        db.addPayment('b1', 3000, paymentId: 'disp', status: 'disputed');
        await expectLater(
          db.service.verify('mine'),
          actionFailure(
            'You recorded this payment, so someone else has to verify it.',
          ),
        );
        await expectLater(
          db.service.verify('done'),
          actionFailure('This payment was already verified.'),
        );
        await expectLater(
          db.service.verify('disp'),
          actionFailure('The customer already responded to this payment.'),
        );
      },
    );

    test('a dropped connection is a generic sentence', () async {
      db.failAll = Exception('offline');
      await expectLater(
        db.service.verify('p1'),
        actionFailure(
          'The payment could not be verified. Check your connection and try again.',
        ),
      );
    });
  });

  group('tables at a glance, and Tonight', () {
    test('table statuses ask for a club and a night', () async {
      final rows = await db.service.tableStatuses('v1', '2026-10-09');
      expect(db.params.single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
      expect(rows.single.bookingId, 'b1');
      expect(rows.single.balanceDueCents, 4000);
      expect(rows.single.itemsOpen, 2);
      expect(() => db.service.tableStatuses('v1', 'soon'), throwsArgumentError);
    });

    test('Tonight asks for a club and a night and reads the one row', () async {
      db.openRequests = 2;
      final t = await db.service.tonight('v1', '2026-10-09');
      expect(db.functions, ['desk_tonight']);
      expect(db.params.single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
      expect(t.tables, 1);
      expect(t.requestsOpen, 2);
      expect(() => db.service.tonight('v1', ''), throwsArgumentError);
    });

    test(
      'an answer with no row is a failure, not a night with nothing in it',
      () async {
        final svc = TableServiceService(
          rpc: (f, {params}) async => <dynamic>[],
        );
        await expectLater(
          svc.tonight('v1', '2026-10-09'),
          loadFailure(what: 'Tonight'),
        );
      },
    );

    test('only a manager gets Tonight', () async {
      db.role = 'server';
      await expectLater(
        db.service.tonight('v1', '2026-10-09'),
        loadFailure(accessEnded: true, what: 'Tonight'),
      );
    });
  });

  group('what a screen shows when loading failed', () {
    test('the service\'s own failure is shown as it is', () {
      const own = TableServiceLoadException(
        unavailable: true,
        accessEnded: false,
        what: 'orders',
      );
      expect(identical(loadFailureFor(own, 'payments'), own), true);
    });

    test(
      'anything else is a plain "could not be loaded" for what was being loaded',
      () {
        final e = loadFailureFor(Exception('boom'), 'payments');
        expect(
          [e.unavailable, e.accessEnded, e.what],
          [false, false, 'payments'],
        );
        expect(
          e.message,
          'Payments could not be loaded. Check your connection and try again.',
        );
      },
    );
  });

  group('receipt photos', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]);

    test('are filed under the booking, with the SHA-256 of the file', () async {
      String? path;
      String? type;
      final svc = ReceiptService(
        uploader: (p, bytes, t) async {
          path = p;
          type = t;
        },
        newId: () => 'abc',
      );
      final up = await svc.upload('b1', jpeg);
      expect(path, 'b1/abc.jpg');
      expect(up.path, 'b1/abc.jpg');
      expect(type, 'image/jpeg');
      expect(up.hash, hasLength(64));
      expect(up.hash, matches(RegExp(r'^[0-9a-f]{64}$')));
      // The same bytes always hash the same; different bytes differ.
      final other = await svc.upload('b1', Uint8List.fromList([...jpeg, 9]));
      expect((await svc.upload('b1', jpeg)).hash, up.hash);
      expect(other.hash, isNot(up.hash));
    });

    test(
      'the hash is the real SHA-256 (checked against one computed outside Dart)',
      () async {
        final svc = ReceiptService(
          uploader: (p, b, t) async {},
          newId: () => 'x',
        );
        final up = await svc.upload(
          'b1',
          Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        );
        expect(
          up.hash,
          '6e568e1f67fba258184c78181539e5e8fdee447e49bb706fc0ea34fbf12336a5',
        );
      },
    );

    test(
      'a file that is not a photo is refused with a sentence before anything is sent',
      () async {
        var sent = false;
        final svc = ReceiptService(uploader: (p, b, t) async => sent = true);
        await expectLater(
          svc.upload('b1', Uint8List(0)),
          throwsA(
            isA<ReceiptException>().having(
              (e) => e.message,
              'message',
              'That file is empty.',
            ),
          ),
        );
        await expectLater(
          svc.upload('b1', Uint8List.fromList([1, 2, 3])),
          throwsA(
            isA<ReceiptException>().having(
              (e) => e.message,
              'message',
              'Use a JPEG, PNG or WebP image.',
            ),
          ),
        );
        await expectLater(
          svc.upload(
            'b1',
            Uint8List.fromList([
              0xFF,
              0xD8,
              0xFF,
              ...List.filled(5 * 1024 * 1024, 0),
            ]),
          ),
          throwsA(
            isA<ReceiptException>().having(
              (e) => e.message,
              'message',
              'The image is larger than 5 MB. Choose a smaller one.',
            ),
          ),
        );
        expect(sent, false);
      },
    );

    test('a refusal from storage is one plain sentence', () async {
      final svc = ReceiptService(
        uploader: (p, b, t) async => throw Exception('403'),
      );
      await expectLater(
        svc.upload('b1', jpeg),
        throwsA(
          isA<ReceiptException>().having(
            (e) => e.message,
            'message',
            receiptUploadFailed,
          ),
        ),
      );
    });

    test(
      'opening one asks for a short-lived address, and a failure is a sentence',
      () async {
        final svc = ReceiptService(
          signer: (p) async => 'https://signed.example/$p',
        );
        expect(
          await svc.signedUrl('b1/r.jpg'),
          'https://signed.example/b1/r.jpg',
        );
        final bad = ReceiptService(
          signer: (p) async => throw Exception('expired'),
        );
        await expectLater(
          bad.signedUrl('b1/r.jpg'),
          throwsA(
            isA<ReceiptException>().having(
              (e) => e.message,
              'message',
              receiptOpenFailed,
            ),
          ),
        );
      },
    );

    test(
      'they are written with their real type, cached for an hour and never over an existing file',
      () {
        final o = receiptFileOptions('image/png');
        expect(o.contentType, 'image/png');
        expect(o.cacheControl, '3600');
        expect(o.upsert, false);
      },
    );

    test('every upload is a new file, never an overwrite', () async {
      final ids = ['one', 'two'];
      final paths = <String>[];
      final svc = ReceiptService(
        uploader: (p, b, t) async => paths.add(p),
        newId: () => ids.removeAt(0),
      );
      await svc.upload('b1', jpeg);
      await svc.upload('b1', jpeg);
      expect(paths, ['b1/one.jpg', 'b1/two.jpg']);
      expect(ReceiptService.bucket, 'club-payment-receipts');
    });
  });
}
