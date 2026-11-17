import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/features/workspace/logic/context_night.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/widgets/workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The night in the bar at the top of every workspace (brief: "Keep the active venue, event, and night visible on every operational screen"). It is the same business night that Tonight and
// the bookings use: before 06:00 it is still the previous night. An event workspace names the event instead.

const manager = Workspace(membershipId: 'm1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'm2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const door = Workspace(membershipId: 'm3', orgId: 'p', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.door, eventId: 'e1', eventTitle: 'Promoter Night');

void main() {
  group('the night line', () {
    test('after 06:00 it is that day\'s night, and says which', () {
      expect(contextNightLine(manager, DateTime(2026, 10, 9, 21, 30)), 'Night of Fri 9 Oct');
      expect(contextNightLine(manager, DateTime(2026, 10, 10, 6, 0, 0)), 'Night of Sat 10 Oct');
    });

    test('before 06:00 it is still the previous night', () {
      expect(contextNightLine(manager, DateTime(2026, 10, 10, 2, 30)), 'Night of Fri 9 Oct');
      expect(contextNightLine(manager, DateTime(2026, 10, 10, 5, 59, 59)), 'Night of Fri 9 Oct');
      expect(contextNightLine(manager, DateTime(2026, 10, 1, 0, 5)), 'Night of Wed 30 Sep', reason: 'across a month');
    });

    test('an owner of every club has one too; a workspace for one event names the event instead', () {
      expect(contextNightLine(owner, DateTime(2026, 10, 9, 21)), 'Night of Fri 9 Oct');
      expect(contextNightLine(door, DateTime(2026, 10, 9, 21)), isNull);
    });
  });

  group('in the bar', () {
    Future<void> show(WidgetTester tester, Workspace w, DateTime now) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: Align(alignment: Alignment.topCenter, child: WorkspaceContextBar(workspace: w, canSwitch: false, onSwitch: () {}, onSignOut: () {}, clock: () => now))),
        ),
      );
      await tester.pump();
    }

    testWidgets('a venue workspace shows the club and the night', (tester) async {
      await show(tester, manager, DateTime(2026, 10, 9, 22));
      expect(find.text('Manager · Club Co'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('context-night'))).data, 'Night of Fri 9 Oct');
    });

    testWidgets('at 02:00 it still says the night that began the evening before', (tester) async {
      await show(tester, manager, DateTime(2026, 10, 10, 2));
      expect(tester.widget<Text>(find.byKey(const Key('context-night'))).data, 'Night of Fri 9 Oct');
    });

    testWidgets('an event workspace shows the event and no night line', (tester) async {
      await show(tester, door, DateTime(2026, 10, 9, 22));
      expect(find.text('Promoter Night'), findsOneWidget);
      expect(find.byKey(const Key('context-night')), findsNothing);
    });

    testWidgets('the bar does not overflow on a small phone with a long club name', (tester) async {
      const long = Workspace(
        membershipId: 'm4',
        orgId: 'o1',
        orgName: 'The Very Long Hospitality Group Of Toronto',
        orgKind: 'venue_owner',
        role: WorkspaceRole.manager,
        venueId: 'v1',
        venueName: 'The Extremely Long Named Rooftop Lounge And Supper Club',
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Align(alignment: Alignment.topCenter, child: WorkspaceContextBar(workspace: long, canSwitch: true, onSwitch: () {}, onSignOut: () {}, clock: () => DateTime(2026, 10, 9, 22))),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('context-night')), findsOneWidget);
    });
  });
}
