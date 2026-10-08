import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/bookings_rules.dart';
import '../providers/floor_providers.dart';
import '../services/floor_service.dart';
import '../widgets/booking_card.dart';

/// Picks a night. Replaced in tests; in the app it is Flutter's own date picker.
typedef NightPicker = Future<DateTime?> Function(BuildContext context, DateTime initial);

Future<DateTime?> _defaultPicker(BuildContext context, DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

Future<void> _defaultContact(Uri uri) async {
  await launchUrl(uri);
}

/// Floor (manager): the reservations of the manager's own club, night by night, read only. The database decides which club
/// that is, whether this person may read it and which night each booking belongs to (a 1:00 AM table belongs to the night
/// before). Amounts are what was booked, not what was collected; walk-ins, guest allowances, table assignment, check-in and
/// bottle orders are not here yet.
class FloorScreen extends ConsumerStatefulWidget {
  const FloorScreen({
    super.key,
    required this.venueId,
    this.venueName,
    this.clock = DateTime.now,
    this.pickNight = _defaultPicker,
    this.contact = _defaultContact,
  });

  /// The club this workspace is limited to. Null means the workspace is not tied to a club, and there is nothing to show.
  final String? venueId;
  final String? venueName;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;
  final NightPicker pickNight;
  final Future<void> Function(Uri uri) contact;

  @override
  ConsumerState<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends ConsumerState<FloorScreen> {
  late final List<Preset> _presets = presets(widget.clock());
  PresetId? _presetId = PresetId.tonight;
  late NightRange _range = _presets.first.range;
  BookingFilter _filter = BookingFilter.confirmed;

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

  Future<void> _call(Uri uri) async {
    try {
      await widget.contact(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This could not be opened on this phone.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = widget.venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('This workspace is not tied to a club, so there are no bookings to show.', key: Key('floor-no-venue'), textAlign: TextAlign.center),
        ),
      );
    }

    final problem = validateRange(_range);
    final query = FloorQuery(venueId, _range);
    final async = problem == null ? ref.watch(floorBookingsProvider(query)) : null;

    return RefreshIndicator(
      onRefresh: () async {
        if (problem != null) return;
        ref.invalidate(floorBookingsProvider(query));
        try {
          await ref.read(floorBookingsProvider(query).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Text('Bookings', style: theme.textTheme.headlineSmall),
          if (widget.venueName != null) Text(widget.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Wrap(
            key: const Key('floor-presets'),
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  key: Key('preset-${p.id.name}'),
                  label: Text(p.label),
                  selected: _presetId == p.id,
                  onSelected: (_) => setState(() {
                    _presetId = p.id;
                    _range = p.range;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pick-from'),
                  onPressed: () => _pick(from: true),
                  child: _DateLabel(caption: 'From night', value: formatNightShort(_range.from)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('pick-to'),
                  onPressed: () => _pick(from: false),
                  child: _DateLabel(caption: 'To night', value: formatNightShort(_range.to)),
                ),
              ),
            ],
          ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(problem, key: const Key('range-problem'), style: const TextStyle(color: Color(0xFFFFB300))),
            ),
          const SizedBox(height: 8),
          SegmentedButton<BookingFilter>(
            key: const Key('floor-filter'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: BookingFilter.confirmed, label: Text('Confirmed only')),
              ButtonSegment(value: BookingFilter.all, label: Text('Everything')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          const SizedBox(height: 16),
          if (async != null)
            async.when(
              loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
              error: (error, _) {
                final e = error is FloorLoadException ? error : const FloorLoadException(unavailable: false, accessEnded: false);
                return Column(
                  children: [
                    Text(e.message, key: const Key('floor-error'), textAlign: TextAlign.center),
                    if (!e.unavailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton(
                          key: const Key('floor-retry'),
                          onPressed: () => ref.invalidate(floorBookingsProvider(query)),
                          child: const Text('Try again'),
                        ),
                      ),
                  ],
                );
              },
              data: _results,
            ),
        ],
      ),
    );
  }

  Widget _results(List<BookingRow> rows) {
    final theme = Theme.of(context);
    final shown = applyFilter(rows, _filter);
    final summary = summarize(rows);
    final groups = groupByNight(shown);
    final hidden = rows.length - shown.length;
    final nights = nightCount(_range);

    Widget tile(Key key, String label, int value, [String? hint]) => Expanded(
          child: Card(
            key: key,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value', style: theme.textTheme.headlineSmall),
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (hint != null) Text(hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );

    // Each pair of tiles is as tall as the taller one, so a tile without a hint does not look shorter.
    Widget pair(Widget a, Widget b) => IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, b]));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pair(
          tile(const Key('tile-confirmed'), 'Confirmed bookings', summary.bookings, '$nights ${nights == 1 ? 'night' : 'nights'}'),
          tile(const Key('tile-guests'), 'Guests expected', summary.guests),
        ),
        pair(
          tile(const Key('tile-arrived'), 'Arrived', summary.checkedIn, 'Checked in at the venue'),
          tile(const Key('tile-awaiting'), 'Awaiting payment', summary.awaitingPayment, 'Started, not paid yet'),
        ),
        if (rows.length >= rowLimit)
          Container(
            key: const Key('row-limit'),
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
            ),
            child: Text('Only the first $rowLimit bookings are shown. Choose fewer nights to see the rest.'),
          ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              _filter == BookingFilter.confirmed && hidden > 0
                  ? 'No confirmed bookings for these nights. $hidden unpaid or cancelled ${hidden == 1 ? 'is' : 'are'} hidden; choose “Everything” to see ${hidden == 1 ? 'it' : 'them'}.'
                  : 'No bookings for these nights.',
              key: const Key('floor-empty'),
              textAlign: TextAlign.center,
            ),
          ),
        for (final g in groups) ...[
          const SizedBox(height: 20),
          Row(
            key: Key('night-${g.night}'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(g.label, style: theme.textTheme.titleSmall),
              Text('${g.guests} ${g.guests == 1 ? 'guest' : 'guests'} expected', style: theme.textTheme.bodySmall),
            ],
          ),
          for (final b in g.rows) BookingCard(booking: b, onContact: _call),
        ],
        const SizedBox(height: 20),
        Text(
          'Amounts are what was booked, not what has been collected. Walk-ins, guest allowances, table assignment, check-in and bottle orders are not available here yet.',
          key: const Key('floor-footnote'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A date button's two lines: what it sets, and the night it is set to.
class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(caption, style: theme.textTheme.labelSmall),
        Text(value, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
