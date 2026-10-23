import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../auth/services/supabase_auth_service.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';

/// What deleting the account does, in words, for the person about to do it. Honest about what stays: the records people made stay with the business (the database keeps them and only
/// cuts the link to the account); a record of changes may still carry the e-mail address. An owner is told the business is left without an owner until BottlesUp assigns a new one.
List<String> deleteAccountWarnings({required String? email, required Workspace workspace}) => [
      'This permanently deletes your BottlesUp sign-in${email == null ? '' : ' ($email)'}. You will lose your access to every business and event you work for here, and you cannot get it back.',
      'The business keeps its records: bookings, orders, payments, check-ins and messages stay, but they no longer point to your account. A log of changes may still show your e-mail address.',
      if (workspace.role == WorkspaceRole.owner)
        'You are the owner of ${workspace.orgName.isEmpty ? 'this business' : workspace.orgName}. Once your account is gone nobody can manage it until BottlesUp assigns a new owner. Contact BottlesUp first if it should be handed over or closed.'
      else
        'If you are the owner of any business, nobody can manage it once your account is gone, until BottlesUp assigns a new owner. Contact BottlesUp first if it should be handed over or closed.',
    ];

/// The same promise in one paragraph, for the classic profile screens (they have no workspace to name).
const String classicDeleteAccountText =
    'This permanently deletes your sign-in and cannot be undone. Your business keeps its records (bookings, orders, payments), but they no longer point to your account. If you own a business, nobody can manage it afterwards until BottlesUp assigns a new owner: contact BottlesUp first if it should be handed over or closed.';

/// Deletes the account of the signed-in person from Settings: a confirmation that says what happens, one call (a second tap while it runs does nothing), and on success the person
/// is taken to the sign-in. When it does not go through the sentence is shown and the person stays signed in. The call is [deleteAccount] (the website's `delete-account` function,
/// in the app); [onDeleted] says where to go afterwards. Both are replaced in tests.
class DeleteAccountSection extends StatefulWidget {
  const DeleteAccountSection({super.key, required this.workspace, required this.email, this.deleteAccount, this.onDeleted});

  final Workspace workspace;
  final String? email;
  final Future<void> Function()? deleteAccount;
  final void Function(BuildContext context)? onDeleted;

  @override
  State<DeleteAccountSection> createState() => _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends State<DeleteAccountSection> {
  bool _busy = false;
  String? _problem;

  Future<void> _ask() async {
    if (_busy) return;
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        key: const Key('delete-account-dialog'),
        icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 32),
        title: const Text('Delete your account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, line) in deleteAccountWarnings(email: widget.email, workspace: widget.workspace).indexed)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(line, key: Key('delete-account-warning-$i'))),
            ],
          ),
        ),
        actions: [
          TextButton(key: const Key('delete-account-cancel'), onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Keep my account')),
          FilledButton(
            key: const Key('delete-account-confirm'),
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _delete();
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await (widget.deleteAccount ?? SupabaseAuthService().deleteAccount)();
    } on AccountDeletionException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = e.message;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = 'We could not delete your account. Check your connection and try again.';
        });
      }
      return;
    }
    // Gone. Signing in is forgotten on this phone, which also moves the app to the sign-in; if this screen is still there, go there too.
    if (!mounted) return;
    setState(() => _busy = false);
    (widget.onDeleted ?? (c) => GoRouter.of(c).go('/'))(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        ListTile(
          key: const Key('settings-delete-account'),
          contentPadding: EdgeInsets.zero,
          enabled: !_busy,
          leading: _busy
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(key: Key('delete-account-busy'), strokeWidth: 2))
              : Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
          title: Text(_busy ? 'Deleting your account...' : 'Delete my account', style: TextStyle(color: theme.colorScheme.error)),
          subtitle: const Text('Permanently removes your sign-in. Your business keeps its records.'),
          onTap: _busy ? null : _ask,
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_problem!, key: const Key('delete-account-problem'), style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}
