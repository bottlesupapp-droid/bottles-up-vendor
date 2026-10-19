import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../workspace/models/workspace.dart';
import '../logic/chat_rules.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_people_sheet.dart';
import 'chat_thread_screen.dart';

/// A Chat tab: the staff chat of the club, the event team's chat, and the direct chats the person has. What is listed, and what may be
/// read or written, is decided by the database from the person's role right now: take someone's access away and the chat is gone from
/// their list at the next look.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  Future<void> _newMessage(BuildContext context, WidgetRef ref, List<ChatConversation> all) async {
    final venues = [for (final c in all) if (c.isVenue && c.venueId != null) c];
    var venueId = workspace.venueId;
    var venueName = workspace.venueName;
    if (venueId == null) {
      if (venues.isEmpty) return;
      if (venues.length == 1) {
        venueId = venues.first.venueId;
        venueName = venues.first.title;
      } else {
        final picked = await showModalBottomSheet<ChatConversation>(
          context: context,
          builder: (_) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Text('Which club?', style: Theme.of(context).textTheme.titleMedium),
                for (final v in venues)
                  ListTile(key: Key('chat-venue-${v.venueId}'), contentPadding: EdgeInsets.zero, title: Text(v.title), onTap: () => Navigator.of(context).pop(v)),
              ],
            ),
          ),
        );
        if (picked == null || !context.mounted) return;
        venueId = picked.venueId;
        venueName = picked.title;
      }
    }
    if (!context.mounted || venueId == null) return;
    final person = await showChatPeopleSheet(context, venueId: venueId, venueName: venueName);
    if (person == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final id = await ref.read(chatServiceProvider).startDirect(person.userId);
      await ref.read(chatListProvider.notifier).load();
      final started = ref.read(chatListProvider).conversations.where((c) => c.id == id).firstOrNull;
      if (started == null) {
        messenger.showSnackBar(const SnackBar(content: Text('The chat was started, but it could not be opened yet. Pull down to refresh.')));
        return;
      }
      await navigator.push(MaterialPageRoute<void>(builder: (_) => ChatThreadScreen(conversation: started, role: workspace.role, clock: clock)));
      await ref.read(chatListProvider.notifier).load();
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(chatListProvider);
    final chats = chatsForWorkspace(list.conversations, workspace);
    final canStartDirect = workspace.venueId != null || list.conversations.any((c) => c.isVenue);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.read(chatListProvider.notifier).load(),
      child: ListView(
        key: const Key('chat-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
        children: [
          Row(
            children: [
              Expanded(child: Text('Chat', style: theme.textTheme.headlineSmall)),
              if (canStartDirect && list.error == null)
                OutlinedButton.icon(
                  key: const Key('chat-new'),
                  onPressed: () => _newMessage(context, ref, list.conversations),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('New message'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(workspace.scopeLabel, style: theme.textTheme.bodySmall),
          if (list.stale)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Could not refresh. Trying again…', key: const Key('chat-stale'), style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          OpsAsyncView<List<ChatConversation>>(
            value: list.error != null || (list.loading && list.conversations.isEmpty)
                ? list.asAsync
                : AsyncData(chats),
            what: 'chats',
            isEmpty: (items) => items.isEmpty,
            emptyText: 'No chats yet. Your club\'s staff chat, your event team\'s chat and your direct messages appear here.',
            onRetry: () => ref.read(chatListProvider.notifier).load(),
            errorKey: const Key('chat-error'),
            emptyKey: const Key('chat-empty'),
            builder: (items) => Column(
              children: [
                for (final c in items)
                  _ConversationRow(
                    conversation: c,
                    now: clock(),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatThreadScreen(conversation: c, role: workspace.role, clock: clock)));
                      if (context.mounted) await ref.read(chatListProvider.notifier).load();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.now, required this.onTap});

  final ChatConversation conversation;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final theme = Theme.of(context);
    final unread = c.unread > 0;
    final note = c.isEvent ? chatDeletionNote(c.deleteAfter, now) : null;
    return ListTile(
      key: Key('chat-row-${c.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(switch (c.kind) { 'venue' => Icons.groups_outlined, 'event' => Icons.event_outlined, _ => Icons.person_outline }),
      title: Text(c.title, style: unread ? const TextStyle(fontWeight: FontWeight.w700) : null, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.kindLabel, style: theme.textTheme.labelSmall),
          Text(chatPreviewLine(c), maxLines: 1, overflow: TextOverflow.ellipsis, style: unread ? const TextStyle(fontWeight: FontWeight.w600) : null),
          if (note != null) Text(note, key: Key('chat-row-note-${c.id}'), style: theme.textTheme.labelSmall),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (c.lastAt != null) Text(chatTimeLabel(c.lastAt!, now), style: theme.textTheme.labelSmall),
          if (unread)
            Container(
              key: Key('chat-unread-${c.id}'),
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10)),
              child: Text(c.unread > 99 ? '99+' : '${c.unread}', style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
