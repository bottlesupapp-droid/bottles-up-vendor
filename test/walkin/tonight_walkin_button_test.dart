import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/walkin/providers/walkin_providers.dart';
import 'package:bottles_up_vendor/features/walkin/screens/walkin_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../table_service/fake_table_backend.dart';
import 'fake_walkin_backend.dart';

late FakeTableBackend tables;
late FakeWalkinBackend walkin;

const managerWs = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [tableServiceServiceProvider.overrideWithValue(tables.service), walkinServiceProvider.overrideWithValue(walkin.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: TonightScreen(workspace: managerWs, clock: friday9pm))),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    tables = FakeTableBackend()..role = 'manager';
    tables.now = DateTime(2026, 10, 9, 21);
    walkin = FakeWalkinBackend();
  });

  testWidgets('tonight offers Add walk-in, and it opens the walk-in screen for this club and tonight\'s date', (tester) async {
    await open(tester);
    final button = find.byKey(const Key('add-walkin'));
    expect(button, findsOneWidget);
    expect(find.byKey(const Key('walkin-tonight-only')), findsNothing);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(WalkinScreen), findsOneWidget);
    expect(walkin.paramsOf('desk_walkin_options').single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
  });

  testWidgets('on another night the button is off and the screen says walk-ins are for tonight', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('night-next')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('add-walkin'))).onPressed, isNull);
    expect(find.byKey(const Key('walkin-tonight-only')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-walkin')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(WalkinScreen), findsNothing);
    expect(walkin.calls, isEmpty);
  });

  testWidgets('after a walk-in is booked, Done returns to Tonight, which is read again', (tester) async {
    await open(tester);
    final before = tables.count('desk_tonight');
    await tester.tap(find.byKey(const Key('add-walkin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('walkin-slot-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('walkin-table-t1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('walkin-name')), 'Ann Guest');
    await tester.enterText(find.byKey(const Key('walkin-email')), 'ann@guest.example');
    await tester.ensureVisible(find.byKey(const Key('walkin-terms')));
    await tester.tap(find.byKey(const Key('walkin-terms')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('walkin-confirm')));
    await tester.tap(find.byKey(const Key('walkin-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('walkin-done')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('walkin-finish')));
    await tester.tap(find.byKey(const Key('walkin-finish')));
    await tester.pumpAndSettle();
    expect(find.byType(WalkinScreen), findsNothing);
    expect(find.text('Club A'), findsOneWidget);
    expect(tables.count('desk_tonight'), greaterThan(before), reason: 'Tonight was read again after the walk-in');
  });
}
