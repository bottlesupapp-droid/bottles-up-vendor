import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/sign_rules.dart';
import '../providers/bottle_sign_providers.dart';
import 'decline_sign_dialog.dart';
import 'sign_sheet.dart';

Color signStatusColor(SignStatus s) => switch (s) {
      SignStatus.pendingReview => const Color(0xFFFFB300),
      SignStatus.approved => const Color(0xFF66BB6A),
      SignStatus.rejected => const Color(0xFFEF5350),
    };

/// The sign on an order card: the words, where it stands, a way to add or change it, and (for a manager) approving or declining a waiting one. It does the calls itself and
/// tells the screen through [onChanged] so the list is read again. Nothing is shown for a line that has no sign and cannot take one.
class LineSignBar extends ConsumerStatefulWidget {
  const LineSignBar({super.key, required this.sign, required this.title, required this.manager, required this.onChanged, this.bookingId});

  final LineSign sign;

  /// What the sign is for: "2 × Patron".
  final String title;
  final bool manager;
  final String? bookingId;
  final VoidCallback onChanged;

  @override
  ConsumerState<LineSignBar> createState() => _LineSignBarState();
}

class _LineSignBarState extends ConsumerState<LineSignBar> {
  bool _busy = false;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SignSheet(lineId: widget.sign.lineId, title: widget.title, current: widget.sign.text, bookingId: widget.bookingId),
    );
    // Whatever happened, the list shows where the sign stands now.
    widget.onChanged();
    if (message != null) _say(message);
  }

  Future<void> _approve() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final change = await ref.read(bottleSignServiceProvider).review(widget.sign.lineId, approve: true);
      _say(change.changed ? 'Sign approved.' : 'It was already approved.');
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      widget.onChanged();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final declined = await showDialog<bool>(context: context, builder: (_) => DeclineSignDialog(lineId: widget.sign.lineId, signText: widget.sign.text ?? ''));
    widget.onChanged();
    if (declined == true) _say('Sign declined.');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sign;
    if (!s.hasSign && !s.canSet) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final id = s.lineId;
    final status = s.status;
    final showStatus = status != null && (s.reviewRequired || status != SignStatus.approved);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.hasSign)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.only(top: 2, right: 6), child: Icon(Icons.edit_note, size: 18)),
                Expanded(child: Text('Sign: “${s.text}”', key: Key('sign-text-$id'), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
                if (showStatus) ...[const SizedBox(width: 6), DeskChip(key: Key('sign-status-$id'), text: status.label, color: signStatusColor(status))],
              ],
            ),
          if (s.isDeclined && s.reviewNote != null) Text('Declined: ${s.reviewNote}', key: Key('sign-note-$id'), style: theme.textTheme.bodySmall),
          if (s.blockMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(s.blockMessage!, key: Key('sign-blocked-$id'), style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFFFB300))),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (s.canSet) TextButton(key: Key('sign-edit-$id'), onPressed: _busy ? null : _edit, child: Text(s.hasSign ? 'Change the sign' : 'Add a sign')),
              if (widget.manager && s.isWaiting) ...[
                FilledButton.tonal(key: Key('sign-approve-$id'), onPressed: _busy ? null : _approve, child: const Text('Approve')),
                OutlinedButton(key: Key('sign-decline-$id'), onPressed: _busy ? null : _decline, child: const Text('Decline')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
