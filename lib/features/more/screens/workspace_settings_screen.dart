import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../owner/logic/owner_rules.dart' show siteUrl;
import '../../workspace/models/workspace.dart';

/// Opens a web address in the browser. Replaced in tests.
typedef OpenLink = Future<bool> Function(Uri uri);

Future<bool> _openInBrowser(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

String? _signedInEmail() {
  try {
    return Supabase.instance.client.auth.currentUser?.email;
  } catch (_) {
    return null;
  }
}

/// Settings for a workspace: who is signed in and in which role, and the privacy policy. Switching workspace and signing out live in the
/// Account menu at the top of every workspace screen, and this screen says so.
class WorkspaceSettingsScreen extends StatelessWidget {
  const WorkspaceSettingsScreen({super.key, required this.workspace, this.email, this.openLink = _openInBrowser, this.site});

  final Workspace workspace;

  /// The signed-in account's email, given in tests; otherwise read from the session.
  final String? email;
  final OpenLink openLink;

  /// The website's address, given in tests.
  final String? site;

  Future<void> _privacy(BuildContext context) async {
    final base = (site ?? siteUrl).replaceAll(RegExp(r'/+$'), '');
    final opened = await openLink(Uri.parse('$base/privacy-policy'));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The privacy policy could not be opened. Check your connection and try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = email ?? _signedInEmail();
    return ListView(
      key: const Key('settings-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        ListTile(
          key: const Key('settings-account'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(signedIn ?? 'Signed in'),
          subtitle: const Text('Your account'),
        ),
        ListTile(
          key: const Key('settings-acting-as'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.badge_outlined),
          title: Text('${workspace.role.label} · ${workspace.scopeLabel}'),
          subtitle: Text(workspace.orgName.isEmpty ? 'Working as' : 'Working as, for ${workspace.orgName}'),
        ),
        ListTile(
          key: const Key('settings-privacy'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy policy'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _privacy(context),
        ),
        const SizedBox(height: 12),
        Text(
          'To switch workspace or sign out, use the Account menu at the top of the screen.',
          key: const Key('settings-account-note'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
