import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../logic/chat_rules.dart';
import '../providers/chat_providers.dart';

/// The colleagues at one club that can be messaged. The database lists them (names and roles, never an email address) and refuses a
/// message to anyone who does not work with the person asking.
Future<ChatPerson?> showChatPeopleSheet(BuildContext context, {required String venueId, String? venueName}) {
  return showModalBottomSheet<ChatPerson>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PeopleSheet(venueId: venueId, venueName: venueName),
  );
}

class _PeopleSheet extends ConsumerWidget {
  const _PeopleSheet({required this.venueId, this.venueName});

  final String venueId;
  final String? venueName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(chatPeopleProvider(venueId));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(venueName == null ? 'Message someone' : 'Message someone at $venueName', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: OpsAsyncView<List<ChatPerson>>(
                    value: people,
                    what: 'colleagues',
                    isEmpty: (list) => list.isEmpty,
                    emptyText: 'No one else works here yet.',
                    onRetry: () => ref.invalidate(chatPeopleProvider(venueId)),
                    errorKey: const Key('chat-people-error'),
                    emptyKey: const Key('chat-people-empty'),
                    builder: (list) => Column(
                      children: [
                        for (final p in list)
                          ListTile(
                            key: Key('chat-person-${p.userId}'),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: Text(p.name),
                            subtitle: Text(p.roleLabel),
                            onTap: () => Navigator.of(context).pop(p),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
