import '../../../core/utils/plain_error.dart';
import 'package:flutter/material.dart';
import '../../more/widgets/delete_account_section.dart' show classicDeleteAccountText;
import '../../../core/config/app_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/services/supabase_auth_service.dart';
import '../providers/profile_stats_provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../shared/widgets/classic_top_bar.dart' show classicRoleLabel;

/// More (the last tab), as in the design: who you are, then the places the other tabs do not cover, in groups. What is not built yet says "Coming soon" and
/// opens a sheet that says what it will do. Signing out and deleting the account are at the bottom, as before.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorUser = ref.watch(currentVendorUserProvider);
    final supabaseUser = ref.watch(currentUserProvider);
    final authState = ref.watch(supabaseAuthProvider);
    final profileStatsAsync = ref.watch(profileStatsProvider);
    final theme = Theme.of(context);
    final bu = context.bu;

    // Create fallback vendor user from Supabase Auth if database data is not available
    VendorUser? displayUser = vendorUser;
    if (vendorUser == null && supabaseUser != null) {
      displayUser = VendorUser(
        id: supabaseUser.id,
        email: supabaseUser.email ?? 'Unknown Email',
        phone: supabaseUser.userMetadata?['phone'],
        businessName: supabaseUser.userMetadata?['business_name'] ?? 'BottlesUp Business',
        logoUrl: supabaseUser.userMetadata?['avatar_url'],
        onboardingCompleted: false,
        twoFaEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        role: supabaseUser.userMetadata?['vendor_type'] ?? 'staff',
      );
    }

    if (displayUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading your profile...', style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted)),
          ],
        ),
      );
    }

    final business = (displayUser.businessName ?? '').trim();
    final shownName = business.isNotEmpty ? business : displayUser.email;
    final stats = profileStatsAsync.valueOrNull;
    final rating = stats != null && stats.averageRating > 0 ? ' · ${stats.averageRating.toStringAsFixed(1)} rating' : '';

    BuListRow soon(String key, IconData icon, String title, String subtitle, String sheetText) => BuListRow(
          key: Key(key),
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: const BuComingSoonPill(),
          showChevron: false,
          onTap: () => showComingSoon(context, title: title, text: sheetText),
        );

    return ListView(
      key: const Key('more-list'),
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, 100),
      children: [
        BuPageHeader(eyebrow: business.isNotEmpty ? business : 'Your account', title: 'More'),
        const SizedBox(height: BuSpace.xl),
        if (vendorUser == null) ...[
          BuCard(accent: bu.orange, child: Row(children: [
            Icon(Ionicons.information_circle_outline, color: bu.orangeSoft, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Profile data is being synchronized', style: theme.textTheme.bodyMedium)),
          ])),
          const SizedBox(height: BuSpace.m),
        ],
        BuCard(
          key: const Key('more-profile-card'),
          padding: const EdgeInsets.all(BuSpace.m + 2),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [bu.orange, bu.orangeSoft.withValues(alpha: 0.7)])),
                child: Text(BuMiniVenue.initialsOf(shownName), style: theme.textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: BuSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shownName, style: theme.textTheme.titleSmall?.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${classicRoleLabel(displayUser.role)}$rating', style: theme.textTheme.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              TextButton(key: const Key('more-edit-profile'), onPressed: () => context.push('/profile/edit'), child: const Text('Edit')),
            ],
          ),
        ),
        const SizedBox(height: BuSpace.xl),
        const BuEyebrow('Operations'),
        const SizedBox(height: BuSpace.m),
        BuListCard(children: [
          soon('more-team', Ionicons.people_outline, 'Team', 'Staff, roles, and invitations', 'Invite your staff, give each a role, and see who is on shift.'),
          BuListRow(
            key: const Key('more-inventory'),
            icon: Ionicons.cube_outline,
            title: 'Inventory',
            subtitle: 'Stock, deliveries, and low-stock alerts',
            trailing: stats == null ? null : BuCountBadge(stats.totalInventoryItems, tone: BuTone.neutral),
            onTap: () => context.push('/inventory'),
          ),
          soon('more-vip', Ionicons.star_outline, 'VIP clients', 'Contacts, perks, hosts and private notes', 'Keep your regulars, their perks and your private notes in one list.'),
        ]),
        const SizedBox(height: BuSpace.xl),
        const BuEyebrow('Business'),
        const SizedBox(height: BuSpace.m),
        BuListCard(children: [
          soon('more-payments', Ionicons.card_outline, 'Payments', 'Payouts, balances, and transactions', 'See your payouts, your balance and every transaction.'),
          BuListRow(
            key: const Key('more-events'),
            icon: Ionicons.calendar_outline,
            title: 'Events',
            subtitle: 'Create one-time or weekly events',
            trailing: stats == null ? null : BuCountBadge(stats.totalEvents, tone: BuTone.brand),
            onTap: () => context.push('/events'),
          ),
          BuListRow(key: const Key('more-bookings'), icon: Ionicons.bookmarks_outline, title: 'Bookings', subtitle: 'Your booking history', onTap: () => context.push('/bookings')),
          soon('more-agreements', Ionicons.ticket_outline, 'Agreements', 'Organizer terms and approvals', 'Review and approve the terms organizers send you.'),
        ]),
        const SizedBox(height: BuSpace.xl),
        const BuEyebrow('Account'),
        const SizedBox(height: BuSpace.m),
        BuListCard(children: [
          BuListRow(key: const Key('more-settings'), icon: Ionicons.settings_outline, title: 'Settings', subtitle: 'App preferences and account settings', onTap: () => context.push('/profile/settings')),
          BuListRow(key: const Key('more-terms'), icon: Ionicons.document_text_outline, title: 'Terms of Service', subtitle: 'Legal terms and conditions', onTap: () => context.push('/legal/terms')),
          BuListRow(key: const Key('more-privacy'), icon: Ionicons.shield_outline, title: 'Privacy Policy', subtitle: 'How we protect your data', onTap: () => context.push('/legal/privacy')),
          BuListRow(key: const Key('more-about'), icon: Ionicons.information_circle_outline, title: 'About BottlesUp Business', subtitle: 'Version $appVersion · App info', onTap: () => context.push('/about')),
        ]),
        const SizedBox(height: BuSpace.xl),
        OutlinedButton.icon(
          key: const Key('more-delete-account'),
          onPressed: () => _showDeleteAccountDialog(context, ref),
          style: OutlinedButton.styleFrom(foregroundColor: bu.red, side: BorderSide(color: bu.red.withValues(alpha: 0.6))),
          icon: const Icon(Ionicons.trash_outline, size: 18),
          label: const Text('Delete Account'),
        ),
        const SizedBox(height: BuSpace.m),
        OutlinedButton.icon(
          key: const Key('more-sign-out'),
          onPressed: authState.isLoading ? null : () => _showSignOutDialog(context, ref),
          style: OutlinedButton.styleFrom(foregroundColor: bu.red, side: BorderSide(color: bu.red.withValues(alpha: 0.6))),
          icon: authState.isLoading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(bu.red))) : const Icon(Ionicons.log_out_outline, size: 18),
          label: const Text('Sign Out'),
        ),
        const SizedBox(height: BuSpace.xl),
        Center(child: Text('BottlesUp Business · $appVersionLabel', style: theme.textTheme.bodySmall?.copyWith(color: bu.muted))),
      ],
    );
  }

  Future<void> _showSignOutDialog(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: Icon(
          Ionicons.log_out_outline,
          color: theme.colorScheme.error,
          size: 32,
        ),
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await ref.read(supabaseAuthProvider.notifier).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: Icon(
          Ionicons.warning_outline,
          color: theme.colorScheme.error,
          size: 32,
        ),
        title: const Text('Delete Account?'),
        content: const Text(
          classicDeleteAccountText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e is AccountDeletionException ? e.message : couldNot('delete your account', e)),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
    }
  }
} 