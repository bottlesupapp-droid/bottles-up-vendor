import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Ionicons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coming Soon Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.darkContainerDecoration,
              child: Column(
                children: [
                  Icon(
                    Ionicons.construct_outline,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Settings Coming Soon',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re working on bringing you comprehensive settings to customize your experience.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Features Preview
            Text(
              'Upcoming Features',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                children: [
                  _buildFeatureTile(
                    context,
                    icon: Ionicons.create_outline,
                    title: 'Profile Editing',
                    subtitle: 'Update your personal information',
                  ),
                  _buildFeatureTile(
                    context,
                    icon: Ionicons.lock_closed_outline,
                    title: 'Security Settings',
                    subtitle: 'Manage passwords and 2FA',
                  ),
                  _buildFeatureTile(
                    context,
                    icon: Ionicons.notifications_outline,
                    title: 'Notification Preferences',
                    subtitle: 'Control how you receive alerts',
                  ),
                  _buildFeatureTile(
                    context,
                    icon: Ionicons.shield_checkmark_outline,
                    title: 'Privacy Controls',
                    subtitle: 'Manage your data and privacy',
                  ),
                  _buildFeatureTile(
                    context,
                    icon: Ionicons.language_outline,
                    title: 'Language & Region',
                    subtitle: 'Customize localization settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    
    return ListTile(
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
        Ionicons.time_outline,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
    );
  }
} 