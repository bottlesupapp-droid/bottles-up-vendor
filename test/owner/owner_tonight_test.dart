import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/owner_tonight_screen.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../table_service/fake_table_backend.dart';

const ownerWs = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

late FakeTableBackend db;
late Future<List<OrgVenue>> Function() venues;

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        tableServiceServiceProvider.overrideWithValue(db.service),
        ownerVenuesProvider.overrideWith((ref, org) => venues()),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: OwnerTonightScreen(workspace: ownerWs, clock: friday9pm))),
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
    db = FakeTableBackend()..role = 'manager';
    db.now = DateTime(2026, 10, 9, 21);
    venues = () async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published')];
  });

  testWidgets('an owner with one venue lands straight on Tonight for it, with no picker', (tester) async {
    await open(tester);
    expect(find.byType(TonightScreen), findsOneWidget);
    expect(find.byKey(const Key('owner-tonight-venues')), findsNothing);
    expect(db.params.single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
    expect(find.text('Club A'), findsOneWidget);
  });

  testWidgets('with several venues the first is open and the others are one tap away; the night is asked again for the one chosen', (tester) async {
    venues = () async => const [
          OrgVenue(id: 'v1', name: 'Club A', status: 'published'),
          OrgVenue(id: 'v2', name: 'Club B', status: 'draft'),
        ];
    await open(tester);
    expect(db.params.last?['p_venue'], 'v1');
    expect(find.byKey(const Key('owner-tonight-venues')), findsOneWidget);

    await tester.tap(find.byKey(const Key('owner-tonight-venue-v2')));
    await tester.pumpAndSettle();

    expect(db.params.last, {'p_venue': 'v2', 'p_night': '2026-10-09'});
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('owner-tonight-venue-v2'))).selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('owner-tonight-venue-v1'))).selected, isFalse);
  });

  testWidgets('a different venue is a fresh screen: nothing in progress for one venue can carry over to another', (tester) async {
    venues = () async => const [
          OrgVenue(id: 'v1', name: 'Club A', status: 'published'),
          OrgVenue(id: 'v2', name: 'Club B', status: 'draft'),
        ];
    await open(tester);
    final before = tester.state(find.byType(TonightScreen));
    await tester.tap(find.byKey(const Key('owner-tonight-venue-v2')));
    await tester.pumpAndSettle();
    expect(identical(before, tester.state(find.byType(TonightScreen))), isFalse);
  });

  testWidgets('an owner with no venue is told what to do next, not shown an empty night', (tester) async {
    venues = () async => const [];
    await open(tester);
    expect(find.byKey(const Key('owner-tonight-empty')), findsOneWidget);
    expect(find.byType(TonightScreen), findsNothing);
    expect(db.functions, isEmpty);
  });

  testWidgets('a failed request is said in plain words with a way to try again, and is not shown as an empty night', (tester) async {
    var fail = true;
    venues = () async {
      if (fail) throw StateError('relation "site_venues" does not exist');
      return const [OrgVenue(id: 'v1', name: 'Club A', status: 'published')];
    };
    await open(tester);
    expect(find.byKey(const Key('owner-tonight-error')), findsOneWidget);
    expect(find.textContaining('relation'), findsNothing);
    expect(find.byKey(const Key('owner-tonight-empty')), findsNothing);

    fail = false;
    await tester.tap(find.byKey(const Key('owner-tonight-retry')));
    await tester.pumpAndSettle();
    expect(find.byType(TonightScreen), findsOneWidget);
  });

  test('a workspace looking at one venue keeps everything else about the person\'s access', () {
    final w = ownerWs.atVenue('v9', 'Club Nine');
    expect(w.venueId, 'v9');
    expect(w.venueName, 'Club Nine');
    expect(w.role, WorkspaceRole.owner);
    expect(w.membershipId, 'w1');
    expect(w.orgId, 'o1');
    expect(ownerWs.venueId, isNull, reason: 'the owner\'s own workspace is not changed');
  });
}
