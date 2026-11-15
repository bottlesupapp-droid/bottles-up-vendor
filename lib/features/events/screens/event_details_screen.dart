import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../core/utils/plain_error.dart';
import '../../../shared/models/event.dart';
import '../providers/event_details_provider.dart';

/// The word and colour for an event's status.
(String, BuTone) eventStatusLook(String status) {
  switch (status.toLowerCase()) {
    case 'active':
    case 'upcoming':
      return (status.toLowerCase() == 'upcoming' ? 'Upcoming' : 'Live', BuTone.good);
    case 'draft':
      return ('Draft', BuTone.attention);
    case 'completed':
      return ('Completed', BuTone.brand);
    case 'cancelled':
      return ('Cancelled', BuTone.bad);
    default:
      return (status.isEmpty ? 'Unknown' : '${status[0].toUpperCase()}${status.substring(1)}', BuTone.neutral);
  }
}

/// An event, as the design draws a detail page: what it is (picture, name, status, when, price), four figures, then what you can do with it as grouped rows (scanner, guests,
/// releases, tiers, team, tables, bookings). Share, Duplicate and Delete are not built: they say "Coming soon" (Delete used to ask "are you sure?" and then say Coming Soon).
class EventDetailsScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailsProvider(eventId));
    final statsAsync = ref.watch(eventStatsProvider(eventId));
    final bu = context.bu;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BuDetailAppBar(
        eyebrow: 'Event',
        title: 'Event Details',
        actions: [IconButton(key: const Key('event-edit'), icon: const Icon(Ionicons.create_outline), onPressed: () => context.push('/events/$eventId/edit'), tooltip: 'Edit Event')],
      ),
      body: eventAsync.when(
        data: (event) => _Body(event: event, eventId: eventId, stats: statsAsync),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Ionicons.alert_circle_outline, size: 56, color: bu.red),
                const SizedBox(height: BuSpace.l),
                Text(loadFailedMessage('this event'), textAlign: TextAlign.center),
                const SizedBox(height: BuSpace.l),
                FilledButton(onPressed: () => ref.invalidate(eventDetailsProvider(eventId)), child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.event, required this.eventId, required this.stats});

  final Event event;
  final String eventId;
  final AsyncValue<Map<String, dynamic>> stats;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final (statusWord, statusTone) = eventStatusLook(event.status);
    final s = stats.valueOrNull;
    final sold = '${s?['tickets_sold'] ?? event.currentBookings}';
    final available = '${s?['available_tickets'] ?? event.maxCapacity - event.currentBookings}';
    final revenue = stats.when(data: (m) => '\$${((m['total_revenue'] ?? 0) as num).toStringAsFixed(0)}', loading: () => '…', error: (_, __) => 'N/A');
    final name = Uri.encodeComponent(event.name);

    Widget fact(IconData icon, String value) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [Icon(icon, size: 16, color: bu.muted), const SizedBox(width: 8), Expanded(child: Text(value, style: text.bodyMedium?.copyWith(color: bu.soft)))]),
        );
    BuListRow go(String key, IconData icon, String title, String subtitle, VoidCallback onTap) => BuListRow(key: Key(key), icon: icon, title: title, subtitle: subtitle, onTap: onTap);
    BuListRow soon(String key, IconData icon, String title, String sheet) =>
        BuListRow(key: Key(key), icon: icon, title: title, trailing: const BuComingSoonPill(), showChevron: false, onTap: () => showComingSoon(context, title: title, text: sheet));

    return ListView(
      key: const Key('event-details-list'),
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
      children: [
        BuCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.images != null && event.images!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(BuRadius.card)),
                  child: CachedNetworkImage(
                    imageUrl: event.images!.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(height: 180, color: bu.panel2, child: const Center(child: CircularProgressIndicator())),
                    errorWidget: (context, url, error) => Container(height: 180, color: bu.panel2, child: Icon(Ionicons.image_outline, size: 40, color: bu.muted)),
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
                        Expanded(child: Text(event.name, key: const Key('event-name'), style: text.headlineSmall)),
                        const SizedBox(width: BuSpace.s),
                        KeyedSubtree(key: const Key('event-status'), child: BuStatusPill(statusWord, tone: statusTone)),
                      ],
                    ),
                    if ((event.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: BuSpace.s),
                      Text(event.description!, style: text.bodyMedium?.copyWith(color: bu.soft)),
                    ],
                    const SizedBox(height: BuSpace.s),
                    fact(Ionicons.calendar_outline, '${DateFormat('EEE d MMM yyyy').format(event.eventDate)} · ${event.startTime} to ${event.endTime}'),
                    fact(Ionicons.cash_outline, 'Tickets from \$${event.ticketPrice.toStringAsFixed(2)}'),
                    if (event.dressCode != null) fact(Ionicons.shirt_outline, 'Dress code: ${event.dressCode}'),
                    if (event.minAge != null) fact(Ionicons.person_outline, 'Age: ${event.minAge}+'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: BuSpace.l),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: BuStatTile(key: const Key('event-stat-sold'), label: 'Tickets sold', value: sold, note: 'of ${event.maxCapacity}')),
            const SizedBox(width: BuSpace.m),
            Expanded(child: BuStatTile(key: const Key('event-stat-revenue'), label: 'Revenue', value: revenue, note: 'Gross')),
          ],
        ),
        const SizedBox(height: BuSpace.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: BuStatTile(key: const Key('event-stat-capacity'), label: 'Capacity', value: '${event.maxCapacity}', note: 'Total')),
            const SizedBox(width: BuSpace.m),
            Expanded(child: BuStatTile(key: const Key('event-stat-available'), label: 'Available', value: available, note: 'Still to sell')),
          ],
        ),
        const SizedBox(height: BuSpace.xl),
        const BuEyebrow('On the night'),
        const SizedBox(height: BuSpace.s),
        BuListCard(
          children: [
            go('event-scanner', Ionicons.qr_code_outline, 'QR Scanner', 'Scan tickets and check in guests', () => context.push('/events/$eventId/scanner')),
            go('event-guests', Ionicons.people_outline, 'Guest List', 'Manage guests and upload a CSV', () => context.push('/events/$eventId/guests')),
            go('event-tables', Ionicons.grid_outline, 'Table Management', 'Add and manage VIP tables for booking', () => context.push('/events/$eventId/tables')),
            go('event-bookings', Ionicons.ticket_outline, 'View Bookings', 'See all event bookings', () => context.push('/bookings')),
          ],
        ),
        const SizedBox(height: BuSpace.xl),
        const BuEyebrow('Before the night'),
        const SizedBox(height: BuSpace.s),
        BuListCard(
          children: [
            go('event-tiers', Ionicons.pricetags_outline, 'Ticket Tiers', 'Set ticket prices and capacity', () => context.push('/events/$eventId/tiers?name=$name')),
            go('event-releases', Ionicons.time_outline, 'Scheduled Releases', 'Set up timed ticket releases', () => context.push('/events/$eventId/releases')),
            go('event-lineup', Ionicons.musical_notes_outline, 'Team & Lineup', 'Manage DJs, security and staff', () => context.push('/events/$eventId/lineup?name=$name')),
          ],
        ),
        const SizedBox(height: BuSpace.xl),
        const BuEyebrow('More'),
        const SizedBox(height: BuSpace.s),
        BuListCard(
          children: [
            soon('event-share', Ionicons.share_social_outline, 'Share Event', 'Send a link to this event to your guests and your followers.'),
            soon('event-duplicate', Ionicons.copy_outline, 'Duplicate Event', 'Start a new event from this one, with the same tickets and details.'),
            soon('event-delete', Ionicons.trash_outline, 'Delete Event', 'Remove this event. Until then, Contact Support and the team will do it for you.'),
          ],
        ),
      ],
    );
  }
}
