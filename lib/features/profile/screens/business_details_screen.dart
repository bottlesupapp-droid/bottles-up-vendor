import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../core/theme/app_theme.dart';

class BusinessDetailsScreen extends ConsumerWidget {
  const BusinessDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Business Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Business Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Ionicons.storefront,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Business Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildInfoRow(
                    context,
                    icon: Ionicons.business_outline,
                    label: 'Business Name',
                    value: 'Bottles Up Vendor',
                  ),
                  const SizedBox(height: 16),

                  _buildInfoRow(
                    context,
                    icon: Ionicons.location_outline,
                    label: 'Address',
                    value: 'Coming Soon',
                  ),
                  const SizedBox(height: 16),

                  _buildInfoRow(
                    context,
                    icon: Ionicons.call_outline,
                    label: 'Business Phone',
                    value: 'Coming Soon',
                  ),
                  const SizedBox(height: 16),

                  _buildInfoRow(
                    context,
                    icon: Ionicons.mail_outline,
                    label: 'Business Email',
                    value: 'Coming Soon',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Operating Hours Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Ionicons.time_outline,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Operating Hours',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildHoursRow(context, 'Monday', '9:00 AM - 5:00 PM'),
                  _buildHoursRow(context, 'Tuesday', '9:00 AM - 5:00 PM'),
                  _buildHoursRow(context, 'Wednesday', '9:00 AM - 5:00 PM'),
                  _buildHoursRow(context, 'Thursday', '9:00 AM - 5:00 PM'),
                  _buildHoursRow(context, 'Friday', '9:00 AM - 5:00 PM'),
                  _buildHoursRow(context, 'Saturday', '10:00 AM - 2:00 PM'),
                  _buildHoursRow(context, 'Sunday', 'Closed', isClosed: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Edit Button
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit Business Details - Coming Soon')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Ionicons.create_outline),
                label: const Text(
                  'Edit Business Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHoursRow(
    BuildContext context,
    String day,
    String hours, {
    bool isClosed = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            hours,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isClosed
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
