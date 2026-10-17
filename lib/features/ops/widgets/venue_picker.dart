import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../owner/logic/owner_rules.dart' show OrgVenue;
import '../../owner/providers/owner_providers.dart';
import '../../workspace/models/workspace.dart';
import 'ops_async_view.dart';

/// "Which club?" for an owner, whose workspace is the whole business: lists the business's clubs and calls [onPick] with the one chosen.
/// A manager's workspace is already one club and never shows this.
class VenuePicker extends ConsumerWidget {
  const VenuePicker({super.key, required this.workspace, required this.title, required this.onPick, this.listKey = const Key('venue-picker'), this.itemKeyPrefix = 'venue-pick-'});

  final Workspace workspace;
  final String title;
  final ValueChanged<String> onPick;
  final Key listKey;
  final String itemKeyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(ownerVenuesProvider(workspace.orgId));
    return ListView(
      key: listKey,
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Which club?'),
        OpsAsyncView<List<OrgVenue>>(
          value: venues,
          what: 'your venues',
          isEmpty: (d) => d.isEmpty,
          emptyText: 'No venues yet.',
          errorKey: Key('${itemKeyPrefix}error'),
          onRetry: () => ref.invalidate(ownerVenuesProvider(workspace.orgId)),
          builder: (list) => Column(
            children: [
              for (final v in list) ListTile(key: Key('$itemKeyPrefix${v.id}'), contentPadding: EdgeInsets.zero, title: Text(v.name), trailing: const Icon(Icons.chevron_right), onTap: () => onPick(v.id)),
            ],
          ),
        ),
      ],
    );
  }
}
