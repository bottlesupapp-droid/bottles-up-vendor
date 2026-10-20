import 'package:bottles_up_vendor/features/server_desk/logic/server_desk_rules.dart'
    show AssignedTable;
import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:flutter_test/flutter_test.dart';

OrderLine line({
  ServiceState state = ServiceState.awaitingPrep,
  LinePayment payment = LinePayment.paid,
  int? balance,
  bool cancelled = false,
}) => OrderLine(
  lineId: 'l1',
  bookingId: 'b1',
  bottleName: 'Patron',
  size: '750ml',
  quantity: 2,
  unitPriceCents: null,
  lineTotalCents: 10000,
  isAddon: false,
  payment: payment,
  state: state,
  orderedAt: DateTime.utc(2026, 10, 9, 21),
  cancelledAt: cancelled ? DateTime.utc(2026, 10, 9, 21, 30) : null,
  balanceDueCents: balance,
);

Map<String, dynamic> orderRow({Map<String, dynamic> over = const {}}) => {
  'line_id': 'l1',
  'booking_id': 'b1',
  'confirmation_code': 'AB12CD',
  'customer_name': 'Ada Lovelace',
  'table_name': 'VIP booth',
  'guest_count': 4,
  'bottle_name': 'Patron',
  'size': '750ml',
  'quantity': 2,
  'line_total_cents': 10000,
  'is_addon': false,
  'payment_status': 'due_at_venue',
  'service_status': 'preparing',
  'ordered_at': '2026-10-09T21:00:00+00:00',
  'checked_in_at': '2026-10-09T21:10:00+00:00',
  'balance_due_cents': 4000,
  'server_membership_id': 'm1',
  'server_is_me': true,
  ...over,
};

AssignedTable table({bool arrived = true}) => AssignedTable(
  bookingId: 'b1',
  venueId: 'v1',
  venueName: 'Club A',
  nightDate: '2026-10-09',
  startTime: '21:00:00',
  slotLabel: null,
  tableName: 'VIP booth',
  guestCount: 4,
  customerName: 'Ada',
  confirmationCode: null,
  checkedInAt: arrived ? DateTime.utc(2026, 10, 9, 21, 10) : null,
);

TableStatus status({
  int balance = 0,
  int open = 0,
  int unchecked = 0,
  bool closed = false,
}) => TableStatus(
  bookingId: 'b1',
  balanceDueCents: balance,
  itemsOpen: open,
  itemsDelivered: 0,
  paymentsRecorded: 0,
  paymentsUnchecked: unchecked,
  closedOut: closed,
  closeoutRequested: false,
);

