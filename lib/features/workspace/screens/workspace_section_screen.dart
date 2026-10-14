import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role_navigation.dart';
import '../providers/workspace_providers.dart';

/// A tab of a workspace. Until each one is built it says so plainly and states
/// what it will hold, instead of showing an empty or broken screen. The brief:
/// "An unavailable integration must appear as unavailable, not connected."
class WorkspaceSectionScreen extends ConsumerWidget {
  const WorkspaceSectionScreen({super.key, required this.membershipId, required this.sectionId});

  final String membershipId;
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceStateProvider).byMembershipId(membershipId);
    final section = workspace == null ? null : navigationFor(workspace.role).byId(sectionId);
    final theme = Theme.of(context);

    if (section == null) {
      return const Center(child: Text('This section is not part of your role.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      children: [
        Row(
          children: [
            Icon(section.activeIcon, size: 28, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(section.label, style: theme.textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 12),
        Text(section.summary, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 20),
        Container(
          key: const Key('not-built-yet'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
          ),
          child: Text(
            'Not built yet. This is where it will appear for ${workspace!.role.label.toLowerCase()}s of ${workspace.scopeLabel}.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
