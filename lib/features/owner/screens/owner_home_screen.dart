import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../business/widgets/business_status_card.dart';
import '../../floor/logic/bookings_rules.dart';
import '../../floor/providers/floor_providers.dart';
import '../../floor/screens/floor_screen.dart' show NightPicker, defaultNightPicker;
import '../../workspace/models/workspace.dart';
import '../logic/owner_rules.dart';
import '../providers/owner_providers.dart';
import '../services/owner_service.dart';
import '../widgets/venue_status_chip.dart';
import 'owner_venues_screen.dart';

/// Overview (owner): the business's venues for a chosen set of nights, tonight to begin with. Confirmed bookings, guests expected and who has arrived, from the same
/// read of bookings the venue pages use. The nights are chosen with the same ready-made ranges and dates as the Floor (tonight, the next 7 or 30 nights, the last 7, or
/// any dates up to 93 nights). Sales, collections, balances, event status and unresolved issues are not available here yet, and the screen says so rather than showing
/// zeros that look like real figures.
class OwnerHomeScreen extends ConsumerStatefulWidget {
  const OwnerHomeScreen({super.key, required this.workspace, this.clock = DateTime.now, this.onOpenVenue = openVenueInRouter, this.pickNight = defaultNightPicker});

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;
  final OpenVenue onOpenVenue;

  /// Chooses a date. Replaced in tests.
  final NightPicker pickNight;

