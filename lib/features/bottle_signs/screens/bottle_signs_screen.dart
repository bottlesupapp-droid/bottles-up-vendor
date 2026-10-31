import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../workspace/models/workspace.dart';
import '../logic/sign_rules.dart';
import '../providers/bottle_sign_providers.dart';
import '../widgets/decline_sign_dialog.dart';

/// Bottle signs (club manager, and the owner for any of their clubs): whether the club puts a short sign ("Happy Birthday") with bottles, on which bottles, whether a manager approves a
/// server's sign before the bottle is prepared, and the signs waiting for that approval. Servers write the signs themselves on the order. Changing a setting changes what can be done
/// from then on; signs already on orders stay as they are.
class BottleSignsScreen extends ConsumerStatefulWidget {
  const BottleSignsScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<BottleSignsScreen> createState() => _BottleSignsScreenState();
}

class _BottleSignsScreenState extends ConsumerState<BottleSignsScreen> {
  String? _chosenVenue;
  bool _busy = false;
  final Set<String> _busyLines = {};

  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Runs a change to the settings: the controls wait while it goes through, a refusal is said in the database's words, and the settings are read again either way.
  Future<void> _change(String venue, Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      ref.invalidate(signSettingsProvider(venue));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(String venue, PendingSign p) async {
    if (_busyLines.contains(p.lineId)) return;
    setState(() => _busyLines.add(p.lineId));
    try {
      final change = await ref.read(bottleSignServiceProvider).review(p.lineId, approve: true);
      _say(change.changed ? 'Sign approved.' : 'It was already approved.');
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      ref.invalidate(pendingSignsProvider(venue));
      if (mounted) setState(() => _busyLines.remove(p.lineId));
    }
  }

  Future<void> _decline(String venue, PendingSign p) async {
    final done = await showDialog<bool>(context: context, builder: (_) => DeclineSignDialog(lineId: p.lineId, signText: p.text));
    ref.invalidate(pendingSignsProvider(venue));
    if (done == true) _say('Sign declined.');
  }

  @override
  Widget build(BuildContext context) {
    final venue = _venueId;
    if (venue == null) {
      return VenuePicker(workspace: widget.workspace, title: 'Bottle signs', listKey: const Key('signs-pick-club'), itemKeyPrefix: 'signs-club-', onPick: (id) => setState(() => _chosenVenue = id));
    }
    final theme = Theme.of(context);
    final settings = ref.watch(signSettingsProvider(venue));
    final pending = ref.watch(pendingSignsProvider(venue));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(signSettingsProvider(venue));
        ref.invalidate(pendingSignsProvider(venue));
        try {
          await ref.read(signSettingsProvider(venue).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView(
        key: const Key('bottle-signs'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text('Bottle signs', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('A short sign that goes with a bottle to the table. Servers write it on the order.', style: theme.textTheme.bodyMedium),
          OpsAsyncView<SignSettings>(
            value: settings,
            what: 'the bottle sign settings',
            errorKey: const Key('signs-error'),
            onRetry: () => ref.invalidate(signSettingsProvider(venue)),
            builder: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('Where signs can go', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<SignMode>(
                  key: const Key('sign-mode'),
                  showSelectedIcon: false,
                  segments: [for (final m in SignMode.values) ButtonSegment(value: m, label: Text(m.label, key: Key('sign-mode-${m.value}')))],
                  selected: {s.mode},
                  onSelectionChanged: _busy ? null : (v) => _change(venue, () => ref.read(bottleSignServiceProvider).save(venue, mode: v.first)),
                ),
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.mode.explanation, key: const Key('sign-mode-explanation'), style: theme.textTheme.bodySmall)),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('sign-review'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('A manager approves servers\' signs'),
                  subtitle: const Text('Until a manager approves it, the bottle is not prepared or delivered. A manager\'s own sign needs no approval.'),
                  value: s.reviewRequired,
                  onChanged: _busy ? null : (v) => _change(venue, () => ref.read(bottleSignServiceProvider).save(venue, reviewRequired: v)),
                ),
                if (s.mode == SignMode.selected) ...[
                  const SizedBox(height: 8),
                  Text('Bottles that can carry a sign', style: theme.textTheme.titleMedium),
                  if (s.bottles.isEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('There are no bottles on your menu yet.', key: const Key('sign-no-bottles'), style: theme.textTheme.bodyMedium))
                  else
                    for (final b in s.bottles)
                      SwitchListTile(
                        key: Key('sign-bottle-${b.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(b.title),
                        subtitle: b.category == null ? null : Text(b.category!),
                        value: b.signEligible,
                        onChanged: _busy ? null : (v) => _change(venue, () => ref.read(bottleSignServiceProvider).setEligible(venue, b.id, v)),
                      ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Waiting for approval', style: theme.textTheme.titleMedium),
          OpsAsyncView<List<PendingSign>>(
            value: pending,
            what: 'the signs waiting for approval',
            errorKey: const Key('pending-signs-error'),
            onRetry: () => ref.invalidate(pendingSignsProvider(venue)),
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No sign is waiting for you.',
            emptyKey: const Key('pending-signs-empty'),
            builder: (list) => Column(
              children: [
                for (final p in list)
                  Card(
                    key: Key('pending-sign-${p.lineId}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('“${p.text}”', key: Key('pending-sign-text-${p.lineId}'), style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text([p.title, if (p.guestName != null) 'for ${p.guestName}', 'from ${p.setByName}'].join(' · '), style: theme.textTheme.bodySmall),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton.tonal(key: Key('pending-approve-${p.lineId}'), onPressed: _busyLines.contains(p.lineId) ? null : () => _approve(venue, p), child: const Text('Approve')),
                              const SizedBox(width: 8),
                              OutlinedButton(key: Key('pending-decline-${p.lineId}'), onPressed: _busyLines.contains(p.lineId) ? null : () => _decline(venue, p), child: const Text('Decline')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
