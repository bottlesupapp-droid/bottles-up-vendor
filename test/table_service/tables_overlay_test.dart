import 'package:bottles_up_vendor/features/floor/providers/floor_providers.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/my_tables_screen.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../floor/fake_floor_backend.dart';
import '../server_desk/fake_desk_backend.dart';
import 'fake_table_backend.dart';

late FakeDeskBackend desk;
late FakeTableBackend money;

const serverWs = Workspace(
  membershipId: 'w1',
  orgId: 'o1',
  orgName: 'Club Co',
  orgKind: 'venue_owner',
  role: WorkspaceRole.server,
  venueId: 'v1',
  venueName: 'Club A',
);

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

void main() {
  group('a server\'s tables show where each stands', () {
    Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        serverDeskServiceProvider.overrideWithValue(desk.service),
        tableServiceServiceProvider.overrideWithValue(money.service),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MyTablesScreen(workspace: serverWs, clock: friday9pm),
        ),
      ),
    );

    setUp(() {
      desk = FakeDeskBackend();
      desk.now = DateTime(2026, 10, 9, 21, 30);
      money = FakeTableBackend()..role = 'server';
      money.now = DateTime(2026, 10, 9, 21, 30);
      for (final id in ['b1', 'b2', 'b3', 'b4', 'b5']) {
        desk.addBooking(
          id,
          name: 'Guest $id',
          checkedInAt:
              id == 'b4' || id == 'b3' || id == 'b5' || id == 'b1'
                  ? '2026-10-09T21:10:00Z'
                  : null,
        );
        desk.assignments[id] = 'm-me';
        money.addBooking(id, name: 'Guest $id', total: 10000, paid: 10000);
        money.assignments[id] = 'm-me';
      }
      // b1: items to deliver; b2: guests not arrived; b3: money owed; b4: a payment waiting to be checked; b5: closed out.
      money.addLine('b1', 'Patron', state: 'preparing');
      money.addLine('b1', 'Moet', state: 'awaiting_prep');
      money.bookings['b3']!.paid = 6000;
      money.addPayment('b4', 100, by: 'u-me');
      money.bookings['b5']!.reconciled = true;
    });

    testWidgets('each card says what to do next', (tester) async {
      await open(tester, host());
      expect(find.byKey(const Key('next-b1')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('next-b1'))).data,
        '2 items to deliver',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('next-b2'))).data,
        'Waiting for the guests',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('next-b3'))).data,
        'Take payment: \$40.00',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('next-b4'))).data,
        'Payment recorded - waiting to be checked',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('next-b5'))).data,
        'Closed out',
      );
    });

    testWidgets(
      'the overlay is asked for the same club and night as the tables',
      (tester) async {
        await open(tester, host());
        final call = money.calls.firstWhere((c) => c.$1 == 'desk_table_status');
        expect(call.$2, {'p_venue': 'v1', 'p_night': '2026-10-09'});
      },
    );

    testWidgets('a table with nothing left to do says so', (tester) async {
      money.lines.clear();
      money.bookings['b3']!.paid = 10000;
      money.payments.clear();
      await open(tester, host());
      expect(
        tester.widget<Text>(find.byKey(const Key('next-b3'))).data,
        'Nothing to do',
      );
    });

    testWidgets(
      'if where the tables stand cannot be loaded, the tables still show, with no next line',
      (tester) async {
        money.failOn['desk_table_status'] = Exception('offline');
        await open(tester, host());
        expect(find.text('Guest b1'), findsOneWidget);
        expect(find.byKey(const Key('next-b1')), findsNothing);
        expect(
          find.byKey(const Key('open-b1')),
          findsOneWidget,
          reason: 'the table can still be opened',
        );
      },
    );

    testWidgets(
      'a database without the money functions leaves the tables as they were',
      (tester) async {
        money.failAll = Exception('no function');
        await open(tester, host());
        expect(find.text('Guest b1'), findsOneWidget);
        expect(find.byKey(const Key('next-b1')), findsNothing);
      },
    );

    testWidgets(
      '"Orders and payments" opens the table, and coming back reads where the tables stand again',
      (tester) async {
        await open(tester, host());
        expect(money.count('desk_table_status'), 1);
        await tester.ensureVisible(find.byKey(const Key('open-b1')));
        await tester.tap(find.byKey(const Key('open-b1')));
        await tester.pumpAndSettle();
        expect(find.byType(TableDetailScreen), findsOneWidget);
        expect(find.text('VIP booth · Guest b1'), findsWidgets);
        expect(find.byKey(const Key('money-card')), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(money.count('desk_table_status'), 2);
      },
    );

    testWidgets(
      'moving an order on the table\'s page is reflected on the card afterwards',
      (tester) async {
        await open(tester, host());
        await tester.ensureVisible(find.byKey(const Key('open-b1')));
        await tester.tap(find.byKey(const Key('open-b1')));
        await tester.pumpAndSettle();
        for (final l
            in money.lines.where((l) => l.bookingId == 'b1').toList()) {
          l.state = 'served';
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('next-b1'))).data,
          'Nothing to do',
        );
      },
    );

    testWidgets('the footnote points at the table page', (tester) async {
      await open(tester, host());
      expect(
        find.text('Open a table for its bottle orders and payments.'),
        findsOneWidget,
      );
    });
  });

  group(
    'the manager\'s Floor leads into a confirmed booking\'s orders and payments',
    () {
      late FakeFloorBackend floor;

      Widget host() => ProviderScope(
        key: UniqueKey(),
        overrides: [
          floorServiceProvider.overrideWithValue(floor.service),
          tableServiceServiceProvider.overrideWithValue(money.service),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: FloorScreen(
              venueId: 'v1',
              venueName: 'Club A',
              clock: friday9pm,
            ),
          ),
        ),
      );

      setUp(() {
        floor = FakeFloorBackend();
        floor.onList =
            (_) => [
              bookingRow('b1', code: 'AB12CD'),
              bookingRow('b3', name: 'Linus Torvalds', status: 'pending'),
            ];
        money = FakeTableBackend()..role = 'manager';
        money.now = DateTime(2026, 10, 9, 21);
        money.addBooking(
          'b1',
          name: 'Ada Lovelace',
          code: 'AB12CD',
          total: 10000,
          paid: 6000,
        );
        money.addLine('b1', 'Patron');
      });

      testWidgets('a confirmed booking has the link; a pending one does not', (
        tester,
      ) async {
        await open(tester, host());
        expect(find.byKey(const Key('open-table-b1')), findsOneWidget);
        expect(find.byKey(const Key('open-table-b3')), findsNothing);
      });

      testWidgets('the link opens that table', (tester) async {
        await open(tester, host());
        await tester.ensureVisible(find.byKey(const Key('open-table-b1')));
        await tester.tap(find.byKey(const Key('open-table-b1')));
        await tester.pumpAndSettle();
        expect(find.byType(TableDetailScreen), findsOneWidget);
        expect(money.params.first, {'p_booking': 'b1'});
        expect(find.byKey(const Key('money-card')), findsOneWidget);
        expect(find.byKey(const Key('record-payment')), findsOneWidget);
      });
    },
  );
}
