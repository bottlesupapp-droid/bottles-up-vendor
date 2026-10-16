import 'package:bottles_up_vendor/features/chat/logic/chat_rules.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_backend.dart';

void main() {
  late FakeChatBackend db;
  setUp(() {
    db = FakeChatBackend();
    db.conversations.add(FakeConversation('c1', 'venue', 'Club A', venueId: 'v1', members: {'me', 'sam', 'mia'}));
    db.conversations.add(FakeConversation('c2', 'venue', 'Club B', venueId: 'v2', members: {'mia'}));
    db.people['v1'] = [(id: 'sam', name: 'Sam Server', role: 'server'), (id: 'mia', name: 'Mia Manager', role: 'manager')];
  });

  test('only the chats the person is in come back, with unread counts that leave out their own messages', () async {
    db.add('c1', 'sam', 'Sam Server', 'Table 4 needs ice', ago: const Duration(minutes: 5));
    db.add('c1', 'me', 'Me', 'on it', ago: const Duration(minutes: 4));
    final chats = await db.service.conversations();
    expect(chats.map((c) => c.id), ['c1'], reason: 'Club B is not theirs');
    expect(chats.single.unread, 1);
    expect(chats.single.lastPreview, 'on it');
  });

  test('messages are asked for with the conversation, the cut-off and the page size, newest first', () async {
    for (var i = 0; i < 5; i++) {
      db.add('c1', 'sam', 'Sam Server', 'm$i', ago: Duration(minutes: 10 - i));
    }
    final page = await db.service.messages('c1', limit: 2);
    expect(db.calledWith('chat_messages').single, {'p_conversation': 'c1', 'p_before': null, 'p_limit': 2});
    expect(page.map((m) => m.body), ['m4', 'm3']);
    final older = await db.service.messages('c1', before: page.last.createdAt, limit: 2);
    expect(db.calledWith('chat_messages').last['p_before'], page.last.createdAt.toUtc().toIso8601String());
    expect(older.map((m) => m.body), ['m2', 'm1']);
  });

  test('sending passes the key; the same key again is the same message', () async {
    final first = await db.service.send('c1', '  hello  ', 'k1');
    final again = await db.service.send('c1', 'hello', 'k1');
    expect(again, first);
    expect(db.conv('c1').messages, hasLength(1));
    expect(db.conv('c1').messages.single.body, 'hello', reason: 'trimmed');
    expect(db.calledWith('chat_send').first, {'p_conversation': 'c1', 'p_body': '  hello  ', 'p_client_key': 'k1'});
  });

  test('refusals are the database\'s own sentences', () async {
    Future<void> expectRefusal(Future<Object?> f, String message) =>
        expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));
    await expectRefusal(db.service.send('c2', 'hi', 'k'), "You don't have access to do that.");
    await expectRefusal(db.service.send('c1', '   ', 'k'), 'Write a message first.');
    await expectRefusal(db.service.send('c1', 'x' * 2001, 'k'), 'Keep a message to 2000 characters or fewer.');
    await expectRefusal(db.service.send('nope', 'hi', 'k'), "You don't have access to do that.");
  });

  test('the 31st message in a minute is slowed, with the database\'s sentence', () async {
    for (var i = 0; i < 30; i++) {
      await db.service.send('c1', 'spam $i', 'k$i');
    }
    await expectLater(
      db.service.send('c1', 'spam 30', 'k30'),
      throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'Slow down: you are sending messages too fast.')),
    );
    expect(await db.service.send('c1', 'spam 29', 'k29'), isNotEmpty, reason: 'a retry of one already sent is still answered');
  });

  test('a chat that cannot be read says so; a missing backend says it is not available yet; offline says to try again', () async {
    await expectLater(db.service.messages('c2'), throwsA(isA<OpsLoadException>().having((e) => e.what, 'what', 'messages')));
    db.missing = true;
    await expectLater(db.service.conversations(), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    db.missing = false;
    db.offline = true;
    await expectLater(db.service.conversations(), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
    await expectLater(
      db.service.send('c1', 'hi', 'k'),
      throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The message could not be sent. Check your connection and try again.')),
    );
  });

  test('revoking access takes the chat away at once', () async {
    expect(await db.service.conversations(), hasLength(1));
    db.revoked = true;
    expect(await db.service.conversations(), isEmpty);
    await expectLater(db.service.messages('c1'), throwsA(isA<OpsLoadException>()));
  });

  test('pinning: the manager may, the message must be in the chat, and null un-pins', () async {
    final m = await db.service.send('c1', 'Doors at 9', 'k');
    await expectLater(db.service.pin('c1', m), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', "You don't have access to do that.")));
    db.conv('c1').canPin = true;
    await expectLater(db.service.pin('c1', 'elsewhere'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'That message is not in this chat.')));
    await db.service.pin('c1', m);
    expect((await db.service.conversations()).single.pinnedBody, 'Doors at 9');
    await db.service.pin('c1', null);
    expect((await db.service.conversations()).single.pinnedBody, isNull);
  });

  test('people are names and roles of colleagues; starting a chat finds the same one again', () async {
    final people = await db.service.people('v1');
    expect(people.map((p) => '${p.name}/${p.roleLabel}'), hasLength(2));
    final id = await db.service.startDirect('sam');
    expect(await db.service.startDirect('sam'), id);
    expect((await db.service.conversations()).where((c) => c.isDirect).single.title, 'Sam Server');
    await expectLater(db.service.startDirect('stranger'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'You can only message people you work with.')));
    await expectLater(db.service.startDirect('me'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'You cannot message yourself.')));
    await expectLater(db.service.people('v2'), throwsA(isA<OpsLoadException>()), reason: 'a club they are not at');
  });

  test('marking read sends the conversation and clears the unread count', () async {
    db.add('c1', 'sam', 'Sam Server', 'hi', ago: const Duration(minutes: 1));
    expect((await db.service.conversations()).single.unread, 1);
    await db.service.markRead('c1');
    expect(db.calledWith('chat_mark_read').single, {'p_conversation': 'c1'});
    expect((await db.service.conversations()).single.unread, 0);
  });
}
