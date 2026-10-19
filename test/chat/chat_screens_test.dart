import 'package:bottles_up_vendor/features/chat/logic/chat_rules.dart';
import 'package:bottles_up_vendor/features/chat/providers/chat_providers.dart';
import 'package:bottles_up_vendor/features/chat/screens/chat_screen.dart';
import 'package:bottles_up_vendor/features/chat/screens/chat_thread_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_backend.dart';

late FakeChatBackend db;

Workspace ws({WorkspaceRole role = WorkspaceRole.server, String? venueId = 'v1', String? eventId}) => Workspace(
      membershipId: 'w1',
      orgId: 'o1',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: role,
      venueId: venueId,
      venueName: venueId == null ? null : 'Club A',
      eventId: eventId,
    );

DateTime fridayNight() => DateTime(2026, 10, 9, 22, 0);

Widget host(Widget child, {Duration poll = const Duration(hours: 1)}) => ProviderScope(
      key: UniqueKey(),
      overrides: [chatServiceProvider.overrideWithValue(db.service), chatPollIntervalProvider.overrideWithValue(poll)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child, {Duration poll = const Duration(hours: 1), double height = 3000}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child, poll: poll));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<ChatConversation> conversationOf(String id) async => (await db.service.conversations()).firstWhere((c) => c.id == id);

Future<Widget> thread(String id, {WorkspaceRole role = WorkspaceRole.server}) async =>
    ChatThreadScreen(conversation: await conversationOf(id), role: role, clock: fridayNight);

Finder text(String t) => find.text(t);

