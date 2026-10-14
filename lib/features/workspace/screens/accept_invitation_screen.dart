import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../auth/providers/supabase_auth_provider.dart';
import '../logic/workspace_routing.dart';
import '../providers/workspace_providers.dart';
import '../services/workspace_service.dart';

/// Opens an invitation link: accepts it for the signed-in user and explains the
/// result in plain words. Every failure says what to do next, never a bare error.
class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends ConsumerState<AcceptInvitationScreen> {
  InvitationOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      pendingInviteToken.value = null;
      if (mounted) setState(() => _outcome = InvitationOutcome.invalid);
      return;
    }
    final outcome = await ref.read(workspaceServiceProvider).acceptInvitation(token);
    if (outcome != InvitationOutcome.failed) pendingInviteToken.value = null;
    if (outcome.grantedAccess) ref.invalidate(workspaceSnapshotProvider);
    if (mounted) setState(() => _outcome = outcome);
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: outcome == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(outcome.grantedAccess ? Ionicons.checkmark_circle_outline : Ionicons.alert_circle_outline, size: 44),
                    const SizedBox(height: 16),
                    Text(invitationMessage(outcome),
                        key: const Key('invitation-message'), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ..._actions(context, outcome),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, InvitationOutcome outcome) {
    if (outcome.grantedAccess) {
      return [FilledButton(onPressed: () => context.go(WorkspaceRoutes.workspaces), child: const Text('Open my workspace'))];
    }
    if (outcome == InvitationOutcome.emailMismatch) {
      return [
        FilledButton(
          onPressed: () => ref.read(supabaseAuthProvider.notifier).signOut(),
          child: const Text('Sign out and use the invited email'),
        ),
      ];
    }
    if (outcome == InvitationOutcome.failed) {
      return [FilledButton(onPressed: () { setState(() => _outcome = null); _run(); }, child: const Text('Try again'))];
    }
    return [TextButton(onPressed: () => context.go(WorkspaceRoutes.workspaces), child: const Text('Back'))];
  }
}

/// The words for each outcome. Kept separate so they can be tested.
String invitationMessage(InvitationOutcome outcome) {
  switch (outcome) {
    case InvitationOutcome.ok:
      return 'You are in. Your workspace is ready.';
    case InvitationOutcome.alreadyAccepted:
      return 'You already accepted this invitation.';
    case InvitationOutcome.expired:
      return 'This link has expired. Ask the person who invited you to send a new one.';
    case InvitationOutcome.revoked:
      return 'This invitation was cancelled. Contact the person who sent it.';
    case InvitationOutcome.emailMismatch:
      return 'This invitation was sent to a different email address. Sign in with the address it was sent to.';
    case InvitationOutcome.invalid:
      return 'This link is not valid. Check that you opened the whole link.';
    case InvitationOutcome.failed:
      return 'Something went wrong. Check your connection and try again.';
  }
}
