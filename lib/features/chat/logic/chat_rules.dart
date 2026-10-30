import 'package:intl/intl.dart';

import '../../ops/logic/ops_json.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';

/// Staff chat. Who may read and write is worked out by the database from the person's role right now, on every call; this file reads what
/// it sends back and checks what a person typed before it is sent.

/// How many messages one page holds. The database caps a page at 100.
const int chatPageSize = 50;

/// The longest message the database accepts.
const int chatMaxLength = 2000;

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.kind,
    required this.title,
    this.venueId,
    this.eventId,
    this.unread = 0,
    this.lastAt,
    this.lastPreview,
    this.lastSender,
    this.pinnedBody,
    this.deleteAfter,
  });

  final String id;

  /// 'venue', 'event' or 'direct'.
  final String kind;

  /// The club or event name; for a direct chat, the other person's name.
  final String title;
  final String? venueId;
  final String? eventId;
  final int unread;
  final DateTime? lastAt;
  final String? lastPreview;
  final String? lastSender;
  final String? pinnedBody;

  /// When an event chat is deleted. Null for the others.
  final DateTime? deleteAfter;

  bool get isDirect => kind == 'direct';
  bool get isVenue => kind == 'venue';
  bool get isEvent => kind == 'event';

  String get kindLabel => switch (kind) {
        'venue' => 'Club staff',
        'event' => 'Event team',
        'direct' => 'Direct message',
        _ => 'Chat',
      };
}

ChatConversation? parseConversation(Map<String, dynamic> r) {
  final id = opsStr(r, 'conversation_id');
  final kind = opsStr(r, 'kind');
  if (id == null || kind == null || !const {'venue', 'event', 'direct'}.contains(kind)) return null;
  return ChatConversation(
    id: id,
    kind: kind,
    title: opsStr(r, 'title') ?? 'Chat',
    venueId: opsStr(r, 'venue_id'),
    eventId: opsStr(r, 'event_id'),
    unread: opsInt(r, 'unread_count'),
    lastAt: opsTime(r, 'last_message_at'),
    lastPreview: opsStr(r, 'last_message_preview'),
    lastSender: opsStr(r, 'last_sender_name'),
    pinnedBody: opsStr(r, 'pinned_body'),
    deleteAfter: opsTime(r, 'delete_after'),
  );
}

class ChatMessage {
  const ChatMessage({required this.id, required this.senderName, required this.isMine, required this.body, required this.createdAt, required this.pinned});

  final String id;
  final String senderName;
  final bool isMine;
  final String body;
  final DateTime createdAt;
  final bool pinned;
}

ChatMessage? parseChatMessage(Map<String, dynamic> r) {
  final id = opsStr(r, 'message_id');
  final at = opsTime(r, 'created_at');
  if (id == null || at == null) return null;
  return ChatMessage(
    id: id,
    senderName: opsStr(r, 'sender_name') ?? 'Staff member',
    isMine: opsBool(r, 'is_mine'),
    body: r['body']?.toString() ?? '',
    createdAt: at,
    pinned: opsBool(r, 'pinned'),
  );
}

class ChatPerson {
  const ChatPerson({required this.userId, required this.name, required this.role});

  final String userId;
  final String name;
  final String role;

  String get roleLabel => WorkspaceRole.fromDb(role)?.label ?? role;
}

ChatPerson? parseChatPerson(Map<String, dynamic> r) {
  final id = opsStr(r, 'user_id');
  if (id == null) return null;
  return ChatPerson(userId: id, name: opsStr(r, 'name') ?? 'Staff member', role: opsStr(r, 'role') ?? '');
}

/// A message as typed: trimmed, and checked against what the database accepts. Exactly one of the two is set.
({String? body, String? error}) checkChatMessage(String text) {
  final body = text.trim();
  if (body.isEmpty) return (body: null, error: 'Write a message first.');
  if (body.length > chatMaxLength) return (body: null, error: 'Keep a message to $chatMaxLength characters or fewer.');
  return (body: body, error: null);
}

/// The chats that belong in one workspace's Chat tab: a club's workspace shows that club's chat, an event workspace that event's chat,
/// and everyone keeps their direct chats. An owner or organizer workspace is not tied to one club or event and shows all of theirs.
List<ChatConversation> chatsForWorkspace(List<ChatConversation> all, Workspace w) => [
      for (final c in all)
        if (c.isDirect ||
            (c.isVenue && (w.venueId == null || c.venueId == w.venueId)) ||
            (c.isEvent && (w.eventId == null || c.eventId == w.eventId)))
          c,
    ];

int totalUnread(Iterable<ChatConversation> chats) => chats.fold(0, (sum, c) => sum + c.unread);

/// Only a hint for which buttons to show; the database decides who may pin: a manager or owner on a club chat, the organizer or owner on
/// an event chat, nobody on a direct chat.
bool canPinIn(ChatConversation c, WorkspaceRole role) => switch (c.kind) {
      'venue' => role == WorkspaceRole.manager || role == WorkspaceRole.owner,
      'event' => role == WorkspaceRole.organizer || role == WorkspaceRole.owner,
      _ => false,
    };

/// "21:42" today, "Yesterday 21:42", otherwise "9 Oct 21:42", in the viewer's own time.
String chatTimeLabel(DateTime at, DateTime now) {
  final t = at.toLocal();
  final n = now.toLocal();
  final clock = DateFormat('HH:mm').format(t);
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(n.year, n.month, n.day);
  final gap = today.difference(day).inDays;
  if (gap == 0) return clock;
  if (gap == 1) return 'Yesterday $clock';
  return '${DateFormat('d MMM').format(t)} $clock';
}

/// What an event chat says about its end: they are deleted a week after the event, and the person is told so.
String? chatDeletionNote(DateTime? deleteAfter, DateTime now) {
  if (deleteAfter == null) return null;
  if (!deleteAfter.isAfter(now)) return 'This chat has ended.';
  return 'This chat is deleted on ${DateFormat('d MMM y').format(deleteAfter.toLocal())}.';
}

/// The newest-first list with [incoming] added: a message already held is not added twice, and the order is by time (then by id).
List<ChatMessage> mergeChatMessages(List<ChatMessage> held, List<ChatMessage> incoming) {
  final byId = <String, ChatMessage>{for (final m in held) m.id: m};
  for (final m in incoming) {
    byId[m.id] = m;
  }
  final out = byId.values.toList()
    ..sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
  return out;
}

/// The line under a chat's name in the list: "Sam: Table 4 needs ice", or that there is nothing yet.
String chatPreviewLine(ChatConversation c) {
  final text = c.lastPreview;
  if (text == null) return 'No messages yet';
  final sender = c.lastSender;
  return c.isDirect || sender == null ? text : '$sender: $text';
}

/// The longest alert a manager can send to the club's staff. It is pinned at the top of the chat, so it is kept short (the chat itself takes 2000).
const int alertMaxLength = 300;

/// A sentence about what is wrong with an alert's text, or null when it is fine.
String? validateAlert(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'Write the alert first.';
  if (t.length > alertMaxLength) return 'Keep the alert to $alertMaxLength characters or fewer.';
  return null;
}
