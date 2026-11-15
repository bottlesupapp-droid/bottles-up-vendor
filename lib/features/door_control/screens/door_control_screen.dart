import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../ops/services/ops_rpc.dart' show OpsActionException;
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../workspace/models/workspace.dart';
import '../logic/door_control_rules.dart';
import '../providers/door_control_providers.dart';

/// Door control, for the owner and the manager (door staff do not have it): the club's nights with who is inside and whether exits are tracked, an override for a guest the
/// scan held back only because of the entry code (with a reason that is kept), and the overrides recorded for the night. The owner picks the club first.
class DoorControlScreen extends ConsumerStatefulWidget {
  const DoorControlScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<DoorControlScreen> createState() => _DoorControlScreenState();
}

class _DoorControlScreenState extends ConsumerState<DoorControlScreen> {
  String? _chosenVenue;
  String? _night;
  final Set<String> _busy = {};
  final _code = TextEditingController();
  final _reason = TextEditingController();
  OverrideOutcome? _outcome;
  String? _problem;
  bool _sending = false;
  int _count = 1;

  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  /// The night an override is aimed at: the one the person chose, otherwise the first (the one shown as chosen).
  String? get _effectiveNight => _night ?? ref.read(clubNightsProvider(_venueId ?? '')).valueOrNull?.firstOrNull?.eventId;

