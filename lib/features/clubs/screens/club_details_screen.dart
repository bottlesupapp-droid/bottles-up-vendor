import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../features/venues/providers/venues_provider.dart';
import '../../../features/venues/services/venue_request_service.dart';
import '../../../shared/models/venue_model.dart';

class ClubDetailsScreen extends ConsumerWidget {
  final String clubId;

  const ClubDetailsScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueAsync = ref.watch(venueByIdProvider(clubId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: venueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load venue: $e')),
        data: (venue) {
          if (venue == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 48),
                  const SizedBox(height: 12),
                  const Text('Venue not found'),
                  TextButton(
                      onPressed: () => context.pop(), child: const Text('Go Back')),
                ],
              ),
            );
          }
          return _VenueDetailBody(venue: venue, ref: ref);
        },
      ),
    );
  }
}

class _VenueDetailBody extends StatelessWidget {
  final Venue venue;
  final WidgetRef ref;

  const _VenueDetailBody({required this.venue, required this.ref});

  Color _statusColor() {
    switch (venue.status) {
      case VenueStatus.active:
        return Colors.green;
      case VenueStatus.approved:
        return Colors.blue;
      case VenueStatus.suspended:
        return Colors.red;
      case VenueStatus.pending:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor();
    final sl = venue.socialLinks ?? {};

    return CustomScrollView(
      slivers: [
        // Hero app bar
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () =>
                  context.push('/clubs/${venue.id}/edit', extra: venue),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(venue.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            background: venue.gallery.isNotEmpty
                ? Image.network(venue.gallery.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _heroBg(theme))
                : _heroBg(theme),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        venue.status.name[0].toUpperCase() +
                            venue.status.name.substring(1),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quick stats row
                Row(
                  children: [
                    if (venue.capacity != null)
                      Expanded(
                        child: _StatCard(
                          icon: Icons.people_outline,
                          label: 'Capacity',
                          value: '${venue.capacity}',
                        ),
                      ),
                    if (venue.capacity != null) const SizedBox(width: 12),
                    if (sl['vip_booths'] != null)
                      Expanded(
                        child: _StatCard(
                          icon: Icons.table_bar_outlined,
                          label: 'VIP Booths',
                          value: '${sl['vip_booths']}',
                        ),
                      ),
                    if (sl['vip_booths'] != null) const SizedBox(width: 12),
                    if (sl['side_tables'] != null)
                      Expanded(
                        child: _StatCard(
                          icon: Icons.chair_outlined,
                          label: 'Side Tables',
                          value: '${sl['side_tables']}',
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Address
                if (venue.fullAddress != null)
                  _Section(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    child: Text(venue.fullAddress!,
                        style: theme.textTheme.bodyMedium),
                  ),

                // Description
                if (venue.description != null &&
                    venue.description!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    icon: Icons.info_outline,
                    title: 'About',
                    child: Text(venue.description!,
                        style: theme.textTheme.bodyMedium),
                  ),
                ],

                // Venue details
                const SizedBox(height: 16),
                _Section(
                  icon: Icons.nightlife,
                  title: 'Venue Details',
                  child: Column(
                    children: [
                      if (sl['venue_type'] != null)
                        _DetailRow('Type', sl['venue_type']),
                      if (sl['min_age'] != null)
                        _DetailRow('Age Requirement', '${sl['min_age']}+'),
                      if (sl['dress_code'] != null)
                        _DetailRow('Dress Code', sl['dress_code']),
                    ],
                  ),
                ),

                // Music
                if (sl['music_genres'] != null &&
                    (sl['music_genres'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    icon: Icons.music_note_outlined,
                    title: 'Music',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (sl['music_genres'] as List)
                          .map((g) => Chip(
                                label: Text(g.toString()),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ),
                ],

                // Amenities
                if (sl['amenities'] != null &&
                    (sl['amenities'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    icon: Icons.star_outline,
                    title: 'Amenities',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (sl['amenities'] as List)
                          .map((a) => Chip(
                                label: Text(a.toString()),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ),
                ],

                // Contact
                if (venue.phone != null || venue.email != null) ...[
                  const SizedBox(height: 16),
                  _Section(
                    icon: Icons.contact_phone_outlined,
                    title: 'Contact',
                    child: Column(
                      children: [
                        if (venue.phone != null)
                          _DetailRow('Phone', venue.phone!),
                        if (venue.email != null)
                          _DetailRow('Email', venue.email!),
                      ],
                    ),
                  ),
                ],

                // Gallery
                if (venue.gallery.length > 1) ...[
                  const SizedBox(height: 16),
                  _Section(
                    icon: Icons.photo_library_outlined,
                    title: 'Gallery',
                    child: SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: venue.gallery.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            venue.gallery[i],
                            width: 140,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 140, height: 100,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Edit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/clubs/${venue.id}/edit', extra: venue),
                    icon: const Icon(Ionicons.create_outline),
                    label: const Text('Edit Venue'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete Venue',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroBg(ThemeData theme) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Ionicons.business_outline,
              size: 64, color: theme.colorScheme.onSurfaceVariant),
        ),
      );

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Venue'),
        content: Text(
            'Are you sure you want to delete "${venue.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final service = ref.read(venueRequestServiceProvider);
                await service.deleteVenue(venue.id);
                ref.invalidate(myVenuesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Venue deleted'),
                        backgroundColor: Colors.green),
                  );
                  context.go('/clubs');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed to delete: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Section(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
