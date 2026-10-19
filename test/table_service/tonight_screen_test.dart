import 'package:bottles_up_vendor/features/server_desk/screens/service_requests_screen.dart';
import 'package:bottles_up_vendor/features/table_service/logic/table_service_rules.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/orders_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/payment_review_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_backend.dart';

late FakeTableBackend db;

const managerWs = Workspace(
  membershipId: 'w2',
  orgId: 'o1',
  orgName: 'Club Co',
  orgKind: 'venue_owner',
  role: WorkspaceRole.manager,
  venueId: 'v1',
  venueName: 'Club A',
);

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host({Workspace ws = managerWs}) => ProviderScope(
  key: UniqueKey(),
  overrides: [tableServiceServiceProvider.overrideWithValue(db.service)],
  child: MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: TonightScreen(workspace: ws, clock: friday9pm)),
  ),
);

Future<void> open(WidgetTester tester, Widget w, {double height = 3000}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

String count(WidgetTester tester, String tileKey) {
  final texts =
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(Key(tileKey)),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .toList();
  return texts.last;
}

void main() {
  setUp(() {
    db = FakeTableBackend()..role = 'manager';
    db.now = DateTime(2026, 10, 9, 21);
    db.addBooking(
      'b1',
      name: 'Ada Lovelace',
      total: 10000,
      paid: 6000,
      guests: 4,
    );
    db.addBooking(
      'b2',
      name: 'Grace Hopper',
      total: 5000,
      paid: 5000,
      guests: 2,
      table: 'Corner',
    );
    db.addBooking(
      'b3',
      name: 'Nobody Nell',
      total: 2000,
      paid: 0,
      guests: 3,
      table: 'Booth 3',
    );
    db.addBooking(
      'b4',
      name: 'Next Night',
      night: '2026-10-10',
      total: 3000,
      paid: 0,
    );
    db.assignments['b1'] = 'm-me';
    db.assignments['b2'] = 'm-me';
    db.bookings['b1']!.checkedIn = true;
    db.addLine('b1', 'Patron', state: 'awaiting_prep');
    db.addLine('b1', 'Grey Goose', state: 'preparing', pay: 'due_at_venue');
    db.addLine('b2', 'Moet', state: 'served');
    db.addLine('b3', 'Belvedere', state: 'awaiting_prep');
    db.addPayment('b1', 3000);
    db.addPayment('b2', 1000);
    db.addPayment('b2', 500, status: 'disputed');
    db.addPayment('b1', 400, verified: true);
    db.bookings['b2']!.closeoutRequested = true;
    db.openRequests = 3;
  });

  testWidgets('opens on tonight and asks for the club and the night', (
    tester,
  ) async {
    await open(tester, host());
    expect(db.functions, ['desk_tonight']);
    expect(db.params.single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('Club A'), findsOneWidget);
    expect(find.text('Friday Oct 9'), findsOneWidget);
  });

  testWidgets('puts what needs a person first, each with its number', (
    tester,
  ) async {
    await open(tester, host());
    expect(find.text('Needs attention'), findsOneWidget);
    expect(
      count(tester, 'tile-payments'),
      '3',
      reason: 'two unchecked and one disputed',
    );
    expect(find.text('1 disputed by the guest'), findsOneWidget);
    expect(count(tester, 'tile-orders-new'), '2');
    expect(count(tester, 'tile-requests'), '3');
    expect(count(tester, 'tile-without-server'), '1');
    expect(count(tester, 'tile-closeouts'), '1');
  });

  testWidgets('then the night at a glance', (tester) async {
    await open(tester, host());
    expect(find.text('The night'), findsOneWidget);
    expect(count(tester, 'tile-tables'), '3');
    expect(find.text('9 guests expected · 1 table arrived'), findsOneWidget);
    expect(count(tester, 'tile-balance'), '2');
    expect(find.text('\$60.00 still due'), findsOneWidget);
    expect(count(tester, 'tile-in-progress'), '1');
    expect(count(tester, 'tile-delivered'), '1');
  });

  testWidgets(
    'a night with nothing keeps the club-wide numbers and has none of its own',
    (tester) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('night-next')));
      await tester.pumpAndSettle();
      expect(find.text('Saturday Oct 10'), findsOneWidget);
      expect(count(tester, 'tile-tables'), '1');
      await tester.tap(find.byKey(const Key('night-next')));
      await tester.pumpAndSettle();
      expect(count(tester, 'tile-tables'), '0');
      expect(find.text('0 guests expected · 0 tables arrived'), findsOneWidget);
      expect(
        count(tester, 'tile-payments'),
        '3',
        reason: 'payments to check are not tied to a night',
      );
      expect(find.text('\$60.00 still due'), findsNothing);
    },
  );

  testWidgets('singular wording for one guest and one arrived table', (
    tester,
  ) async {
    db.bookings.clear();
    db.lines.clear();
    db.payments.clear();
    db.addBooking('b1', total: 1000, paid: 0, guests: 1);
    db.bookings['b1']!.checkedIn = true;
    await open(tester, host());
    expect(find.text('1 guest expected · 1 table arrived'), findsOneWidget);
  });

  testWidgets('says plainly what is not built', (tester) async {
    await open(tester, host());
    expect(find.byKey(const Key('tonight-footnote')), findsOneWidget);
    expect(find.textContaining('not built yet'), findsWidgets);
    expect(find.text('Closing a table is not built yet.'), findsOneWidget);
    expect(find.text('Give them one from the Floor tab.'), findsOneWidget);
  });

  group('what is highlighted', () {
    Color? colour(WidgetTester tester, String tile) {
      final texts =
          tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byKey(Key(tile)),
                  matching: find.byType(Text),
                ),
              )
              .toList();
      return texts.last.style?.color;
    }

    const amber = Color(0xFFFFB300);

    testWidgets('a number that needs a person is amber, when it is not zero', (
      tester,
    ) async {
      await open(tester, host());
      for (final t in [
        'tile-payments',
        'tile-orders-new',
        'tile-requests',
        'tile-without-server',
        'tile-closeouts',
      ]) {
        expect(colour(tester, t), amber, reason: t);
      }
    });

    testWidgets('a number that is zero is not highlighted', (tester) async {
      db.payments.clear();
      db.lines.clear();
      db.openRequests = 0;
      db.bookings['b2']!.closeoutRequested = false;
      db.assignments['b3'] = 'm-me';
      await open(tester, host());
      for (final t in [
        'tile-payments',
        'tile-orders-new',
        'tile-requests',
        'tile-without-server',
        'tile-closeouts',
      ]) {
        expect(colour(tester, t), isNot(amber), reason: t);
      }
    });

    testWidgets('the night at a glance is never highlighted', (tester) async {
      await open(tester, host());
      for (final t in [
        'tile-tables',
        'tile-balance',
        'tile-in-progress',
        'tile-delivered',
      ]) {
        expect(colour(tester, t), isNot(amber), reason: t);
      }
    });

    testWidgets('"disputed by the guest" is mentioned only when something is', (
      tester,
    ) async {
      db.payments.removeWhere((p) => p.customerStatus == 'disputed');
      await open(tester, host());
      expect(find.textContaining('disputed by the guest'), findsNothing);
    });
  });

  group('opening a list', () {
    testWidgets('payments to check opens the queue', (tester) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('tile-payments')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentReviewScreen), findsOneWidget);
      expect(find.text('3 payments waiting'), findsOneWidget);
    });

    testWidgets('new orders opens the orders already narrowed to New', (
      tester,
    ) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('tile-orders-new')));
      await tester.pumpAndSettle();
      final screen = tester.widget<OrdersScreen>(find.byType(OrdersScreen));
      expect(screen.initialFilter, OrderFilter.fresh);
      expect(find.text('1 × Patron 750ml'), findsOneWidget);
      expect(
        find.text('1 × Grey Goose 750ml'),
        findsNothing,
        reason: 'that one is already being prepared',
      );
    });

    testWidgets('open requests opens the requests', (tester) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('tile-requests')));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceRequestsScreen), findsOneWidget);
    });

    testWidgets('the numbers that have no list yet do nothing when tapped', (
      tester,
    ) async {
      await open(tester, host());
      for (final k in [
        'tile-without-server',
        'tile-closeouts',
        'tile-tables',
        'tile-balance',
      ]) {
        await tester.tap(find.byKey(Key(k)));
        await tester.pumpAndSettle();
        expect(find.byType(PaymentReviewScreen), findsNothing, reason: k);
        expect(find.byType(OrdersScreen), findsNothing, reason: k);
      }
    });

    testWidgets('coming back from a list reads the numbers again', (
      tester,
    ) async {
      await open(tester, host());
      await tester.tap(find.byKey(const Key('tile-payments')));
      await tester.pumpAndSettle();
      expect(db.count('desk_tonight'), 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(db.count('desk_tonight'), 2);
    });
  });

  group('when it goes wrong', () {
    testWidgets('a server is refused and told their access does not cover it', (
      tester,
    ) async {
      db.role = 'server';
      await open(tester, host());
      expect(
        find.text('Your access has ended, or you are signed out.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a database without the migration says so, with nothing to retry',
      (tester) async {
        db.failAll = PostgrestException(message: 'no function', code: '42883');
        await open(tester, host());
        expect(
          find.text('Tonight are not set up on this server yet.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('tonight-retry')), findsNothing);
      },
    );

    testWidgets('a dropped connection can be tried again', (tester) async {
      db.failAll = Exception('offline');
      await open(tester, host());
      expect(
        find.text(
          'Tonight could not be loaded. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      db.failAll = null;
      await tester.tap(find.byKey(const Key('tonight-retry')));
      await tester.pumpAndSettle();
      expect(count(tester, 'tile-tables'), '3');
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
        await open(tester, host(ws: ws));
        expect(find.byKey(const Key('tonight-no-venue')), findsOneWidget);
        expect(db.calls, isEmpty);
      },
    );

    testWidgets('pulling down reads the numbers again', (tester) async {
      await open(tester, host(), height: 600);
      expect(db.count('desk_tonight'), 1);
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(db.count('desk_tonight'), 2);
    });
  });
}
