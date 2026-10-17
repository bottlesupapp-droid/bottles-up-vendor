import 'package:bottles_up_vendor/features/chat/logic/chat_rules.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation conv(String id, String kind, {String? venue, String? event, int unread = 0}) =>
    ChatConversation(id: id, kind: kind, title: id, venueId: venue, eventId: event, unread: unread);

ChatMessage msg(String id, DateTime at, {bool mine = false}) =>
    ChatMessage(id: id, senderName: 'x', isMine: mine, body: id, createdAt: at, pinned: false);

Workspace ws(WorkspaceRole role, {String? venue, String? event}) =>
    Workspace(membershipId: 'm', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: role, venueId: venue, eventId: event);

void main() {
  group('reading what the database sends', () {
    test('a conversation row becomes a conversation', () {
      final c = parseConversation({
        'conversation_id': 'c1',
        'kind': 'venue',
        'title': 'Club A',
        'venue_id': 'v1',
        'unread_count': 3,
        'last_message_at': '2026-10-09T20:00:00Z',
        'last_message_preview': 'Table 4 needs ice',
        'last_sender_name': 'Sam Server',
        'pinned_body': 'Doors at 9',
      })!;
      expect(c.title, 'Club A');
      expect(c.venueId, 'v1');
      expect(c.unread, 3);
      expect(c.pinnedBody, 'Doors at 9');
      expect(c.kindLabel, 'Club staff');
      expect(chatPreviewLine(c), 'Sam Server: Table 4 needs ice');
    });

    test('a row without an id or with an unknown kind is dropped, not shown', () {
      expect(parseConversation({'kind': 'venue'}), isNull);
      expect(parseConversation({'conversation_id': 'c', 'kind': 'broadcast'}), isNull);
      expect(parseChatMessage({'message_id': 'm'}), isNull, reason: 'no time');
      expect(parseChatPerson({'name': 'x'}), isNull);
    });

    test('a direct chat preview is the text alone; an empty chat says so', () {
      expect(chatPreviewLine(const ChatConversation(id: 'd', kind: 'direct', title: 'Mia', lastPreview: 'got a minute?', lastSender: 'Mia')), 'got a minute?');
      expect(chatPreviewLine(conv('c', 'venue')), 'No messages yet');
    });

    test('a person\'s role is worded for the screen', () {
      expect(parseChatPerson({'user_id': 'u', 'name': 'Vera', 'role': 'verifier'})!.roleLabel, WorkspaceRole.verifier.label);
      expect(parseChatPerson({'user_id': 'u', 'role': 'something-new'})!.roleLabel, 'something-new');
      expect(parseChatPerson({'user_id': 'u'})!.name, 'Staff member');
    });
  });

  group('checking a message before it is sent', () {
    test('trimmed; empty and too long are refused with a sentence', () {
      expect(checkChatMessage('  hello ').body, 'hello');
      expect(checkChatMessage('   ').error, 'Write a message first.');
      expect(checkChatMessage('x' * 2000).error, isNull);
      expect(checkChatMessage('x' * 2001).error, 'Keep a message to 2000 characters or fewer.');
    });
  });

  group('which chats a workspace shows', () {
    final all = [
      conv('a', 'venue', venue: 'v1'),
      conv('b', 'venue', venue: 'v2'),
      conv('e1', 'event', event: 'ev1'),
      conv('e2', 'event', event: 'ev2'),
      conv('d', 'direct'),
    ];

    test('a club\'s workspace shows that club, never another', () {
      expect(chatsForWorkspace(all, ws(WorkspaceRole.server, venue: 'v1')).map((c) => c.id), ['a', 'e1', 'e2', 'd']);
    });

    test('an event workspace shows that event\'s chat and the direct chats', () {
      expect(chatsForWorkspace(all, ws(WorkspaceRole.door, event: 'ev2')).map((c) => c.id), ['a', 'b', 'e2', 'd']);
    });

    test('an owner or organizer, tied to no club or event, sees all of theirs', () {
      expect(chatsForWorkspace(all, ws(WorkspaceRole.owner)).map((c) => c.id), ['a', 'b', 'e1', 'e2', 'd']);
    });

    test('the unread total adds up', () {
      expect(totalUnread([conv('a', 'venue', unread: 2), conv('b', 'venue', unread: 5)]), 7);
      expect(totalUnread(const []), 0);
    });
  });

  group('who is offered the pin button (the database still decides)', () {
    test('managers and owners on a club chat; organizers and owners on an event chat; nobody on a direct chat', () {
      for (final role in WorkspaceRole.values) {
        expect(canPinIn(conv('c', 'venue'), role), role == WorkspaceRole.manager || role == WorkspaceRole.owner, reason: 'venue/${role.name}');
        expect(canPinIn(conv('c', 'event'), role), role == WorkspaceRole.organizer || role == WorkspaceRole.owner, reason: 'event/${role.name}');
        expect(canPinIn(conv('c', 'direct'), role), isFalse, reason: 'direct/${role.name}');
      }
    });
  });

  group('time and deletion wording', () {
    final now = DateTime(2026, 10, 9, 23, 30);
    test('today shows the time, yesterday says so, earlier shows the date', () {
      expect(chatTimeLabel(DateTime(2026, 10, 9, 21, 5), now), '21:05');
      expect(chatTimeLabel(DateTime(2026, 10, 8, 23, 59), now), 'Yesterday 23:59');
      expect(chatTimeLabel(DateTime(2026, 10, 2, 8, 0), now), '2 Oct 08:00');
    });

    test('an event chat says when it is deleted, or that it has ended', () {
      expect(chatDeletionNote(null, now), isNull);
      expect(chatDeletionNote(DateTime(2026, 10, 25, 12), now), 'This chat is deleted on 25 Oct 2026.');
      expect(chatDeletionNote(DateTime(2026, 10, 9, 23, 30), now), 'This chat has ended.');
      expect(chatDeletionNote(DateTime(2026, 10, 1), now), 'This chat has ended.');
    });
  });

  group('merging pages', () {
    final t = DateTime.utc(2026, 10, 9, 20);
    test('no message appears twice, newest first, and the same moment is ordered by id', () {
      final held = [msg('m2', t.add(const Duration(minutes: 2))), msg('m1', t.add(const Duration(minutes: 1)))];
      final merged = mergeChatMessages(held, [msg('m3', t.add(const Duration(minutes: 3))), msg('m1', t.add(const Duration(minutes: 1)))]);
      expect(merged.map((m) => m.id), ['m3', 'm2', 'm1']);
      final same = mergeChatMessages([msg('a', t)], [msg('b', t)]);
      expect(same.map((m) => m.id), ['b', 'a']);
    });

    test('a changed copy of a held message replaces it (pinned, for example)', () {
      final pinned = ChatMessage(id: 'm1', senderName: 'x', isMine: false, body: 'm1', createdAt: t, pinned: true);
      expect(mergeChatMessages([msg('m1', t)], [pinned]).single.pinned, isTrue);
    });
  });
}
