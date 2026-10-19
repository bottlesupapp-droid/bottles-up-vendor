import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/chat_rules.dart';
import '../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// How often an open thread and the list look for new messages. There is no push yet, so this is how a message arrives; tests make it long.
final chatPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 6));

class ChatListState {
  const ChatListState({this.conversations = const [], this.loading = true, this.error, this.stale = false});

  final List<ChatConversation> conversations;
  final bool loading;
  final OpsLoadException? error;

  /// A refresh failed while the list is on screen: it is kept, and the screen says it is retrying.
  final bool stale;

  AsyncValue<List<ChatConversation>> get asAsync {
    if (error != null) return AsyncError<List<ChatConversation>>(error!, StackTrace.empty);
    if (loading && conversations.isEmpty) return const AsyncLoading<List<ChatConversation>>();
    return AsyncData(conversations);
  }
}

/// The caller's chats, looked at again every few seconds while the list is open (there is no push yet), without ever blanking the list.
class ChatListNotifier extends AutoDisposeNotifier<ChatListState> {
  bool _disposed = false;
  bool _busy = false;

  @override
  ChatListState build() {
    final timer = Timer.periodic(ref.watch(chatPollIntervalProvider), (_) => refresh());
    ref.onDispose(() {
      _disposed = true;
      timer.cancel();
    });
    Future.microtask(load);
    return const ChatListState();
  }

  Future<void> load() async {
    if (_busy) return;
    _busy = true;
    if (!_disposed) state = ChatListState(conversations: state.conversations);
    try {
      final list = await ref.read(chatServiceProvider).conversations();
      if (!_disposed) state = ChatListState(conversations: list, loading: false);
    } catch (e) {
      if (!_disposed) state = ChatListState(conversations: state.conversations, loading: false, error: opsLoadFailureFor(e, 'chats'));
    } finally {
      _busy = false;
    }
  }

  /// A quiet look for news: a failure keeps the list and says it is retrying.
  Future<void> refresh() async {
    if (_busy || state.loading || state.error != null) return;
    _busy = true;
    try {
      final list = await ref.read(chatServiceProvider).conversations();
      if (!_disposed) state = ChatListState(conversations: list, loading: false);
    } catch (_) {
      if (!_disposed) state = ChatListState(conversations: state.conversations, loading: false, stale: true);
    } finally {
      _busy = false;
    }
  }
}

final chatListProvider = NotifierProvider.autoDispose<ChatListNotifier, ChatListState>(ChatListNotifier.new);

/// The colleagues at one club that the caller can message.
final chatPeopleProvider = FutureProvider.autoDispose.family<List<ChatPerson>, String>((ref, venueId) => ref.watch(chatServiceProvider).people(venueId));

/// A message that has been typed and not yet confirmed by the database. A failed one keeps its key so a retry is the same message.
class PendingMessage {
  const PendingMessage({required this.key, required this.body, this.failure});

  final String key;
  final String body;

  /// Why it was not sent, as a sentence. Null while it is still being sent.
  final String? failure;

  PendingMessage failed(String why) => PendingMessage(key: key, body: body, failure: why);
  PendingMessage sending() => PendingMessage(key: key, body: body);
}

class ChatThreadState {
  const ChatThreadState({
    this.messages = const [],
    this.pending = const [],
    this.loading = true,
    this.loadingOlder = false,
    this.hasMore = false,
    this.error,
    this.stale = false,
  });

  /// Newest first.
  final List<ChatMessage> messages;
  final List<PendingMessage> pending;
  final bool loading;
  final bool loadingOlder;

  /// There may be older messages than the ones held.
  final bool hasMore;

  /// The thread could not be loaded at all (not allowed, ended, or the backend has no chat yet).
  final OpsLoadException? error;

  /// A refresh failed while messages are on screen: they are kept, and the screen says it is retrying.
  final bool stale;

  ChatThreadState copyWith({
    List<ChatMessage>? messages,
    List<PendingMessage>? pending,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    OpsLoadException? error,
    bool clearError = false,
    bool? stale,
  }) =>
      ChatThreadState(
        messages: messages ?? this.messages,
        pending: pending ?? this.pending,
        loading: loading ?? this.loading,
        loadingOlder: loadingOlder ?? this.loadingOlder,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
        stale: stale ?? this.stale,
      );
}

/// One open conversation: loads the newest page, looks for newer messages every few seconds, pages backwards on request, and sends with a
/// key so that a retry never doubles a message. Opening it (and every new message from someone else while it is open) marks it read.
class ChatThreadNotifier extends AutoDisposeFamilyNotifier<ChatThreadState, String> {
  bool _disposed = false;
  bool _refreshing = false;
  int _seq = 0;

