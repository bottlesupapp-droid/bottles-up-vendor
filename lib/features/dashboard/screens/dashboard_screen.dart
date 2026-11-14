import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../shared/models/dashboard_stats.dart';
import '../../../shared/models/venue_model.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../venues/providers/venues_provider.dart';
import '../providers/dashboard_provider.dart';

/// Overview (the first tab), as in the design: the date and a greeting with "Create event", a card with how the month is going, four figures, what needs you,
/// your venues, and shortcuts. Everything on it is read from the account: no sample numbers.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, DateTime? now}) : _now = now;

  final DateTime? _now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardProvider);
    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(onRetry: () => ref.invalidate(dashboardProvider)),
      data: (data) => ResponsiveWrapper(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(venueProfileCompletenessProvider);
            ref.invalidate(myVenuesProvider);
            await ref.read(dashboardProvider.future);
          },
          child: _Overview(data: data, now: _now ?? DateTime.now()),
        ),
      ),
    );
  }
}

String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

String dollars(num amount) => '\$${NumberFormat('#,###').format(amount.round())}';

class _Overview extends ConsumerWidget {
  const _Overview({required this.data, required this.now});

  final DashboardStats data;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bu = context.bu;
    final missing = ref.watch(venueProfileCompletenessProvider).valueOrNull ?? const <String>[];
    final venues = ref.watch(myVenuesProvider).valueOrNull ?? const <Venue>[];

    final confirmed = data.confirmedBookings;
    final total = data.totalBookings;
    final pending = data.monthlyBookings; // the figure the old screen called "pending" (bookings waiting to be confirmed)
    final upcoming = data.upcomingEvents;

    final heroTitle = upcoming > 0 ? (upcoming == 1 ? 'One event coming up' : '$upcoming events coming up') : 'Nothing coming up yet';
    final heroLine = <String>[
      if (data.monthlyRevenue > 0) '${dollars(data.monthlyRevenue)} in sales this month',
      if (total > 0) '$confirmed of $total ${total == 1 ? 'booking' : 'bookings'} confirmed',
      if (data.monthlyRevenue <= 0 && total <= 0) 'Create an event to start taking bookings.',
    ].join(' · ');

    final attention = <Widget>[
      if (pending > 0)
        BuListRow(
          key: const Key('attention-pending'),
          icon: Ionicons.time_outline,
          title: '$pending ${pending == 1 ? 'booking waits' : 'bookings wait'} for you',
          subtitle: 'Confirm them so guests know they are in',
          trailing: BuCountBadge(pending, tone: BuTone.attention),
          onTap: () => context.go('/bookings'),
        ),
      if (data.lowStockItems > 0)
        BuListRow(
          key: const Key('attention-stock'),
          icon: Ionicons.alert_circle_outline,
          title: '${data.lowStockItems} ${data.lowStockItems == 1 ? 'item is' : 'items are'} low on stock',
          subtitle: 'Restock before the next night',
          trailing: BuCountBadge(data.lowStockItems, tone: BuTone.attention),
          onTap: data.inventoryCount > 0 ? () => context.go('/inventory') : null,
        ),
      if (missing.isNotEmpty)
        BuListRow(
          key: const Key('attention-profile'),
          icon: Ionicons.create_outline,
          title: 'Finish your venue profile',
          subtitle: missing.take(2).join(' · '),
          trailing: BuCountBadge(missing.length, tone: BuTone.brand),
          onTap: () => context.go('/clubs'),
        ),
    ];

    final recent = <(IconData, String, DateTime)>[
      if (data.lastBookingDate != null) (Ionicons.bookmarks_outline, 'Last booking', data.lastBookingDate!),
      if (data.lastEventDate != null) (Ionicons.calendar_outline, 'Last event', data.lastEventDate!),
      if (data.lastInventoryUpdate != null) (Ionicons.wine_outline, 'Stock last updated', data.lastInventoryUpdate!),
    ];

