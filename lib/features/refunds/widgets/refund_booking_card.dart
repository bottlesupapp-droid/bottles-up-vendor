import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../logic/refund_rules.dart';
import '../providers/refund_providers.dart';

/// Cancelling a booking and asking for a refund, on the booking's own page (club manager and owner). Cancelling goes through the website's cancel function, which keeps the paid bottle
/// lines and the reason; if money was paid on the booking the next step is offered straight away. A refund request records that money is to go back; the manager decides it (amount, and
/// how it is paid back) under Refunds. Nothing here moves money.
class RefundBookingCard extends ConsumerWidget {
  const RefundBookingCard({super.key, required this.bookingId, required this.canCancel, this.onChanged});

  final String bookingId;

  /// A confirmed booking whose night is not closed out.
  final bool canCancel;

  /// Called after the booking was cancelled, so the page reads it again.
  final VoidCallback? onChanged;

  void _say(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _ask(BuildContext context, WidgetRef ref, RefundOptions options) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AskRefundSheet(bookingId: bookingId, options: options),
    );
    ref.invalidate(refundOptionsProvider(bookingId));
    if (message != null && context.mounted) _say(context, message);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(context: context, builder: (_) => CancelBookingDialog(bookingId: bookingId));
    ref.invalidate(refundOptionsProvider(bookingId));
    if (result == null || !context.mounted) return;
    onChanged?.call();
    _say(context, cancelledMessage(refundSuggested: result));
    if (result) {
      final options = await ref.read(refundOptionsProvider(bookingId).future).then<RefundOptions?>((o) => o).catchError((_) => null);
      if (options != null && options.canAsk && context.mounted) await _ask(context, ref, options);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final options = ref.watch(refundOptionsProvider(bookingId));
    return Card(
      key: const Key('refund-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cancel and refund', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            options.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
              error: (error, _) {
                final e = opsLoadFailureFor(error, 'the refund details');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.message, key: const Key('refund-card-error')),
                    if (!e.unavailable) TextButton(key: const Key('refund-card-retry'), onPressed: () => ref.invalidate(refundOptionsProvider(bookingId)), child: const Text('Try again')),
                  ],
                );
              },
              data: (o) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paid ${formatDollars(o.paidCents)} · can still be refunded ${formatDollars(o.availableCents)}', key: const Key('refund-card-money')),
                  if (o.why != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(o.why!, key: const Key('refund-card-why'), style: theme.textTheme.bodySmall)),
                  if (arrivalLine(o.hoursToArrival).isNotEmpty) Text(arrivalLine(o.hoursToArrival), style: theme.textTheme.bodySmall),
                  if (o.hasOpenRequest) Padding(padding: const EdgeInsets.only(top: 6), child: Text('A refund request is open on this booking. Decide it under More > Refunds.', key: const Key('refund-card-open'))),
                  if (o.status == 'cancelled') Padding(padding: const EdgeInsets.only(top: 6), child: Text('This booking is cancelled.', key: const Key('refund-card-cancelled'), style: theme.textTheme.bodySmall)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (canCancel && o.status == 'paid')
                        OutlinedButton.icon(key: const Key('cancel-booking'), onPressed: () => _cancel(context, ref), icon: const Icon(Icons.cancel_outlined, size: 18), label: const Text('Cancel booking')),
                      if (o.canAsk)
                        OutlinedButton.icon(key: const Key('ask-refund'), onPressed: () => _ask(context, ref, o), icon: const Icon(Icons.undo, size: 18), label: const Text('Ask for a refund')),
                    ],
                  ),
                  if (o.availableCents <= 0 && !o.hasOpenRequest && o.status != 'cancelled')
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('Nothing is left to refund on this booking.', key: const Key('refund-card-nothing'), style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Records that a refund is wanted on a booking: the policy's suggestion is shown, and a reason is needed. Pops with the message to show.
class AskRefundSheet extends ConsumerStatefulWidget {
  const AskRefundSheet({super.key, required this.bookingId, required this.options});

  final String bookingId;
  final RefundOptions options;

  @override
  ConsumerState<AskRefundSheet> createState() => _AskRefundSheetState();
}

class _AskRefundSheetState extends ConsumerState<AskRefundSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final problem = validateRequestReason(_reason.text);
    setState(() => _problems = [if (problem != null) problem]);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(refundServiceProvider).ask(widget.bookingId, _reason.text);
      if (!mounted) return;
      Navigator.of(context).pop('Refund request recorded. Decide it under More > Refunds.');
    } on OpsActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _problems = [e.message];
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = widget.options;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('ask-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask for a refund', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Paid ${formatDollars(o.paidCents)} · can still be refunded ${formatDollars(o.availableCents)}'),
            if (o.why != null) Text(o.why!, style: theme.textTheme.bodySmall),
            if (o.percent != null) Text('Suggested by the policy: ${formatDollars(o.suggestedCents)}', key: const Key('ask-suggested'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text('This only records that a refund is wanted. You decide the amount, and how it is paid back, under More > Refunds.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ask-reason'),
              controller: _reason,
              enabled: !_busy,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Why is a refund wanted?', border: OutlineInputBorder(), counterText: ''),
            ),
            if (_problems.isNotEmpty) ...[const SizedBox(height: 8), ProblemsBox(problems: _problems)],
            const SizedBox(height: 12),
            FilledButton(key: const Key('ask-confirm'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving...' : 'Record the request')),
          ],
        ),
      ),
    );
  }
}

/// Cancels a booking after asking why. Stays open, with what was typed, when the cancellation is refused or its outcome is unknown. Pops whether money had been paid on it.
class CancelBookingDialog extends ConsumerStatefulWidget {
  const CancelBookingDialog({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends ConsumerState<CancelBookingDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_busy) return;
    final problem = validateCancelReason(_reason.text);
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      final paid = await ref.read(refundServiceProvider).cancelBooking(widget.bookingId, _reason.text);
      if (mounted) Navigator.of(context).pop(paid);
    } on OpsActionException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel this booking?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The table is given back and the paid bottle orders are kept with the reason. Money already paid is not returned until you decide a refund. This cannot be undone.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('cancel-reason'),
            controller: _reason,
            enabled: !_busy,
            maxLength: 500,
            decoration: InputDecoration(labelText: 'Why is it cancelled?', errorText: _problem, errorMaxLines: 4, border: const OutlineInputBorder(), counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(key: const Key('cancel-keep'), onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Keep the booking')),
        FilledButton(
          key: const Key('cancel-confirm'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
          onPressed: _busy ? null : _cancel,
          child: Text(_busy ? 'Cancelling...' : 'Cancel the booking'),
        ),
      ],
    );
  }
}
