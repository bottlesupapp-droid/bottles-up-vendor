import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/connectivity/connection_banner.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../core/ui/glass_kit.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../logic/workspace_routing.dart';
import '../models/role_navigation.dart';
import '../models/workspace.dart';
import '../providers/workspace_providers.dart';

/// The frame around every screen of a workspace: a bar that always says WHO and
/// WHERE you are acting as (role, organization, venue or event), and the bottom
/// navigation for that role. The brief: "Keep the active venue, event, and night
/// visible on every operational screen."
class WorkspaceShell extends ConsumerWidget {
  const WorkspaceShell({super.key, required this.membershipId, required this.child});

  final String membershipId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(workspaceStateProvider);
    final workspace = snapshot.byMembershipId(membershipId);

    if (workspace == null) {
      return Scaffold(
        body: SafeArea(child: AccessEnded(onBack: () => context.go(WorkspaceRoutes.workspaces))),
      );
    }

    final nav = navigationFor(workspace.role);
    final segments = GoRouterState.of(context).uri.pathSegments; // ['w', id, section]
    final sectionId = segments.length > 2 ? segments[2] : nav.landing.id;

    return Scaffold(
      extendBody: false, // the page ends where the floating bar begins (see MainShell)
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            WorkspaceContextBar(
              workspace: workspace,
              canSwitch: snapshot.workspaces.length > 1,
              onSwitch: () => context.go(WorkspaceRoutes.workspaces),
              onSignOut: () => ref.read(supabaseAuthProvider.notifier).signOut(),
            ),
            const ConnectionBanner(),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: nav.indexOf(sectionId),
        onTap: (i) => context.go(workspaceSectionPath(workspace.membershipId, nav.sections[i].id)),
        items: [
          for (final s in nav.sections) GlassNavItem(icon: s.icon, activeIcon: s.activeIcon, label: s.label),
        ],
      ),
    );
  }
}

class WorkspaceContextBar extends StatelessWidget {
  const WorkspaceContextBar({
    super.key,
    required this.workspace,
    required this.canSwitch,
    required this.onSwitch,
    required this.onSignOut,
  });

  final Workspace workspace;
  final bool canSwitch;
  final VoidCallback onSwitch;

  /// Called after the person has confirmed. Everyone gets this, including people with a single workspace (who never
  /// see the workspace list), so a shared phone at the club can always be handed over.
  final VoidCallback onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to see your workspace.'),
        actions: [
          TextButton(
            key: const Key('cancel-sign-out'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-sign-out'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bu = context.bu;
    final until = workspace.accessEndAt;
    return Container(
      key: const Key('workspace-context-bar'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(BuSpace.page, 12, BuSpace.m, 12),
      decoration: BoxDecoration(
        color: bu.bg.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          // Who you are acting as is always on screen: the brand mark, then role and organisation, then the venue or event.
          const BuLogoMark(size: 38),
          const SizedBox(width: BuSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${workspace.role.label} · ${workspace.orgName}',
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 15, letterSpacing: -0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  until == null
                      ? workspace.scopeLabel
                      : '${workspace.scopeLabel} · access until ${DateFormat('MMM d, HH:mm').format(until.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(color: bu.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (canSwitch)
            IconButton(
              key: const Key('switch-workspace'),
              tooltip: 'Switch workspace',
              onPressed: onSwitch,
              style: _barButtonStyle(bu),
              icon: const Icon(Ionicons.swap_horizontal_outline, size: 20),
            ),
          if (canSwitch) const SizedBox(width: 6),
          PopupMenuButton<String>(
            key: const Key('account-menu'),
            tooltip: 'Account',
            offset: const Offset(0, 46),
            onSelected: (value) {
              if (value == 'sign-out') _confirmSignOut(context);
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(key: Key('menu-sign-out'), value: 'sign-out', child: Text('Sign out')),
            ],
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bu.panel, borderRadius: BorderRadius.circular(13), border: Border.all(color: bu.line)),
              child: Icon(Ionicons.person_outline, size: 20, color: bu.ink),
            ),
          ),
        ],
      ),
    );
  }

  /// The look of a button on the bar: a small dark tile with a soft edge, the same as the account button next to it.
  static ButtonStyle _barButtonStyle(BuTokens bu) => IconButton.styleFrom(
        backgroundColor: bu.panel,
        foregroundColor: bu.ink,
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: BorderSide(color: bu.line)),
      );
}

/// Shown when the workspace in the address is no longer yours (revoked, expired,
/// or a shift that has ended). Never a blank screen or a raw error.
class AccessEnded extends StatelessWidget {
  const AccessEnded({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Ionicons.lock_closed_outline, size: 40),
            const SizedBox(height: 16),
            Text('This workspace is no longer available to you',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Your access may have ended, or the shift is over.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onBack, child: const Text('Back to my workspaces')),
          ],
        ),
      ),
    );
  }
}
