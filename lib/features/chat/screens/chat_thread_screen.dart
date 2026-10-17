import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/chat_rules.dart';
import '../providers/chat_providers.dart';

/// One conversation. Newest message at the bottom, earlier ones a tap away, a pinned instruction at the top. A message that could not be
/// sent stays in the thread as "Not sent" with a Retry that sends the same message (never a second copy). Managers and organizers can
/// pin a message; the database refuses anyone else.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversation, required this.role, this.clock = DateTime.now});

  final ChatConversation conversation;
  final WorkspaceRole role;
  final DateTime Function() clock;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();
  String? _problem;
  late String? _pinned = widget.conversation.pinnedBody;

  ChatConversation get _c => widget.conversation;
  bool get _canPin => canPinIn(_c, widget.role);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final problem = await ref.read(chatThreadProvider(_c.id).notifier).send(_input.text);
    if (!mounted) return;
    setState(() => _problem = problem);
    if (problem == null) _input.clear();
  }

  Future<void> _pin(ChatMessage? message) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatThreadProvider(_c.id).notifier).pin(message?.id);
      if (!mounted) return;
      setState(() => _pinned = message?.body);
      messenger.showSnackBar(SnackBar(content: Text(message == null ? 'Unpinned.' : 'Pinned at the top of this chat.')));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _messageActions(ChatMessage m) async {
    if (!_canPin) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.pinned)
              ListTile(key: const Key('chat-unpin-action'), leading: const Icon(Icons.push_pin_outlined), title: const Text('Unpin'), onTap: () => Navigator.of(context).pop('unpin'))
            else
              ListTile(key: const Key('chat-pin-action'), leading: const Icon(Icons.push_pin_outlined), title: const Text('Pin at the top of this chat'), onTap: () => Navigator.of(context).pop('pin')),
          ],
        ),
      ),
    );
    if (action == 'pin') await _pin(m);
    if (action == 'unpin') await _pin(null);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(chatThreadProvider(_c.id));
    final theme = Theme.of(context);
    final pinnedMessage = s.messages.where((m) => m.pinned).firstOrNull;
    final pinnedBody = pinnedMessage?.body ?? _pinned;
    final note = _c.isEvent ? chatDeletionNote(_c.deleteAfter, widget.clock()) : null;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_c.kindLabel, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
      body: Column(
        key: const Key('chat-thread'),
        children: [
          if (note != null)
            Container(width: double.infinity, color: theme.colorScheme.surfaceContainerHighest, padding: const EdgeInsets.all(8), child: Text(note, key: const Key('chat-ended-note'), style: theme.textTheme.bodySmall)),
          if (pinnedBody != null)
            Container(
              key: const Key('chat-pinned'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              color: theme.colorScheme.secondaryContainer,
              child: Row(
                children: [
                  const Icon(Icons.push_pin, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(pinnedBody, maxLines: 3, overflow: TextOverflow.ellipsis)),
                  if (_canPin) IconButton(key: const Key('chat-unpin'), tooltip: 'Unpin', icon: const Icon(Icons.close, size: 18), onPressed: () => _pin(null)),
                ],
              ),
            ),
          Expanded(child: _body(context, s)),
          if (s.stale && s.error == null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('Could not refresh. Trying again…', key: const Key('chat-stale'), style: theme.textTheme.bodySmall)),
          if (s.error == null) _composer(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ChatThreadState s) {
    final theme = Theme.of(context);
    if (s.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.error!.message, key: const Key('chat-thread-error'), textAlign: TextAlign.center),
              if (!s.error!.unavailable && !s.error!.accessEnded)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(key: const Key('chat-thread-retry'), onPressed: () => ref.read(chatThreadProvider(_c.id).notifier).load(), child: const Text('Try again')),
                ),
            ],
          ),
        ),
      );
    }
    if (s.loading && s.messages.isEmpty) return const Center(child: CircularProgressIndicator());
    if (s.messages.isEmpty && s.pending.isEmpty) {
      return Center(child: Text('No messages yet. Say hello.', key: const Key('chat-thread-empty'), style: theme.textTheme.bodyMedium));
    }
    final pending = s.pending.reversed.toList();
    final count = pending.length + s.messages.length + (s.hasMore ? 1 : 0);
    return ListView.builder(
      key: const Key('chat-messages'),
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i < pending.length) return _pendingBubble(context, pending[i], s.pending.length - 1 - i);
        final mi = i - pending.length;
        if (mi >= s.messages.length) {
          return Center(
            child: s.loadingOlder
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                : TextButton(key: const Key('chat-load-earlier'), onPressed: () => ref.read(chatThreadProvider(_c.id).notifier).loadOlder(), child: const Text('Load earlier messages')),
          );
        }
        return _bubble(context, s.messages[mi]);
      },
    );
  }

  Widget _bubble(BuildContext context, ChatMessage m) {
    final theme = Theme.of(context);
    final mine = m.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        key: Key('chat-msg-${m.id}'),
        onLongPress: () => _messageActions(m),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) Text(m.senderName, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(m.body),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.pinned) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.push_pin, size: 12)),
                  Text(chatTimeLabel(m.createdAt, widget.clock()), style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingBubble(BuildContext context, PendingMessage p, int index) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        key: Key('chat-pending-$index'),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: p.failure == null ? theme.colorScheme.outline : theme.colorScheme.error),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.body),
            const SizedBox(height: 2),
            if (p.failure == null)
              Text('Sending…', key: Key('chat-sending-$index'), style: theme.textTheme.labelSmall)
            else ...[
              Text('Not sent. ${p.failure}', key: Key('chat-failed-$index'), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(key: Key('chat-retry-$index'), onPressed: () => ref.read(chatThreadProvider(_c.id).notifier).retry(p.key), child: const Text('Retry')),
                  TextButton(key: Key('chat-discard-$index'), onPressed: () => ref.read(chatThreadProvider(_c.id).notifier).discard(p.key), child: const Text('Discard')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final theme = Theme.of(context);
    final length = _input.text.trim().length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: _input,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _problem = null),
                decoration: InputDecoration(
                  hintText: 'Message',
                  errorText: _problem,
                  helperText: length > chatMaxLength - 200 ? '$length / $chatMaxLength' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  isDense: true,
                ),
              ),
            ),
            IconButton(key: const Key('chat-send'), tooltip: 'Send', icon: Icon(Icons.send, color: theme.colorScheme.primary), onPressed: _send),
          ],
        ),
      ),
    );
  }
}
