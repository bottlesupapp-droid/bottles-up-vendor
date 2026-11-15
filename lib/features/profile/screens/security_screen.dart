import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../core/utils/plain_error.dart';
import '../../auth/services/supabase_auth_service.dart';
import '../../more/widgets/delete_account_section.dart' show classicDeleteAccountText;

/// Security, as the design draws it: how you sign in, then the danger zone. Changing the password, two-step sign-in, login activity and connected devices are designed and
/// not built, so each says "Coming soon" (the two-step switch used to be fixed at "off" whatever the account had). Deleting the account works as before.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;

    BuListRow soon(String key, IconData icon, String title, String subtitle, String sheet) =>
        BuListRow(key: Key(key), icon: icon, title: title, subtitle: subtitle, trailing: const BuComingSoonPill(), showChevron: false, onTap: () => showComingSoon(context, title: title, text: sheet));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const BuDetailAppBar(eyebrow: 'Account', title: 'Security'),
      body: ListView(
        key: const Key('security-list'),
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
        children: [
          const BuEyebrow('Sign-in'),
          const SizedBox(height: BuSpace.s),
          BuListCard(
            children: [
              soon('security-password', Ionicons.key_outline, 'Change password', 'Choose a new password', 'Change your password from here, without having to sign out first.'),
              soon(
                'security-2fa',
                Ionicons.shield_checkmark_outline,
                'Two-step sign-in',
                'Add an extra layer of security',
                'Ask for a code from your phone as well as your password when you sign in.',
              ),
            ],
          ),
          const SizedBox(height: BuSpace.xl),
          const BuEyebrow('Activity'),
          const SizedBox(height: BuSpace.s),
          BuListCard(
            children: [
              soon('security-activity', Ionicons.time_outline, 'Login activity', 'See when and where you signed in', 'A list of recent sign-ins, so you can spot one that was not you.'),
              soon('security-devices', Ionicons.phone_portrait_outline, 'Connected devices', 'Phones signed in to your account', 'See the phones signed in to your account and sign any of them out.'),
            ],
          ),
          const SizedBox(height: BuSpace.xl),
          BuEyebrow('Danger zone', color: bu.red),
          const SizedBox(height: BuSpace.s),
          BuCard(
            key: const Key('security-delete'),
            accent: bu.red,
            padding: EdgeInsets.zero,
            child: BuListRow(
              icon: Ionicons.trash_outline,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and all data',
              showChevron: false,
              trailing: Icon(Ionicons.chevron_forward, size: 18, color: bu.red),
              onTap: () => _confirmAndDelete(context, ref),
            ),
          ),
          const SizedBox(height: BuSpace.m),
          Text('This cannot be undone.', style: text.bodySmall?.copyWith(color: bu.muted)),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final error = context.bu.red;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account?'),
            content: const Text(classicDeleteAccountText),
            actions: [
              TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
              TextButton(style: TextButton.styleFrom(foregroundColor: error), child: const Text('Delete'), onPressed: () => Navigator.pop(context, true)),
            ],
          ),
    );

    if (confirm == true && context.mounted) {
      try {
        // Show loading
        showDialog<void>(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

        // Call delete account
        await ref.read(supabaseAuthServiceProvider).deleteAccount();

        if (context.mounted) {
          // Pop loading
          Navigator.pop(context);
          // Navigate to login/splash
          context.go('/');
        }
      } catch (e) {
        if (context.mounted) {
          // Pop loading
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is AccountDeletionException ? e.message : couldNot('delete your account', e)), backgroundColor: error));
        }
      }
    }
  }
}
