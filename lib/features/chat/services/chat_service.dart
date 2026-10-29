import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/chat_rules.dart';

/// The calls to the website's chat functions (website repo, 20261018120000_chat.sql): `chat_conversations`, `chat_messages`, `chat_send`,
/// `chat_mark_read`, `chat_pin`, `chat_people` and `chat_start_direct`. The database decides who is in which chat, from their role right
/// now; nothing here keeps a list of members.
class ChatService {
  ChatService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<ChatConversation>> conversations() => _rpc.list('chat_conversations', const {}, parseConversation, 'chats');

  /// Newest first. [before] pages backwards: only messages older than it.
  Future<List<ChatMessage>> messages(String conversationId, {DateTime? before, int limit = chatPageSize}) => _rpc.list(
        'chat_messages',
        {'p_conversation': conversationId, 'p_before': before?.toUtc().toIso8601String(), 'p_limit': limit},
        parseChatMessage,
        'messages',
      );

  /// Sends a message. [clientKey] makes a retry the same message: sending the same key again returns the message already sent.
  Future<String> send(String conversationId, String body, String clientKey) => _rpc.act(() async {
        final data = await _rpc.call('chat_send', {'p_conversation': conversationId, 'p_body': body, 'p_client_key': clientKey});
        return data.toString();
      }, generic: 'The message could not be sent. Check your connection and try again.');

  Future<void> markRead(String conversationId) => _rpc.act(() async {
        await _rpc.call('chat_mark_read', {'p_conversation': conversationId});
      });

  /// Pins a message as the instruction at the top of the chat; null un-pins.
  Future<void> pin(String conversationId, String? messageId) => _rpc.act(() async {
        await _rpc.call('chat_pin', {'p_conversation': conversationId, 'p_message': messageId});
      }, generic: 'This could not be pinned. Check your connection and try again.');

  /// A manager's alert to the club's staff: a message in the club's staff chat, pinned at the top so everybody sees it first (it replaces the instruction pinned before it). The text is
  /// checked first; the database decides who may send and pin (managers and owners of the club). A message that was sent but could not be pinned is said plainly, not hidden.
  Future<void> sendAlert(String venueId, String text, String clientKey) => _rpc.act(() async {
        final problem = validateAlert(text);
        if (problem != null) throw OpsActionException(problem);
        final List<ChatConversation> chats;
        try {
          chats = await conversations();
        } on OpsLoadException {
          throw const OpsActionException('The club\'s staff chat could not be found. Check your connection and try again.');
        }
        final staffChat = chats.where((c) => c.isVenue && c.venueId == venueId).firstOrNull;
        if (staffChat == null) throw const OpsActionException('The club\'s staff chat is not set up yet.');
        final id = await send(staffChat.id, text.trim(), clientKey);
        try {
          await pin(staffChat.id, id);
        } on OpsActionException {
          throw const OpsActionException('The alert was sent to the staff chat but could not be pinned. Open the chat to pin it.');
        }
      }, generic: 'The alert could not be sent. Check your connection and try again.');

  /// The colleagues a person can message at one club: names and roles, never an email address.
  Future<List<ChatPerson>> people(String venueId) => _rpc.list('chat_people', {'p_venue': venueId}, parseChatPerson, 'colleagues');

  /// Opens (or finds) the direct chat with [userId]; returns its id.
  Future<String> startDirect(String userId) => _rpc.act(() async {
        final data = await _rpc.call('chat_start_direct', {'p_other': userId});
        return data.toString();
      }, generic: 'The chat could not be started. Check your connection and try again.');
}
