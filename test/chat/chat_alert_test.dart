import 'package:bottles_up_vendor/features/chat/logic/chat_rules.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_chat_backend.dart';

late FakeChatBackend db;

Future<String> failure(Future<void> Function() action) async {
  try {
    await action();
  } on OpsActionException catch (e) {
    return e.message;
  }
  return 'accepted';
}

void main() {
  setUp(() {
    db = FakeChatBackend();
    db.conversations.add(FakeConversation('dm', 'direct', 'Sam'));
    db.conversations.add(FakeConversation('other', 'venue', 'Club B', venueId: 'v2', canPin: true));
    db.conversations.add(FakeConversation('staff', 'venue', 'Club A', venueId: 'v1', canPin: true));
  });

  group('the words of an alert', () {
    test('some text is needed, and 300 characters are the most', () {
      expect(validateAlert(''), 'Write the alert first.');
      expect(validateAlert('   '), 'Write the alert first.');
      expect(validateAlert('Fire door at the back is blocked'), isNull);
      expect(validateAlert('x' * 300), isNull);
      expect(validateAlert('x' * 301), 'Keep the alert to 300 characters or fewer.');
      expect(validateAlert('  ${'x' * 300}  '), isNull, reason: 'the spaces do not count');
      expect(alertMaxLength, 300);
    });
  });

  group('sending an alert', () {
    test('goes to THIS club\'s staff chat, trimmed, and is pinned there', () async {
      await db.service.sendAlert('v1', '  Fire door at the back is blocked  ', 'alert-1');
      final chat = db.conv('staff');
      expect(chat.messages.single.body, 'Fire door at the back is blocked');
      expect(db.calledWith('chat_send').single['p_body'], 'Fire door at the back is blocked', reason: 'the app sends it trimmed; it does not rely on the database to do it');
      expect(chat.pinnedId, chat.messages.single.id);
      expect(db.conv('other').messages, isEmpty, reason: 'another club\'s chat is untouched');
      expect(db.conv('dm').messages, isEmpty);
    });

    test('sends with the key it was given, so a retry is the same message', () async {
      await db.service.sendAlert('v1', 'Fire door at the back is blocked', 'alert-1');
      expect(db.calledWith('chat_send').single['p_client_key'], 'alert-1');
      await db.service.sendAlert('v1', 'Fire door at the back is blocked', 'alert-1');
      expect(db.conv('staff').messages, hasLength(1), reason: 'the same key is the same message');
    });

    test('a new alert replaces the pinned one', () async {
      await db.service.sendAlert('v1', 'First alert', 'alert-1');
      await db.service.sendAlert('v1', 'Second alert', 'alert-2');
      final chat = db.conv('staff');
      expect(chat.messages.map((m) => m.body), ['First alert', 'Second alert']);
      expect(chat.pinnedId, chat.messages.last.id);
    });

    test('the text is checked before anything is sent', () async {
      expect(await failure(() => db.service.sendAlert('v1', '  ', 'a')), 'Write the alert first.');
      expect(await failure(() => db.service.sendAlert('v1', 'x' * 301, 'a')), 'Keep the alert to 300 characters or fewer.');
      expect(db.calls, isEmpty);
    });

    test('a club with no staff chat is told so, and nothing is sent', () async {
      db.conversations.removeWhere((c) => c.id == 'staff');
      expect(await failure(() => db.service.sendAlert('v1', 'Fire door is blocked', 'a')), 'The club\'s staff chat is not set up yet.');
      expect(db.calledWith('chat_send'), isEmpty);
    });

    test('an event chat or a direct chat with the same club is not the staff chat', () async {
      db.conversations.removeWhere((c) => c.id == 'staff');
      db.conversations.add(FakeConversation('ev', 'event', 'Launch night', venueId: 'v1', eventId: 'e1', canPin: true));
      expect(await failure(() => db.service.sendAlert('v1', 'Fire door is blocked', 'a')), 'The club\'s staff chat is not set up yet.');
    });

    test('someone who may not pin (a server) has the message sent but is told it could not be pinned', () async {
      db.conv('staff').canPin = false;
      expect(await failure(() => db.service.sendAlert('v1', 'Fire door is blocked', 'a')), 'The alert was sent to the staff chat but could not be pinned. Open the chat to pin it.');
      expect(db.conv('staff').messages, hasLength(1));
      expect(db.conv('staff').pinnedId, isNull);
    });

    test('when the chats cannot be read nothing is sent', () async {
      db.offline = true;
      expect(await failure(() => db.service.sendAlert('v1', 'Fire door is blocked', 'a')), 'The club\'s staff chat could not be found. Check your connection and try again.');
      expect(db.calledWith('chat_send'), isEmpty);
    });

    test('a message that does not go through says so plainly', () async {
      db.failNextSends = 1;
      expect(await failure(() => db.service.sendAlert('v1', 'Fire door is blocked', 'a')), 'The message could not be sent. Check your connection and try again.');
      expect(db.conv('staff').messages, isEmpty);
    });
  });
}