  @override
  void dispose() {
    _code.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _setTracking(ClubNight night, bool on) async {
    setState(() => _busy.add(night.eventId));
    try {
      await ref.read(doorControlServiceProvider).setExitTracking(night.eventId, on);
      _say(on ? 'Exits are now tracked for ${night.title}.' : 'Exits are no longer tracked for ${night.title}.');
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      // Read it again either way: after a refusal the list shows what the database says now.
      ref.invalidate(clubNightsProvider(_venueId ?? ''));
      if (mounted) setState(() => _busy.remove(night.eventId));
    }
  }

  Future<void> _override({int? count}) async {
    final problem = validateOverrideReason(_reason.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    if (_code.text.trim().isEmpty) {
      setState(() => _problem = 'Type or scan the ticket code first.');
      return;
    }
    setState(() {
      _sending = true;
      _problem = null;
    });
    try {
      final outcome = await ref.read(doorControlServiceProvider).override(_code.text, _reason.text, count: count, eventId: _effectiveNight);
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _count = 1;
      });
      if (outcome.done) {
        _code.clear();
        _reason.clear();
        final night = _effectiveNight;
        if (night != null) ref.invalidate(overrideLogProvider(night));
        ref.invalidate(clubNightsProvider(_venueId ?? ''));
      }
    } on OpsActionException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = _venueId;
    if (venue == null) {
      return VenuePicker(workspace: widget.workspace, title: 'Door control', onPick: (id) => setState(() => _chosenVenue = id));
    }
    final theme = Theme.of(context);
    final bu = context.bu;
    final nights = ref.watch(clubNightsProvider(venue));
    final selected = _night ?? nights.valueOrNull?.firstOrNull?.eventId;
    return ListView(
      key: const Key('door-control'),
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xxl),
      children: [
        const BuPageHeader(eyebrow: 'Door', title: 'Door control'),
        const SizedBox(height: BuSpace.l),
        const BuEyebrow('Nights'),
        const SizedBox(height: BuSpace.s),
        OpsAsyncView<List<ClubNight>>(
          value: nights,
          what: 'the club\'s nights',
          isEmpty: (d) => d.isEmpty,
          emptyText: 'No night is on right now. A night appears from a day before it starts until 12 hours after it ends.',
          errorKey: const Key('nights-error'),
          emptyKey: const Key('nights-empty'),
          onRetry: () => ref.invalidate(clubNightsProvider(venue)),
          builder:
              (list) => Column(
                children: [
                  for (final n in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BuSpace.m),
                      child: BuCard(
                        key: Key('night-${n.eventId}'),
                        highlight: n.eventId == selected,
                        onTap: () => setState(() => _night = n.eventId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: theme.textTheme.titleMedium),
                            Text(DateFormat('EEE d MMM, HH:mm').format(n.startDate.toLocal()), style: theme.textTheme.bodySmall?.copyWith(color: bu.muted)),
                            const SizedBox(height: BuSpace.s),
                            Text(nightFigure(n), key: Key('night-figure-${n.eventId}'), style: theme.textTheme.bodyMedium),
                            const SizedBox(height: BuSpace.s),
                            Row(
                              children: [
                                Expanded(child: Text('Track exits', style: theme.textTheme.bodyMedium)),
                                Switch(key: Key('track-${n.eventId}'), value: n.trackExits, onChanged: _busy.contains(n.eventId) ? null : (v) => _setTracking(n, v)),
                              ],
                            ),
                            Text(
                              n.trackExits ? 'The door shows "Inside now" and can record guests leaving.' : 'The door shows "Total checked in". Turn this on to count guests leaving.',
                              style: theme.textTheme.bodySmall?.copyWith(color: bu.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
        ),
        const SizedBox(height: BuSpace.xl),
        const BuEyebrow('Override'),
        const SizedBox(height: BuSpace.s),
        BuCard(
          key: const Key('override-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admit a guest the scan held back', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Only for a ticket held back by its entry code (the guest lost their e-mail or phone). An unpaid, refunded or ended ticket stays refused. Your reason is kept with your name.',
                style: theme.textTheme.bodySmall?.copyWith(color: bu.muted),
              ),
              const SizedBox(height: BuSpace.m),
              TextField(key: const Key('override-code'), controller: _code, autocorrect: false, decoration: const InputDecoration(labelText: 'Ticket code')),
              const SizedBox(height: BuSpace.m),
              TextField(
                key: const Key('override-reason'),
                controller: _reason,
                maxLines: 2,
                maxLength: overrideReasonMax,
                decoration: const InputDecoration(labelText: 'Why', hintText: 'For example: lost their phone, ID checked'),
                onChanged: (_) => setState(() => _problem = null),
              ),
              if (_problem != null) Padding(padding: const EdgeInsets.only(bottom: BuSpace.s), child: Text(_problem!, key: const Key('override-problem'), style: TextStyle(color: bu.red))),
              SizedBox(
                width: double.infinity,
                child: FilledButton(key: const Key('override-send'), onPressed: _sending ? null : () => _override(), child: Text(_sending ? 'Checking' : 'Admit with override')),
              ),
              if (_outcome != null) ...[const SizedBox(height: BuSpace.m), _OutcomePanel(outcome: _outcome!)],
              if (_outcome?.needsCount ?? false) ...[
                const SizedBox(height: BuSpace.m),
                Text('How many are coming in now?', style: theme.textTheme.bodyMedium),
                const SizedBox(height: BuSpace.s),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var n = 1; n <= (_outcome!.remaining ?? 1).clamp(1, 12); n++)
                      ChoiceChip(key: Key('override-count-$n'), label: Text('$n'), selected: _count == n, onSelected: (_) => setState(() => _count = n)),
                  ],
                ),
                const SizedBox(height: BuSpace.s),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(key: const Key('override-admit-count'), onPressed: _sending ? null : () => _override(count: _count), child: Text('Admit $_count')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: BuSpace.xl),
        const BuEyebrow('Overrides on this night'),
        const SizedBox(height: BuSpace.s),
        if (selected == null)
          Text('Choose a night above.', style: theme.textTheme.bodyMedium?.copyWith(color: bu.muted))
        else
          OpsAsyncView<List<OverrideLogEntry>>(
            value: ref.watch(overrideLogProvider(selected)),
            what: 'the overrides',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No guest has been admitted by override on this night.',
            errorKey: const Key('log-error'),
            emptyKey: const Key('log-empty'),
            onRetry: () => ref.invalidate(overrideLogProvider(selected)),
            builder:
                (list) => BuListCard(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      BuListRow(
                        key: Key('log-$i'),
                        title: '${list[i].customerName} · ${list[i].guests} guest${list[i].guests == 1 ? '' : 's'}',
                        subtitle: '${list[i].reason}\n${DateFormat('HH:mm').format(list[i].overriddenAt.toLocal())}${list[i].byMe ? ' · by you' : ''}',
                        showChevron: false,
                      ),
                  ],
                ),
          ),
      ],
    );
  }
}

/// The answer to an override, in words, with the colour of what it means.
class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.outcome});

  final OverrideOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final copy = overrideCopy(outcome);
    final color = switch (copy.tone) {
      OverrideTone.ok => bu.green,
      OverrideTone.warn => bu.amber,
      OverrideTone.error => bu.red,
    };
    return Container(
      key: const Key('override-outcome'),
      padding: const EdgeInsets.all(BuSpace.m),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(BuRadius.control), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.label, key: const Key('override-label'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(copy.hint, key: const Key('override-hint')),
        ],
      ),
    );
  }
}
