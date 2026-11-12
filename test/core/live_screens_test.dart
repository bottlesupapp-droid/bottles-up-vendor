import 'package:bottles_up_vendor/core/live/live_refresh.dart';
import 'package:bottles_up_vendor/features/floor/providers/floor_providers.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/my_tables_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/service_requests_screen.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/orders_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/payment_review_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../floor/fake_floor_backend.dart';
import '../server_desk/fake_desk_backend.dart';
import '../table_service/fake_table_backend.dart';

// The brief: floor status, order progress, payments, admission counts and requests update live. Each operational screen looks again by itself while it is in front, and says when it last did. These
// open each of them with the setting on and check, with the screen's own fake backend, that it asks the server again after the interval and shows the line.
Workspace ws(WorkspaceRole role) =>
    Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: role, venueId: 'v1', venueName: 'Club A');

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

/// The table-service fake as the manager's and the verifier's own tests set it up: one booking, so the screens have something to ask about.
FakeTableBackend tableBackend(String role) => FakeTableBackend()
  ..role = role
  ..now = DateTime(2026, 10, 9, 21)
  ..addBooking('b1', name: 'Ada Lovelace', total: 10000, paid: 6000, guests: 4);

const every = Duration(seconds: 20);

/// Opens [screen] with the live setting on, and returns how many times the server was asked for what the screen first asked.
Future<int Function()> openLive(WidgetTester tester, Widget screen, List<(String, Map<String, dynamic>?)> calls, List<Override> backend) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [...backend, liveRefreshEnabledProvider.overrideWithValue(true), liveRefreshIntervalProvider.overrideWithValue(every)],
    child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: screen)),
  ));
  await tester.pumpAndSettle();
  final first = calls.first.$1;
  return () => calls.where((c) => c.$1 == first).length;
}

Future<void> lookAgain(WidgetTester tester) async {
  await tester.pump(every);
  await tester.pump();
  await tester.pump();
}

void expectStatusLine(WidgetTester tester) {
  expect(find.byKey(const Key('live-status')), findsOneWidget);
  expect(tester.widget<Text>(find.byKey(const Key('live-status'))).data, startsWith('Updated '));
}

void main() {
  testWidgets('the manager\'s Tonight', (tester) async {
    final db = tableBackend('manager');
    final asked = await openLive(tester, TonightScreen(workspace: ws(WorkspaceRole.manager), clock: friday9pm), db.calls, [tableServiceServiceProvider.overrideWithValue(db.service)]);
    expectStatusLine(tester);
    final before = asked();
    await lookAgain(tester);
    expect(asked(), greaterThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the manager\'s Floor', (tester) async {
    final db = FakeFloorBackend()..onList = (_) => [];
    final asked = await openLive(tester, FloorScreen(venueId: 'v1', venueName: 'Club A', clock: friday9pm), db.calls, [floorServiceProvider.overrideWithValue(db.service)]);
    expectStatusLine(tester);
    final before = asked();
    await lookAgain(tester);
    expect(asked(), greaterThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Orders', (tester) async {
    final db = tableBackend('manager');
    final asked = await openLive(tester, OrdersScreen(workspace: ws(WorkspaceRole.manager), clock: friday9pm), db.calls, [tableServiceServiceProvider.overrideWithValue(db.service)]);
    expectStatusLine(tester);
    final before = asked();
    await lookAgain(tester);
    expect(asked(), greaterThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a server\'s My tables', (tester) async {
    final db = FakeDeskBackend();
    final asked = await openLive(tester, MyTablesScreen(workspace: ws(WorkspaceRole.server), clock: friday9pm, pickAsk: (c, label) async => null), db.calls, [serverDeskServiceProvider.overrideWithValue(db.service)]);
    expectStatusLine(tester);
    final before = asked();
    await lookAgain(tester);
    expect(asked(), greaterThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Requests', (tester) async {
    final db = FakeDeskBackend();
    final asked = await openLive(tester, ServiceRequestsScreen(workspace: ws(WorkspaceRole.server), clock: friday9pm, pickReason: (c, a) async => null), db.calls, [serverDeskServiceProvider.overrideWithValue(db.service)]);
    expectStatusLine(tester);
    final before = asked();
    await lookAgain(tester);
    expect(asked(), greaterThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a verifier\'s payment review', (tester) async {
    final db = tableBackend('verifier');
    final asked = await openLive(tester, PaymentReviewScreen(workspace: ws(WorkspaceRole.verifier), clock: friday9pm), db.calls, [tableServiceServiceProvider.overrideWithValue(db.service)]);
    expectStatusLine(tester);
    final before = asked();
    await lookAgain(tester);
    expect(asked(), greaterThan(before));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with the setting off (the default in tests) a screen asks once and starts no timer', (tester) async {
    final db = FakeDeskBackend();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [serverDeskServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(home: Scaffold(body: ServiceRequestsScreen(workspace: ws(WorkspaceRole.server), clock: friday9pm, pickReason: (c, a) async => null))),
    ));
    await tester.pumpAndSettle();
    final before = db.calls.length;
    await tester.pump(const Duration(minutes: 10));
    expect(db.calls.length, before);
  });
}
