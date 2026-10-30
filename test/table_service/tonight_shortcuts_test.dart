import 'package:bottles_up_vendor/features/chat/providers/chat_providers.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/fake_chat_backend.dart';
import 'fake_table_backend.dart';

// The manager's two shortcuts on Tonight from the brief (section 6): Assign Staff and Send Alert.

late FakeChatBackend chat;
late FakeTableBackend desk;

const manager = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [chatServiceProvider.overrideWithValue(chat.service), tableServiceServiceProvider.overrideWithValue(desk.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: TonightScreen(workspace: manager, clock: () => DateTime(2026, 10, 9, 21)))),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    chat = FakeChatBackend();
    chat.conversations.add(FakeConversation('staff', 'venue', 'Club A', venueId: 'v1', canPin: true));
    desk = FakeTableBackend()..role = 'manager';
    desk.now = DateTime(2026, 10, 9, 21);
  });

  testWidgets('Tonight offers both shortcuts next to the others', (tester) async {
    await open(tester);
    for (final k in ['add-walkin', 'message-team', 'assign-staff', 'send-alert']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.text('Assign staff'), findsOneWidget);
    expect(find.text('Send alert'), findsOneWidget);
  });

  group('Assign staff', () {
    testWidgets('opens the club\'s bookings, where each is given to a server', (tester) async {
      await open(tester);
      await tapKey(tester, 'assign-staff');
      final floor = tester.widget<FloorScreen>(find.byType(FloorScreen));
      expect([floor.venueId, floor.venueName, floor.orgId, floor.showHeading], ['v1', 'Club A', 'o1', false]);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Assign staff')), findsOneWidget);
    });
  });

  group('Send alert', () {
    testWidgets('asks for the words, sends them to the club\'s staff chat, pins them, and says so', (tester) async {
      await open(tester);
      await tapKey(tester, 'send-alert');
      expect(find.text('Alert the staff'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reason-field')), '  Fire door at the back is blocked  ');
      await tapKey(tester, 'reason-confirm');
      final staff = chat.conv('staff');
      expect(staff.messages.single.body, 'Fire door at the back is blocked');
      expect(staff.pinnedId, staff.messages.single.id);
      expect(chat.calledWith('chat_send').single['p_client_key'], 'alert-${DateTime(2026, 10, 9, 21).microsecondsSinceEpoch}');
      expect(find.text('Alert sent. It is pinned at the top of the staff chat.'), findsOneWidget);
    });

    testWidgets('an empty alert is refused in its own words and nothing is sent', (tester) async {
      await open(tester);
      await tapKey(tester, 'send-alert');
      await tapKey(tester, 'reason-confirm');
      expect(find.text('Write the alert first.'), findsOneWidget);
      expect(chat.calls, isEmpty);
    });

    testWidgets('the box stops at 300 characters', (tester) async {
      await open(tester);
      await tapKey(tester, 'send-alert');
      await tester.enterText(find.byKey(const Key('reason-field')), 'x' * 350);
      await tester.pump();
      final field = tester.widget<TextField>(find.byKey(const Key('reason-field')));
      expect(field.maxLength, 300);
      expect(field.controller!.text.length, 300);
    });

    testWidgets('backing out sends nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'send-alert');
      await tapKey(tester, 'reason-back');
      expect(chat.calls, isEmpty);
      expect(find.text('Alert the staff'), findsNothing);
    });

    testWidgets('a club without a staff chat is told so', (tester) async {
      chat.conversations.clear();
      await open(tester);
      await tapKey(tester, 'send-alert');
      await tester.enterText(find.byKey(const Key('reason-field')), 'Fire door at the back is blocked');
      await tapKey(tester, 'reason-confirm');
      expect(find.text('The club\'s staff chat is not set up yet.'), findsOneWidget);
    });

    testWidgets('an alert that was sent but could not be pinned says exactly that', (tester) async {
      chat.conv('staff').canPin = false;
      await open(tester);
      await tapKey(tester, 'send-alert');
      await tester.enterText(find.byKey(const Key('reason-field')), 'Fire door at the back is blocked');
      await tapKey(tester, 'reason-confirm');
      expect(find.text('The alert was sent to the staff chat but could not be pinned. Open the chat to pin it.'), findsOneWidget);
    });

    testWidgets('a lost connection says so plainly', (tester) async {
      await open(tester);
      chat.offline = true;
      await tapKey(tester, 'send-alert');
      await tester.enterText(find.byKey(const Key('reason-field')), 'Fire door at the back is blocked');
      await tapKey(tester, 'reason-confirm');
      expect(find.text('The club\'s staff chat could not be found. Check your connection and try again.'), findsOneWidget);
    });
  });
}