void main() {
  group('the service states', () {
    test(
      'six of them, as the database stores them, with the words the app uses (the client\'s five, with "ready" as Ready to collect)',
      () {
        expect(
          [for (final s in ServiceState.values) s.value],
          ['awaiting_prep', 'accepted', 'preparing', 'ready', 'picked_up', 'served'],
        );
        expect(
          [for (final s in ServiceState.values) s.label],
          ['Submitted', 'Accepted', 'Preparing', 'Ready to collect', 'On the way', 'Delivered'],
        );
      },
    );

    test('what the button into each state says', () {
      expect(
        [for (final s in ServiceState.values) s.moveLabel],
        [
          'Back to Submitted',
          'Accept',
          'Start preparing',
          'Mark ready',
          'On the way',
          'Delivered',
        ],
      );
    });

    test('each has a next step, until delivered', () {
      expect(ServiceState.awaitingPrep.next, ServiceState.accepted);
      expect(ServiceState.accepted.next, ServiceState.preparing);
      expect(ServiceState.preparing.next, ServiceState.ready);
      expect(ServiceState.ready.next, ServiceState.pickedUp);
      expect(ServiceState.pickedUp.next, ServiceState.served);
      expect(ServiceState.served.next, isNull);
    });

    test('reading one from the database; anything else is null, never New', () {
      expect(ServiceState.fromDb('picked_up'), ServiceState.pickedUp);
      expect(ServiceState.fromDb('cooking'), isNull);
      expect(ServiceState.fromDb(null), isNull);
      expect(ServiceState.fromDb(3), isNull);
    });

    test('how a line is paid', () {
      expect(
        [for (final p in LinePayment.values) p.value],
        ['paid', 'due_at_venue', 'pending_payment'],
      );
      expect(
        [for (final p in LinePayment.values) p.label],
        ['Paid', 'Pay at venue', 'Payment pending'],
      );
      expect(LinePayment.fromDb('due_at_venue'), LinePayment.dueAtVenue);
      expect(LinePayment.fromDb('free'), isNull);
    });
  });

  group('reading a night\'s order line', () {
    test('a full row', () {
      final l = parseOrderLine(orderRow())!;
      expect(l.lineId, 'l1');
      expect(l.bookingId, 'b1');
      expect(l.confirmationCode, 'AB12CD');
      expect(l.customerName, 'Ada Lovelace');
      expect(l.tableName, 'VIP booth');
      expect(l.guestCount, 4);
      expect(l.bottleName, 'Patron');
      expect(l.size, '750ml');
      expect(l.quantity, 2);
      expect(l.lineTotalCents, 10000);
      expect(l.payment, LinePayment.dueAtVenue);
      expect(l.state, ServiceState.preparing);
      expect(l.orderedAt, DateTime.utc(2026, 10, 9, 21));
      expect(l.checkedInAt, DateTime.utc(2026, 10, 9, 21, 10));
      expect(l.balanceDueCents, 4000);
      expect(l.serverMembershipId, 'm1');
      expect(l.serverIsMe, true);
      expect(l.isAddon, false);
      expect(l.cancelled, false);
      expect(l.delivered, false);
      expect(l.title, '2 × Patron 750ml');
    });

    test('a bottle with no size reads without one', () {
      expect(
        parseOrderLine(orderRow(over: {'size': null}))!.title,
        '2 × Patron',
      );
      expect(parseOrderLine(orderRow(over: {'size': '  '}))!.size, isNull);
    });

    test('a missing name still shows something, and blanks become none', () {
      final l =
          parseOrderLine(
            orderRow(
              over: {
                'bottle_name': null,
                'confirmation_code': '',
                'customer_name': ' ',
              },
            ),
          )!;
      expect(l.bottleName, 'Bottle');
      expect(l.confirmationCode, isNull);
      expect(l.customerName, isNull);
    });

    test('a table nobody has has no server; the add-on flag is read', () {
      final l =
          parseOrderLine(
            orderRow(
              over: {
                'server_membership_id': null,
                'server_is_me': false,
                'is_addon': true,
              },
            ),
          )!;
      expect(l.serverMembershipId, isNull);
      expect(l.serverIsMe, false);
      expect(l.isAddon, true);
    });

    test('a row that cannot be trusted is dropped, not guessed at', () {
      expect(parseOrderLine(orderRow(over: {'line_id': null})), isNull);
      expect(parseOrderLine(orderRow(over: {'line_id': ''})), isNull);
      expect(
        parseOrderLine(orderRow(over: {'service_status': 'cooking'})),
        isNull,
        reason: 'an unknown state is not New',
      );
      expect(parseOrderLine(orderRow(over: {'service_status': null})), isNull);
      expect(
        parseOrderLine(orderRow(over: {'payment_status': 'free'})),
        isNull,
      );
      expect(parseOrderLine(orderRow(over: {'ordered_at': null})), isNull);
      expect(
        parseOrderLine(orderRow(over: {'ordered_at': 'yesterday'})),
        isNull,
      );
    });

    test(
      'a whole-number total sent as a decimal is read; a fraction is not trusted',
      () {
        expect(
          parseOrderLine(
            orderRow(over: {'line_total_cents': 10000.0}),
          )!.lineTotalCents,
          10000,
        );
        expect(
          parseOrderLine(
            orderRow(over: {'line_total_cents': 100.5}),
          )!.lineTotalCents,
          0,
        );
        expect(
          parseOrderLine(
            orderRow(over: {'balance_due_cents': null}),
          )!.balanceDueCents,
          isNull,
        );
        expect(
          parseOrderLine(
            orderRow(over: {'balance_due_cents': 12.5}),
          )!.balanceDueCents,
          isNull,
        );
      },
    );

    test('a row with no booking is kept but cannot open a table', () {
      expect(
        parseOrderLine(orderRow(over: {'booking_id': null}))!.bookingId,
        isNull,
      );
    });
  });

  group('reading one table\'s line', () {
    Map<String, dynamic> row([Map<String, dynamic> over = const {}]) => {
      'line_id': 'l9',
      'bottle_name': 'Moet',
      'size': null,
      'quantity': 1,
      'unit_price_cents': 8000,
      'line_total_cents': 8000,
      'is_addon': true,
      'payment_status': 'paid',
      'service_status': 'served',
      'ordered_at': '2026-10-09T20:00:00Z',
      'cancelled_at': null,
      'cancellation_reason': null,
      ...over,
    };

    test(
      'carries the unit price and the table\'s balance it was read with',
      () {
        final l = parseTableLine(row(), bookingId: 'b1', balanceDueCents: 500)!;
        expect(l.bookingId, 'b1');
        expect(l.unitPriceCents, 8000);
        expect(l.balanceDueCents, 500);
        expect(l.isAddon, true);
        expect(l.delivered, true);
        expect(l.cancelled, false);
        expect(
          l.serverIsMe,
          false,
          reason: "a table's own sheet does not say whose table it is",
        );
      },
    );

    test('a cancelled line says why', () {
      final l =
          parseTableLine(
            row({
              'cancelled_at': '2026-10-09T22:00:00Z',
              'cancellation_reason': 'guest changed their mind',
            }),
            bookingId: 'b1',
          )!;
      expect(l.cancelled, true);
      expect(l.cancellationReason, 'guest changed their mind');
    });

    test('a row that cannot be trusted is dropped', () {
      expect(parseTableLine(row({'line_id': null}), bookingId: 'b1'), isNull);
      expect(
        parseTableLine(row({'service_status': 'x'}), bookingId: 'b1'),
        isNull,
      );
      expect(
        parseTableLine(row({'payment_status': 'x'}), bookingId: 'b1'),
        isNull,
      );
      expect(
        parseTableLine(row({'ordered_at': null}), bookingId: 'b1'),
        isNull,
      );
    });
  });

  group('the filters', () {
    test(
      'the six of them, in the brief\'s order, without a guessed "needs attention"',
      () {
        expect(
          [for (final f in OrderFilter.values) f.label],
          [
            'All',
            'New',
            'Needs payment',
            'Preparing',
            'On the way',
            'Delivered',
          ],
        );
      },
    );

    test('each matches what its name says', () {
      expect(
        orderMatches(OrderFilter.all, line(state: ServiceState.served)),
        true,
      );
      expect(orderMatches(OrderFilter.fresh, line()), true);
      expect(
        orderMatches(OrderFilter.fresh, line(state: ServiceState.preparing)),
        false,
      );
      expect(
        orderMatches(
          OrderFilter.preparing,
          line(state: ServiceState.preparing),
        ),
        true,
      );
      expect(
        orderMatches(OrderFilter.preparing, line(state: ServiceState.ready)),
        true,
        reason: 'ready is still being prepared',
      );
      expect(
        orderMatches(OrderFilter.preparing, line(state: ServiceState.pickedUp)),
        false,
      );
      expect(
        orderMatches(OrderFilter.onTheWay, line(state: ServiceState.pickedUp)),
        true,
      );
      expect(
        orderMatches(OrderFilter.onTheWay, line(state: ServiceState.ready)),
        false,
      );
      expect(
        orderMatches(OrderFilter.delivered, line(state: ServiceState.served)),
        true,
      );
      expect(
        orderMatches(OrderFilter.delivered, line(state: ServiceState.pickedUp)),
        false,
      );
    });

    test('needs payment: to be paid at the venue AND the table still owes', () {
      expect(
        orderMatches(
          OrderFilter.needsPayment,
          line(payment: LinePayment.dueAtVenue, balance: 100),
        ),
        true,
      );
      expect(
        orderMatches(
          OrderFilter.needsPayment,
          line(payment: LinePayment.dueAtVenue, balance: 0),
        ),
        false,
      );
      expect(
        orderMatches(
          OrderFilter.needsPayment,
          line(payment: LinePayment.dueAtVenue),
        ),
        false,
        reason: 'an unknown balance is not owing',
      );
      expect(
        orderMatches(
          OrderFilter.needsPayment,
          line(payment: LinePayment.paid, balance: 100),
        ),
        false,
        reason: 'a prepaid item needs no payment',
      );
    });

    test('the counts', () {
      final lines = [
        line(),
        line(state: ServiceState.preparing),
        line(state: ServiceState.ready),
        line(state: ServiceState.pickedUp),
        line(state: ServiceState.served),
        line(payment: LinePayment.dueAtVenue, balance: 500),
      ];
      final c = filterCounts(lines);
      expect(c[OrderFilter.all], 6);
      expect(c[OrderFilter.fresh], 2);
      expect(c[OrderFilter.needsPayment], 1);
      expect(c[OrderFilter.preparing], 2);
      expect(c[OrderFilter.onTheWay], 1);
      expect(c[OrderFilter.delivered], 1);
      expect(filterCounts(const []).values, everyElement(0));
    });
  });

  group('which moves to offer', () {
    test(
      'an item to be paid at the venue cannot be delivered while the table owes',
      () {
        expect(
          deliveryBlock(line(payment: LinePayment.dueAtVenue, balance: 4000)),
          'The table still owes \$40.00. Take payment first.',
        );
        expect(
          deliveryBlock(line(payment: LinePayment.dueAtVenue, balance: 0)),
          isNull,
        );
        expect(deliveryBlock(line(payment: LinePayment.dueAtVenue)), isNull);
        expect(
          deliveryBlock(line(payment: LinePayment.paid, balance: 4000)),
          isNull,
          reason: 'prepaid items are never held back',
        );
      },
    );

    test('any state except the current one can be chosen, and Accept only for an order that is still new', () {
      expect(moveTargets(line(state: ServiceState.preparing), manager: false), [
        ServiceState.awaitingPrep,
        ServiceState.ready,
        ServiceState.pickedUp,
        ServiceState.served,
      ], reason: 'Accepted is not offered once the order has moved on: the database refuses it, so a stale tap cannot send it backwards');
      expect(moveTargets(line(), manager: true), [
        ServiceState.accepted,
        ServiceState.preparing,
        ServiceState.ready,
        ServiceState.pickedUp,
        ServiceState.served,
      ]);
      expect(moveTargets(line(state: ServiceState.accepted), manager: true), [
        ServiceState.awaitingPrep,
        ServiceState.preparing,
        ServiceState.ready,
        ServiceState.pickedUp,
        ServiceState.served,
      ]);
    });

    test('a server cannot take a delivered item back; a manager can', () {
      expect(
        moveTargets(line(state: ServiceState.served), manager: false),
        isEmpty,
      );
      expect(
        moveTargets(line(state: ServiceState.served), manager: true),
        hasLength(4),
      );
    });

    test('a cancelled line cannot be moved by anyone', () {
      expect(moveTargets(line(cancelled: true), manager: true), isEmpty);
      expect(primaryMove(line(cancelled: true), manager: true), isNull);
    });

    test('the first button is the next step', () {
      expect(primaryMove(line(), manager: false), ServiceState.accepted);
      expect(
        primaryMove(line(state: ServiceState.accepted), manager: false),
        ServiceState.preparing,
      );
      expect(
        primaryMove(line(state: ServiceState.preparing), manager: false),
        ServiceState.ready,
      );
      expect(
        primaryMove(line(state: ServiceState.ready), manager: false),
        ServiceState.pickedUp,
      );
      expect(
        primaryMove(line(state: ServiceState.pickedUp), manager: false),
        ServiceState.served,
      );
      expect(
        primaryMove(line(state: ServiceState.served), manager: true),
        isNull,
      );
      expect(
        primaryMove(line(state: ServiceState.served), manager: false),
        isNull,
      );
    });

    test('what is sent', () {
      expect(moveParams('l1', ServiceState.pickedUp), {
        'p_line': 'l1',
        'p_status': 'picked_up',
      });
    });
  });

  group('how long something has waited', () {
    final t = DateTime.utc(2026, 10, 9, 21);
    test('in the words a server uses', () {
      expect(waitedLabel(t, t), 'just now');
      expect(waitedLabel(t, t.add(const Duration(seconds: 59))), 'just now');
      expect(waitedLabel(t, t.add(const Duration(minutes: 1))), '1 min');
      expect(waitedLabel(t, t.add(const Duration(minutes: 59))), '59 min');
      expect(waitedLabel(t, t.add(const Duration(minutes: 60))), '1 h');
      expect(waitedLabel(t, t.add(const Duration(minutes: 80))), '1 h 20 min');
      expect(
        waitedLabel(t, t.add(const Duration(hours: 23, minutes: 59))),
        '23 h 59 min',
      );
      expect(waitedLabel(t, t.add(const Duration(hours: 24))), '1 day');
      expect(waitedLabel(t, t.add(const Duration(days: 3))), '3 days');
    });
  });

  group('a table\'s money', () {
    Map<String, dynamic> pay([Map<String, dynamic> over = const {}]) => {
      'id': 'p1',
      'billed_amount_cents': 3500,
      'amount_paid_cents': 3000,
      'payment_method': 'debit',
      'pos_reference': 'POS-1',
      'receipt_photo_path': 'b1/r.jpg',
      'missing_receipt_reason': null,
      'payer_name': 'Ada L',
      'recorded_at': '2026-10-09T21:30:00Z',
      'recorded_by_me': true,
      'gratuity_cents': 500,
      'manager_verified_note': null,
      'verification': 'pending',
      ...over,
    };

    Map<String, dynamic> money([
      Map<String, dynamic> over = const {},
      List<dynamic>? payments,
    ]) => {
      'level': 'manager',
      'confirmation_code': 'AB12CD',
      'customer_name': 'Ada Lovelace',
      'table_name': 'VIP booth',
      'guest_count': 4,
      'currency': 'cad',
      'status': 'paid',
      'amount_total_cents': 10000,
      'amount_paid_cents': 6000,
      'balance_due_cents': 4000,
      'closed_out': false,
      'closeout_requested': false,
      'payments': payments ?? [pay()],
      ...over,
    };

    test('reads the table and its payments', () {
      final m = parseBookingMoney(money())!;
      expect(m.level, 'manager');
      expect(m.isManager, true);
      expect(m.confirmationCode, 'AB12CD');
      expect(m.customerName, 'Ada Lovelace');
      expect(m.tableName, 'VIP booth');
      expect(m.guestCount, 4);
      expect(m.currency, 'cad');
      expect(m.totalCents, 10000);
      expect(m.paidCents, 6000);
      expect(m.balanceDueCents, 4000);
      expect(m.closedOut, false);
      expect(m.closeoutRequested, false);
      final p = m.payments.single;
      expect(p.id, 'p1');
      expect(p.billedCents, 3500);
      expect(p.paidCents, 3000);
      expect(p.method, 'debit');
      expect(p.methodLabel, 'Debit');
      expect(p.posReference, 'POS-1');
      expect(p.receiptPath, 'b1/r.jpg');
      expect(p.payerName, 'Ada L');
      expect(p.recordedAt, DateTime.utc(2026, 10, 9, 21, 30));
      expect(p.recordedByMe, true);
      expect(p.tipCents, 500);
      expect(p.verification, Verification.pending);
    });

    test('an answer that is not an object with a level cannot be read', () {
      expect(parseBookingMoney(null), isNull);
      expect(parseBookingMoney([]), isNull);
      expect(parseBookingMoney('x'), isNull);
      expect(parseBookingMoney(money({'level': null})), isNull);
      expect(parseBookingMoney(money({'level': ''})), isNull);
    });

    test('a payment that cannot be trusted is dropped; the rest stay', () {
      final m =
          parseBookingMoney(
            money({}, [
              pay(),
              pay({'id': null}),
              pay({'id': 'p2', 'recorded_at': null}),
              pay({'id': 'p3', 'verification': 'mystery'}),
              pay({'id': 'p4'}),
              'junk',
            ]),
          )!;
      expect([for (final p in m.payments) p.id], ['p1', 'p4']);
    });

    test('no payments is an empty list; a missing list too', () {
      expect(parseBookingMoney(money({}, []))!.payments, isEmpty);
      expect(parseBookingMoney(money({'payments': null}))!.payments, isEmpty);
    });

    test(
      'a verified payment carries its note; a method it does not know shows as stored',
      () {
        final p =
            parseBookingMoney(
              money({}, [
                pay({
                  'verification': 'verified',
                  'manager_verified_note': 'matches the till',
                  'payment_method': 'cheque',
                }),
              ]),
            )!.payments.single;
        expect(p.verification, Verification.verified);
        expect(p.verifiedNote, 'matches the till');
        expect(p.methodLabel, 'cheque');
      },
    );

    test(
      'who can record a payment: the manager or the table\'s server, on a confirmed table that is not closed out',
      () {
        expect(parseBookingMoney(money())!.canRecord, true);
        expect(parseBookingMoney(money({'level': 'server'}))!.canRecord, true);
        expect(
          parseBookingMoney(money({'level': 'verifier'}))!.canRecord,
          false,
        );
        expect(
          parseBookingMoney(money({'closed_out': true}))!.canRecord,
          false,
        );
        expect(
          parseBookingMoney(money({'status': 'pending'}))!.canRecord,
          false,
        );
        expect(
          parseBookingMoney(money({'status': 'cancelled'}))!.canRecord,
          false,
        );
      },
    );

    test('the four verification states and their words', () {
      expect(
        [for (final v in Verification.values) v.value],
        ['pending', 'verified', 'customer_confirmed', 'disputed'],
      );
      expect(Verification.pending.label, 'Recorded - verification pending');
      expect(Verification.verified.label, 'Verified');
      expect(Verification.customerConfirmed.label, 'Confirmed by the guest');
      expect(Verification.disputed.label, 'Disputed by the guest');
      expect(Verification.fromDb('verified'), Verification.verified);
      expect(Verification.fromDb('x'), isNull);
    });
  });

  group('where a table stands, and what to do next', () {
    TableStatus? parse(Map<String, dynamic> r) => parseTableStatus(r);

    test('reads a status row', () {
      final s =
          parse({
            'booking_id': 'b1',
            'balance_due_cents': 400,
            'items_open': 3,
            'items_delivered': 1,
            'payments_recorded': 2,
            'payments_unchecked': 1,
            'closed_out': true,
            'closeout_requested': true,
          })!;
      expect(
        [
          s.bookingId,
          s.balanceDueCents,
          s.itemsOpen,
          s.itemsDelivered,
          s.paymentsRecorded,
          s.paymentsUnchecked,
          s.closedOut,
          s.closeoutRequested,
        ],
        ['b1', 400, 3, 1, 2, 1, true, true],
      );
      expect(parse({'balance_due_cents': 1}), isNull);
      expect(parse({'booking_id': ''}), isNull);
    });

    test('the server\'s next action, most urgent first', () {
      expect(
        nextAction(table(), null),
        isNull,
        reason: 'no line is better than a wrong one',
      );
      expect(
        nextAction(table(), status(closed: true, open: 2, balance: 900)),
        'Closed out',
      );
      expect(
        nextAction(table(arrived: false), status(open: 2)),
        'Waiting for the guests',
      );
      expect(
        nextAction(table(), status(open: 1, balance: 900)),
        '1 item to deliver',
      );
      expect(nextAction(table(), status(open: 3)), '3 items to deliver');
      expect(
        nextAction(table(), status(balance: 4000)),
        'Take payment: \$40.00',
      );
      expect(
        nextAction(table(), status(unchecked: 2)),
        'Payment recorded - waiting to be checked',
      );
      expect(nextAction(table(), status()), 'Nothing to do');
    });
  });

  group('the payment form', () {
    PaymentInput ok({
      String billed = '120.50',
      String collected = '120.50',
      PayMethod? method = PayMethod.cash,
      List<SplitPart> split = const [],
      bool photo = true,
      bool readable = true,
      bool noReceipt = false,
      String reason = '',
    }) => PaymentInput(
      billed: billed,
      collected: collected,
      method: method,
      split: split,
      hasReceiptPhoto: photo,
      receiptReadable: readable,
      noReceipt: noReceipt,
      noReceiptReason: reason,
    );

    test('a complete form has no problems', () {
      expect(paymentProblems(ok(), manager: false), isEmpty);
      expect(paymentProblems(ok(), manager: true), isEmpty);
    });

    test('the amounts', () {
      expect(
        paymentProblems(ok(billed: ''), manager: false)['billed'],
        'Enter the bill total.',
      );
      expect(
        paymentProblems(ok(collected: ''), manager: false)['collected'],
        'Enter the amount collected.',
      );
      expect(
        paymentProblems(ok(billed: 'abc'), manager: false)['billed'],
        'The bill total must be an amount like 120.50.',
      );
      expect(
        paymentProblems(ok(billed: '-5'), manager: false)['billed'],
        'The bill total must be an amount like 120.50.',
      );
      expect(
        paymentProblems(ok(billed: '1.234'), manager: false)['billed'],
        'The bill total must be an amount like 120.50.',
      );
      expect(
        paymentProblems(ok(collected: '0'), manager: false)['collected'],
        'Enter the amount collected.',
      );
      expect(
        paymentProblems(ok(collected: '0.00'), manager: false)['collected'],
        'Enter the amount collected.',
      );
      expect(
        paymentProblems(
          ok(collected: '100000.01'),
          manager: false,
        )['collected'],
        'The amount collected is too large.',
      );
      expect(
        paymentProblems(
          ok(collected: '100000'),
          manager: false,
        ).containsKey('collected'),
        false,
        reason: 'exactly \$100,000 is allowed',
      );
      expect(
        paymentProblems(ok(billed: '\$1,250.50'), manager: false),
        isEmpty,
      );
    });

    test('the optional amounts are checked only when filled in', () {
      PaymentInput with_({
        String bottles = '',
        String discount = '',
        String tax = '',
        String tip = '',
      }) => PaymentInput(
        billed: '10',
        collected: '10',
        method: PayMethod.cash,
        hasReceiptPhoto: true,
        receiptReadable: true,
        bottles: bottles,
        discount: discount,
        tax: tax,
        tip: tip,
      );
      expect(paymentProblems(with_(), manager: false), isEmpty);
      expect(
        paymentProblems(with_(bottles: 'x'), manager: false)['bottles'],
        'The bottle subtotal must be an amount like 120.50.',
      );
      expect(
        paymentProblems(with_(discount: 'x'), manager: false)['discount'],
        'The discount must be an amount like 120.50.',
      );
      expect(
        paymentProblems(with_(tax: 'x'), manager: false)['tax'],
        'The tax must be an amount like 120.50.',
      );
      expect(
        paymentProblems(with_(tip: 'x'), manager: false)['tip'],
        'The tip must be an amount like 120.50.',
      );
      expect(
        paymentProblems(with_(tip: '100001'), manager: false)['tip'],
        'The tip is too large.',
      );
      expect(
        paymentProblems(
          with_(tip: '5', tax: '1.50', discount: '2', bottles: '8'),
          manager: false,
        ),
        isEmpty,
      );
    });

    test('how it was paid', () {
      expect(
        paymentProblems(ok(method: null), manager: false)['method'],
        'Choose how it was paid.',
      );
    });

    test('a split must have two parts that add up to what was collected', () {
      const cash50 = SplitPart(PayMethod.cash, 5000);
      const debit70 = SplitPart(PayMethod.debit, 7050);
      expect(
        paymentProblems(ok(method: PayMethod.split), manager: false)['split'],
        'Add the parts of the split.',
      );
      expect(
        paymentProblems(
          ok(method: PayMethod.split, split: [cash50]),
          manager: false,
        )['split'],
        'Add the parts of the split.',
      );
      expect(
        paymentProblems(
          ok(
            method: PayMethod.split,
            split: [cash50, const SplitPart(PayMethod.debit, 0)],
          ),
          manager: false,
        )['split'],
        'Every part of a split needs an amount.',
      );
      expect(
        paymentProblems(
          ok(
            method: PayMethod.split,
            split: [cash50, const SplitPart(PayMethod.debit, 7000)],
          ),
          manager: false,
        )['split'],
        'The parts of the split must add up to the amount collected.',
      );
      expect(
        paymentProblems(
          ok(method: PayMethod.split, split: [cash50, debit70]),
          manager: false,
        ),
        isEmpty,
      );
    });

    test('a split\'s parts are not looked at for any other method', () {
      expect(
        paymentProblems(
          ok(
            method: PayMethod.cash,
            split: [const SplitPart(PayMethod.cash, 1)],
          ),
          manager: false,
        ),
        isEmpty,
      );
    });

    test('the receipt number and the payer\'s name have limits', () {
      expect(
        paymentProblems(
          PaymentInput(
            billed: '1',
            collected: '1',
            method: PayMethod.cash,
            hasReceiptPhoto: true,
            receiptReadable: true,
            posReference: 'x' * 80,
          ),
          manager: false,
        ),
        isEmpty,
      );
      expect(
        paymentProblems(
          PaymentInput(
            billed: '1',
            collected: '1',
            method: PayMethod.cash,
            hasReceiptPhoto: true,
            receiptReadable: true,
            posReference: 'x' * 81,
          ),
          manager: false,
        )['pos'],
        'The receipt number is too long.',
      );
      expect(
        paymentProblems(
          PaymentInput(
            billed: '1',
            collected: '1',
            method: PayMethod.cash,
            hasReceiptPhoto: true,
            receiptReadable: true,
            payerName: 'n' * 120,
          ),
          manager: false,
        ),
        isEmpty,
      );
      expect(
        paymentProblems(
          PaymentInput(
            billed: '1',
            collected: '1',
            method: PayMethod.cash,
            hasReceiptPhoto: true,
            receiptReadable: true,
            payerName: 'n' * 121,
          ),
          manager: false,
        )['payer'],
        "The payer's name is too long.",
      );
    });

    test('a server must attach a receipt photo and say it can be read', () {
      expect(
        paymentProblems(ok(photo: false), manager: false)['receipt'],
        'Take a photo of the receipt.',
      );
      expect(
        paymentProblems(ok(readable: false), manager: false)['receipt'],
        'Check that the total and the date can be read on the photo.',
      );
      expect(
        paymentProblems(
          ok(photo: false, noReceipt: true, reason: 'printer broken'),
          manager: false,
        )['receipt'],
        'A receipt photo is required.',
        reason: 'only a manager may record without one',
      );
    });

    test('a manager may instead say why there is no receipt', () {
      expect(
        paymentProblems(
          ok(photo: false, noReceipt: true, reason: 'printer broken'),
          manager: true,
        ),
        isEmpty,
      );
      expect(
        paymentProblems(
          ok(photo: false, noReceipt: true),
          manager: true,
        )['receipt'],
        'Say why there is no receipt.',
      );
      expect(
        paymentProblems(
          ok(photo: false, noReceipt: true, reason: '   '),
          manager: true,
        )['receipt'],
        'Say why there is no receipt.',
      );
      expect(
        paymentProblems(
          ok(photo: false, noReceipt: true, reason: 'r' * 300),
          manager: true,
        ),
        isEmpty,
      );
      expect(
        paymentProblems(
          ok(photo: false, noReceipt: true, reason: 'r' * 301),
          manager: true,
        )['receipt'],
        'Keep the reason to 300 characters or fewer.',
      );
    });

    test(
      'a photo that has not been confirmed readable is not enough, by default',
      () {
        expect(
          paymentProblems(
            const PaymentInput(
              billed: '1',
              collected: '1',
              method: PayMethod.cash,
              hasReceiptPhoto: true,
            ),
            manager: false,
          )['receipt'],
          'Check that the total and the date can be read on the photo.',
        );
      },
    );

    test('every problem is reported at once, by field', () {
      final p = paymentProblems(const PaymentInput(), manager: false);
      expect(p.keys.toSet(), {'billed', 'collected', 'method', 'receipt'});
    });

    test('the limits match the database', () {
      expect(maxPaymentCents, 10000000);
      expect(maxReceiptNumberLength, 80);
      expect(maxPayerNameLength, 120);
      expect(maxReasonLength, 300);
      expect(maxSplitBreakdownLength, 2000);
    });
  });

  group('what is sent to record a payment', () {
    test('a cash payment with a photo', () {
      final params = recordPaymentParams(
        'b1',
        const PaymentInput(
          billed: '120.50',
          collected: '100',
          method: PayMethod.cash,
          posReference: ' POS-9 ',
          payerName: ' Ada ',
          bottles: '80',
          discount: '5',
          tax: '10.40',
          tip: '15',
          hasReceiptPhoto: true,
          receiptReadable: true,
          noReceiptReason: 'ignored',
        ),
        receiptPath: 'b1/r.jpg',
        receiptHash: 'a' * 64,
        deviceId: 'dev-1',
      );
      expect(params, {
        'p_booking': 'b1',
        'p_billed_amount_cents': 12050,
        'p_amount_paid_cents': 10000,
        'p_payment_method': 'cash',
        'p_split_breakdown': null,
        'p_pos_reference': 'POS-9',
        'p_receipt_photo_path': 'b1/r.jpg',
        'p_payer_name': 'Ada',
        'p_payer_email': null,
        'p_bottle_subtotal_cents': 8000,
        'p_discount_cents': 500,
        'p_tax_cents': 1040,
        'p_gratuity_cents': 1500,
        'p_receipt_photo_hash': 'a' * 64,
        'p_device_id': 'dev-1',
        'p_missing_receipt_reason': null,
      });
    });

    test('blank optional fields are sent as none and amounts as zero', () {
      final params = recordPaymentParams(
        'b1',
        const PaymentInput(
          billed: '10',
          collected: '10',
          method: PayMethod.debit,
        ),
        receiptPath: 'b1/r.jpg',
      );
      expect(params['p_pos_reference'], isNull);
      expect(params['p_payer_name'], isNull);
      expect(
        [
          params['p_bottle_subtotal_cents'],
          params['p_discount_cents'],
          params['p_tax_cents'],
          params['p_gratuity_cents'],
        ],
        [0, 0, 0, 0],
      );
      expect(params['p_receipt_photo_hash'], isNull);
      expect(params['p_device_id'], isNull);
    });

    test('a split is sent as its parts, and only for a split', () {
      const parts = [
        SplitPart(PayMethod.cash, 5000),
        SplitPart(PayMethod.credit, 7050),
      ];
      final split = recordPaymentParams(
        'b1',
        const PaymentInput(
          billed: '120.50',
          collected: '120.50',
          method: PayMethod.split,
          split: parts,
        ),
        receiptPath: 'b1/r.jpg',
      );
      expect(split['p_split_breakdown'], [
        {'method': 'cash', 'cents': 5000},
        {'method': 'credit', 'cents': 7050},
      ]);
      final cash = recordPaymentParams(
        'b1',
        const PaymentInput(
          billed: '120.50',
          collected: '120.50',
          method: PayMethod.cash,
          split: parts,
        ),
        receiptPath: 'b1/r.jpg',
      );
      expect(cash['p_split_breakdown'], isNull);
    });

    test(
      'with no photo, the manager\'s reason goes along; with one, it does not',
      () {
        const form = PaymentInput(
          billed: '10',
          collected: '10',
          method: PayMethod.cash,
          noReceipt: true,
          noReceiptReason: '  printer broken  ',
        );
        expect(
          recordPaymentParams('b1', form)['p_missing_receipt_reason'],
          'printer broken',
        );
        expect(
          recordPaymentParams(
            'b1',
            form,
            receiptPath: 'b1/r.jpg',
          )['p_missing_receipt_reason'],
          isNull,
        );
        expect(
          recordPaymentParams(
            'b1',
            const PaymentInput(
              billed: '10',
              collected: '10',
              method: PayMethod.cash,
              noReceipt: true,
              noReceiptReason: '  ',
            ),
          )['p_missing_receipt_reason'],
          isNull,
        );
      },
    );

    test('a photo is filed inside the booking\'s own folder', () {
      expect(receiptStoragePath('b1', 'jpg', 'abc'), 'b1/abc.jpg');
    });

    test('what the database answered', () {
      final ok =
          parseRecordedPayment({
            'success': true,
            'duplicate': false,
            'payment_id': 'p1',
            'new_amount_paid_cents': 5000,
            'balance_due_cents': 5000,
          })!;
      expect(
        [ok.paymentId, ok.duplicate, ok.balanceDueCents],
        ['p1', false, 5000],
      );
      expect(
        parseRecordedPayment({
          'success': true,
          'duplicate': true,
          'payment_id': 'p1',
          'balance_due_cents': 0,
        })!.duplicate,
        true,
      );
      expect(
        parseRecordedPayment({'success': true, 'payment_id': 'p1'})!.duplicate,
        false,
      );
      expect(
        parseRecordedPayment({'success': false, 'payment_id': 'p1'}),
        isNull,
      );
      expect(parseRecordedPayment({'success': true}), isNull);
      expect(parseRecordedPayment({'success': true, 'payment_id': ''}), isNull);
      expect(parseRecordedPayment(null), isNull);
      expect(parseRecordedPayment('ok'), isNull);
    });

    test('the methods', () {
      expect(
        [for (final m in PayMethod.values) m.value],
        ['cash', 'debit', 'credit', 'split'],
      );
      expect(
        [for (final m in PayMethod.values) m.label],
        ['Cash', 'Debit', 'Credit', 'Split'],
      );
      expect(payMethodFromDb('split'), PayMethod.split);
      expect(payMethodFromDb('bitcoin'), isNull);
    });
  });

  group('the checking queue', () {
    Map<String, dynamic> row([Map<String, dynamic> over = const {}]) => {
      'payment_id': 'p1',
      'booking_id': 'b1',
      'confirmation_code': 'AB12CD',
      'customer_name': 'Ada Lovelace',
      'table_name': 'VIP booth',
      'payment_method': 'debit',
      'billed_amount_cents': 3500,
      'amount_paid_cents': 3000,
      'pos_reference': 'POS-1',
      'receipt_photo_path': 'b1/r.jpg',
      'missing_receipt_reason': null,
      'recorded_at': '2026-10-09T21:30:00Z',
      'recorded_by_name': 'Sam Server',
      'recorded_by_me': false,
      'customer_confirmation_status': 'pending',
      'dispute_reason': null,
      ...over,
    };

    test('reads a row', () {
      final p = parsePendingPayment(row())!;
      expect(p.paymentId, 'p1');
      expect(p.bookingId, 'b1');
      expect(p.confirmationCode, 'AB12CD');
      expect(p.customerName, 'Ada Lovelace');
      expect(p.tableName, 'VIP booth');
      expect(p.method, 'debit');
      expect(p.methodLabel, 'Debit');
      expect(p.billedCents, 3500);
      expect(p.paidCents, 3000);
      expect(p.posReference, 'POS-1');
      expect(p.receiptPath, 'b1/r.jpg');
      expect(p.recordedAt, DateTime.utc(2026, 10, 9, 21, 30));
      expect(p.recordedByName, 'Sam Server');
      expect(p.recordedByMe, false);
      expect(p.disputed, false);
    });

    test('a row that cannot be trusted is dropped', () {
      expect(parsePendingPayment(row({'payment_id': null})), isNull);
      expect(parsePendingPayment(row({'payment_id': ''})), isNull);
      expect(parsePendingPayment(row({'booking_id': ''})), isNull);
      expect(parsePendingPayment(row({'recorded_at': null})), isNull);
    });

    test('an ordinary payment can be checked by someone else', () {
      final p = parsePendingPayment(row())!;
      expect(p.canVerify, true);
      expect(p.cannotVerifyBecause, isNull);
    });

    test('your own entry cannot be checked by you', () {
      final p = parsePendingPayment(row({'recorded_by_me': true}))!;
      expect(p.canVerify, false);
      expect(
        p.cannotVerifyBecause,
        'You recorded this payment, so someone else has to verify it.',
      );
    });

    test('a disputed payment cannot be checked; it needs a manager', () {
      final p =
          parsePendingPayment(
            row({
              'customer_confirmation_status': 'disputed',
              'dispute_reason': 'I paid \$20 less',
            }),
          )!;
      expect(p.disputed, true);
      expect(p.disputeReason, 'I paid \$20 less');
      expect(p.canVerify, false);
      expect(
        p.cannotVerifyBecause,
        'The guest disputed this payment. A manager has to settle it.',
      );
    });

    test(
      'a disputed payment that is also your own says it is disputed first',
      () {
        expect(
          parsePendingPayment(
            row({
              'customer_confirmation_status': 'disputed',
              'recorded_by_me': true,
            }),
          )!.cannotVerifyBecause,
          'The guest disputed this payment. A manager has to settle it.',
        );
      },
    );

    test('the note is optional and at most 300 characters', () {
      expect(validateVerifyNote(''), isNull);
      expect(validateVerifyNote('matches the till'), isNull);
      expect(validateVerifyNote('n' * 300), isNull);
      expect(
        validateVerifyNote('n' * 301),
        'Keep the note to 300 characters or fewer.',
      );
      expect(
        validateVerifyNote('   ${'n' * 300}   '),
        isNull,
        reason: 'spaces round the note do not count',
      );
      expect(verifyNoteLimit, 300);
    });

    test('what is sent; a blank note is sent as none', () {
      expect(verifyParams('p1', '  matches  '), {
        'p_payment': 'p1',
        'p_note': 'matches',
      });
      expect(verifyParams('p1', ''), {'p_payment': 'p1', 'p_note': null});
      expect(verifyParams('p1', null), {'p_payment': 'p1', 'p_note': null});
    });
  });

  group('Tonight', () {
    Map<String, dynamic> row([Map<String, dynamic> over = const {}]) => {
      'tables': 5,
      'guests': 10,
      'arrived': 1,
      'without_server': 2,
      'with_balance': 2,
      'balance_due_cents': 1400,
      'orders_new': 3,
      'orders_in_progress': 4,
      'orders_delivered': 5,
      'payments_to_check': 8,
      'payments_disputed': 2,
      'closeouts_requested': 1,
      'requests_open': 6,
      ...over,
    };

    test('reads the row', () {
      final t = parseTonight(row())!;
      expect(
        [
          t.tables,
          t.guests,
          t.arrived,
          t.withoutServer,
          t.withBalance,
          t.balanceDueCents,
        ],
        [5, 10, 1, 2, 2, 1400],
      );
      expect([t.ordersNew, t.ordersInProgress, t.ordersDelivered], [3, 4, 5]);
      expect(
        [
          t.paymentsToCheck,
          t.paymentsDisputed,
          t.closeoutsRequested,
          t.requestsOpen,
        ],
        [8, 2, 1, 6],
      );
    });

    test(
      'the checking queue is the unchecked payments plus the disputed ones',
      () {
        expect(parseTonight(row())!.paymentQueue, 10);
        expect(
          parseTonight(
            row({'payments_to_check': 0, 'payments_disputed': 0}),
          )!.paymentQueue,
          0,
        );
      },
    );

    test(
      'a row with nothing in it cannot be read; a missing number is zero',
      () {
        expect(parseTonight({}), isNull);
        expect(parseTonight({'tables': 3})!.requestsOpen, 0);
      },
    );
  });

  group('wording for a failed load', () {
    test('it is the same wording as the rest of the desk', () {
      expect(
        tableServiceLoadMessage(
          unavailable: true,
          accessEnded: false,
          what: 'orders',
        ),
        'Orders are not set up on this server yet.',
      );
      expect(
        tableServiceLoadMessage(
          unavailable: true,
          accessEnded: true,
          what: 'orders',
        ),
        'Orders are not set up on this server yet.',
        reason: '"not set up" wins: retrying cannot fix it',
      );
      expect(
        tableServiceLoadMessage(
          unavailable: false,
          accessEnded: true,
          what: 'orders',
        ),
        'Your access has ended, or you are signed out.',
      );
      expect(
        tableServiceLoadMessage(
          unavailable: false,
          accessEnded: false,
          what: 'orders',
        ),
        'Orders could not be loaded. Check your connection and try again.',
      );
      expect(
        tableServiceLoadMessage(
          unavailable: false,
          accessEnded: false,
          what: '',
        ),
        ' could not be loaded. Check your connection and try again.',
      );
    });
  });
}
