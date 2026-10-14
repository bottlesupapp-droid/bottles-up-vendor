import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart';
import '../../floor/providers/floor_providers.dart';
import '../../workspace/models/workspace.dart';
import '../logic/owner_rules.dart';
import '../providers/owner_providers.dart';
import '../services/owner_service.dart';
import '../widgets/venue_status_chip.dart';
import 'owner_venues_screen.dart';

/// Home (owner): tonight across every venue of the business. Confirmed bookings, guests expected and who has arrived, from the
/// same read of bookings the venue pages use. Sales, collections, balances, event status and unresolved issues are not available
/// here yet, and the screen says so rather than showing zeros that look like real figures.
class OwnerHomeScreen extends ConsumerWidget {
  const OwnerHomeScreen({super.key, required this.workspace, this.clock = DateTime.now, this.onOpenVenue = openVenueInRouter});

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;
  final OpenVenue onOpenVenue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orgId = workspace.orgId;
    final venues = ref.watch(ownerVenuesProvider(orgId));
    final tonight = presets(clock()).first.range;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ownerVenuesProvider(orgId));
        try {
          await ref.read(ownerVenuesProvider(orgId).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('All venues', style: theme.textTheme.headlineSmall),
          Text('${workspace.orgName} · ${formatNight(tonight.from)}', key: const Key('home-night'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          venues.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = error is OwnerLoadException ? error : const OwnerLoadException(unavailable: false, accessEnded: false);
              return Column(
                children: [
                  Text(e.message, key: const Key('home-error'), textAlign: TextAlign.center),
                  if (!e.unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(key: const Key('home-retry'), onPressed: () => ref.invalidate(ownerVenuesProvider(orgId)), child: const Text('Try again')),
                    ),
                ],
              );
            },
            data: (list) => _body(context, ref, list, tonight),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, List<OrgVenue> list, NightRange tonight) {
    final theme = Theme.of(context);
    if (list.isEmpty) {
      return Container(
        key: const Key('home-no-venues'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(14)),
        child: const Text('No venues yet. Add one in the Venues tab.', textAlign: TextAlign.center),
      );
    }

    final reads = [for (final v in list) ref.watch(floorBookingsProvider(FloorQuery(v.id, tonight)))];
    var bookings = 0, guests = 0, arrived = 0, awaiting = 0, failed = 0, loading = 0;
    for (final r in reads) {
      if (r.hasValue) {
        final s = summarize(r.requireValue);
        bookings += s.bookings;
        guests += s.guests;
        arrived += s.checkedIn;
        awaiting += s.awaitingPayment;
      } else if (r.hasError) {
        failed++;
      } else {
        loading++;
      }
    }

    Widget tile(Key key, String label, int value) => Expanded(
          child: Card(
            key: key,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('$value', style: theme.textTheme.headlineSmall), Text(label, style: theme.textTheme.bodyMedium)],
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            tile(const Key('home-bookings'), 'Confirmed bookings', bookings),
            tile(const Key('home-guests'), 'Guests expected', guests),
          ]),
        ),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            tile(const Key('home-arrived'), 'Arrived', arrived),
            tile(const Key('home-awaiting'), 'Awaiting payment', awaiting),
          ]),
        ),
        if (failed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${failed == 1 ? 'One venue' : '$failed venues'} could not be loaded, so these totals are incomplete.',
              key: const Key('home-incomplete'),
              style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFFFB300)),
            ),
          )
        else if (loading > 0)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Still loading ${loading == 1 ? 'one venue' : '$loading venues'}…', style: theme.textTheme.bodySmall)),
        const SizedBox(height: 16),
        Text('Venues', style: theme.textTheme.titleSmall),
        for (var i = 0; i < list.length; i++) _venueCard(context, list[i], reads[i]),
        const SizedBox(height: 20),
        Text(
          'Sales, collections, balances, event status and unresolved issues are not available here yet.',
          key: const Key('home-footnote'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _venueCard(BuildContext context, OrgVenue v, AsyncValue<List<BookingRow>> read) {
    final theme = Theme.of(context);
    final String line;
    if (read.hasValue) {
      final s = summarize(read.requireValue);
      line = '${s.bookings} confirmed ${s.bookings == 1 ? 'booking' : 'bookings'} · ${s.guests} ${s.guests == 1 ? 'guest' : 'guests'} expected'
          '${s.checkedIn > 0 ? ' · ${s.checkedIn} arrived' : ''}'
          '${s.awaitingPayment > 0 ? ' · ${s.awaitingPayment} awaiting payment' : ''}';
    } else if (read.hasError) {
      line = "Tonight's bookings could not be loaded.";
    } else {
      line = 'Loading…';
    }
    return Card(
      key: Key('home-venue-${v.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpenVenue(context, workspace.membershipId, v.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(v.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                VenueStatusChip(status: v.status),
              ]),
              const SizedBox(height: 6),
              Text(line, key: Key('home-line-${v.id}'), style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