  @override
  ConsumerState<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends ConsumerState<OwnerHomeScreen> {
  late final List<Preset> _presets = presets(widget.clock());
  PresetId? _presetId = PresetId.tonight;
  late NightRange _range = _presets.first.range;

  Workspace get workspace => widget.workspace;

  /// The two date buttons sit under the ready-made ranges: a step smaller than a full-size button, so the page's first card is not pushed off the screen.
  static final ButtonStyle _dateButton = OutlinedButton.styleFrom(minimumSize: const Size(0, 44));

  bool get _isTonight => _presetId == PresetId.tonight;

  Future<void> _pick({required bool from}) async {
    final current = parseNight(from ? _range.from : _range.to) ?? widget.clock();
    final picked = await widget.pickNight(context, current);
    if (picked == null || !mounted) return;
    final iso = isoDate(picked);
    setState(() {
      _presetId = null;
      _range = from ? NightRange(iso, _range.to) : NightRange(_range.from, iso);
    });
  }

  /// "Friday Oct 9" for one night, "Fri Oct 9 to Thu Oct 15" for several.
  String _nightsLabel() => _range.from == _range.to ? formatNight(_range.from) : '${formatNightShort(_range.from)} to ${formatNightShort(_range.to)}';

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final theme = Theme.of(context);
    final bu = context.bu;
    final orgId = workspace.orgId;
    final venues = ref.watch(ownerVenuesProvider(orgId));
    final problem = validateRange(_range);

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
        padding: const EdgeInsets.fromLTRB(
          BuSpace.page,
          BuSpace.l,
          BuSpace.page,
          BuSpace.xl,
        ),
        children: [
          BusinessStatusCard(orgId: workspace.orgId),
          const BuPageHeader(eyebrow: 'Overview', title: 'All venues'),
          const SizedBox(height: BuSpace.xs),
          Text(
            '${workspace.orgName} · ${_nightsLabel()}',
            key: const Key('home-night'),
            style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted),
          ),
          const SizedBox(height: BuSpace.l),
          Wrap(
            key: const Key('home-presets'),
            spacing: BuSpace.s,
            runSpacing: BuSpace.xs,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  key: Key('home-preset-${p.id.name}'),
                  label: Text(p.label),
                  showCheckmark: false,
                  selected: _presetId == p.id,
                  onSelected:
                      (_) => setState(() {
                        _presetId = p.id;
                        _range = p.range;
                      }),
                ),
            ],
          ),
          const SizedBox(height: BuSpace.s),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('home-pick-from'),
                  style: _dateButton,
                  onPressed: () => _pick(from: true),
                  child: Text('From ${formatNightShort(_range.from)}'),
                ),
              ),
              const SizedBox(width: BuSpace.s),
              Expanded(
                child: OutlinedButton(
                  key: const Key('home-pick-to'),
                  style: _dateButton,
                  onPressed: () => _pick(from: false),
                  child: Text('To ${formatNightShort(_range.to)}'),
                ),
              ),
            ],
          ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: BuSpace.s),
              child: Text(
                problem,
                key: const Key('home-range-problem'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: BuSpace.xl),
          if (problem == null)
            venues.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.only(top: BuSpace.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error: (error, _) {
                final e =
                    error is OwnerLoadException
                        ? error
                        : const OwnerLoadException(
                          unavailable: false,
                          accessEnded: false,
                        );
                return BuCard(
                  child: Column(
                    children: [
                      Text(
                        e.message,
                        key: const Key('home-error'),
                        textAlign: TextAlign.center,
                      ),
                      if (!e.unavailable)
                        Padding(
                          padding: const EdgeInsets.only(top: BuSpace.m),
                          child: OutlinedButton(
                            key: const Key('home-retry'),
                            onPressed:
                                () =>
                                    ref.invalidate(ownerVenuesProvider(orgId)),
                            child: const Text('Try again'),
                          ),
                        ),
                    ],
                  ),
                );
              },
              data: (list) => _body(context, ref, list, _range),
            ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    List<OrgVenue> list,
    NightRange range,
  ) {
    final theme = Theme.of(context);
    final bu = context.bu;
    if (list.isEmpty) {
      return BuCard(
        key: const Key('home-no-venues'),
        padding: const EdgeInsets.all(BuSpace.xl),
        child: Text(
          'No venues yet. Add one in the Venues tab.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final reads = [
      for (final v in list)
        ref.watch(floorBookingsProvider(FloorQuery(v.id, range))),
    ];
    var bookings = 0,
        guests = 0,
        arrived = 0,
        awaiting = 0,
        failed = 0,
        loading = 0,
        cut = 0;
    // A night in the past has guests booked, not expected.
    final past = range.to.compareTo(currentNight(widget.clock())) < 0;
    for (final r in reads) {
      if (r.hasValue && r.requireValue.length >= rowLimit) {
        // The database stops at this many rows: the totals would be short, so they are not added up.
        cut++;
      } else if (r.hasValue) {
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

    // The big card only speaks when every venue has answered in full: a headline built from a short total would look more certain than it is.
    final complete = cut == 0 && failed == 0 && loading == 0;
    final share = bookings == 0 ? 0.0 : (arrived / bookings).clamp(0.0, 1.0);

    Widget tile(Key key, String label, int value, {Color? color}) => Expanded(
      child: BuMetricTile(
        key: key,
        value: '$value',
        label: label,
        valueColor: color,
      ),
    );
    final warn = theme.textTheme.bodySmall?.copyWith(color: bu.amber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (complete) ...[
          BuHeroCard(
            key: const Key('home-hero'),
            eyebrow: _isTonight ? 'Tonight' : 'These nights',
            title:
                '$guests ${guests == 1 ? 'guest' : 'guests'} ${past ? 'booked' : 'expected'}',
            subtitle:
                '$arrived of $bookings ${bookings == 1 ? 'booking has' : 'bookings have'} arrived',
            trailing: BuRing(
              value: share,
              center: '${(share * 100).round()}%',
              caption: 'arrived',
            ),
          ),
          const SizedBox(height: BuSpace.m),
        ],
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(const Key('home-bookings'), 'Confirmed bookings', bookings),
              const SizedBox(width: BuSpace.m),
              tile(
                const Key('home-guests'),
                past ? 'Guests booked' : 'Guests expected',
                guests,
              ),
            ],
          ),
        ),
        const SizedBox(height: BuSpace.m),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(
                const Key('home-arrived'),
                'Arrived',
                arrived,
                color: arrived > 0 ? bu.green : null,
              ),
              const SizedBox(width: BuSpace.m),
              tile(
                const Key('home-awaiting'),
                'Awaiting payment',
                awaiting,
                color: awaiting > 0 ? bu.amber : null,
              ),
            ],
          ),
        ),
        if (cut > 0)
          Padding(
            padding: const EdgeInsets.only(top: BuSpace.m),
            child: Text(
              '${cut == 1 ? 'One venue has' : '$cut venues have'} more than $rowLimit bookings in these nights, so these totals are incomplete. Choose fewer nights.',
              key: const Key('home-cut'),
              style: warn,
            ),
          )
        else if (failed > 0)
          Padding(
            padding: const EdgeInsets.only(top: BuSpace.m),
            child: Text(
              '${failed == 1 ? 'One venue' : '$failed venues'} could not be loaded, so these totals are incomplete.',
              key: const Key('home-incomplete'),
              style: warn,
            ),
          )
        else if (loading > 0)
          Padding(
            padding: const EdgeInsets.only(top: BuSpace.m),
            child: Text(
              'Still loading ${loading == 1 ? 'one venue' : '$loading venues'}…',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: BuSpace.xl),
        const BuSectionHeader(title: 'Venues'),
        const SizedBox(height: BuSpace.s),
        for (var i = 0; i < list.length; i++)
          _venueCard(context, list[i], reads[i]),
        const SizedBox(height: BuSpace.xl),
        Text(
          'Sales, collections, balances, event status and unresolved issues are not available here yet.',
          key: const Key('home-footnote'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _venueCard(
    BuildContext context,
    OrgVenue v,
    AsyncValue<List<BookingRow>> read,
  ) {
    final theme = Theme.of(context);
    final String line;
    if (read.hasValue && read.requireValue.length >= rowLimit) {
      line =
          'More than $rowLimit bookings in these nights. Choose fewer nights.';
    } else if (read.hasValue) {
      final s = summarize(read.requireValue);
      line =
          '${s.bookings} confirmed ${s.bookings == 1 ? 'booking' : 'bookings'} · ${s.guests} ${s.guests == 1 ? 'guest' : 'guests'} expected'
          '${s.checkedIn > 0 ? ' · ${s.checkedIn} arrived' : ''}'
          '${s.awaitingPayment > 0 ? ' · ${s.awaitingPayment} awaiting payment' : ''}';
    } else if (read.hasError) {
      line =
          _isTonight
              ? "Tonight's bookings could not be loaded."
              : 'Bookings for these nights could not be loaded.';
    } else {
      line = 'Loading…';
    }
    return BuCard(
      key: Key('home-venue-${v.id}'),
      margin: const EdgeInsets.only(bottom: BuSpace.s),
      onTap: () => widget.onOpenVenue(context, workspace.membershipId, v.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  v.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: BuSpace.s),
              VenueStatusChip(status: v.status),
            ],
          ),
          const SizedBox(height: BuSpace.xs + 2),
          Text(
            line,
            key: Key('home-line-${v.id}'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
