import 'package:bottles_up_vendor/features/chat/services/chat_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeChatMessage {
  FakeChatMessage(this.id, this.sender, this.senderName, this.body, this.at, {this.key});

  final String id;
  final String sender;
  final String senderName;
  final String body;
  final DateTime at;
  final String? key;
}

class FakeConversation {
  FakeConversation(this.id, this.kind, this.title, {this.venueId, this.eventId, Set<String>? members, this.deleteAfter, this.canPin = false})
      : members = members ?? {'me'};

  final String id;
  final String kind;
  final String title;
  final String? venueId;
  final String? eventId;

  /// Who can read and write right now (the database works this out from roles; the fake is told).
  final Set<String> members;
  DateTime? deleteAfter;

  /// Whether the signed-in person ('me') may pin here.
  bool canPin;
  String? pinnedId;
  DateTime? lastRead;
  final List<FakeChatMessage> messages = [];
}

/// The database's chat functions, as a fake with the same sentences the SQL raises. The person signed in is 'me'.
class FakeChatBackend {
  FakeChatBackend();

  final List<FakeConversation> conversations = [];
  final Map<String, List<({String id, String name, String role})>> people = {};
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;
  bool revoked = false;
  DateTime now = DateTime.utc(2026, 10, 9, 21, 42);
  int _ids = 0;

  /// Fail the next [failNextSends] sends as if the connection dropped (the message is NOT stored).
  int failNextSends = 0;

  /// Fail the next send AFTER storing the message (the answer was lost): a retry with the same key must not double it.
  bool loseNextAnswer = false;

  ChatService get service => ChatService(rpc: OpsRpc(rpc: call));

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  FakeConversation conv(String id) => conversations.firstWhere((c) => c.id == id);

  FakeChatMessage add(String convId, String sender, String senderName, String body, {Duration ago = Duration.zero, String? key}) {
    final m = FakeChatMessage('m${_ids++}', sender, senderName, body, now.subtract(ago), key: key);
    conv(convId).messages.add(m);
    return m;
  }

  bool _allowed(FakeConversation c) => !revoked && c.members.contains('me') && !(c.deleteAfter != null && !c.deleteAfter!.isAfter(now));

  FakeConversation _need(Object? id) {
    final c = conversations.where((c) => c.id == id).firstOrNull;
    if (c == null || !_allowed(c)) throw refuse('not allowed');
    return c;
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    switch (function) {
      case 'chat_conversations':
        {
          final rows = <Map<String, dynamic>>[];
          for (final c in conversations.where(_allowed)) {
            final sorted = [...c.messages]..sort((a, b) => b.at.compareTo(a.at));
            final last = sorted.firstOrNull;
            final unread = c.messages.where((m) => m.sender != 'me' && (c.lastRead == null || m.at.isAfter(c.lastRead!))).length;
            final pinned = c.messages.where((m) => m.id == c.pinnedId).firstOrNull;
            rows.add({
              'conversation_id': c.id,
              'kind': c.kind,
              'title': c.title,
              'venue_id': c.venueId,
              'event_id': c.eventId,
              'unread_count': unread,
              'last_message_at': last?.at.toIso8601String(),
              'last_message_preview': last == null ? null : (last.body.length > 80 ? last.body.substring(0, 80) : last.body),
              'last_sender_name': last?.senderName,
              'pinned_body': pinned?.body,
              'delete_after': c.deleteAfter?.toIso8601String(),
            });
          }
          rows.sort((a, b) => (b['last_message_at'] ?? '').toString().compareTo((a['last_message_at'] ?? '').toString()));
          return rows;
        }
      case 'chat_messages':
        {
          final c = _need(params!['p_conversation']);
          final before = params['p_before'] == null ? null : DateTime.parse(params['p_before'] as String);
          final limit = ((params['p_limit'] as int?) ?? 50).clamp(1, 100);
          final sorted = [...c.messages]..sort((a, b) => b.at.compareTo(a.at));
          return [
            for (final m in sorted.where((m) => before == null || m.at.isBefore(before)).take(limit))
              {
                'message_id': m.id,
                'sender_name': m.senderName,
                'is_mine': m.sender == 'me',
                'body': m.body,
                'created_at': m.at.toIso8601String(),
                'pinned': m.id == c.pinnedId,
              },
          ];
        }
      case 'chat_send':
        {
          final c = _need(params!['p_conversation']);
          final body = (params['p_body'] as String?)?.trim() ?? '';
          if (body.isEmpty) throw refuse('write a message first');
          if (body.length > 2000) throw refuse('keep a message to 2000 characters or fewer');
          final key = (params['p_client_key'] as String?)?.trim();
          if (key != null && key.length > 64) throw refuse('that message key is too long');
          if (failNextSends > 0) {
            failNextSends--;
            throw Exception('SocketException: connection lost');
          }
          if (key != null) {
            final held = c.messages.where((m) => m.sender == 'me' && m.key == key).firstOrNull;
            if (held != null) return held.id;
          }
          final recent = c.messages.where((m) => m.sender == 'me' && m.at.isAfter(now.subtract(const Duration(minutes: 1)))).length;
          if (recent >= 30) throw refuse('slow down: you are sending messages too fast');
          final m = add(c.id, 'me', 'Me', body, key: key);
          if (loseNextAnswer) {
            loseNextAnswer = false;
            throw Exception('SocketException: connection lost');
          }
          return m.id;
        }
      case 'chat_mark_read':
        {
          final c = _need(params!['p_conversation']);
          c.lastRead = now.add(const Duration(seconds: 1));
          return null;
        }
      case 'chat_pin':
        {
          final c = _need(params!['p_conversation']);
          if (!c.canPin) throw refuse('not allowed');
          final id = params['p_message'];
          if (id != null && !c.messages.any((m) => m.id == id)) throw refuse('that message is not in this chat');
          c.pinnedId = id as String?;
          return null;
        }
      case 'chat_people':
        {
          final venue = params!['p_venue'];
          if (revoked || !conversations.any((c) => c.venueId == venue && c.members.contains('me'))) throw refuse('not allowed');
          return [
            for (final p in people[venue] ?? const []) {'user_id': p.id, 'name': p.name, 'role': p.role},
          ];
        }
      case 'chat_start_direct':
        {
          final other = params!['p_other'];
          if (other == null) throw refuse('choose who to message');
          if (other == 'me') throw refuse('you cannot message yourself');
          final venue = people.entries.where((e) => e.value.any((p) => p.id == other)).firstOrNull;
          if (venue == null) throw refuse('you can only message people you work with');
          final name = venue.value.firstWhere((p) => p.id == other).name;
          final held = conversations.where((c) => c.kind == 'direct' && c.members.contains(other as String)).firstOrNull;
          if (held != null) return held.id;
          final c = FakeConversation('d${_ids++}', 'direct', name, members: {'me', other as String});
          conversations.add(c);
          return c.id;
        }
    }
    throw StateError('unexpected call $function');
  }
}
