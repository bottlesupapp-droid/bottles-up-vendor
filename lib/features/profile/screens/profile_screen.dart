import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/services/supabase_auth_service.dart';
import '../providers/profile_stats_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorUser = ref.watch(currentVendorUserProvider);
    final supabaseUser = ref.watch(currentUserProvider);
    final authState = ref.watch(supabaseAuthProvider);
    final profileStatsAsync = ref.watch(profileStatsProvider);
    final theme = Theme.of(context);

    // Create fallback vendor user from Supabase Auth if database data is not available
    VendorUser? displayUser = vendorUser;
    if (vendorUser == null && supabaseUser != null) {
      displayUser = VendorUser(
        id: supabaseUser.id,
        email: supabaseUser.email ?? 'Unknown Email',
        phone: supabaseUser.userMetadata?['phone'],
        businessName: supabaseUser.userMetadata?['business_name'] ?? 'Bottles Up Vendor',
        logoUrl: supabaseUser.userMetadata?['avatar_url'],
        onboardingCompleted: false,
        twoFaEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        role: supabaseUser.userMetadata?['vendor_type'] ?? 'staff',
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: displayUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading profile...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (authState.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Ionicons.warning_outline,
                            color: theme.colorScheme.error,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Profile Load Error',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            authState.error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile status indicator if using fallback data
                  if (vendorUser == null) 
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Ionicons.information_circle_outline,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Profile data is being synchronized from Firebase Auth',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.darkContainerDecoration,
                    child: Column(
                      children: [
                        // Avatar with edit option
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: 3,
                            ),
                          ),
                          child: displayUser.logoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(47),
                                  child: Image.network(
                                    displayUser.logoUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Ionicons.person,
                                  size: 50,
                                  color: theme.colorScheme.primary,
                                ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Business Name and Email
                        Text(
                          displayUser.businessName ?? displayUser.email.split('@')[0],
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        
                        Text(
                          displayUser.email,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        if (displayUser.businessName != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Ionicons.storefront,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  displayUser.businessName!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                        
                        // Quick Stats
                        profileStatsAsync.when(
                          data: (stats) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildQuickStat(
                                context,
                                icon: Ionicons.calendar,
                                label: 'Events',
                                value: stats.totalEvents.toString(),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                              _buildQuickStat(
                                context,
                                icon: Ionicons.cube,
                                label: 'Items',
                                value: stats.totalInventoryItems.toString(),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                              _buildQuickStat(
                                context,
                                icon: Ionicons.star,
                                label: 'Rating',
                                value: stats.averageRating > 0
                                    ? stats.averageRating.toStringAsFixed(1)
                                    : 'N/A',
                              ),
                            ],
                          ),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (_, __) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildQuickStat(
                                context,
                                icon: Ionicons.calendar,
                                label: 'Events',
                                value: '0',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                              _buildQuickStat(
                                context,
                                icon: Ionicons.cube,
                                label: 'Items',
                                value: '0',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                              _buildQuickStat(
                                context,
                                icon: Ionicons.star,
                                label: 'Rating',
                                value: 'N/A',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Account Management
                  _buildSection(
                    context,
                    'Account',
                    [
                      _buildActionTile(
                        context,
                        icon: Ionicons.create_outline,
                        title: 'Edit Profile',
                        subtitle: 'Update your information',
                        onTap: () {
                          context.push('/profile/edit');
                        },
                      ),
                      _buildActionTile(
                        context,
                        icon: Ionicons.calendar_outline,
                        title: 'My Bookings',
                        subtitle: 'View your booking history',
                        onTap: () {
                          context.push('/bookings');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Support & Legal
                  _buildSection(
                    context,
                    'Support & Legal',
                    [
                      _buildActionTile(
                        context,
                        icon: Ionicons.document_text_outline,
                        title: 'Terms of Service',
                        subtitle: 'Legal terms & conditions',
                        onTap: () {
                          context.push('/legal/terms');
                        },
                      ),
                      _buildActionTile(
                        context,
                        icon: Ionicons.shield_outline,
                        title: 'Privacy Policy',
                        subtitle: 'How we protect your data',
                        onTap: () {
                          context.push('/legal/privacy');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // About
                  Container(
                    decoration: AppTheme.darkCardDecoration,
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Ionicons.information_circle_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'About Bottles Up',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Version 1.0.0 • App info',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(
                        Ionicons.chevron_forward,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      onTap: () {
                        context.push('/about');
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Delete Account Button
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeleteAccountDialog(context, ref),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Ionicons.trash_outline,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Delete Account',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sign Out Button
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: authState.isLoading
                          ? null
                          : () => _showSignOutDialog(context, ref),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: authState.isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.error,
                                ),
                              ),
                            )
                          : Icon(
                              Ionicons.log_out_outline,
                              color: theme.colorScheme.error,
                            ),
                      label: Text(
                        'Sign Out',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: AppTheme.darkCardDecoration,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Ionicons.chevron_forward,
        color: theme.colorScheme.onSurfaceVariant,
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
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
          'This action cannot be undone. All your data, including profile, events, and bookings will be permanently deleted.',
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
              content: Text('Error deleting account: $e'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
    }
  }
} 