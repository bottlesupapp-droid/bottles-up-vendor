import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'sales_progress_bar.dart';

class EventCardEnhanced extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const EventCardEnhanced({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventDate = _parseEventDate();
    final isUpcoming = eventDate.isAfter(DateTime.now());
    final capacity = event['max_capacity'] as int? ?? 0;
    final soldCount = event['sales_count'] as int? ?? event['current_bookings'] as int? ?? 0;
    final revenue = event['revenue'] as num? ?? 0;
    final isSoldOut = soldCount >= capacity;
    final isLowStock = soldCount >= (capacity * 0.8) && soldCount < capacity;
    final status = event['status'] as String? ?? 'upcoming';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flyer Image Section with Gradient Overlay
            _buildImageSection(context),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badges
                  _buildStatusBadges(context, status, isUpcoming, isSoldOut, isLowStock),

                  const SizedBox(height: 16),

                  // Event Title
                  Text(
                    event['name'] ?? 'Untitled Event',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Date and Venue
                  _buildInfoRow(context, eventDate),

                  const SizedBox(height: 16),

                  // Sales Progress Bar
                  SalesProgressBar(
                    sold: soldCount,
                    capacity: capacity,
                  ),

                  const SizedBox(height: 16),

                  // Revenue Display
                  _buildRevenueDisplay(context, revenue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final theme = Theme.of(context);
    final flyerImageUrl = event['flyer_image_url'] as String?;
    final images = event['images'] as List?;
    final imageUrl = flyerImageUrl ?? (images?.isNotEmpty == true ? images!.first : null);
    final eventName = event['name'] ?? 'Untitled Event';

    return Stack(
      children: [
        // Image or Placeholder
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: imageUrl != null
              ? ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildPlaceholderImage(context),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildPlaceholderImage(context);
                    },
                  ),
                )
              : _buildPlaceholderImage(context),
        ),

        // Gradient Overlay at Bottom
        if (imageUrl != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              child: Text(
                eventName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 3.0,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Center(
        child: Icon(
          Ionicons.calendar_outline,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildStatusBadges(
    BuildContext context,
    String status,
    bool isUpcoming,
    bool isSoldOut,
    bool isLowStock,
  ) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(theme, status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor(theme, status).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            _getStatusLabel(status),
            style: theme.textTheme.labelSmall?.copyWith(
              color: _getStatusColor(theme, status),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Sold Out Badge
        if (isSoldOut)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Sold Out',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // Low Stock Badge
        if (isLowStock && !isSoldOut)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Low Stock',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // Featured Badge
        if (event['is_featured'] == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFB800).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'Featured',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFFFFB800),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(ThemeData theme, String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return theme.colorScheme.secondary;
      case 'published':
      case 'upcoming':
      case 'live':
        return theme.colorScheme.primary;
      case 'completed':
        return theme.colorScheme.tertiary;
      case 'cancelled':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'published':
        return 'Published';
      case 'upcoming':
        return 'Upcoming';
      case 'live':
      case 'ongoing':
        return 'Live';
      case 'completed':
        return 'Past';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Widget _buildInfoRow(BuildContext context, DateTime eventDate) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final venue = event['club_id'] != null ? 'Club Venue' : event['city'] ?? 'Venue TBA';

    return Row(
      children: [
        Icon(
          Ionicons.calendar_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            dateFormat.format(eventDate),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Ionicons.location_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            venue,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueDisplay(BuildContext context, num revenue) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Ionicons.cash_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Revenue',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            '\$${revenue.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseEventDate() {
    try {
      if (event['event_date'] != null) {
        return DateTime.parse(event['event_date'].toString());
      }
    } catch (e) {
      // Handle parsing errors
    }
    return DateTime.now();
  }
}
