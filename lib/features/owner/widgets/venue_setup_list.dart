import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../logic/owner_rules.dart';
import '../providers/owner_providers.dart';
import '../screens/setup/booking_times_editor.dart';
import '../screens/setup/bottle_menu_editor.dart';
import '../screens/setup/table_types_editor.dart';
import '../services/owner_service.dart';

String _failure(Object error) => error is OwnerLoadException ? error.message : ownerLoadMessage(unavailable: false, accessEnded: false);

/// A venue's setup progress in one line: a bar and "3 of 5 required steps". For the venue list.
class SetupProgress extends ConsumerWidget {
  const SetupProgress({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref.watch(venueSetupProvider(venueId)).when(
          loading: () => const SizedBox(height: 18, child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
          error: (e, _) => Text('Setup progress is not available right now.', key: Key('setup-unavailable-$venueId'), style: theme.textTheme.bodySmall),
          data: (steps) {
            final s = summarizeSetup(steps);
            if (s.requiredTotal == 0) return Text('Setup progress is not available right now.', key: Key('setup-unavailable-$venueId'), style: theme.textTheme.bodySmall);
            return Column(
              key: Key('setup-progress-$venueId'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(minHeight: 6, value: s.percent / 100, backgroundColor: theme.colorScheme.surfaceContainerHighest),
                ),
                const SizedBox(height: 4),
                Text('${s.requiredDone} of ${s.requiredTotal} required steps', style: theme.textTheme.bodySmall),
              ],
            );
          },
        );
  }
}

/// A venue's full setup checklist, computed by the database from what really exists. Readiness counts only the required steps;
/// a step the system cannot do yet says "Coming soon" and never counts as done or pending.
class VenueSetupList extends ConsumerWidget {
  const VenueSetupList({super.key, required this.venueId});

  final String venueId;

  /// The editor behind a step, when this app has one. The others (the profile, the floor plan) are edited on the website for now.
  Widget? _editorFor(String step) => switch (step) {
        'tables' => TableTypesEditor(venueId: venueId),
        'bottles' => BottleMenuEditor(venueId: venueId),
        'booking_rules' => BookingTimesEditor(venueId: venueId),
        _ => null,
      };

  IconData _icon(SetupStatus s) => switch (s) {
        SetupStatus.done => Ionicons.checkmark_circle,
        SetupStatus.todo => Ionicons.ellipse_outline,
        SetupStatus.unavailable => Ionicons.time_outline,
      };

  Color _color(SetupStatus s) => switch (s) {
        SetupStatus.done => const Color(0xFF66BB6A),
        SetupStatus.todo => const Color(0xFFFFB300),
        SetupStatus.unavailable => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref.watch(venueSetupProvider(venueId)).when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(_failure(e), key: const Key('setup-error'), textAlign: TextAlign.center),
                if (!(e is OwnerLoadException && e.unavailable))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton(key: const Key('setup-retry'), onPressed: () => ref.invalidate(venueSetupProvider(venueId)), child: const Text('Try again')),
                  ),
              ],
            ),
          ),
          data: (steps) {
            final s = summarizeSetup(steps);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              children: [
                if (s.requiredTotal > 0) ...[
                  Text(
                    s.ready ? 'Every required step is done.' : '${s.requiredDone} of ${s.requiredTotal} required steps done',
                    key: const Key('setup-summary'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(minHeight: 8, value: s.percent / 100, backgroundColor: theme.colorScheme.surfaceContainerHighest),
                  ),
                  if (s.nextStep != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Next: ${stepLabel(s.nextStep!.step)}', key: const Key('setup-next'), style: theme.textTheme.bodyMedium),
                    ),
                ] else
                  Text('Setup progress is not available right now.', key: const Key('setup-empty'), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                for (final step in steps)
                  Card(
                    key: Key('step-${step.step}'),
                    margin: const EdgeInsets.only(top: 8),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _editorFor(step.step) == null
                          ? null
                          : () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => _editorFor(step.step)!)),
                      child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_icon(step.status), color: _color(step.status), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(step.required ? stepLabel(step.step) : '${stepLabel(step.step)} (optional)', style: theme.textTheme.titleSmall),
                                if (stepDescription(step.step).isNotEmpty) Text(stepDescription(step.step), style: theme.textTheme.bodySmall),
                                if (step.status == SetupStatus.todo && step.detail != null)
                                  Text('To do: ${step.detail}', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFFFB300))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(setupStatusLabel(step.status), style: theme.textTheme.labelSmall),
                              if (_editorFor(step.step) != null) Text('Edit', key: Key('edit-step-${step.step}'), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Tables, the bottle menu and booking times can be edited here. The venue profile, floor plans and photos are edited on the website for now '
                  '(bottlesupapp.com, My Venues). Taking a venue live is done by the BottlesUp team once your business is verified and every required step is done.',
                  key: const Key('setup-footnote'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        );
  }
}
