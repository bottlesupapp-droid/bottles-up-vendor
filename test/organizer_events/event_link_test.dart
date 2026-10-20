import 'package:bottles_up_vendor/features/door_staff/providers/door_staff_providers.dart';
import 'package:bottles_up_vendor/features/door_staff/screens/organizer_team_screen.dart';
import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/organizer_events/screens/organizer_events_screen.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../door_staff/fake_door_staff_backend.dart';
import '../owner/fake_setup_backend.dart' show FakeMedia;
import 'fake_organizer_events_backend.dart';

const orgWs = Workspace(membershipId: 'm-g', orgId: 'o1', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);

void main() {
  late FakeOrganizerEventsBackend db;
  late List<String?> clipboard;
  late bool clipboardWorks;

  setUp(() {
    db = FakeOrganizerEventsBackend();
    clipboard = [];
    clipboardWorks = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (!clipboardWorks) throw PlatformException(code: 'denied');
        clipboard.add((call.arguments as Map)['text'] as String?);
      }
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  group('the rules', () {
    test('the public link of an event is the site address and /events/<id>', () {
      expect(eventLink('e1'), 'https://www.bottlesupapp.com/events/e1');
      expect(eventLink('e1', site: 'https://staging.example.com/'), 'https://staging.example.com/events/e1');
      expect(eventLink('e1', site: 'https://staging.example.com'), 'https://staging.example.com/events/e1');
    });

    test('only exactly "published" is live; a draft, an unknown or a future status is not', () {
      OrgEvent parse(String? status) => parseOrgEvent({'event_id': 'e', 'title': 'T', 'start_date': '2031-01-01T00:00:00Z', 'status': status})!;
      expect(parse('published').isLive, isTrue);
      expect(parse('draft').isLive, isFalse);
      expect(parse('cancelled').isLive, isFalse, reason: 'it is read as published for editing, but it must not get a public link');
      expect(parse('Published').isLive, isFalse);
      expect(parse(null).isLive, isFalse);
      expect(parse('cancelled').status, OrgEventStatus.published);
    });
  });

  group('the screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [organizerEventsServiceProvider.overrideWithValue(db.service), mediaServiceProvider.overrideWithValue(FakeMedia().service)],
        child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: OrganizerEventsScreen(workspace: orgWs, clock: () => DateTime(2031, 10, 24, 12)))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a live event offers Copy event link; a draft and an odd status do not', (tester) async {
      db.events.addAll([eventRow('d', 'Draft party'), eventRow('p', 'Live night', status: 'published'), eventRow('x', 'Odd one', status: 'cancelled')]);
      await open(tester);
      expect(find.byKey(const Key('copy-link-p')), findsOneWidget);
      expect(find.byKey(const Key('copy-link-d')), findsNothing);
      expect(find.byKey(const Key('copy-link-x')), findsNothing);
    });

    testWidgets('Invite door staff opens the organizer\'s door staff screen, and Back returns to the events', (tester) async {
      final doors = FakeDoorStaffBackend();
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          organizerEventsServiceProvider.overrideWithValue(db.service),
          mediaServiceProvider.overrideWithValue(FakeMedia().service),
          doorStaffServiceProvider.overrideWithValue(doors.doorService),
          teamServiceProvider.overrideWithValue(doors.teamService),
        ],
        child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: OrganizerEventsScreen(workspace: orgWs, clock: () => DateTime(2031, 10, 24, 12)))),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(OrganizerTeamScreen), findsNothing);
      await tester.tap(find.byKey(const Key('invite-team')));
      await tester.pumpAndSettle();
      expect(find.byType(OrganizerTeamScreen), findsOneWidget);
      expect(find.text('Door staff'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(OrganizerTeamScreen), findsNothing);
      expect(find.byKey(const Key('create-event')), findsOneWidget);
    });

    testWidgets('Copy puts exactly the event\'s public link on the clipboard and says so', (tester) async {
      db.events.add(eventRow('p', 'Live night', status: 'published'));
      await open(tester);
      await tester.tap(find.byKey(const Key('copy-link-p')));
      await tester.pumpAndSettle();
      expect(clipboard, ['https://www.bottlesupapp.com/events/p']);
      expect(find.text('Link copied. Anyone with it can open the event page.'), findsOneWidget);
    });

    testWidgets('when the phone refuses to copy, the link is shown so it can be typed or read out', (tester) async {
      db.events.add(eventRow('p', 'Live night', status: 'published'));
      clipboardWorks = false;
      await open(tester);
      await tester.tap(find.byKey(const Key('copy-link-p')));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be copied'), findsOneWidget);
      expect(find.textContaining('https://www.bottlesupapp.com/events/p'), findsOneWidget);
    });
  });
}
