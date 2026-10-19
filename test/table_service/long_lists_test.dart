import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/orders_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/payment_review_screen.dart';
import 'package:bottles_up_vendor/features/table_service/widgets/order_card.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_table_backend.dart';

// The longest lists the database will return (a thousand orders, three hundred payments). They are kept apart because they are slow to
// build, and they say two things: the screen tells the person the list was cut off, and it only builds the rows near the screen.

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

Future<void> open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [tableServiceServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: screen)),
    ),
  );
  await tester.pumpAndSettle();
}

/// A lazy list only builds what is near the screen, so its end is reached by jumping to the end a few times (the length is an
/// estimate until the rows have been built).
Future<void> scrollToEnd(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  for (var i = 0; i < 6; i++) {
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
  }
}

void main() {
  setUp(() {
    db = FakeTableBackend()..role = 'manager';
    db.now = DateTime(2026, 10, 9, 21);
    db.addBooking('b3', name: 'Nobody Nell', total: 2000, paid: 0);
  });

  testWidgets(
    'a night with a thousand orders says the list was cut off, and builds only the cards near the screen',
    (tester) async {
      for (var i = 0; i < 1000; i++) {
        db.addLine('b3', 'Bulk $i', lineId: 'bulk$i', minutesAgo: 3);
      }
      await open(tester, OrdersScreen(workspace: managerWs, clock: friday9pm));
      expect(
        find.byKey(const Key('orders-cutoff')),
        findsNothing,
        reason: 'the end of the list is not on screen yet',
      );
      await scrollToEnd(tester);
      expect(find.byKey(const Key('orders-cutoff')), findsOneWidget);
      expect(
        find.byType(OrderCard).evaluate().length,
        lessThan(100),
        reason: 'only the cards near the screen are built',
      );
    },
  );

  testWidgets('999 orders are not cut off', (tester) async {
    for (var i = 0; i < 999; i++) {
      db.addLine('b3', 'Bulk $i', lineId: 'bulk$i', minutesAgo: 3);
    }
    await open(tester, OrdersScreen(workspace: managerWs, clock: friday9pm));
    await scrollToEnd(tester);
    expect(find.byKey(const Key('orders-cutoff')), findsNothing);
  });

  testWidgets('a queue of 300 payments says it was cut off', (tester) async {
    for (var i = 0; i < 300; i++) {
      db.addPayment('b3', 100, paymentId: 'bulk$i');
    }
    await open(
      tester,
      PaymentReviewScreen(workspace: managerWs, clock: friday9pm),
    );
    await scrollToEnd(tester);
    expect(find.byKey(const Key('review-cutoff')), findsOneWidget);
  });

  testWidgets('299 payments are not cut off', (tester) async {
    for (var i = 0; i < 299; i++) {
      db.addPayment('b3', 100, paymentId: 'bulk$i');
    }
    await open(
      tester,
      PaymentReviewScreen(workspace: managerWs, clock: friday9pm),
    );
    await scrollToEnd(tester);
    expect(find.byKey(const Key('review-cutoff')), findsNothing);
  });
}
