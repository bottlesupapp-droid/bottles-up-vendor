import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:bottles_up_vendor/features/table_service/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrderLine line({
  ServiceState state = ServiceState.awaitingPrep,
  LinePayment payment = LinePayment.paid,
  String? table = 'VIP booth',
  String? customer = 'Ada Lovelace',
  String? code = 'AB12CD',
  String? server = 'm1',
  int? balance,
  bool cancelled = false,
  String? reason,
  bool addon = false,
}) => OrderLine(
  lineId: 'l1',
  bookingId: 'b1',
  bottleName: 'Patron',
  size: '750ml',
  quantity: 2,
  unitPriceCents: null,
  lineTotalCents: 10000,
  isAddon: addon,
  payment: payment,
  state: state,
  orderedAt: DateTime.utc(2026, 10, 9, 20, 30),
  cancelledAt: cancelled ? DateTime.utc(2026, 10, 9, 21) : null,
  cancellationReason: reason,
  confirmationCode: code,
  customerName: customer,
  tableName: table,
  balanceDueCents: balance,
  serverMembershipId: server,
);

final now = DateTime.utc(2026, 10, 9, 21);

Future<List<ServiceState>> show(
  WidgetTester tester,
  OrderLine l, {
  bool manager = false,
  bool busy = false,
  bool showTable = true,
}) async {
  final moves = <ServiceState>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OrderCard(
            line: l,
            now: now,
            manager: manager,
            busy: busy,
            showTable: showTable,
            onMove: moves.add,
          ),
        ),
      ),
    ),
  );
  return moves;
}

