import 'package:flutter/material.dart';

import '../../chat/screens/chat_screen.dart';
import '../../team/screens/team_screen.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/more_entries.dart';
import 'workspace_settings_screen.dart';

/// The page behind a More entry, or null while that part is not built. Add to this as each part is built; nothing else changes.
Widget? moreDestinationFor(Workspace workspace, String entryId) => switch (entryId) {
      'chat' => ChatScreen(workspace: workspace),
      // The Team screen is the owner's (and the manager's own Team tab); an organizer's team is not built.
      'team' when workspace.role == WorkspaceRole.owner => TeamScreen(workspace: workspace),
      'settings' => WorkspaceSettingsScreen(workspace: workspace),
      _ => null,
    };

/// The More tab of an owner, a manager or an organizer: the parts that do not have a tab of their own. A part that is not built says so,
/// plainly, instead of opening an empty page.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.workspace});

  final Workspace workspace;

  void _open(BuildContext context, MoreEntry entry, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(entry.label)),
          body: SafeArea(child: page),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = moreEntriesFor(workspace.role);
    return ListView(
      key: const Key('more-list'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
      children: [
        Text('More', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(workspace.scopeLabel, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (final e in entries)
          Builder(builder: (context) {
            final page = moreDestinationFor(workspace, e.id);
            return ListTile(
              key: Key('more-${e.id}'),
              contentPadding: EdgeInsets.zero,
              enabled: page != null,
              leading: Icon(e.icon),
              title: Text(e.label),
              subtitle: Text(page == null ? 'Not available yet. ${e.subtitle}' : e.subtitle),
              trailing: page == null ? null : const Icon(Icons.chevron_right),
              onTap: page == null ? null : () => _open(context, e, page),
            );
          }),
      ],
    );
  }
}
