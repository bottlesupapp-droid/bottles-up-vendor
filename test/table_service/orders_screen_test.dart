import 'dart:async';

import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/orders_screen.dart';
import 'package:bottles_up_vendor/features/table_service/services/table_service_service.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_backend.dart';

late FakeTableBackend db;

const serverWs = Workspace(
  membershipId: 'w1',
  orgId: 'o1',
  orgName: 'Club Co',
  orgKind: 'venue_owner',
  role: WorkspaceRole.server,
  venueId: 'v1',
  venueName: 'Club A',
);
const managerWs = Workspace(
  membershipId: 'w2',
  orgId: 'o1',
  orgName: 'Club Co',
  orgKind: 'venue_owner',
  role: WorkspaceRole.manager,
  venueId: 'v1',
  venueName: 'Club A',
);

/// A Friday evening: the business night is Friday 9 October 2026. The fake database's clock is the same moment.
DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host(Workspace ws, {OrderFilter filter = OrderFilter.all}) =>
    ProviderScope(
      key: UniqueKey(),
      overrides: [tableServiceServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: OrdersScreen(
            workspace: ws,
            clock: friday9pm,
            initialFilter: filter,
          ),
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

/// Taps a filter chip, scrolling the row to it first (the later chips are off screen on a narrow phone).
Future<void> chooseFilter(WidgetTester tester, String name) async {
  final chip = find.byKey(Key('filter-$name'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pump();
}

void main() {
  setUp(() {
    db = FakeTableBackend();
    db.now = DateTime(2026, 10, 9, 21);
    db.addBooking(
      'b1',
      name: 'Ada Lovelace',
      code: 'AB12CD',
      total: 10000,
      paid: 6000,
    );
    db.addBooking(
      'b2',
      name: 'Grace Hopper',
      code: 'EF34GH',
      table: 'Dance floor table',
      guests: 2,
      total: 5000,
      paid: 5000,
    );
    db.addBooking(
      'b3',
      name: 'Nobody Nell',
      code: 'ZZ99ZZ',
      table: 'Corner',
      total: 2000,
      paid: 0,
    );
    db.assignments['b1'] = 'm-me';
    db.assignments['b2'] = 'm-me';
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
    db.addLine('b2', 'Moet', lineId: 'l3', state: 'picked_up', minutesAgo: 15);
    db.addLine(
      'b2',
      'Don Julio',
      lineId: 'l4',
      state: 'served',
      minutesAgo: 90,
    );
    db.addLine('b3', 'Belvedere', lineId: 'l5', minutesAgo: 5);
  });

  group('a server\'s orders', () {
    testWidgets(
      'opens on tonight and lists their own tables\' lines, longest wait first, delivered last',
      (tester) async {
        await open(tester, host(serverWs));
        expect(db.calls.first.$1, 'desk_orders');
        expect(db.params.first, {'p_venue': 'v1', 'p_night': '2026-10-09'});
        expect(find.text('My orders'), findsOneWidget);
        expect(find.text('Club A'), findsOneWidget);
        expect(find.text('Friday Oct 9'), findsOneWidget);
        final order = [
          for (final id in ['l1', 'l2', 'l3', 'l4'])
            tester.getTopLeft(find.byKey(Key('order-$id'))).dy,
        ];
        expect(
          order,
          [...order]..sort(),
          reason: 'oldest first, delivered last',
        );
        expect(
          find.byKey(const Key('order-l5')),
          findsNothing,
          reason: 'a table nobody gave this server',
        );
      },
    );

    testWidgets(
      'a line says what it is, who it is for, where it stands, how it is paid and how long it has waited',
      (tester) async {
        await open(tester, host(serverWs));
        expect(find.text('2 × Grey Goose 750ml'), findsOneWidget);
        expect(find.text('VIP booth · Ada Lovelace'), findsWidgets);
        expect(find.text('AB12CD'), findsWidgets);
        expect(find.text('Preparing'), findsWidgets);
        expect(find.byKey(const Key('payment-l2')), findsOneWidget);
        expect(find.text('Pay at venue'), findsOneWidget);
        expect(find.text('Paid'), findsWidgets);
        expect(find.text('\$100.00'), findsWidgets);
        expect(find.byKey(const Key('waiting-l2')), findsOneWidget);
        expect(find.text('Waiting 25 min'), findsOneWidget);
        expect(find.text('Waiting 40 min'), findsOneWidget);
        expect(
          find.byKey(const Key('waiting-l4')),
          findsNothing,
          reason: 'delivered: nothing to wait for',
        );
      },
    );

    testWidgets('shows no guest email or phone', (tester) async {
      await open(tester, host(serverWs));
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('+1'), findsNothing);
    });

    testWidgets(
      'the filters count what is in each, and choosing one narrows the list',
      (tester) async {
        await open(tester, host(serverWs));
        expect(find.text('All 4'), findsOneWidget);
        expect(find.text('New 1'), findsOneWidget);
        expect(find.text('Needs payment 1'), findsOneWidget);
        expect(find.text('Preparing 1'), findsOneWidget);
        expect(find.text('On the way 1'), findsOneWidget);
        expect(find.text('Delivered 1'), findsOneWidget);

        await chooseFilter(tester, 'fresh');
        expect(find.byKey(const Key('order-l1')), findsOneWidget);
        expect(find.byKey(const Key('order-l2')), findsNothing);

        await chooseFilter(tester, 'needsPayment');
        expect(find.byKey(const Key('order-l2')), findsOneWidget);
        expect(find.byKey(const Key('order-l1')), findsNothing);

        await chooseFilter(tester, 'onTheWay');
        expect(find.byKey(const Key('order-l3')), findsOneWidget);

        await chooseFilter(tester, 'delivered');
        expect(find.byKey(const Key('order-l4')), findsOneWidget);
        expect(find.byKey(const Key('order-l3')), findsNothing);

        await chooseFilter(tester, 'all');
        expect(find.byKey(const Key('order-l1')), findsOneWidget);
        expect(find.byKey(const Key('order-l4')), findsOneWidget);
      },
    );

    testWidgets('the chosen filter is the selected chip', (tester) async {
      await open(tester, host(serverWs));
      bool selected(String name) =>
          tester.widget<ChoiceChip>(find.byKey(Key('filter-$name'))).selected;
      expect(selected('all'), true);
      expect(selected('fresh'), false);
      await chooseFilter(tester, 'fresh');
      expect(selected('fresh'), true);
      expect(selected('all'), false);
    });

    testWidgets(
      'a line with no table or guest name still shows, with no table line',
      (tester) async {
        final svc = TableServiceService(
          rpc:
              (f, {params}) async => [
                {
                  'line_id': 'x1',
                  'booking_id': 'b1',
                  'bottle_name': 'Patron',
                  'quantity': 1,
                  'line_total_cents': 5000,
                  'payment_status': 'paid',
                  'service_status': 'awaiting_prep',
                  'ordered_at': '2026-10-09T20:00:00Z',
                },
              ],
        );
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [tableServiceServiceProvider.overrideWithValue(svc)],
            child: MaterialApp(
              home: Scaffold(
                body: OrdersScreen(workspace: serverWs, clock: friday9pm),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('order-x1')), findsOneWidget);
        expect(find.byKey(const Key('table-link-x1')), findsNothing);
      },
    );

    testWidgets(
      'opening a line\'s table, moving an order there and coming back shows the new state in the list',
      (tester) async {
        await open(tester, host(serverWs));
        await tester.tap(find.byKey(const Key('table-link-l1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('money-card')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('VIP booth · Ada Lovelace'),
          ),
          findsOneWidget,
          reason: 'the page is titled with the table and the guest',
        );
        await tester.tap(find.widgetWithText(Tab, 'Orders'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('move-l1')));
        await tester.pumpAndSettle();
        expect(db.line('l1').state, 'preparing');
        await tester.pageBack();
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

    testWidgets('a filter with nothing in it says so', (tester) async {
      db.lines.removeWhere((l) => l.state == 'picked_up');
      await open(tester, host(serverWs));
      await chooseFilter(tester, 'onTheWay');
      expect(find.text('Nothing is on the way.'), findsOneWidget);
    });

    testWidgets('the list can open on a chosen filter', (tester) async {
      await open(tester, host(serverWs, filter: OrderFilter.fresh));
      expect(find.byKey(const Key('order-l1')), findsOneWidget);
      expect(find.byKey(const Key('order-l2')), findsNothing);
    });

    testWidgets('the first button is the next step and it moves the order', (
      tester,
    ) async {
      await open(tester, host(serverWs));
      expect(
        find.descendant(
          of: find.byKey(const Key('move-l1')),
          matching: find.text('Start preparing'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('move-l2')),
          matching: find.text('Mark ready'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('move-l3')),
          matching: find.text('Delivered'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('move-l4')),
        findsNothing,
        reason: 'delivered: no next step',
      );

      await tester.tap(find.byKey(const Key('move-l1')));
      await tester.pumpAndSettle();
      expect(db.calls.map((c) => c.$1), contains('desk_set_service_status'));
      expect(
        db.params.firstWhere((p) => p != null && p.containsKey('p_line')),
        {'p_line': 'l1', 'p_status': 'preparing'},
      );
      expect(db.line('l1').state, 'preparing');
      // The list was read again and shows the new state and the next button.
      expect(db.count('desk_orders'), 2);
      expect(
        find.descendant(
          of: find.byKey(const Key('move-l1')),
          matching: find.text('Mark ready'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'the menu offers every other state, and choosing one moves the order there',
      (tester) async {
        await open(tester, host(serverWs));
        await tester.tap(find.byKey(const Key('more-l1')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('move-l1-preparing')),
          findsNothing,
          reason: 'that one is the button',
        );
        expect(find.byKey(const Key('move-l1-ready')), findsOneWidget);
        expect(find.byKey(const Key('move-l1-picked_up')), findsOneWidget);
        expect(find.byKey(const Key('move-l1-served')), findsOneWidget);
        expect(
          find.byKey(const Key('move-l1-awaiting_prep')),
          findsNothing,
          reason: 'it is New already',
        );
        await tester.tap(find.byKey(const Key('move-l1-picked_up')));
        await tester.pumpAndSettle();
        expect(db.line('l1').state, 'picked_up');
      },
    );

    testWidgets('going back a step is worded as going back', (tester) async {
      await open(tester, host(serverWs));
      await tester.tap(find.byKey(const Key('more-l3')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('move-l3-awaiting_prep')),
          matching: find.text('Back to New'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('move-l3-ready')),
          matching: find.text('Back to Ready'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'an item to be paid at the venue says why it cannot be delivered while the table owes',
      (tester) async {
        await open(tester, host(serverWs));
        expect(find.byKey(const Key('blocked-l2')), findsOneWidget);
        expect(
          find.text('The table still owes \$40.00. Take payment first.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('move-l2')))
              .onPressed,
          isNotNull,
          reason: 'the next step is not delivery, so it is not held',
        );
        await tester.tap(find.byKey(const Key('more-l2')));
        await tester.pumpAndSettle();
        final served = tester.widget<PopupMenuItem<ServiceState>>(
          find.byKey(const Key('move-l2-served')),
        );
        expect(
          served.enabled,
          false,
          reason: 'jumping straight to delivered is held too',
        );
        expect(
          tester
              .widget<PopupMenuItem<ServiceState>>(
                find.byKey(const Key('move-l2-picked_up')),
              )
              .enabled,
          true,
        );
      },
    );

    testWidgets('when delivery is the next step, the button itself is held', (
      tester,
    ) async {
      db.line('l2').state = 'picked_up';
      await open(tester, host(serverWs));
      expect(find.byKey(const Key('blocked-l2')), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('move-l2')),
      );
      expect(button.onPressed, isNull, reason: 'the delivery step is held');
      expect(
        find.descendant(
          of: find.byKey(const Key('move-l2')),
          matching: find.text('Delivered'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'earlier steps of that same item are not held, and the note does not show on a prepaid item',
      (tester) async {
        await open(tester, host(serverWs));
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('move-l2')))
              .onPressed,
          isNotNull,
        );
        expect(find.byKey(const Key('blocked-l1')), findsNothing);
        expect(find.byKey(const Key('blocked-l3')), findsNothing);
      },
    );

    testWidgets('once the table has paid, the item can be delivered', (
      tester,
    ) async {
      db.line('l2').state = 'picked_up';
      db.bookings['b1']!.paid = 10000;
      db.addPayment('b1', 4000, by: 'u-other');
      await open(tester, host(serverWs));
      expect(find.byKey(const Key('blocked-l2')), findsNothing);
      await tester.tap(find.byKey(const Key('move-l2')));
      await tester.pumpAndSettle();
      expect(db.line('l2').state, 'served');
    });

    testWidgets(
      'a server cannot take a delivered item back: there is no menu on it',
      (tester) async {
        await open(tester, host(serverWs));
        expect(find.byKey(const Key('more-l4')), findsNothing);
        expect(find.byKey(const Key('move-l4')), findsNothing);
      },
    );

    testWidgets(
      'the database\'s own sentence is shown when it refuses, and the list is read again',
      (tester) async {
        db.beforeCall = (f) {
          if (f == 'desk_set_service_status') {
            db.bookings['b1']!.reconciled = true;
          }
        };
        await open(tester, host(serverWs));
        await tester.tap(find.byKey(const Key('move-l1')));
        await tester.pumpAndSettle();
        expect(
          find.text('This table has already been closed out.'),
          findsOneWidget,
        );
        expect(db.count('desk_orders'), 2);
        expect(
          find.byKey(const Key('order-l1')),
          findsNothing,
          reason: 'a closed-out table leaves the list',
        );
      },
    );

    testWidgets(
      'a colleague got there first: the person is told it was already so',
      (tester) async {
        db.beforeCall = (f) {
          if (f == 'desk_set_service_status') db.line('l1').state = 'preparing';
        };
        await open(tester, host(serverWs));
        await tester.tap(find.byKey(const Key('move-l1')));
        await tester.pumpAndSettle();
        expect(find.text('It was already preparing.'), findsOneWidget);
      },
    );

    testWidgets(
      'the buttons wait while a move is on its way, so a second tap cannot send it twice',
      (tester) async {
        final gate = Completer<void>();
        await open(tester, host(serverWs));
        db.hold = gate.future;
        await tester.tap(find.byKey(const Key('move-l1')));
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('move-l1')))
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const Key('move-l1')), warnIfMissed: false);
        await tester.pump();
        db.hold = null;
        gate.complete();
        await tester.pumpAndSettle();
        expect(db.count('desk_set_service_status'), 1);
      },
    );
  });

  group('a manager\'s orders', () {
    testWidgets('see the whole club, and the tables that have no server', (
      tester,
    ) async {
      db.role = 'manager';
      await open(tester, host(managerWs));
      expect(find.text('Orders'), findsOneWidget);
      expect(find.byKey(const Key('order-l5')), findsOneWidget);
      expect(find.byKey(const Key('no-server-l5')), findsOneWidget);
      expect(find.byKey(const Key('no-server-l1')), findsNothing);
      expect(find.text('All 5'), findsOneWidget);
    });

    testWidgets('a manager can take a delivered item back', (tester) async {
      db.role = 'manager';
      await open(tester, host(managerWs));
      expect(
        find.byKey(const Key('move-l4')),
        findsNothing,
        reason: 'there is no next step after delivered',
      );
      await tester.tap(find.byKey(const Key('more-l4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('move-l4-picked_up')));
      await tester.pumpAndSettle();
      expect(db.line('l4').state, 'picked_up');
    });

    testWidgets('an empty night says so', (tester) async {
      db.role = 'manager';
      db.lines.clear();
      await open(tester, host(managerWs));
      expect(find.byKey(const Key('orders-empty')), findsOneWidget);
      expect(find.text('No bottle orders for this night.'), findsOneWidget);
    });
  });

  group('the night', () {
    testWidgets(
      'steps to the next night and back, and can jump back to tonight',
      (tester) async {
        await open(tester, host(serverWs));
        expect(find.byKey(const Key('night-tonight')), findsNothing);
        await tester.tap(find.byKey(const Key('night-next')));
        await tester.pumpAndSettle();
        expect(find.text('Saturday Oct 10'), findsOneWidget);
        expect(db.params.last, {'p_venue': 'v1', 'p_night': '2026-10-10'});
        expect(find.byKey(const Key('orders-empty')), findsOneWidget);
        expect(
          find.text('No bottle orders on your tables for this night.'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('night-tonight')));
        await tester.pumpAndSettle();
        expect(find.text('Friday Oct 9'), findsOneWidget);
        await tester.tap(find.byKey(const Key('night-prev')));
        await tester.pumpAndSettle();
        expect(find.text('Thursday Oct 8'), findsOneWidget);
      },
    );

    testWidgets(
      'a slot after midnight still belongs to the night before: the screen asks for the night, not the date',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              tableServiceServiceProvider.overrideWithValue(db.service),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: OrdersScreen(
                  workspace: serverWs,
                  clock: () => DateTime(2026, 10, 10, 1, 30),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(db.params.first, {'p_venue': 'v1', 'p_night': '2026-10-09'});
        expect(find.text('Friday Oct 9'), findsOneWidget);
      },
    );
  });

  group('when it goes wrong', () {
    testWidgets(
      'a database without the migration says so, with nothing to retry',
      (tester) async {
        db.failAll = PostgrestException(message: 'no function', code: '42883');
        await open(tester, host(serverWs));
        expect(
          find.text('Orders are not set up on this server yet.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('orders-retry')), findsNothing);
      },
    );

    testWidgets('a dropped connection can be tried again', (tester) async {
      db.failAll = Exception('offline');
      await open(tester, host(serverWs));
      expect(
        find.text(
          'Orders could not be loaded. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      db.failAll = null;
      await tester.tap(find.byKey(const Key('orders-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('order-l1')), findsOneWidget);
    });

    testWidgets('a person whose access ended is told so', (tester) async {
      db.role = 'none';
      await open(tester, host(serverWs));
      expect(
        find.text('Your access has ended, or you are signed out.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a workspace that is not tied to a club shows nothing and asks for nothing',
      (tester) async {
        const ws = Workspace(
          membershipId: 'w9',
          orgId: 'o1',
          orgName: 'Club Co',
          orgKind: 'venue_owner',
          role: WorkspaceRole.manager,
        );
        await open(tester, host(ws));
        expect(find.byKey(const Key('orders-no-venue')), findsOneWidget);
        expect(db.calls, isEmpty);
      },
    );

    testWidgets('pulling down reads the orders again', (tester) async {
      await open(tester, host(serverWs), height: 600);
      expect(db.count('desk_orders'), 1);
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(db.count('desk_orders'), 2);
    });
  });
}
