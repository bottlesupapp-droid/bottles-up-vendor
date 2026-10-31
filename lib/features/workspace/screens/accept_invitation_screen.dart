import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../auth/providers/supabase_auth_provider.dart';
import '../logic/invitation_check.dart';
import '../logic/workspace_routing.dart';
import '../providers/workspace_providers.dart';
import '../services/workspace_service.dart';

/// Opens an invitation link: accepts it for the signed-in user and explains the result in plain words. Every failure says what to do next, never a bare error.
///
/// A temporary link is first checked: the person is sent a 6-digit code at the address the invitation was made for and types it here before the link works. A link that has expired offers
/// to ask the person who invited them for a new one, instead of an empty error. Where the server does not have this yet, the link is used as it always was.
class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

enum _Stage { loading, code, expired, result }

class _AcceptInvitationScreenState extends ConsumerState<AcceptInvitationScreen> {
  _Stage _stage = _Stage.loading;
  InvitationOutcome? _outcome;
  InvitationPreview? _preview;

  // The code step.
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _sending = false;
  bool _checking = false;
  String? _codeMessage;

  // Asking for a new link.
  bool _renewing = false;
  String? _renewalMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _show(InvitationOutcome outcome) {
    if (outcome != InvitationOutcome.failed) pendingInviteToken.value = null;
    if (outcome.grantedAccess) ref.invalidate(workspaceSnapshotProvider);
    if (mounted) {
      setState(() {
        _outcome = outcome;
        _stage = _Stage.result;
      });
    }
  }

  Future<void> _run() async {
    if (mounted) setState(() => _stage = _Stage.loading);
    final token = widget.token;
    if (token == null || token.isEmpty) {
      _show(InvitationOutcome.invalid);
      return;
    }
    // What the link is. Where the server cannot say, the link is used as it always was.
    InvitationPreview? preview;
    try {
      preview = await ref.read(invitationCheckServiceProvider).preview(token);
    } catch (_) {
      preview = null;
    }
    if (!mounted) return;
    if (preview == null) {
      await _accept(token);
      return;
    }
    switch (preview.outcome) {
      case PreviewOutcome.ok:
        if (preview.needsCode) {
          setState(() {
            _preview = preview;
            _stage = _Stage.code;
          });
        } else {
          await _accept(token);
        }
      case PreviewOutcome.expired:
        pendingInviteToken.value = null;
        setState(() {
          _preview = preview;
          _stage = _Stage.expired;
        });
      case PreviewOutcome.alreadyAccepted:
        _show(InvitationOutcome.alreadyAccepted);
      case PreviewOutcome.revoked:
        _show(InvitationOutcome.revoked);
      case PreviewOutcome.emailMismatch:
        _show(InvitationOutcome.emailMismatch);
      case PreviewOutcome.invalid:
        _show(InvitationOutcome.invalid);
    }
  }

  Future<void> _accept(String token) async {
    final outcome = await ref.read(workspaceServiceProvider).acceptInvitation(token);
    _show(outcome);
  }

