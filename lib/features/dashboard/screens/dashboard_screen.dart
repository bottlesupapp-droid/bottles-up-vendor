import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../../core/utils/responsive_utils.dart' as utils;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardData = ref.watch(dashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: ResponsiveText.titleLarge(
          'Dashboard',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications - Coming Soon')),
              );
            },
            icon: const Icon(Ionicons.notifications_outline),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: dashboardData.when(
        data: (data) => _buildDashboardContent(context, data, ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(context, error, ref),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, dynamic data, WidgetRef ref) {
    final hasEvents = data.activeEvents > 0;

    return ResponsiveWrapper(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            utils.ResponsiveUtils.getResponsivePadding(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            SizedBox(
              height: utils.ResponsiveUtils.getResponsiveSpacing(context),
            ),

            // Show Empty State or Dashboard Content
            if (!hasEvents) ...[
              _buildEmptyState(context),
            ] else ...[
              // Metric Cards - 6 cards in 2 rows
              _buildMetricCardsSection(context, data),

              SizedBox(
                height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2,
              ),

              // Quick Actions - 4 buttons
              _buildQuickActionsSection(context),

              SizedBox(
                height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2,
              ),

              // Activity Feed
              _buildActivityFeedSection(context, data),

              SizedBox(
                height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2,
              ),

              // Analytics Cards
              _buildAnalyticsCardsSection(context, data),

              SizedBox(
                height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2,
              ),

              // Configurable Widgets Section
              _buildConfigurableSection(context),
            ],

            SizedBox(
              height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2,
            ),
          ],
        ),
      ),
      ),
    );
  }


  Widget _buildMetricCardsSection(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText.titleLarge(
          'Overview',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

        ResponsiveGrid(
          children: [
            // Sales Card
            _buildMetricCard(
              context,
              icon: Ionicons.cash_outline,
              title: 'Sales',
              value: '\$${NumberFormat('#,###').format(data.monthlyRevenue)}',
              subtitle: 'This month',
              color: Colors.green,
              trend: data.monthlyRevenue > 0 ? '+12.5%' : null,
            ),
            // Events Card
            _buildMetricCard(
              context,
              icon: Ionicons.calendar_outline,
              title: 'Events',
              value: data.activeEvents.toString(),
              subtitle: '${data.upcomingEvents} upcoming',
              color: theme.colorScheme.primary,
              trend: data.upcomingEvents > 0 ? '+${data.upcomingEvents}' : null,
            ),
            // Payouts Card
            _buildMetricCard(
              context,
              icon: Ionicons.wallet_outline,
              title: 'Payouts',
              value: '\$${NumberFormat('#,###').format((data.monthlyRevenue * 0.85).toInt())}',
              subtitle: 'Pending',
              color: Colors.blue,
              trend: 'Processing',
            ),
            // Pre-orders Card
            _buildMetricCard(
              context,
              icon: Ionicons.bookmarks_outline,
              title: 'Pre-orders',
              value: data.totalBookings.toString(),
              subtitle: '${data.confirmedBookings} confirmed',
              color: Colors.purple,
              trend:
                  data.confirmedBookings > 0
                      ? '${((data.confirmedBookings / data.totalBookings) * 100).toStringAsFixed(0)}%'
                      : null,
            ),
            // Love Bottles Card
            _buildMetricCard(
              context,
              icon: Ionicons.heart_outline,
              title: 'Love Bottles',
              value: '${(data.totalBookings * 0.3).toInt()}',
              subtitle: 'Favorited',
              color: Colors.pink,
              trend: '+8',
            ),
            // Low Stock Card
            _buildMetricCard(
              context,
              icon: Ionicons.alert_circle_outline,
              title: 'Low Stock',
              value: data.lowStockItems.toString(),
              subtitle: 'Items need restock',
              color: Colors.amber,
              trend:
                  data.lowStockItems > 0
                      ? '${data.lowStockItems} alerts'
                      : null,
              isAlert: data.lowStockItems > 0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText.titleLarge(
          'Quick Actions',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

        ResponsiveGrid(
          crossAxisCount: getValueForScreenType<int>(
            context: context,
            mobile: 2,
            tablet: 4,
            desktop: 4,
          ),
          childAspectRatio: getValueForScreenType<double>(
            context: context,
            mobile: 1.0,
            tablet: 1.3,
            desktop: 1.5,
          ),
          children: [
            _buildActionCard(
              context,
              icon: Ionicons.add_circle_outline,
              title: 'Create Event',
              subtitle: 'New event',
              onTap: () => context.go('/events/create'),
            ),
            _buildActionCard(
              context,
              icon: Ionicons.calendar_outline,
              title: 'Bookings',
              subtitle: 'View orders',
              onTap: () => context.go('/bookings'),
            ),
            _buildActionCard(
              context,
              icon: Ionicons.wine_outline,
              title: 'Bottles',
              subtitle: 'Inventory',
              onTap: () => context.go('/inventory'),
            ),
            _buildActionCard(
              context,
              icon: Ionicons.megaphone_outline,
              title: 'Broadcast',
              subtitle: 'Send alerts',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Broadcast - Coming Soon')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityFeedSection(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ResponsiveText.titleLarge(
              'Activity Feed',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('View All - Coming Soon')),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

        ResponsiveContainer(
          decoration: AppTheme.darkCardDecoration,
          child: Column(
            children: [
              _buildActivityItem(
                context,
                icon: Ionicons.calendar_outline,
                title: 'New booking received',
                subtitle: data.lastBookingDate != null
                    ? DateFormat('MMM dd, yyyy • hh:mm a')
                        .format(data.lastBookingDate!)
                    : 'No bookings yet',
                color: theme.colorScheme.primary,
                trailing: '\$${NumberFormat('#,###').format(250)}',
              ),
              Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
              _buildActivityItem(
                context,
                icon: Ionicons.cash_outline,
                title: 'Payout processed',
                subtitle: 'Transferred to bank account',
                color: Colors.green,
                trailing: '\$${NumberFormat('#,###').format((data.monthlyRevenue * 0.4).toInt())}',
              ),
              Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
              _buildActivityItem(
                context,
                icon: Ionicons.pricetag_outline,
                title: 'Promo code used',
                subtitle: 'SUMMER2024 • Table booking',
                color: Colors.purple,
                trailing: '-15%',
              ),
              Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
              _buildActivityItem(
                context,
                icon: Ionicons.cube_outline,
                title: 'Low stock alert',
                subtitle: '${data.lowStockItems} items need restock',
                color: Colors.amber,
                trailing: '!',
                isAlert: data.lowStockItems > 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    String? trend,
    bool isAlert = false,
  }) {
    final theme = Theme.of(context);

    return ResponsiveContainer(
      decoration: AppTheme.darkCardDecoration.copyWith(
        border:
            isAlert
                ? Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                  width: 1,
                )
                : null,
      ),
      padding: EdgeInsets.all(
        utils.ResponsiveUtils.getResponsiveCardPadding(context) * 0.85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (trend != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isAlert
                              ? theme.colorScheme.error.withValues(alpha: 0.1)
                              : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      trend,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isAlert ? theme.colorScheme.error : color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ResponsiveText.headlineMedium(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  isAlert
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          ResponsiveText.titleSmall(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          ResponsiveText.bodySmall(
            subtitle,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ResponsiveContainer(
        decoration: AppTheme.darkCardDecoration,
        padding: EdgeInsets.all(
          utils.ResponsiveUtils.getResponsiveCardPadding(context) * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(height: 6),
            ResponsiveText.titleSmall(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            ResponsiveText.bodySmall(
              subtitle,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? trailing,
    bool isAlert = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveText.titleSmall(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(
                  height:
                      utils.ResponsiveUtils.getResponsiveSpacing(context) *
                      0.25,
                ),
                ResponsiveText.bodySmall(
                  subtitle,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (trailing != null)
            ResponsiveText.titleSmall(
              trailing,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isAlert ? theme.colorScheme.error : color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Ionicons.calendar_outline,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            ResponsiveText.headlineSmall(
              'No events yet',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ResponsiveText.bodyMedium(
              'Create your first event to start managing\nbookings and inventory',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/events/create'),
              icon: const Icon(Ionicons.add_circle_outline),
              label: const Text('Create Event'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCardsSection(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ResponsiveText.titleLarge(
              'Analytics',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Ionicons.trending_up,
                    color: theme.colorScheme.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Last 30 days',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

        ResponsiveGrid(
          crossAxisCount: getValueForScreenType<int>(
            context: context,
            mobile: 1,
            tablet: 2,
            desktop: 3,
          ),
          children: [
            // Top Events Card
            _buildAnalyticsCard(
              context,
              title: 'Top Events',
              icon: Ionicons.trophy,
              iconColor: Colors.amber,
              items: [
                _AnalyticsItem('Summer Bash 2024', 156, 0.95),
                _AnalyticsItem('Friday Night Live', 142, 0.86),
                _AnalyticsItem('Weekend Vibes', 128, 0.78),
              ],
            ),

            // Best Promoters Card
            _buildAnalyticsCard(
              context,
              title: 'Best Promoters',
              icon: Ionicons.people,
              iconColor: Colors.blue,
              items: [
                _AnalyticsItem('John Smith', 45, 0.90),
                _AnalyticsItem('Sarah Johnson', 38, 0.76),
                _AnalyticsItem('Mike Davis', 32, 0.64),
              ],
            ),

            // Most Ordered Bottles Card
            _buildAnalyticsCard(
              context,
              title: 'Popular Bottles',
              icon: Ionicons.wine,
              iconColor: Colors.purple,
              items: [
                _AnalyticsItem('Grey Goose', 89, 1.0),
                _AnalyticsItem('Hennessy VS', 76, 0.85),
                _AnalyticsItem('Patron Silver', 65, 0.73),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_AnalyticsItem> items,
  }) {
    final theme = Theme.of(context);

    return ResponsiveContainer(
      decoration: AppTheme.darkCardDecoration.copyWith(
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(
        utils.ResponsiveUtils.getResponsiveCardPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: ResponsiveText.titleMedium(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Ionicons.chevron_forward,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < items.length - 1 ? 16 : 0),
              child: _buildAnalyticsItemRow(context, item, index + 1, iconColor),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAnalyticsItemRow(
    BuildContext context,
    _AnalyticsItem item,
    int rank,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: rank == 1
                    ? color.withValues(alpha: 0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: rank == 1 ? color : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.value} ${rank == 1 ? "🔥" : ""}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: item.progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              rank == 1 ? color : color.withValues(alpha: 0.7),
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurableSection(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveContainer(
      decoration: AppTheme.darkCardDecoration.copyWith(
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Ionicons.options_outline,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveText.titleMedium(
                  'Customize Dashboard',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(
                  height:
                      utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.3,
                ),
                ResponsiveText.bodySmall(
                  'Configure widgets and layout preferences',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customize - Coming Soon')),
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.primary),
            ),
            child: const Text('Customize'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: ResponsiveWrapper(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Ionicons.warning_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            ResponsiveText.headlineSmall(
              'Unable to load dashboard',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ResponsiveText.bodyMedium(
              'Please check your connection and try again',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => ref.refresh(dashboardProvider),
              icon: const Icon(Ionicons.refresh_outline),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for analytics items
class _AnalyticsItem {
  final String name;
  final int value;
  final double progress;

  _AnalyticsItem(this.name, this.value, this.progress);
}
