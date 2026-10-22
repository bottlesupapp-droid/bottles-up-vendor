import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_info.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/site_contact_provider.dart';
import 'contact_support_screen.dart' show contactLinkOpenerProvider;

/// About: what the app is, the version it really is, how to reach BottlesUp and its social pages exactly as the BottlesUp team has set them in the CMS (a contact it has not filled in is not shown),
/// and the legal pages. Nothing about the company is written into the app.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _open(WidgetRef ref, Uri uri) async {
    try {
      await ref.read(contactLinkOpenerProvider)(uri);
    } catch (_) {
      // nothing on this device can open it: the address is on the screen to copy
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
              'BottlesUp Business',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'For venues and event organizers',
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
                appVersionLabel,
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
                    'Helping venues and event organizers manage events, inventory, and bookings while delivering exceptional experiences to customers.',
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
                    'Payments',
                    'Record what guests pay and follow what is owed',
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Contact and social pages: only what the BottlesUp team has published in the CMS
            ref.watch(siteContactProvider).maybeWhen(
                  data: (c) => c.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            Container(
                              key: const Key('about-contact'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: AppTheme.darkCardDecoration,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Contact', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  if (c.email != null) _buildInfoRow(theme, 'Email', c.email!, isLast: c.phone == null && c.address == null),
                                  if (c.phone != null) _buildInfoRow(theme, 'Phone', c.phone!, isLast: c.address == null),
                                  if (c.address != null) _buildInfoRow(theme, 'Location', c.address!, isLast: true),
                                  if (c.socials.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        for (final link in c.socials)
                                          ActionChip(key: Key('about-social-${link.name.toLowerCase()}'), label: Text(link.name), onPressed: () => _open(ref, link.url)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),

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
                    onTap: () => context.push('/legal/terms'),
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
                    onTap: () => context.push('/legal/privacy'),
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
                        applicationName: 'BottlesUp Business',
                        applicationVersion: appVersion,
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
              '© BottlesUp',
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
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
}
