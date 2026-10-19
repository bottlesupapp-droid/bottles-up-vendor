import 'dart:async';
import 'dart:typed_data';

import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/record_payment_screen.dart';
import 'package:bottles_up_vendor/features/table_service/services/receipt_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_table_backend.dart';

late FakeTableBackend db;
late List<String> uploads;
late List<bool> pickedFrom; // true = camera
late Uint8List? nextPhoto;
RecordedPayment? result;
bool popped = false;
int idCounter = 0;
bool uploadFails = false;

final jpegA = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);
final jpegB = Uint8List.fromList([0xFF, 0xD8, 0xFF, 9, 9, 9]);

Widget host({required bool manager, int balance = 4000}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    tableServiceServiceProvider.overrideWithValue(db.service),
    receiptServiceProvider.overrideWithValue(
      ReceiptService(
        uploader: (path, bytes, type) async {
          if (uploadFails) throw Exception('403');
          uploads.add(path);
        },
        newId: () => 'photo${++idCounter}',
      ),
    ),
    receiptPhotoPickerProvider.overrideWithValue((
      context, {
      required camera,
    }) async {
      pickedFrom.add(camera);
      return nextPhoto;
    }),
  ],
  child: MaterialApp(
    theme: ThemeData.dark(),
    home: Builder(
      builder:
          (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('launch'),
                onPressed: () async {
                  result = await Navigator.of(context).push<RecordedPayment>(
                    MaterialPageRoute(
                      builder:
                          (_) => RecordPaymentScreen(
                            bookingId: 'b1',
                            tableLabel: 'VIP booth · Ada Lovelace',
                            balanceDueCents: balance,
                            manager: manager,
                          ),
                    ),
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
    ),
  ),
);

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.tap(find.byKey(const Key('launch')));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> typeKey(WidgetTester tester, String key, String text) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

/// A server's complete form: cash, a photo they confirm they can read.
Future<void> fillAsServer(WidgetTester tester) async {
  await tapKey(tester, 'method-cash');
  await tapKey(tester, 'receipt-take');
  await tapKey(tester, 'receipt-readable');
}

Map<String, dynamic> sent() =>
    db.params.lastWhere((p) => p != null && p.containsKey('p_payment_method'))!;

void main() {
  setUp(() {
    db = FakeTableBackend()..role = 'server';
    db.now = DateTime(2026, 10, 9, 21);
    db.addBooking('b1', name: 'Ada Lovelace', total: 10000, paid: 6000);
    db.assignments['b1'] = 'm-me';
    uploads = [];
    pickedFrom = [];
    nextPhoto = jpegA;
    result = null;
    popped = false;
    idCounter = 0;
    uploadFails = false;
  });

  group('the form', () {
    testWidgets(
      'opens with the balance filled in as the bill and the amount collected, and says what is still due',
      (tester) async {
        await open(tester, host(manager: false));
        expect(find.text('VIP booth · Ada Lovelace'), findsOneWidget);
        expect(find.text('Still due on the booking: \$40.00'), findsOneWidget);
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
      },
    );

    testWidgets('a table that owes nothing starts with empty amounts', (
      tester,
    ) async {
      await open(tester, host(manager: false, balance: 0));
      expect(find.byKey(const Key('pay-still-due')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('pay-billed')))
            .controller!
            .text,
        '',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('pay-collected')))
            .controller!
            .text,
        '',
      );
    });

    testWidgets('money is typed with a decimal keyboard', (tester) async {
      await open(tester, host(manager: false));
      const decimal = TextInputType.numberWithOptions(decimal: true);
      for (final k in ['pay-billed', 'pay-collected']) {
        expect(
          tester.widget<TextField>(find.byKey(Key(k))).keyboardType,
          decimal,
          reason: k,
        );
      }
      await tapKey(tester, 'method-split');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('split-amount-0')))
            .keyboardType,
        decimal,
      );
      await tester.tap(find.byKey(const Key('pay-details')));
      await tester.pumpAndSettle();
      for (final k in ['pay-bottles', 'pay-discount', 'pay-tax', 'pay-tip']) {
        expect(
          tester.widget<TextField>(find.byKey(Key(k))).keyboardType,
          decimal,
          reason: k,
        );
      }
    });

    testWidgets('the chosen way of paying is the selected chip', (
      tester,
    ) async {
      await open(tester, host(manager: false));
      bool selected(String m) =>
          tester.widget<ChoiceChip>(find.byKey(Key('method-$m'))).selected;
      const all = ['cash', 'debit', 'credit', 'split'];
      expect([for (final m in all) selected(m)], [false, false, false, false]);
      await tapKey(tester, 'method-debit');
      expect([for (final m in all) selected(m)], [false, true, false, false]);
    });

    testWidgets(
      'only a split shows parts, and going back to a split does not add more',
      (tester) async {
        await open(tester, host(manager: false));
        await tapKey(tester, 'method-cash');
        expect(find.byKey(const Key('split-row-0')), findsNothing);
        await tapKey(tester, 'method-split');
        await tapKey(tester, 'method-cash');
        await tapKey(tester, 'method-split');
        expect(find.byKey(const Key('split-row-1')), findsOneWidget);
        expect(
          find.byKey(const Key('split-row-2')),
          findsNothing,
          reason: 'still two parts',
        );
      },
    );

    testWidgets(
      'a server can only take a photo with the camera and has no way to skip the receipt',
      (tester) async {
        await open(tester, host(manager: false));
        expect(find.byKey(const Key('receipt-take')), findsOneWidget);
        expect(find.byKey(const Key('receipt-gallery')), findsNothing);
        expect(find.byKey(const Key('receipt-none')), findsNothing);
      },
    );

    testWidgets(
      'a manager can also choose a photo, or say there is no receipt',
      (tester) async {
        await open(tester, host(manager: true));
        expect(find.byKey(const Key('receipt-gallery')), findsOneWidget);
        expect(find.byKey(const Key('receipt-none')), findsOneWidget);
      },
    );

    testWidgets('says that recording is not verifying', (tester) async {
      await open(tester, host(manager: false));
      expect(find.textContaining('does not verify it'), findsOneWidget);
    });

    testWidgets(
      'sending an empty form tells the person what is missing and sends nothing',
      (tester) async {
        await open(tester, host(manager: false, balance: 0));
        await tapKey(tester, 'pay-submit');
        expect(find.text('Enter the bill total.'), findsOneWidget);
        expect(find.text('Enter the amount collected.'), findsOneWidget);
        expect(find.byKey(const Key('pay-method-error')), findsOneWidget);
        expect(find.text('Choose how it was paid.'), findsOneWidget);
        expect(find.byKey(const Key('receipt-error')), findsOneWidget);
        expect(find.text('Take a photo of the receipt.'), findsOneWidget);
        expect(db.calls, isEmpty);
        expect(uploads, isEmpty);
      },
    );

    testWidgets(
      'nothing is said about a field until the person tries to send',
      (tester) async {
        await open(tester, host(manager: false, balance: 0));
        expect(find.text('Enter the bill total.'), findsNothing);
        await typeKey(tester, 'pay-billed', 'abc');
        expect(
          find.text('The bill total must be an amount like 120.50.'),
          findsNothing,
        );
        await tapKey(tester, 'pay-submit');
        expect(
          find.text('The bill total must be an amount like 120.50.'),
          findsOneWidget,
        );
      },
    );
  });

  group('a split', () {
    testWidgets(
      'shows two parts to fill in, adds more, and removes only beyond two',
      (tester) async {
        await open(tester, host(manager: false));
        expect(find.byKey(const Key('split-row-0')), findsNothing);
        await tapKey(tester, 'method-split');
        expect(find.byKey(const Key('split-row-0')), findsOneWidget);
        expect(find.byKey(const Key('split-row-1')), findsOneWidget);
        expect(
          find.byKey(const Key('split-remove-0')),
          findsNothing,
          reason: 'two parts is the least a split can be',
        );
        await tapKey(tester, 'split-add');
        expect(find.byKey(const Key('split-row-2')), findsOneWidget);
        expect(find.byKey(const Key('split-remove-2')), findsOneWidget);
        await tapKey(tester, 'split-remove-2');
        expect(find.byKey(const Key('split-row-2')), findsNothing);
      },
    );

    testWidgets('the parts must add up to what was collected', (tester) async {
      await open(tester, host(manager: false));
      await tapKey(tester, 'method-split');
      await tapKey(tester, 'receipt-take');
      await tapKey(tester, 'receipt-readable');
      await typeKey(tester, 'split-amount-0', '10');
      await typeKey(tester, 'split-amount-1', '25');
      await tapKey(tester, 'pay-submit');
      expect(
        find.text(
          'The parts of the split must add up to the amount collected.',
        ),
        findsOneWidget,
      );
      expect(db.calls, isEmpty);
      await typeKey(tester, 'split-amount-1', '30');
      await tapKey(tester, 'pay-submit');
      expect(sent()['p_split_breakdown'], [
        {'method': 'cash', 'cents': 1000},
        {'method': 'debit', 'cents': 3000},
      ]);
      expect(sent()['p_payment_method'], 'split');
    });

    testWidgets('a part can be paid another way', (tester) async {
      await open(tester, host(manager: false));
      await tapKey(tester, 'method-split');
      await tapKey(tester, 'receipt-take');
      await tapKey(tester, 'receipt-readable');
      await typeKey(tester, 'split-amount-0', '15');
      await typeKey(tester, 'split-amount-1', '25');
      await tester.tap(find.byKey(const Key('split-method-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Credit').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'pay-submit');
      expect(sent()['p_split_breakdown'], [
        {'method': 'cash', 'cents': 1500},
        {'method': 'credit', 'cents': 2500},
      ]);
    });
  });

  group('the receipt photo', () {
    testWidgets(
      'taking a photo shows it, and it must be confirmed readable before it counts',
      (tester) async {
        await open(tester, host(manager: false));
        await tapKey(tester, 'method-cash');
        await tapKey(tester, 'receipt-take');
        expect(pickedFrom, [true]);
        expect(find.byKey(const Key('receipt-preview')), findsOneWidget);
        expect(find.byKey(const Key('receipt-take')), findsNothing);
        await tapKey(tester, 'pay-submit');
        expect(
          find.text(
            'Check that the total and the date can be read on the photo.',
          ),
          findsOneWidget,
        );
        expect(db.calls, isEmpty);
        expect(
          uploads,
          isEmpty,
          reason: 'nothing is uploaded until the form is sent',
        );
      },
    );

    testWidgets(
      'taking it again drops the confirmation, so the new photo must be checked too',
      (tester) async {
        await open(tester, host(manager: false));
        await fillAsServer(tester);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('receipt-readable')),
              )
              .value,
          true,
        );
        nextPhoto = jpegB;
        await tapKey(tester, 'receipt-retake');
        expect(pickedFrom, [true, true]);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('receipt-readable')),
              )
              .value,
          false,
        );
      },
    );

    testWidgets('cancelling the camera changes nothing', (tester) async {
      nextPhoto = null;
      await open(tester, host(manager: false));
      await tapKey(tester, 'receipt-take');
      expect(find.byKey(const Key('receipt-preview')), findsNothing);
      expect(find.byKey(const Key('receipt-take')), findsOneWidget);
    });

    testWidgets('a file that is not a photo is refused with a sentence', (
      tester,
    ) async {
      nextPhoto = Uint8List.fromList([1, 2, 3]);
      await open(tester, host(manager: false));
      await tapKey(tester, 'receipt-take');
      expect(find.text('Use a JPEG, PNG or WebP image.'), findsOneWidget);
      expect(find.byKey(const Key('receipt-preview')), findsNothing);
    });

    testWidgets('a manager can choose one from the gallery', (tester) async {
      await open(tester, host(manager: true));
      await tapKey(tester, 'receipt-gallery');
      expect(pickedFrom, [false]);
      expect(find.byKey(const Key('receipt-preview')), findsOneWidget);
    });
  });

  group('sending it', () {
    testWidgets(
      'a server\'s payment uploads the photo under the booking, then records it with the photo\'s path and hash',
      (tester) async {
        await open(tester, host(manager: false));
        await fillAsServer(tester);
        await typeKey(tester, 'pay-pos', ' POS-77 ');
        await typeKey(tester, 'pay-payer', ' Ada L ');
        await tapKey(tester, 'pay-submit');
        expect(uploads, ['b1/photo1.jpg']);
        final p = sent();
        expect(p['p_booking'], 'b1');
        expect(p['p_billed_amount_cents'], 4000);
        expect(p['p_amount_paid_cents'], 4000);
        expect(p['p_payment_method'], 'cash');
        expect(p['p_receipt_photo_path'], 'b1/photo1.jpg');
        expect(p['p_receipt_photo_hash'], matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(p['p_pos_reference'], 'POS-77');
        expect(p['p_payer_name'], 'Ada L');
        expect(p['p_missing_receipt_reason'], isNull);
        expect(popped, true);
        expect(result!.duplicate, false);
        expect(result!.balanceDueCents, 0);
        expect(db.bookings['b1']!.paid, 10000);
      },
    );

    testWidgets('the optional bill details go along', (tester) async {
      await open(tester, host(manager: false));
      await fillAsServer(tester);
      await tester.tap(find.byKey(const Key('pay-details')));
      await tester.pumpAndSettle();
      await typeKey(tester, 'pay-bottles', '30');
      await typeKey(tester, 'pay-discount', '2.50');
      await typeKey(tester, 'pay-tax', '3.90');
      await typeKey(tester, 'pay-tip', '5');
      await tapKey(tester, 'pay-submit');
      final p = sent();
      expect(
        [
          p['p_bottle_subtotal_cents'],
          p['p_discount_cents'],
          p['p_tax_cents'],
          p['p_gratuity_cents'],
        ],
        [3000, 250, 390, 500],
      );
    });

    testWidgets(
      'a manager without a receipt must say why, and no photo is uploaded',
      (tester) async {
        db.role = 'manager';
        await open(tester, host(manager: true));
        await tapKey(tester, 'method-cash');
        await tapKey(tester, 'receipt-none');
        await tapKey(tester, 'pay-submit');
        expect(find.text('Say why there is no receipt.'), findsOneWidget);
        expect(db.calls, isEmpty);
        await typeKey(tester, 'receipt-reason', ' printer broke ');
        await tapKey(tester, 'pay-submit');
        expect(uploads, isEmpty);
        final p = sent();
        expect(p['p_receipt_photo_path'], isNull);
        expect(p['p_receipt_photo_hash'], isNull);
        expect(p['p_missing_receipt_reason'], 'printer broke');
        expect(popped, true);
      },
    );

    testWidgets(
      'switching "no receipt" on hides the photo and the form no longer needs one',
      (tester) async {
        await open(tester, host(manager: true));
        await tapKey(tester, 'receipt-take');
        expect(find.byKey(const Key('receipt-preview')), findsOneWidget);
        await tapKey(tester, 'receipt-none');
        expect(find.byKey(const Key('receipt-preview')), findsNothing);
        expect(find.byKey(const Key('receipt-reason')), findsOneWidget);
      },
    );

    testWidgets(
      'the database\'s own sentence is shown when it refuses, and the form stays as it was',
      (tester) async {
        db.addPayment('b1', 100, pos: 'POS-77', by: 'u-other');
        await open(tester, host(manager: false));
        await fillAsServer(tester);
        await typeKey(tester, 'pay-pos', 'POS-77');
        await tapKey(tester, 'pay-submit');
        expect(
          find.text(
            'This POS receipt number has already been recorded for another payment at this venue.',
          ),
          findsOneWidget,
        );
        expect(popped, false);
        expect(find.byKey(const Key('receipt-preview')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('pay-pos')))
              .controller!
              .text,
          'POS-77',
        );
      },
    );

    testWidgets('a photo that cannot be uploaded says so and records nothing', (
      tester,
    ) async {
      uploadFails = true;
      await open(tester, host(manager: false));
      await fillAsServer(tester);
      await tapKey(tester, 'pay-submit');
      expect(find.text(receiptUploadFailed), findsOneWidget);
      expect(db.calls, isEmpty);
      expect(popped, false);
    });

    testWidgets(
      'trying again after a lost answer sends the same photo, so the database sees a repeat, not a second payment',
      (tester) async {
        await open(tester, host(manager: false));
        await fillAsServer(tester);
        // The first attempt reached the database but the answer was lost on the way back: the payment is there, filed under the path the
        // photo will get again.
        await db.service.recordPayment(
          'b1',
          const PaymentInput(
            billed: '40',
            collected: '40',
            method: PayMethod.cash,
            hasReceiptPhoto: true,
            receiptReadable: true,
          ),
          manager: false,
          receiptPath: 'b1/photo1.jpg',
        );
        await tapKey(tester, 'pay-submit');
        expect(uploads, [
          'b1/photo1.jpg',
        ], reason: 'the photo was uploaded once');
        expect(db.payments, hasLength(1), reason: 'no second payment');
        expect(popped, true);
        expect(result!.duplicate, true);
      },
    );

    testWidgets('after a failed attempt the photo is not uploaded again', (
      tester,
    ) async {
      db.failOn['desk_record_payment'] = Exception('offline');
      await open(tester, host(manager: false));
      await fillAsServer(tester);
      await tapKey(tester, 'pay-submit');
      expect(
        find.text(
          'The payment could not be recorded. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      db.failOn.clear();
      await tapKey(tester, 'pay-submit');
      expect(uploads, ['b1/photo1.jpg']);
      expect(popped, true);
    });

    testWidgets('taking a new photo after a failure does upload the new one', (
      tester,
    ) async {
      db.failOn['desk_record_payment'] = Exception('offline');
      await open(tester, host(manager: false));
      await fillAsServer(tester);
      await tapKey(tester, 'pay-submit');
      db.failOn.clear();
      nextPhoto = jpegB;
      await tapKey(tester, 'receipt-retake');
      await tapKey(tester, 'receipt-readable');
      await tapKey(tester, 'pay-submit');
      expect(uploads, ['b1/photo1.jpg', 'b1/photo2.jpg']);
    });

    testWidgets(
      'the button waits while the payment is on its way, so a second tap cannot send it twice',
      (tester) async {
        final gate = Completer<void>();
        await open(tester, host(manager: false));
        await fillAsServer(tester);
        db.hold = gate.future;
        await tester.ensureVisible(find.byKey(const Key('pay-submit')));
        await tester.tap(find.byKey(const Key('pay-submit')));
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('pay-submit')))
              .onPressed,
          isNull,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('pay-submit')),
          warnIfMissed: false,
        );
        await tester.pump();
        db.hold = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(db.count('desk_record_payment'), 1);
        expect(db.payments, hasLength(1));
      },
    );

    testWidgets(
      'a table the person does not have is refused in the database\'s words for a lost permission',
      (tester) async {
        db.assignments.clear();
        await open(tester, host(manager: false));
        await fillAsServer(tester);
        await tapKey(tester, 'pay-submit');
        expect(find.text("You don't have access to do that."), findsOneWidget);
      },
    );
  });
}