void main() {
  setUp(() {
    db = FakeChatBackend()..now = DateTime.utc(2026, 10, 9, 21, 0);
    db.conversations
      ..add(FakeConversation('c1', 'venue', 'Club A', venueId: 'v1', members: {'me', 'sam', 'mia'}))
      ..add(FakeConversation('c2', 'venue', 'Club B', venueId: 'v2'))
      ..add(FakeConversation('e1', 'event', 'Night One', eventId: 'ev1', deleteAfter: DateTime.utc(2026, 10, 25, 12)));
    db.people['v1'] = [(id: 'sam', name: 'Sam Server', role: 'server'), (id: 'mia', name: 'Mia Manager', role: 'manager')];
  });

  Widget list({Workspace? workspace}) => ChatScreen(workspace: workspace ?? ws(), clock: fridayNight);

  group('Chat list', () {
    testWidgets('lists the club chat and the event chat with the last message and the unread count', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice', ago: const Duration(minutes: 30));
      db.add('c1', 'mia', 'Mia Manager', 'On it', ago: const Duration(minutes: 20));
      db.add('e1', 'mia', 'Mia Manager', 'Doors at 9', ago: const Duration(days: 1));
      await open(tester, list());
      expect(find.byKey(const Key('chat-row-c1')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chat-row-c1')), matching: text('Club A')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('chat-row-c1')), matching: text('Club staff')), findsOneWidget);
      expect(text('Mia Manager: On it'), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('chat-unread-c1')), matching: find.byType(Text))).data, '2');
      expect(find.byKey(const Key('chat-unread-e1')), findsOneWidget);
      expect(text('This chat is deleted on 25 Oct 2026.'), findsOneWidget, reason: 'an event chat says when it goes');
    });

    testWidgets('another club\'s chat is not in this club\'s workspace, and a chat with no messages says so', (tester) async {
      db.conversations.firstWhere((c) => c.id == 'c2').members.add('me');
      await open(tester, list());
      expect(find.byKey(const Key('chat-row-c1')), findsOneWidget);
      expect(find.byKey(const Key('chat-row-c2')), findsNothing);
      expect(text('No messages yet'), findsWidgets);
      expect(find.byKey(const Key('chat-unread-c1')), findsNothing);
    });

    testWidgets('nothing yet is said in words', (tester) async {
      db.revoked = true;
      await open(tester, list());
      expect(find.byKey(const Key('chat-empty')), findsOneWidget);
    });

    testWidgets('a backend without chat says it is not available yet and offers no retry; a dropped connection offers Try again', (tester) async {
      db.missing = true;
      await open(tester, list());
      expect(find.byKey(const Key('chat-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.offline = true;
      await open(tester, list());
      expect(find.byKey(const Key('ops-retry')), findsOneWidget);
      db.offline = false;
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('chat-row-c1')), findsOneWidget);
    });

    testWidgets('a new message from someone else shows up at the next look without blanking the list', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'first', ago: const Duration(minutes: 5));
      await open(tester, list(), poll: const Duration(seconds: 6));
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('chat-unread-c1')), matching: find.byType(Text))).data, '1');
      db.add('c1', 'sam', 'Sam Server', 'second');
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('chat-unread-c1')), matching: find.byType(Text))).data, '2');
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: 'the list was not blanked to look again');
    });

    testWidgets('a failed look keeps the list and says it is trying again; the next good look clears it', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'first', ago: const Duration(minutes: 5));
      await open(tester, list(), poll: const Duration(seconds: 6));
      db.offline = true;
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(find.byKey(const Key('chat-stale')), findsOneWidget);
      expect(find.byKey(const Key('chat-row-c1')), findsOneWidget);
      db.offline = false;
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(find.byKey(const Key('chat-stale')), findsNothing);
    });

    testWidgets('revoking someone\'s access takes the chat out of their list at the next look', (tester) async {
      await open(tester, list(), poll: const Duration(seconds: 6));
      expect(find.byKey(const Key('chat-row-c1')), findsOneWidget);
      db.revoked = true;
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(find.byKey(const Key('chat-row-c1')), findsNothing);
    });

    testWidgets('opening a chat shows it, and coming back shows it read', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice', ago: const Duration(minutes: 5));
      await open(tester, list());
      expect(find.byKey(const Key('chat-unread-c1')), findsOneWidget);
      await tapKey(tester, 'chat-row-c1');
      expect(find.byKey(const Key('chat-thread')), findsOneWidget);
      expect(text('Table 4 needs ice'), findsOneWidget);
      expect(db.calledWith('chat_mark_read').single, {'p_conversation': 'c1'});
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-unread-c1')), findsNothing);
    });
  });

  group('Starting a direct message', () {
    testWidgets('pick a colleague at the club, and the chat opens', (tester) async {
      await open(tester, list());
      await tapKey(tester, 'chat-new');
      expect(find.byKey(const Key('chat-person-sam')), findsOneWidget);
      expect(find.byKey(const Key('chat-person-mia')), findsOneWidget);
      expect(db.calledWith('chat_people').single, {'p_venue': 'v1'});
      await tapKey(tester, 'chat-person-sam');
      expect(db.calledWith('chat_start_direct').single, {'p_other': 'sam'});
      expect(find.byKey(const Key('chat-thread')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: text('Sam Server')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: text('Direct message')), findsOneWidget);
    });

    testWidgets('the database refusing is said in its own words', (tester) async {
      db.people['v1']!.add((id: 'zed', name: 'Zed', role: 'server'));
      db.people['v9'] = [(id: 'zed', name: 'Zed', role: 'server')];
      db.people['v1']!.removeWhere((p) => p.id == 'zed');
      // 'zed' is listed by the picker but is not a colleague by the time the chat is started.
      db.people['v1']!.add((id: 'ghost', name: 'Ghost', role: 'server'));
      await open(tester, list());
      await tapKey(tester, 'chat-new');
      db.people['v1']!.removeWhere((p) => p.id == 'ghost');
      db.people['v9'] = [];
      await tapKey(tester, 'chat-person-ghost');
      expect(text('You can only message people you work with.'), findsOneWidget);
      expect(find.byKey(const Key('chat-thread')), findsNothing);
    });

    testWidgets('an owner of two clubs is asked which club first', (tester) async {
      db.conversations.firstWhere((c) => c.id == 'c2').members.add('me');
      db.people['v2'] = [(id: 'bob', name: 'Bob Barback', role: 'server')];
      await open(tester, list(workspace: ws(role: WorkspaceRole.owner, venueId: null)));
      await tapKey(tester, 'chat-new');
      expect(find.byKey(const Key('chat-venue-v1')), findsOneWidget);
      expect(find.byKey(const Key('chat-venue-v2')), findsOneWidget);
      await tapKey(tester, 'chat-venue-v2');
      expect(find.byKey(const Key('chat-person-bob')), findsOneWidget);
      expect(find.byKey(const Key('chat-person-sam')), findsNothing, reason: 'the people of the club that was chosen');
    });

    testWidgets('no one else at the club is said in words', (tester) async {
      db.people['v1'] = [];
      await open(tester, list());
      await tapKey(tester, 'chat-new');
      expect(find.byKey(const Key('chat-people-empty')), findsOneWidget);
    });

    testWidgets('a person with only an event workspace and no club chat is not offered a way to start one', (tester) async {
      db.conversations.removeWhere((c) => c.kind == 'venue');
      await open(tester, list(workspace: ws(role: WorkspaceRole.door, venueId: null, eventId: 'ev1')));
      expect(find.byKey(const Key('chat-new')), findsNothing);
    });
  });

  group('A conversation', () {
    testWidgets('shows what was said, others by name and one\'s own without, newest at the bottom', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice', ago: const Duration(minutes: 30));
      db.add('c1', 'me', 'Me', 'On it', ago: const Duration(minutes: 20));
      await open(tester, await thread('c1'));
      expect(text('Sam Server'), findsOneWidget);
      expect(text('Table 4 needs ice'), findsOneWidget);
      expect(text('On it'), findsOneWidget);
      expect(tester.getTopLeft(text('Table 4 needs ice')).dy, lessThan(tester.getTopLeft(text('On it')).dy));
      expect(find.text('Me'), findsNothing, reason: 'your own messages do not carry your name');
    });

    testWidgets('an empty chat invites the first message', (tester) async {
      await open(tester, await thread('c1'));
      expect(find.byKey(const Key('chat-thread-empty')), findsOneWidget);
    });

    testWidgets('typing and sending adds the message, clears the box and sends a key', (tester) async {
      await open(tester, await thread('c1'));
      await typeIn(tester, 'chat-input', '  Ice to table 4  ');
      await tapKey(tester, 'chat-send');
      expect(text('Ice to table 4'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text, isEmpty);
      final sent = db.calledWith('chat_send').single;
      expect(sent['p_conversation'], 'c1');
      expect(sent['p_body'], 'Ice to table 4');
      expect((sent['p_client_key'] as String).isNotEmpty, isTrue);
      expect(find.byKey(const Key('chat-pending-0')), findsNothing, reason: 'confirmed, no longer pending');
    });

    testWidgets('an empty message is not sent; a message over 2000 characters is not sent; the box keeps what was typed', (tester) async {
      await open(tester, await thread('c1'));
      await typeIn(tester, 'chat-input', '   ');
      await tapKey(tester, 'chat-send');
      expect(text('Write a message first.'), findsOneWidget);
      await typeIn(tester, 'chat-input', 'x' * 2001);
      await tapKey(tester, 'chat-send');
      expect(text('Keep a message to 2000 characters or fewer.'), findsOneWidget);
      expect(db.calledWith('chat_send'), isEmpty);
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text.length, 2001);
    });

    testWidgets('a message that fails stays as "Not sent" and Retry sends it', (tester) async {
      await open(tester, await thread('c1'));
      db.failNextSends = 1;
      await typeIn(tester, 'chat-input', 'Ice to table 4');
      await tapKey(tester, 'chat-send');
      expect(find.byKey(const Key('chat-failed-0')), findsOneWidget);
      expect(find.textContaining('Not sent.'), findsOneWidget);
      expect(db.conv('c1').messages, isEmpty);
      await tapKey(tester, 'chat-retry-0');
      expect(find.byKey(const Key('chat-failed-0')), findsNothing);
      expect(db.conv('c1').messages.map((m) => m.body), ['Ice to table 4']);
    });

    testWidgets('a retry after the answer was lost is the same message, never a second copy', (tester) async {
      await open(tester, await thread('c1'));
      db.loseNextAnswer = true;
      await typeIn(tester, 'chat-input', 'Ice to table 4');
      await tapKey(tester, 'chat-send');
      expect(find.byKey(const Key('chat-failed-0')), findsOneWidget, reason: 'the app does not know it arrived');
      expect(db.conv('c1').messages, hasLength(1), reason: 'but it did');
      await tapKey(tester, 'chat-retry-0');
      expect(db.conv('c1').messages, hasLength(1));
      expect(db.calledWith('chat_send').map((c) => c['p_client_key']).toSet(), hasLength(1), reason: 'both tries carried the same key');
      expect(text('Ice to table 4'), findsOneWidget);
    });

    testWidgets('a message can be discarded instead', (tester) async {
      await open(tester, await thread('c1'));
      db.failNextSends = 1;
      await typeIn(tester, 'chat-input', 'never mind');
      await tapKey(tester, 'chat-send');
      await tapKey(tester, 'chat-discard-0');
      expect(text('never mind'), findsNothing);
    });

    testWidgets('being slowed down is shown on the message, with the database\'s sentence', (tester) async {
      for (var i = 0; i < 30; i++) {
        db.add('c1', 'me', 'Me', 'spam $i', ago: const Duration(seconds: 10));
      }
      await open(tester, await thread('c1'));
      await typeIn(tester, 'chat-input', 'one more');
      await tapKey(tester, 'chat-send');
      expect(find.textContaining('Slow down: you are sending messages too fast.'), findsOneWidget);
    });

    testWidgets('earlier messages load a page at a time', (tester) async {
      for (var i = 0; i < 70; i++) {
        db.add('c1', 'sam', 'Sam Server', 'm$i', ago: Duration(minutes: 100 - i));
      }
      await open(tester, await thread('c1'), height: 9000);
      final container = ProviderScope.containerOf(tester.element(find.byType(ChatThreadScreen)));
      expect(container.read(chatThreadProvider('c1')).messages, hasLength(50));
      expect(db.calledWith('chat_messages').first['p_limit'], 50);
      await tester.scrollUntilVisible(find.byKey(const Key('chat-load-earlier')), 500, scrollable: find.byType(Scrollable).first);
      await tapKey(tester, 'chat-load-earlier');
      expect(container.read(chatThreadProvider('c1')).messages, hasLength(70));
      expect(container.read(chatThreadProvider('c1')).hasMore, isFalse);
      expect(find.byKey(const Key('chat-load-earlier')), findsNothing, reason: 'nothing earlier is left');
    });

    testWidgets('new messages from others arrive while it is open, and are marked read', (tester) async {
      await open(tester, await thread('c1'), poll: const Duration(seconds: 6));
      expect(db.calledWith('chat_mark_read'), isEmpty, reason: 'nothing to read yet');
      db.add('c1', 'sam', 'Sam Server', 'Ice please');
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(text('Ice please'), findsOneWidget);
      expect(db.calledWith('chat_mark_read'), isNotEmpty);
    });

    testWidgets('a failed refresh keeps the messages and says it is trying again', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice');
      await open(tester, await thread('c1'), poll: const Duration(seconds: 6));
      db.offline = true;
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(find.byKey(const Key('chat-stale')), findsOneWidget);
      expect(text('Table 4 needs ice'), findsOneWidget);
      db.offline = false;
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-stale')), findsNothing);
    });

    testWidgets('losing access while it is open ends it: a sentence, no message box', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice');
      await open(tester, await thread('c1'), poll: const Duration(seconds: 6));
      db.revoked = true;
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-thread-error')), findsOneWidget);
      expect(find.byKey(const Key('chat-input')), findsNothing);
      expect(find.byKey(const Key('chat-thread-retry')), findsNothing, reason: 'trying again will not bring access back');
    });

    testWidgets('a thread that cannot load says what happened and loads on Try again', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice');
      final screen = await thread('c1');
      db.offline = true;
      await open(tester, screen);
      expect(find.byKey(const Key('chat-thread-error')), findsOneWidget);
      db.offline = false;
      await tapKey(tester, 'chat-thread-retry');
      expect(text('Table 4 needs ice'), findsOneWidget);
    });

    testWidgets('an event chat says when it is deleted', (tester) async {
      await open(tester, await thread('e1', role: WorkspaceRole.door));
      expect(text('This chat is deleted on 25 Oct 2026.'), findsOneWidget);
    });
  });

  group('Pinning', () {
    testWidgets('a manager pins a message with a long press; everyone sees it at the top; the X unpins', (tester) async {
      db.conv('c1').canPin = true;
      db.add('c1', 'me', 'Me', 'Doors at 9, ID check on everyone', ago: const Duration(minutes: 5));
      await open(tester, await thread('c1', role: WorkspaceRole.manager));
      expect(find.byKey(const Key('chat-pinned')), findsNothing);
      await tester.longPress(find.text('Doors at 9, ID check on everyone'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'chat-pin-action');
      expect(find.byKey(const Key('chat-pinned')), findsOneWidget);
      expect(db.calledWith('chat_pin').single['p_message'], isNotNull);
      expect((await conversationOf('c1')).pinnedBody, 'Doors at 9, ID check on everyone');
      await tapKey(tester, 'chat-unpin');
      expect(find.byKey(const Key('chat-pinned')), findsNothing);
      expect(db.calledWith('chat_pin').last['p_message'], isNull);
    });

    testWidgets('the instruction already pinned shows the moment the chat opens', (tester) async {
      final m = db.add('c1', 'mia', 'Mia Manager', 'Doors at 9');
      db.conv('c1').pinnedId = m.id;
      await open(tester, await thread('c1'));
      expect(find.descendant(of: find.byKey(const Key('chat-pinned')), matching: text('Doors at 9')), findsOneWidget);
      expect(find.byKey(const Key('chat-unpin')), findsNothing, reason: 'a server cannot unpin');
    });

    testWidgets('a server is not offered the pin menu; the database would refuse them anyway', (tester) async {
      db.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice');
      await open(tester, await thread('c1'));
      await tester.longPress(find.text('Table 4 needs ice'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-pin-action')), findsNothing);
    });

    testWidgets('when the database refuses a pin, the person is told and nothing is pinned', (tester) async {
      db.add('c1', 'me', 'Me', 'Doors at 9');
      await open(tester, await thread('c1', role: WorkspaceRole.manager));
      await tester.longPress(find.text('Doors at 9'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'chat-pin-action');
      expect(text("You don't have access to do that."), findsOneWidget);
      expect(find.byKey(const Key('chat-pinned')), findsNothing);
    });
  });
}
