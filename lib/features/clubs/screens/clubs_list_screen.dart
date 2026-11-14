import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../features/venues/providers/venues_provider.dart';
import '../../../shared/models/venue_model.dart';

/// The five things a venue needs before guests can find it: its photos, its details, a description, an address and a capacity. Each is done or not.
List<(String, bool)> venueSetupItems(Venue v) {
  final links = v.socialLinks;
  final hasDetails = links != null && (links['venue_type'] != null || links['music_genres'] != null || links['amenities'] != null);
  final fp = v.floorplanData;
  final hasDescription = (v.description ?? '').trim().isNotEmpty || ((fp?['description'] as String?) ?? '').trim().isNotEmpty;
  final hasAddress = (v.fullAddress ?? '').trim().isNotEmpty;
  return [
    ('Photos', v.gallery.isNotEmpty),
    ('Details', hasDetails),
    ('Description', hasDescription),
    ('Address', hasAddress),
    ('Capacity', v.capacity != null),
  ];
}

/// Venues (a tab), as in the design: a heading with a round "add" button, a strip of three figures, then one card per venue with its setup progress.
class ClubsListScreen extends ConsumerWidget {
  const ClubsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(myVenuesProvider);
    final theme = Theme.of(context);
    final bu = context.bu;

    return venuesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Ionicons.alert_circle_outline, size: 48, color: bu.red),
            const SizedBox(height: 12),
            Text('Failed to load venues', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextButton(onPressed: () => ref.invalidate(myVenuesProvider), child: const Text('Retry')),
          ],
        ),
      ),
      data: (venues) {
        final items = [for (final v in venues) venueSetupItems(v)];
        final done = items.fold<int>(0, (sum, list) => sum + list.where((i) => i.$2).length);
        final total = items.fold<int>(0, (sum, list) => sum + list.length);
        final open = venues.where((v) => v.status == VenueStatus.active).length;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myVenuesProvider),
          child: ListView(
            key: const Key('venues-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, 100),
            children: [
              BuPageHeader(
                eyebrow: 'Your business',
                title: 'Venues',
                intro: "Manage spaces, teams, and tonight's setup.",
                trailing: Semantics(
                  button: true,
                  label: 'Add venue',
                  child: Material(
                    color: bu.orange,
                    borderRadius: BorderRadius.circular(BuRadius.control),
                    child: InkWell(
                      key: const Key('venues-add'),
                      borderRadius: BorderRadius.circular(BuRadius.control),
                      onTap: () => context.push('/clubs/create'),
                      child: SizedBox(width: 44, height: 44, child: Icon(Ionicons.add, color: Colors.white, size: 24)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BuSpace.xl),
              if (venues.isEmpty)
                BuCard(
                  key: const Key('venues-empty'),
                  child: Column(
                    children: [
                      const BuIconTile(icon: Ionicons.business_outline, size: 56),
                      const SizedBox(height: BuSpace.l),
                      Text('No venues yet', style: theme.textTheme.titleLarge),
                      const SizedBox(height: BuSpace.s),
                      Text('Add your first venue to start managing events and bookings.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted)),
                      const SizedBox(height: BuSpace.xl),
                      FilledButton.icon(key: const Key('venues-empty-add'), onPressed: () => context.push('/clubs/create'), icon: const Icon(Ionicons.add), label: const Text('Add Venue')),
                    ],
                  ),
                )
              else ...[
                _SummaryStrip(venues: venues.length, open: open, setupPercent: total == 0 ? 0 : (done * 100 / total).round()),
                const SizedBox(height: BuSpace.m),
                for (var i = 0; i < venues.length; i++) ...[
                  _VenueCard(
                    venue: venues[i],
                    setup: items[i],
                    onTap: () => context.go('/clubs/${venues[i].id}'),
                    onEdit: () => context.push('/clubs/${venues[i].id}/edit', extra: venues[i]),
                  ),
                  const SizedBox(height: BuSpace.m),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.venues, required this.open, required this.setupPercent});

  final int venues;
  final int open;
  final int setupPercent;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    Widget cell(String key, String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, key: Key(key), style: text.titleLarge?.copyWith(fontSize: 20)),
              const SizedBox(height: 5),
              Text(label, style: text.bodySmall?.copyWith(color: bu.muted)),
            ],
          ),
        );
    return BuCard(
      key: const Key('venues-summary'),
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 6),
      child: IntrinsicHeight(
        child: Row(
          children: [
            cell('summary-venues', '$venues', venues == 1 ? 'Venue' : 'Venues'),
            VerticalDivider(width: 1, color: bu.line),
            cell('summary-open', '$open', 'Open'),
            VerticalDivider(width: 1, color: bu.line),
            cell('summary-setup', '$setupPercent%', 'Setup complete'),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.setup, required this.onTap, required this.onEdit});

  final Venue venue;
  final List<(String, bool)> setup;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bu = context.bu;
    final done = setup.where((i) => i.$2).length;
    final complete = done == setup.length;
    final (statusLabel, tone) = switch (venue.status) {
      VenueStatus.active => ('Open', BuTone.good),
      VenueStatus.approved => ('Approved', BuTone.brand),
      VenueStatus.pending => ('Pending', BuTone.attention),
      VenueStatus.suspended => ('Suspended', BuTone.bad),
    };
    final facts = <String>[
      if (venue.capacity != null) '${venue.capacity} guests',
      if (venue.socialLinks?['venue_type'] != null) '${venue.socialLinks!['venue_type']}',
      if (venue.socialLinks?['min_age'] != null) '${venue.socialLinks!['min_age']}+',
    ];
    return BuCard(
      key: Key('venue-card-${venue.id}'),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BuRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 105,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A2218), Color(0xFF191412)])),
                    child: venue.gallery.isNotEmpty
                        ? Image.network(venue.gallery.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
                        : null,
                  ),
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.05)]))),
                  Padding(
                    padding: const EdgeInsets.all(BuSpace.xl - 4),
                    child: Row(
                      children: [
                        Text(BuMiniVenue.initialsOf(venue.name), style: theme.textTheme.displaySmall?.copyWith(fontSize: 32, letterSpacing: -2.5, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        BuStatusPill(statusLabel, key: Key('venue-status-${venue.id}'), tone: tone),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BuSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(venue.name, style: theme.textTheme.titleLarge?.copyWith(fontSize: 19), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (venue.fullAddress != null) ...[
                              const SizedBox(height: 4),
                              Text(venue.fullAddress!, style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        key: Key('venue-edit-${venue.id}'),
                        tooltip: 'Edit venue',
                        onPressed: onEdit,
                        icon: Icon(Ionicons.create_outline, size: 20, color: bu.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: BuSpace.m),
                  Row(
                    children: [
                      Expanded(child: Text('Venue setup', style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted))),
                      Text('$done of ${setup.length}', key: Key('venue-setup-${venue.id}'), style: theme.textTheme.labelLarge),
                    ],
                  ),
                  const SizedBox(height: BuSpace.s),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BuRadius.pill),
                    child: LinearProgressIndicator(value: done / setup.length, minHeight: 5, backgroundColor: bu.line, valueColor: AlwaysStoppedAnimation(complete ? bu.green : bu.orange)),
                  ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: BuSpace.m + 2),
                    Text(facts.join(' · '), style: theme.textTheme.bodyMedium?.copyWith(color: bu.soft)),
                  ],
                  const SizedBox(height: BuSpace.l),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: Key('venue-manage-${venue.id}'),
                      onPressed: onTap,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Manage venue'), const SizedBox(width: 8), Icon(Ionicons.arrow_forward, size: 16, color: bu.ink)]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
