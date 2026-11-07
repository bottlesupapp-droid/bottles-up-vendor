import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../logic/workspace_routing.dart';
import '../providers/workspace_providers.dart';

/// Signed in, but the request for the person's workspaces failed. This is NOT "you have no business": the account and the business are
/// untouched, only the answer did not arrive. So it says so in plain words and offers Retry (brief, sections 3 and 33). The technical reason
/// is kept out of sight (it goes to the log, see [workspaceSnapshotProvider]).
class WorkspaceLoadFailedScreen extends ConsumerWidget {
  const WorkspaceLoadFailedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final retrying = ref.watch(workspaceStateProvider).status == WorkspaceStatus.loading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BottlesUp Business'),
        actions: [
          TextButton(
            key: const Key('sign-out-button'),
            onPressed: () => ref.read(supabaseAuthProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: BuBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(BuSpace.page),
            child: BuCard(
              padding: const EdgeInsets.all(BuSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BuIconTile(icon: Ionicons.cloud_offline_outline, size: 56, color: context.bu.amber, background: context.bu.amber.withValues(alpha: 0.12)),
                  const SizedBox(height: BuSpace.l),
                  Text('We could not load your workspace', key: const Key('workspace-failed-title'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                  const SizedBox(height: BuSpace.s),
                  Text(
                    'Check your connection and try again. Your account and your business are not affected.',
                    key: const Key('workspace-failed-body'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: context.bu.muted),
                  ),
                  const SizedBox(height: BuSpace.xl),
                  FilledButton(
                    key: const Key('workspace-retry'),
                    onPressed: retrying ? null : () => ref.invalidate(workspaceSnapshotProvider),
                    child: Text(retrying ? 'Retrying...' : 'Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
