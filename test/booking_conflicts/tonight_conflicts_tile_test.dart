import 'package:bottles_up_vendor/features/booking_conflicts/providers/conflict_providers.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../table_service/fake_table_backend.dart';
import 'fake_conflict_backend.dart';

late FakeConflictBackend conflicts;
late FakeTableBackend desk;

const manager = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [bookingConflictServiceProvider.overrideWithValue(conflicts.service), tableServiceServiceProvider.overrideWithValue(desk.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: TonightScreen(workspace: manager, clock: () => DateTime(2026, 10, 9, 21)))),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

String count(WidgetTester tester, String tileKey) =>
    tester.widgetList<Text>(find.descendant(of: find.byKey(Key(tileKey)), matching: find.byType(Text))).map((t) => t.data!).last;

void main() {
  setUp(() {
    conflicts = FakeConflictBackend();
    desk = FakeTableBackend()..role = 'manager';
    desk.now = DateTime(2026, 10, 9, 21);
  });

  testWidgets('nothing double-booked shows a zero and no note', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('tile-conflicts')), findsOneWidget);
    expect(count(tester, 'tile-conflicts'), '0');
    expect(find.text('Double-booked tables'), findsOneWidget);
    expect(find.textContaining('Guests who paid after their table had gone'), findsNothing);
  });

  testWidgets('the count is how many are waiting for the manager, and the note says what it means', (tester) async {
    conflicts.add('k1');
    conflicts.add('k2');
    conflicts.add('k3', status: 'resolved');
    conflicts.add('k4', venue: 'v2');
    await open(tester);
    expect(count(tester, 'tile-conflicts'), '2');
    expect(find.text('Guests who paid after their table had gone. They have no confirmation yet.'), findsOneWidget);
    expect(conflicts.calls.first.$2, {'p_venue': 'v1', 'p_include_resolved': false});
  });

  testWidgets('tapping the tile opens the list of them', (tester) async {
    conflicts.add('k1', name: 'Late Payer');
    await open(tester);
    await tester.ensureVisible(find.byKey(const Key('tile-conflicts')));
    await tester.tap(find.byKey(const Key('tile-conflicts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conflict-k1')), findsOneWidget);
    expect(find.text('Late Payer'), findsOneWidget);
  });

  testWidgets('on a server without the migration there is no tile and the rest of Tonight shows', (tester) async {
    conflicts.failAll = PostgrestExceptionFor.missing();
    await open(tester);
    expect(find.byKey(const Key('tile-conflicts')), findsNothing);
    expect(find.byKey(const Key('tile-payments')), findsOneWidget);
  });
}
