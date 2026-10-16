import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../logic/seating_rules.dart';
import '../providers/seating_providers.dart';
import 'seat_dialog.dart';

/// On a table's page: is the guest seated, since when and by whom, the service estimate (changeable), and what the guest has been told
/// about it. A guest message reads "Queued, not sent yet" until a sender has actually sent it. Shows nothing on a server that does not
/// have the seating functions yet, so the rest of the page is untouched.
class SeatingPanel extends ConsumerWidget {
  const SeatingPanel({super.key, required this.bookingId, required this.title, this.canUnseat = false});

  final String bookingId;

  /// The table and guest, for the dialogs: "VIP booth · Ada Lovelace".
  final String title;

  /// A manager or owner may undo a mis-tap, with a reason.
  final bool canUnseat;

  void _refresh(WidgetRef ref) {
    ref.invalidate(seatingStateProvider(bookingId));
    ref.invalidate(guestMessagesProvider(bookingId));
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final note = await action();
      if (note != null) messenger.showSnackBar(SnackBar(content: Text(note)));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    _refresh(ref);
  }

  Future<void> _seat(BuildContext context, WidgetRef ref) async {
    final answer = await showSeatDialog(context, heading: 'Seat the guest', detailLine: title, manual: true);
    if (answer == null || !context.mounted) return;
    await _run(context, ref, () async {
      final outcome = await ref.read(seatingServiceProvider).seat(bookingId, manual: true, detail: answer.detail, estimateMinutes: answer.minutes);
      return outcome.already ? 'This guest was already seated. Nothing changed.' : 'Seated. The guest\'s confirmation is queued.';
    });
  }

  Future<void> _estimate(BuildContext context, WidgetRef ref, SeatingState s) async {
    final text = await showTextDialog(
      context,
      title: 'Service estimate',
      hint: 'Minutes, for example 25 (empty clears it)',
      confirmLabel: 'Save',
      message: s.estimateMinutes == null ? 'No estimate yet.' : 'It is ${estimateLabel(s.estimateMinutes!)} now.',
      validate: (t) => t.trim().isEmpty ? null : checkEstimate(t).error,
    );
    if (text == null || !context.mounted) return;
    final minutes = checkEstimate(text).minutes;
    await _run(context, ref, () async {
      final changed = await ref.read(seatingServiceProvider).setEstimate(bookingId, minutes);
      if (!changed) return 'The estimate was already that.';
      return minutes == null ? 'Estimate cleared.' : 'Estimate saved. The guest\'s update is queued.';
    });
  }

  Future<void> _unseat(BuildContext context, WidgetRef ref) async {
    final reason = await showTextDialog(
      context,
      title: 'Un-seat this guest',
      hint: 'Why?',
      confirmLabel: 'Un-seat',
      message: 'Use this when a guest was seated by mistake.',
      validate: (t) => t.trim().length < 3 ? 'Say why this guest is being un-seated.' : null,
    );
    if (reason == null || !context.mounted) return;
    await _run(context, ref, () async {
      await ref.read(seatingServiceProvider).unseat(bookingId, reason);
      return 'The guest is no longer marked as seated.';
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(seatingStateProvider(bookingId));
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) {
        final e = opsLoadFailureFor(error, 'the seating');
        if (e.unavailable) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(e.message, key: const Key('seating-error')));
      },
      data: (s) {
        final theme = Theme.of(context);
        final messages = ref.watch(guestMessagesProvider(bookingId)).asData?.value ?? const <GuestMessage>[];
        return Card(
          key: const Key('seating-panel'),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.seated ? 'Seated${s.seatedAt == null ? '' : ' at ${clockLabel(s.seatedAt!)}'}' : 'Guest not seated yet',
                  key: const Key('seating-title'),
                  style: theme.textTheme.titleMedium,
                ),
                if (s.seated && s.seatedByName != null) Text('By ${s.seatedByName}${s.method == 'manual' ? ' (checked by hand)' : ''}', style: theme.textTheme.bodySmall),
                if (s.seated)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.estimateMinutes == null ? 'No service estimate yet' : 'Service estimate: ${estimateLabel(s.estimateMinutes!)}',
                          key: const Key('seating-estimate'),
                        ),
                      ),
                      TextButton(key: const Key('estimate-change'), onPressed: () => _estimate(context, ref, s), child: Text(s.estimateMinutes == null ? 'Set' : 'Change')),
                    ],
                  ),
                for (final (i, m) in messages.indexed)
                  Text('${m.kindLabel}: ${m.statusLabel}', key: Key('guest-message-$i'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (!s.seated) FilledButton(key: const Key('panel-seat'), onPressed: () => _seat(context, ref), child: const Text('Mark seated')),
                    if (s.seated && canUnseat) OutlinedButton(key: const Key('panel-unseat'), onPressed: () => _unseat(context, ref), child: const Text('Un-seat')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