  Future<void> _sendCode() async {
    final token = widget.token;
    if (token == null || _sending) return;
    setState(() {
      _sending = true;
      _codeMessage = null;
    });
    final result = await ref.read(invitationCheckServiceProvider).sendCode(token);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _codeMessage = result.message;
      if (result.sent || result.codeMayExist) _codeSent = true;
    });
  }

  Future<void> _confirm() async {
    final token = widget.token;
    if (token == null || _checking) return;
    final problem = checkCodeInput(_code.text);
    if (problem != null) {
      setState(() => _codeMessage = problem);
      return;
    }
    setState(() {
      _checking = true;
      _codeMessage = null;
    });
    final check = await ref.read(invitationCheckServiceProvider).verify(token, _code.text);
    if (!mounted) return;
    switch (check.outcome) {
      case CodeOutcome.ok:
        setState(() => _checking = false);
        await _accept(token);
      case CodeOutcome.revoked:
        _show(InvitationOutcome.revoked);
      case CodeOutcome.alreadyAccepted:
        _show(InvitationOutcome.alreadyAccepted);
      case CodeOutcome.emailMismatch:
        _show(InvitationOutcome.emailMismatch);
      case CodeOutcome.invalid:
        _show(InvitationOutcome.invalid);
      case CodeOutcome.expired:
        await _run();
      default:
        setState(() {
          _checking = false;
          _codeMessage = codeCheckMessage(check);
        });
    }
  }

  Future<void> _renew() async {
    final token = widget.token;
    if (token == null || _renewing) return;
    setState(() => _renewing = true);
    final outcome = await ref.read(invitationCheckServiceProvider).requestRenewal(token);
    if (!mounted) return;
    setState(() {
      _renewing = false;
      _renewalMessage = renewalMessage(outcome);
      if (outcome.told) _preview = _preview?.copyWith(renewalRequested: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: switch (_stage) {
            _Stage.loading => const CircularProgressIndicator(),
            _Stage.code => _codeStep(context),
            _Stage.expired => _expiredStep(context),
            _Stage.result => _resultStep(context, _outcome ?? InvitationOutcome.failed),
          },
        ),
      ),
    );
  }

  Widget _resultStep(BuildContext context, InvitationOutcome outcome) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(outcome.grantedAccess ? Ionicons.checkmark_circle_outline : Ionicons.alert_circle_outline, size: 44),
        const SizedBox(height: 16),
        Text(invitationMessage(outcome), key: const Key('invitation-message'), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ..._actions(context, outcome),
      ],
    );
  }

  Widget _codeStep(BuildContext context) {
    final theme = Theme.of(context);
    final p = _preview!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Ionicons.lock_closed_outline, size: 44),
          const SizedBox(height: 16),
          Text('Confirm it is you', key: const Key('code-title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(previewSummary(p), key: const Key('code-summary'), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'This link gives temporary access, so we check your e-mail first. We will send a 6-digit code to ${p.emailHint ?? 'the address on your invitation'}.',
            key: const Key('code-explainer'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (!_codeSent)
            FilledButton(key: const Key('code-send'), onPressed: _sending ? null : _sendCode, child: Text(_sending ? 'Sending…' : 'Send me the code'))
          else ...[
            TextField(
              key: const Key('code-field'),
              controller: _code,
              enabled: !_checking,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 6),
              decoration: const InputDecoration(labelText: '6-digit code', border: OutlineInputBorder()),
              onChanged: (_) => setState(() => _codeMessage = null),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 8),
            FilledButton(key: const Key('code-confirm'), onPressed: _checking ? null : _confirm, child: Text(_checking ? 'Checking…' : 'Confirm')),
            TextButton(key: const Key('code-resend'), onPressed: _sending || _checking ? null : _sendCode, child: Text(_sending ? 'Sending…' : 'Send a new code')),
          ],
          if (_codeMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_codeMessage!, key: const Key('code-message'), textAlign: TextAlign.center)),
          TextButton(key: const Key('code-back'), onPressed: () => context.go(WorkspaceRoutes.workspaces), child: const Text('Back')),
        ],
      ),
    );
  }

  Widget _expiredStep(BuildContext context) {
    final p = _preview!;
    final asked = p.renewalRequested;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Ionicons.time_outline, size: 44),
          const SizedBox(height: 16),
          Text(
            asked ? 'This link has expired, and you have asked for a new one.' : 'This link has expired.',
            key: const Key('invitation-message'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(previewSummary(p), key: const Key('expired-summary'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (!asked)
            FilledButton(key: const Key('renew-request'), onPressed: _renewing ? null : _renew, child: Text(_renewing ? 'Sending…' : 'Ask for a new link')),
          if (_renewalMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_renewalMessage!, key: const Key('renewal-message'), textAlign: TextAlign.center)),
          if (asked && _renewalMessage == null)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('The person who invited you has been told. Open the new link when it arrives.', key: Key('renewal-asked'), textAlign: TextAlign.center)),
          TextButton(key: const Key('expired-back'), onPressed: () => context.go(WorkspaceRoutes.workspaces), child: const Text('Back')),
        ],
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
      return [FilledButton(onPressed: _run, child: const Text('Try again'))];
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
