import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/supabase_auth_provider.dart';
import '../logic/business_signup.dart';
import '../logic/workspace_routing.dart';
import '../providers/workspace_providers.dart';
import '../widgets/business_signup_card.dart';

/// Signed in, but not part of any business and not a classic vendor. Business accounts are created on the website, and
/// staff join by invitation, so this says so and offers both: it never creates anything itself.
class NoWorkspaceScreen extends ConsumerStatefulWidget {
  const NoWorkspaceScreen({super.key});

  @override
  ConsumerState<NoWorkspaceScreen> createState() => _NoWorkspaceScreenState();
}

class _NoWorkspaceScreenState extends ConsumerState<NoWorkspaceScreen> {
  final _invitation = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _invitation.dispose();
    super.dispose();
  }

  void _useInvitation() {
    final token = invitationTokenFrom(_invitation.text);
    if (token == null) {
      setState(() => _problem = 'That does not look like an invitation link. Paste the whole link from the email.');
      return;
    }
    setState(() => _problem = null);
    context.go('${WorkspaceRoutes.acceptInvite}?token=${Uri.encodeQueryComponent(token)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = ref.watch(workspaceStateProvider);
    final checking = snapshot.status == WorkspaceStatus.loading;
    final failed = snapshot.status == WorkspaceStatus.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your business'),
        actions: [
          TextButton(
            key: const Key('sign-out-button'),
            onPressed: () => ref.read(supabaseAuthProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (failed) ...[
            Text(
              'We could not check your workspaces. Check your connection and try again.',
              key: const Key('no-workspace-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          Text('This account is not part of a business yet.', key: const Key('no-workspace-title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          const BusinessSignupCard(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Joining a team?', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Open the invitation link from your email, or paste it here. Sign in with the email it was sent to.'),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('invitation-field'),
                    controller: _invitation,
                    decoration: InputDecoration(labelText: 'Invitation link', errorText: _problem),
                    keyboardType: TextInputType.url,
                    onChanged: (_) {
                      if (_problem != null) setState(() => _problem = null);
                    },
                    onSubmitted: (_) => _useInvitation(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('use-invitation-button'),
                    onPressed: _useInvitation,
                    child: const Text('Use invitation'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('check-again-button'),
            onPressed: checking ? null : () => ref.invalidate(workspaceSnapshotProvider),
            child: Text(checking ? 'Checking...' : 'Check again'),
          ),
        ],
      ),
    );
  }
}
