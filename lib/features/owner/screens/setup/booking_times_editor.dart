import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/setup_forms.dart';
import '../../providers/owner_providers.dart';
import '../../services/venue_setup_service.dart';
import '../../widgets/setup_common.dart';

/// Picks a time of day. Replaced in tests; in the app it is Flutter's own time picker.
typedef TimePicker =
    Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initial);

Future<TimeOfDay?> _defaultTimePicker(
  BuildContext context,
  TimeOfDay initial,
) => showTimePicker(context: context, initialTime: initial);

/// Booking times (owner): the days and arrival times guests can choose when they book a table. Several days can be added at once;
/// a time that already exists is skipped and said so, and a time that has bookings cannot be removed.
class BookingTimesEditor extends ConsumerStatefulWidget {
  const BookingTimesEditor({
    super.key,
    required this.venueId,
    this.pickTime = _defaultTimePicker,
  });

  final String venueId;
  final TimePicker pickTime;

  @override
  ConsumerState<BookingTimesEditor> createState() => _BookingTimesEditorState();
}

class _BookingTimesEditorState extends ConsumerState<BookingTimesEditor> {
  final Set<int> _days = {};
  final _label = TextEditingController();
  String _time = '21:00';
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _refresh() => refreshAfterChange(
    ref,
    widget.venueId,
    () => ref.invalidate(arrivalTimesProvider(widget.venueId)),
  );

  Future<void> _pick() async {
    final parts = _time.split(':');
    final picked = await widget.pickTime(
      context,
      TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null || !mounted) return;
    setState(
      () =>
          _time =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _add() async {
    final problems = validateSlotForm(
      days: _days.toList(),
      time: _time,
      label: _label.text,
    );
    setState(() => _problems = problems);
    if (problems.isNotEmpty) return;

    setState(() => _busy = true);
    final service = ref.read(venueSetupServiceProvider);
    final attempts = <SlotAttempt>[];
    for (final day in (_days.toList()..sort())) {
      try {
        await service.addArrivalTime(widget.venueId, day, _time, _label.text);
        attempts.add(SlotAttempt(day, null));
      } on SetupEditException catch (e) {
        attempts.add(SlotAttempt(day, e.message));
      }
    }
    if (!mounted) return;
    final summary = summarizeSlotAttempts(attempts);
    say(
      context,
      summary.description == null
          ? summary.title
          : '${summary.title}. ${summary.description}',
    );
    setState(() => _busy = false);
    if (attempts.any((a) => a.error == null)) {
      setState(() {
        _days.clear();
        _label.clear();
      });
      _refresh();
    }
  }

  Future<void> _remove(ArrivalTime t) async {
    try {
      await ref
          .read(venueSetupServiceProvider)
          .removeArrivalTime(widget.venueId, t.slotId);
      if (!mounted) return;
      _refresh();
    } on SetupEditException catch (e) {
      if (mounted) say(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final times = ref.watch(arrivalTimesProvider(widget.venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Booking times')),
      body: times.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => EditorLoadError(
              error: e,
              onRetry:
                  () => ref.invalidate(arrivalTimesProvider(widget.venueId)),
            ),
        data:
            (list) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Text(
                  'The days and times guests can choose to arrive for a table.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final g in groupByDay(list))
                  Padding(
                    key: Key('day-${g.day}'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            g.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          child:
                              g.times.isEmpty
                                  ? Text(
                                    'No bookings accepted',
                                    style: theme.textTheme.bodySmall,
                                  )
                                  : Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      for (final t in g.times)
                                        InputChip(
                                          key: Key('time-${t.slotId}'),
                                          label: Text(
                                            '${formatSlotTime(t.startTime)}${t.label == null ? '' : ' · ${t.label}'}'
                                            '${t.bookingCount > 0 ? ' · ${t.bookingCount} ${t.bookingCount == 1 ? 'booking' : 'bookings'}' : ''}',
                                          ),
                                          // A time with bookings cannot be removed: the chip shows no delete button instead of failing.
                                          onDeleted:
                                              t.bookingCount > 0
                                                  ? null
                                                  : () => _remove(t),
                                          deleteButtonTooltipMessage:
                                              'Remove ${formatSlotTime(t.startTime)} on ${dayLabels[t.dayOfWeek]}',
                                        ),
                                    ],
                                  ),
                        ),
                      ],
                    ),
                  ),
                if (list.any((t) => t.bookingCount > 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'A time that has bookings cannot be removed.',
                      key: const Key('times-protected-note'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const Divider(height: 32),
                Text('Add arrival times', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final d in dayOrder)
                      FilterChip(
                        key: Key('pick-day-$d'),
                        label: Text(dayShort[d]),
                        selected: _days.contains(d),
                        onSelected:
                            (on) => setState(
                              () => on ? _days.add(d) : _days.remove(d),
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('pick-time'),
                  onPressed: _pick,
                  child: Text('Arrival time: ${formatSlotTime(_time)}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('slot-note'),
                  controller: _label,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Early seating',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                ProblemsBox(problems: _problems),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('add-times'),
                  onPressed: _busy ? null : _add,
                  child: Text(_busy ? 'Adding…' : 'Add arrival time'),
                ),
              ],
            ),
      ),
    );
  }
}
