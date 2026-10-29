import 'package:bottles_up_vendor/features/discounts/providers/discount_providers.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../table_service/fake_table_backend.dart';
import 'fake_discount_backend.dart';

late FakeDiscountBackend discounts;
late FakeTableBackend desk;

const manager = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [discountServiceProvider.overrideWithValue(discounts.service), tableServiceServiceProvider.overrideWithValue(desk.service)],
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
    discounts = FakeDiscountBackend()..role = 'manager';
    discounts.limits = {'server_max_percent': 10, 'manager_max_percent': 25, 'server_free_bottles_per_night': 2, 'manager_free_bottles_per_night': 4, 'allow_stacking': false};
    discounts.addBooking('b1');
    desk = FakeTableBackend()..role = 'manager';
    desk.now = DateTime(2026, 10, 9, 21);
  });

  testWidgets('nothing waiting shows a zero, not attention', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('tile-approvals')), findsOneWidget);
    expect(count(tester, 'tile-approvals'), '0');
    expect(find.text('Discounts and free bottles waiting for approval'), findsOneWidget);
  });

  testWidgets('the count is how many are waiting, and the note says how many are this person\'s to decide', (tester) async {
    discounts.addConcession('b1', amount: 4000, percent: 20); // within a manager's limit
    discounts.addConcession('b1', amount: 10000, percent: 50); // above it: the owner decides
    discounts.addConcession('b1', by: 'u-me', byRole: 'manager', amount: 1000, percent: 5); // their own
    await open(tester);
    expect(count(tester, 'tile-approvals'), '3');
    expect(find.text('1 of them you can decide.'), findsOneWidget);
  });

  testWidgets('when none of them is theirs to decide it says so', (tester) async {
    discounts.addConcession('b1', amount: 10000, percent: 50);
    await open(tester);
    expect(find.text('None of them is yours to decide.'), findsOneWidget);
  });

  testWidgets('when all of them can be decided there is no note', (tester) async {
    discounts.addConcession('b1', amount: 4000, percent: 20);
    await open(tester);
    expect(find.textContaining('you can decide'), findsNothing);
    expect(find.textContaining('yours to decide'), findsNothing);
  });

  testWidgets('tapping the tile opens the waiting requests', (tester) async {
    final c = discounts.addConcession('b1', amount: 4000, percent: 20);
    await open(tester);
    await tester.ensureVisible(find.byKey(const Key('tile-approvals')));
    await tester.tap(find.byKey(const Key('tile-approvals')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('pending-${c.id}')), findsOneWidget);
  });

  testWidgets('on a server without the functions there is no tile and the rest of Tonight shows', (tester) async {
    discounts.failAll = Exception('boom');
    await open(tester);
    expect(find.byKey(const Key('tile-approvals')), findsNothing);
    expect(find.byKey(const Key('tile-payments')), findsOneWidget);
  });
}
