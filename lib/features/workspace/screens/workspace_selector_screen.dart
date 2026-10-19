import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../auth/providers/supabase_auth_provider.dart';
import '../logic/last_workspace.dart';
import '../logic/workspace_routing.dart';
import '../models/role_navigation.dart';
import '../models/workspace.dart';
import '../providers/workspace_providers.dart';

/// "Open assigned workspace": with one workspace it opens straight away, with
/// several it lists them (owner / venue / organizer / shift) so switching is
/// always an explicit choice.
class WorkspaceSelectorScreen extends ConsumerStatefulWidget {
  const WorkspaceSelectorScreen({super.key});

  @override
  ConsumerState<WorkspaceSelectorScreen> createState() => _WorkspaceSelectorScreenState();
}

class _WorkspaceSelectorScreenState extends ConsumerState<WorkspaceSelectorScreen> {
  bool _autoOpened = false;

  void _open(Workspace workspace) {
    ref.read(rememberWorkspaceProvider)(workspace.membershipId);
    context.go(workspaceLandingPath(workspace));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workspaceSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your workspaces'),
        actions: [
          TextButton(
            onPressed: () => ref.read(supabaseAuthProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Empty(snapshot: WorkspaceSnapshot.error(e.toString())),
        data: (snapshot) {
          final sole = snapshot.soleWorkspace;
          if (sole != null && !_autoOpened) {
            _autoOpened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go(workspaceLandingPath(sole));
            });
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasWorkspaces) return _Empty(snapshot: snapshot);
          // The one used last on this phone goes first. Access is the database's: this only orders the list.
          final lastId = ref.watch(lastWorkspaceIdProvider).valueOrNull;
          final shown = withLastUsedFirst(snapshot.workspaces, lastId);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _WorkspaceCard(
              workspace: shown[i],
              lastUsed: isLastUsed(shown[i], shown, lastId),
              onOpen: () => _open(shown[i]),
            ),
          );
        },
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.workspace, required this.onOpen, this.lastUsed = false});

  final Workspace workspace;
  final VoidCallback onOpen;

  /// The one opened last on this phone.
  final bool lastUsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nav = navigationFor(workspace.role);
    final until = workspace.accessEndAt;
    return Card(
      child: ListTile(
        key: Key('workspace-${workspace.membershipId}'),
        onTap: onOpen,
        leading: Icon(nav.landing.activeIcon, color: theme.colorScheme.primary),
        title: Text(workspace.role.label),
        subtitle: Text(
          [
            if (lastUsed) 'Last used',
            '${workspace.orgName} · ${workspace.scopeLabel}',
            if (until != null) 'Access until ${DateFormat('MMM d, HH:mm').format(until.toLocal())}',
          ].join('\n'),
        ),
        isThreeLine: until != null || lastUsed,
        trailing: const Icon(Ionicons.chevron_forward),
      ),
    );
  }
}

class _Empty extends ConsumerWidget {
  const _Empty({required this.snapshot});

  final WorkspaceSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String message;
    switch (snapshot.status) {
      case WorkspaceStatus.unavailable:
        message = 'Workspaces are not set up on this server yet.';
      case WorkspaceStatus.error:
        message = 'We could not load your workspace. Check your connection and try again.';
      default:
        message = 'You do not have a workspace yet. Ask the venue owner or organizer to invite you.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, key: const Key('no-workspaces-message')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => ref.invalidate(workspaceSnapshotProvider),
              child: const Text('Try again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Open the classic dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