    return ListView(
      key: const Key('overview-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xxl),
      children: [
        BuPageHeader(
          eyebrow: DateFormat('EEEE, d MMMM').format(now),
          title: greetingFor(now),
          trailing: FilledButton(
            key: const Key('overview-create-event'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            onPressed: () => context.push('/events/create'),
            child: const Text('Create event'),
          ),
        ),
        const SizedBox(height: BuSpace.xl),
        BuHeroCard(
          key: const Key('overview-hero'),
          eyebrow: 'This month',
          title: heroTitle,
          subtitle: heroLine,
          trailing: total > 0 ? BuRing(value: confirmed / total, center: '${(confirmed * 100 / total).round()}%', caption: 'confirmed', size: 84, stroke: 7) : null,
        ),
        const SizedBox(height: BuSpace.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BuStatTile(
                key: const Key('tile-bookings'),
                label: 'Bookings',
                value: '$total',
                note: '$confirmed confirmed',
                trend: total > 0 ? '$confirmed/$total' : null,
                trendTone: BuTone.neutral,
                onTap: () => context.go('/bookings'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BuStatTile(
                key: const Key('tile-events'),
                label: 'Events',
                value: '${data.totalEvents}',
                note: '$upcoming upcoming',
                trend: upcoming > 0 ? '$upcoming soon' : null,
                trendTone: BuTone.brand,
                onTap: () => context.go('/events'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: BuStatTile(key: const Key('tile-sales'), label: 'Sales', value: dollars(data.monthlyRevenue), note: 'This month · gross')),
            const SizedBox(width: 10),
            Expanded(
              child: BuStatTile(
                key: const Key('tile-payouts'),
                label: 'Payouts',
                value: dollars(data.confirmedRevenue),
                note: 'Estimated earnings',
                trend: data.confirmedRevenue > 0 ? '85%' : null,
                trendTone: BuTone.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: BuSpace.xl + 4),
        const BuSectionHeader(eyebrow: 'Needs attention', title: 'Stay ahead'),
        const SizedBox(height: BuSpace.m),
        if (attention.isEmpty)
          BuCard(key: const Key('attention-clear'), child: Text('All clear. Nothing needs you right now.', style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted)))
        else
          BuListCard(children: attention),
        const SizedBox(height: BuSpace.xl + 4),
        BuSectionHeader(eyebrow: 'Your venues', title: 'At a glance', actionLabel: 'All venues', onAction: () => context.go('/clubs')),
        const SizedBox(height: BuSpace.m),
        if (venues.isEmpty)
          BuListCard(children: [
            BuListRow(key: const Key('overview-add-venue'), icon: Ionicons.add_circle_outline, title: 'Add your first venue', subtitle: 'Guests find you, and book, through your venue', onTap: () => context.push('/clubs/create')),
          ])
        else
          Column(
            children: [
              for (final v in venues.take(3)) ...[
                BuMiniVenue(
                  key: Key('overview-venue-${v.id}'),
                  name: v.name,
                  line: v.status == VenueStatus.active ? 'Open · ${v.fullAddress ?? 'No address yet'}' : '${_statusWords(v.status)}${v.fullAddress == null ? '' : ' · ${v.fullAddress}'}',
                  live: v.status == VenueStatus.active,
                  onTap: () => context.push('/clubs/${v.id}'),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        const SizedBox(height: BuSpace.l),
        const BuSectionHeader(eyebrow: 'Shortcuts', title: 'Jump to'),
        const SizedBox(height: BuSpace.m),
        BuListCard(
          children: [
            BuListRow(key: const Key('shortcut-bookings'), icon: Ionicons.bookmarks_outline, title: 'Bookings', subtitle: 'Orders and who is coming', onTap: () => context.go('/bookings')),
            BuListRow(key: const Key('shortcut-bottles'), icon: Ionicons.wine_outline, title: 'Bottles', subtitle: 'Stock and low-stock alerts', onTap: () => context.go('/inventory')),
            BuListRow(
              key: const Key('shortcut-broadcast'),
              icon: Ionicons.megaphone_outline,
              title: 'Broadcast',
              subtitle: 'Send an alert to your guests or team',
              trailing: const BuComingSoonPill(),
              showChevron: false,
              onTap: () => showComingSoon(context, title: 'Broadcast', text: 'Send an alert to your guests or your team in one tap.'),
            ),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: BuSpace.xl),
          const BuSectionHeader(eyebrow: 'Recent', title: 'What happened last'),
          const SizedBox(height: BuSpace.m),
          BuListCard(
            children: [
              for (final (icon, label, at) in recent)
                BuListRow(icon: icon, title: label, subtitle: DateFormat('MMM d, h:mm a').format(at.toLocal()), showChevron: false),
            ],
          ),
        ],
      ],
    );
  }
}

String _statusWords(VenueStatus status) => switch (status) {
      VenueStatus.active => 'Open',
      VenueStatus.approved => 'Approved, not live yet',
      VenueStatus.pending => 'Waiting for approval',
      VenueStatus.suspended => 'Suspended',
    };

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BuSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Ionicons.cloud_offline_outline, size: 44, color: bu.muted),
            const SizedBox(height: BuSpace.l),
            Text('We could not load your overview', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: BuSpace.s),
            Text('Check your connection and try again.', style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted), textAlign: TextAlign.center),
            const SizedBox(height: BuSpace.xl),
            FilledButton.icon(key: const Key('overview-retry'), onPressed: onRetry, icon: const Icon(Ionicons.refresh), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