  ChatService get _service => ref.read(chatServiceProvider);

  @override
  ChatThreadState build(String conversationId) {
    final timer = Timer.periodic(ref.watch(chatPollIntervalProvider), (_) => refresh());
    ref.onDispose(() {
      _disposed = true;
      timer.cancel();
    });
    Future.microtask(load);
    return const ChatThreadState();
  }

  void _set(ChatThreadState Function(ChatThreadState s) change) {
    if (!_disposed) state = change(state);
  }

  Future<void> load() async {
    _set((s) => s.copyWith(loading: true, clearError: true));
    try {
      final page = await _service.messages(arg);
      _set((s) => s.copyWith(messages: mergeChatMessages(s.messages, page), loading: false, hasMore: page.length >= chatPageSize, stale: false));
      if (page.any((m) => !m.isMine)) _markRead();
    } catch (e) {
      _set((s) => s.copyWith(loading: false, error: opsLoadFailureFor(e, 'messages')));
    }
  }

  /// Looks for new messages. A failure keeps what is on screen and says it is retrying.
  Future<void> refresh() async {
    if (_refreshing || state.loading || state.error != null) return;
    _refreshing = true;
    try {
      final page = await _service.messages(arg);
      final held = {for (final m in state.messages) m.id};
      final fromOthers = page.any((m) => !m.isMine && !held.contains(m.id));
      _set((s) => s.copyWith(messages: mergeChatMessages(s.messages, page), stale: false));
      if (fromOthers) _markRead();
    } catch (e) {
      final err = opsLoadFailureFor(e, 'messages');
      // Access taken away while the thread is open ends it; anything else is a pause.
      _set((s) => err.accessEnded ? s.copyWith(error: err) : s.copyWith(stale: true));
    } finally {
      _refreshing = false;
    }
  }

  Future<void> loadOlder() async {
    final s = state;
    if (s.loadingOlder || !s.hasMore || s.messages.isEmpty) return;
    _set((x) => x.copyWith(loadingOlder: true));
    try {
      final page = await _service.messages(arg, before: s.messages.last.createdAt);
      _set((x) => x.copyWith(messages: mergeChatMessages(x.messages, page), loadingOlder: false, hasMore: page.length >= chatPageSize));
    } catch (_) {
      _set((x) => x.copyWith(loadingOlder: false, stale: true));
    }
  }

  void _markRead() {
    unawaited(_service.markRead(arg).then((_) {}, onError: (_) {}));
  }

  String _newKey() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  /// Sends [text]. Returns the sentence to show when it is not even tried (empty, too long); a send that fails stays in the thread as a
  /// message that was not sent, with a retry.
  Future<String?> send(String text) async {
    final checked = checkChatMessage(text);
    if (checked.error != null) return checked.error;
    final message = PendingMessage(key: _newKey(), body: checked.body!);
    _set((s) => s.copyWith(pending: [...s.pending, message]));
    await _deliver(message);
    return null;
  }

  Future<void> retry(String key) async {
    final message = state.pending.where((p) => p.key == key).firstOrNull;
    if (message == null || message.failure == null) return;
    final again = message.sending();
    _set((s) => s.copyWith(pending: [for (final p in s.pending) p.key == key ? again : p]));
    await _deliver(again);
  }

  void discard(String key) => _set((s) => s.copyWith(pending: [for (final p in s.pending) if (p.key != key) p]));

  Future<void> _deliver(PendingMessage message) async {
    try {
      await _service.send(arg, message.body, message.key);
      _set((s) => s.copyWith(pending: [for (final p in s.pending) if (p.key != message.key) p]));
      await _fetchNewest();
    } on OpsActionException catch (e) {
      _set((s) => s.copyWith(pending: [for (final p in s.pending) p.key == message.key ? p.failed(e.message) : p]));
    }
  }

  Future<void> _fetchNewest() async {
    try {
      final page = await _service.messages(arg);
      _set((s) => s.copyWith(messages: mergeChatMessages(s.messages, page), stale: false));
    } catch (_) {
      _set((s) => s.copyWith(stale: true));
    }
  }

  /// Pins a message as the instruction at the top of the chat (null un-pins). Throws the database's sentence if it refuses.
  Future<void> pin(String? messageId) async {
    await _service.pin(arg, messageId);
    _set((s) => s.copyWith(messages: [for (final m in s.messages) ChatMessage(id: m.id, senderName: m.senderName, isMine: m.isMine, body: m.body, createdAt: m.createdAt, pinned: m.id == messageId)]));
  }
}

final chatThreadProvider = NotifierProvider.autoDispose.family<ChatThreadNotifier, ChatThreadState, String>(ChatThreadNotifier.new);
