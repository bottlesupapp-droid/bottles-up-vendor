import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/team_rules.dart';

/// What was just issued: the link and what happened to the email.
class IssuedInvite {
  const IssuedInvite({required this.email, required this.roleLabel, required this.businessName, required this.link, required this.outcome, this.codeNote});

  final String email;
  final String roleLabel;
  final String businessName;
  final String link;
  final EmailOutcome outcome;

  /// For a temporary link: that the person will be asked for a code, and how long the link works. Null for an ordinary invitation.
  final String? codeNote;
}

/// Opens an address (the person's own email app). Replaced in tests.
typedef UriOpener = Future<bool> Function(Uri uri);

Future<bool> openExternally(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Shown right after an invitation or a new link is created. The link is displayed here and nowhere else: the database keeps only a
/// hash of it, so once this closes it cannot be shown again (send a new link instead).
class InviteResultCard extends StatefulWidget {
  const InviteResultCard({super.key, required this.invite, required this.onClose, this.openUri = openExternally});

  final IssuedInvite invite;
  final VoidCallback onClose;
  final UriOpener openUri;

  @override
  State<InviteResultCard> createState() => _InviteResultCardState();
}

class _InviteResultCardState extends State<InviteResultCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.invite.link));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  Future<void> _mail() async {
    final i = widget.invite;
    final opened = await widget.openUri(mailtoLink(i.email, i.businessName, i.roleLabel, i.link));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email app could be opened. Copy the link and send it yourself.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = widget.invite;
    final message = emailOutcomeMessage(i.outcome, i.email);
    final color = message.tone == Tone.success ? const Color(0xFF66BB6A) : const Color(0xFFFFB300);
    return Card(
      key: const Key('invite-result'),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(message.text, key: const Key('invite-outcome'), style: theme.textTheme.bodyMedium?.copyWith(color: color))),
                IconButton(key: const Key('close-result'), tooltip: 'Close', icon: const Icon(Icons.close, size: 20), onPressed: widget.onClose),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(i.link, key: const Key('invite-link'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('copy-link'),
                  onPressed: _copy,
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                ),
                if (!i.outcome.sent) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(key: const Key('open-mail'), onPressed: _mail, icon: const Icon(Icons.mail_outline, size: 18), label: const Text('Open in your email app')),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This link is personal to ${i.email} and is shown only now. If you lose it, send a new link from the list.',
              style: theme.textTheme.bodySmall,
            ),
            if (i.codeNote != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(i.codeNote!, key: const Key('invite-code-note'), style: theme.textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}