void main() {
  group('who and what', () {
    testWidgets(
      'a night\'s card names the table and the guest, the code, the bottle, the total and the wait',
      (tester) async {
        await show(tester, line());
        expect(find.text('2 × Patron 750ml'), findsOneWidget);
        expect(find.text('VIP booth · Ada Lovelace'), findsOneWidget);
        expect(find.text('AB12CD'), findsOneWidget);
        expect(find.text('\$100.00'), findsOneWidget);
        expect(find.text('Waiting 30 min'), findsOneWidget);
        expect(find.text('Submitted'), findsOneWidget);
        expect(find.text('Paid'), findsOneWidget);
      },
    );

    testWidgets('only what is known of the table and the guest is shown', (
      tester,
    ) async {
      await show(tester, line(customer: null));
      expect(find.text('VIP booth'), findsOneWidget);
      await show(tester, line(table: null));
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('with neither, there is no table line at all', (tester) async {
      await show(tester, line(table: null, customer: null));
      expect(find.byKey(const Key('table-link-l1')), findsNothing);
    });

    testWidgets(
      'a table\'s own page shows no table line and no code, even when the names are known',
      (tester) async {
        await show(tester, line(), showTable: false);
        expect(find.byKey(const Key('table-link-l1')), findsNothing);
        expect(find.text('AB12CD'), findsNothing);
      },
    );

    testWidgets('no code means no code line', (tester) async {
      await show(tester, line(code: null));
      expect(find.text('AB12CD'), findsNothing);
    });

    testWidgets(
      'a manager is told when nobody serves the table; a server is not, nor is a table\'s own page',
      (tester) async {
        await show(tester, line(server: null), manager: true);
        expect(find.byKey(const Key('no-server-l1')), findsOneWidget);
        await show(tester, line(server: null));
        expect(find.byKey(const Key('no-server-l1')), findsNothing);
        await show(tester, line(server: null), manager: true, showTable: false);
        expect(find.byKey(const Key('no-server-l1')), findsNothing);
        await show(tester, line(server: 'm1'), manager: true);
        expect(find.byKey(const Key('no-server-l1')), findsNothing);
        await show(tester, line(server: null, cancelled: true), manager: true);
        expect(
          find.byKey(const Key('no-server-l1')),
          findsNothing,
          reason: 'a cancelled line needs no server',
        );
      },
    );

    testWidgets('an item added at the table says so', (tester) async {
      await show(tester, line(addon: true));
      expect(find.byKey(const Key('addon-l1')), findsOneWidget);
      await show(tester, line());
      expect(find.byKey(const Key('addon-l1')), findsNothing);
    });

    testWidgets(
      'a cancelled line is struck through, says why, and has no wait',
      (tester) async {
        await show(
          tester,
          line(cancelled: true, reason: 'guest changed their mind'),
          manager: true,
        );
        expect(find.text('Cancelled'), findsOneWidget);
        expect(
          find.text('Cancelled: guest changed their mind'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('waiting-l1')), findsNothing);
        expect(find.byKey(const Key('move-l1')), findsNothing);
        expect(find.byKey(const Key('more-l1')), findsNothing);
        final title = tester.widget<Text>(find.text('2 × Patron 750ml'));
        expect(title.style?.decoration, TextDecoration.lineThrough);
      },
    );

    testWidgets('a cancelled line with no reason says just that', (
      tester,
    ) async {
      await show(tester, line(cancelled: true));
      expect(find.byKey(const Key('cancelled-l1')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('cancelled-l1'))).data,
        'Cancelled',
      );
    });

    testWidgets('a delivered line has no wait', (tester) async {
      await show(tester, line(state: ServiceState.served), manager: true);
      expect(find.byKey(const Key('waiting-l1')), findsNothing);
      expect(
        tester.widget<Text>(find.text('2 × Patron 750ml')).style?.decoration,
        isNot(TextDecoration.lineThrough),
      );
    });
  });

  group('the buttons', () {
    testWidgets('the first button is the next step and sends it', (
      tester,
    ) async {
      final moves = await show(tester, line());
      expect(find.text('Accept'), findsOneWidget, reason: 'a new order is accepted first');
      await tester.tap(find.byKey(const Key('move-l1')));
      expect(moves, [ServiceState.accepted]);
    });

    testWidgets('while a move is on its way, nothing can be tapped', (
      tester,
    ) async {
      await show(tester, line(), busy: true);
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('move-l1'))).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<PopupMenuButton<ServiceState>>(
              find.byKey(const Key('more-l1')),
            )
            .enabled,
        false,
      );
    });

    testWidgets(
      'the menu words going forward as the step and going back as "Back to"',
      (tester) async {
        await show(tester, line(state: ServiceState.ready));
        await tester.tap(find.byKey(const Key('more-l1')));
        await tester.pumpAndSettle();
        String label(String key) =>
            (tester.widget<Text>(
              find.descendant(
                of: find.byKey(Key(key)),
                matching: find.byType(Text),
              ),
            )).data!;
        expect(label('move-l1-awaiting_prep'), 'Back to Submitted');
        expect(label('move-l1-preparing'), 'Back to Preparing');
        expect(find.byKey(const Key('move-l1-accepted')), findsNothing, reason: 'Accept is only for an order that is still new');
        expect(label('move-l1-served'), 'Delivered');
        expect(
          find.byKey(const Key('move-l1-picked_up')),
          findsNothing,
          reason: 'that one is the button',
        );
      },
    );

    testWidgets('going forward from the start is worded as the step it is', (
      tester,
    ) async {
      await show(tester, line());
      await tester.tap(find.byKey(const Key('more-l1')));
      await tester.pumpAndSettle();
      String label(String key) =>
          (tester.widget<Text>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Text),
            ),
          )).data!;
      expect(label('move-l1-ready'), 'Mark ready');
      expect(label('move-l1-picked_up'), 'On the way');
      expect(label('move-l1-served'), 'Delivered');
    });

    testWidgets('choosing from the menu sends that state', (tester) async {
      final moves = await show(tester, line());
      await tester.tap(find.byKey(const Key('more-l1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('move-l1-picked_up')));
      await tester.pumpAndSettle();
      expect(moves, [ServiceState.pickedUp]);
    });

    testWidgets(
      'a delivered item has no buttons for a server, and only the menu for a manager',
      (tester) async {
        await show(tester, line(state: ServiceState.served));
        expect(find.byKey(const Key('move-l1')), findsNothing);
        expect(find.byKey(const Key('more-l1')), findsNothing);
        await show(tester, line(state: ServiceState.served), manager: true);
        expect(find.byKey(const Key('move-l1')), findsNothing);
        expect(find.byKey(const Key('more-l1')), findsOneWidget);
      },
    );

    testWidgets(
      'the last step before delivery has a button but nothing worth a menu entry... except going back',
      (tester) async {
        await show(tester, line(state: ServiceState.pickedUp));
        expect(find.byKey(const Key('move-l1')), findsOneWidget);
        expect(find.byKey(const Key('more-l1')), findsOneWidget);
      },
    );
  });

  group('an item to be paid at the venue', () {
    testWidgets(
      'says why it is held while the table owes, and holds the delivery step',
      (tester) async {
        final moves = await show(
          tester,
          line(
            state: ServiceState.pickedUp,
            payment: LinePayment.dueAtVenue,
            balance: 4000,
          ),
        );
        expect(
          find.text('The table still owes \$40.00. Take payment first.'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('move-l1')), warnIfMissed: false);
        expect(moves, isEmpty);
      },
    );

    testWidgets(
      'says nothing once the table is paid up, or when it is a delivered item',
      (tester) async {
        await show(tester, line(payment: LinePayment.dueAtVenue, balance: 0));
        expect(find.byKey(const Key('blocked-l1')), findsNothing);
        await show(
          tester,
          line(
            state: ServiceState.served,
            payment: LinePayment.dueAtVenue,
            balance: 4000,
          ),
          manager: true,
        );
        expect(find.byKey(const Key('blocked-l1')), findsNothing);
        await show(
          tester,
          line(cancelled: true, payment: LinePayment.dueAtVenue, balance: 4000),
          manager: true,
        );
        expect(find.byKey(const Key('blocked-l1')), findsNothing);
      },
    );
  });
}
