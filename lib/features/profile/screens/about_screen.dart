import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Logo and Name
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Ionicons.wine,
                size: 60,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Bottles Up',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Vendor Platform',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Version 1.0.0 (Build 1)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Mission Statement
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                children: [
                  Icon(
                    Ionicons.rocket_outline,
                    color: theme.colorScheme.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Our Mission',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Empowering vendors to seamlessly manage events, inventory, and bookings while delivering exceptional experiences to customers.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Features
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What We Offer',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    theme,
                    Ionicons.calendar_outline,
                    'Event Management',
                    'Create and manage multiple events with ease',
                  ),
                  _buildFeatureItem(
                    theme,
                    Ionicons.cube_outline,
                    'Inventory Control',
                    'Track stock levels and receive low inventory alerts',
                  ),
                  _buildFeatureItem(
                    theme,
                    Ionicons.people_outline,
                    'Booking System',
                    'Manage customer bookings efficiently',
                  ),
                  _buildFeatureItem(
                    theme,
                    Ionicons.analytics_outline,
                    'Analytics',
                    'Gain insights with detailed analytics and reports',
                  ),
                  _buildFeatureItem(
                    theme,
                    Ionicons.card_outline,
                    'Secure Payments',
                    'Fast and secure payment processing',
                  ),
                  _buildFeatureItem(
                    theme,
                    Ionicons.headset_outline,
                    '24/7 Support',
                    'Round-the-clock customer support',
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Company Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(theme, 'Company', 'Bottles Up Inc.'),
                  _buildInfoRow(theme, 'Founded', '2024'),
                  _buildInfoRow(theme, 'Location', 'New York, USA'),
                  _buildInfoRow(theme, 'Email', 'info@bottlesup.com'),
                  _buildInfoRow(theme, 'Phone', '+1-800-BOTTLES', isLast: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Social Media
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                children: [
                  Text(
                    'Connect With Us',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        theme,
                        Ionicons.logo_facebook,
                        'Facebook',
                        () => _launchUrl('https://facebook.com/bottlesup'),
                      ),
                      _buildSocialButton(
                        theme,
                        Ionicons.logo_twitter,
                        'Twitter',
                        () => _launchUrl('https://twitter.com/bottlesup'),
                      ),
                      _buildSocialButton(
                        theme,
                        Ionicons.logo_instagram,
                        'Instagram',
                        () => _launchUrl('https://instagram.com/bottlesup'),
                      ),
                      _buildSocialButton(
                        theme,
                        Ionicons.logo_linkedin,
                        'LinkedIn',
                        () => _launchUrl('https://linkedin.com/company/bottlesup'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Legal Links
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Ionicons.document_text_outline,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Terms of Service'),
                    trailing: Icon(
                      Ionicons.chevron_forward,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/legal/terms');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  ListTile(
                    leading: Icon(
                      Ionicons.shield_checkmark_outline,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Privacy Policy'),
                    trailing: Icon(
                      Ionicons.chevron_forward,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/legal/privacy');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  ListTile(
                    leading: Icon(
                      Ionicons.newspaper_outline,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Open Source Licenses'),
                    trailing: Icon(
                      Ionicons.chevron_forward,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Bottles Up Vendor',
                        applicationVersion: '1.0.0',
                        applicationIcon: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Ionicons.wine,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Copyright
            Text(
              '© 2025 Bottles Up Inc.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    ThemeData theme,
    IconData icon,
    String title,
    String description, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildSocialButton(
    ThemeData theme,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
