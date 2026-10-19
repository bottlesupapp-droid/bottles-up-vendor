import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../server_desk/widgets/desk_chip.dart';
import '../../workspace/models/workspace.dart';
import '../logic/table_service_rules.dart';
import '../providers/table_service_providers.dart';
import '../services/table_service_service.dart';
import '../widgets/payment_tile.dart' show verificationColor;
import '../widgets/receipt_view.dart';
import '../widgets/verify_dialog.dart';
import '../../cash_review/logic/cash_rules.dart' show checkFlagReason;
import '../../cash_review/providers/cash_providers.dart';
import '../../ops/services/ops_rpc.dart' show OpsActionException;
import '../../ops/widgets/ops_dialogs.dart' show showTextDialog;

/// Asks for the note that goes with checking a payment. Replaced in tests.
typedef VerifyPrompt =
    Future<String?> Function(BuildContext context, String summary);

Future<String?> _defaultVerifyPrompt(BuildContext context, String summary) =>
    showVerifyDialog(context, summary: summary);

/// Payments to check (verifier; also reached from the manager's Tonight): the payments staff recorded at this club that nobody has
/// checked yet, and the ones a guest disputed, oldest first with disputes on top. Each shows the bill, what was collected, how, who
/// recorded it, and the receipt photo to compare. You cannot check a payment you recorded yourself, nor one the guest disputed; the
/// database refuses both, and the screen says so instead of offering a button. Checking is a person comparing the bill and the
/// receipt with the till or the cash counted: a photo alone verifies nothing.
class PaymentReviewScreen extends ConsumerStatefulWidget {
  const PaymentReviewScreen({
    super.key,
    required this.workspace,
    this.clock = DateTime.now,
    this.askVerify = _defaultVerifyPrompt,
  });

  final Workspace workspace;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;
  final VerifyPrompt askVerify;

  @override
  ConsumerState<PaymentReviewScreen> createState() =>
      _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends ConsumerState<PaymentReviewScreen> {
  final Set<String> _busy = {};

  Future<void> _verify(PendingPayment p) async {
    final note = await widget.askVerify(
      context,
      '${p.tableName} · ${p.customerName}: ${formatDollars(p.paidCents)} by ${p.methodLabel.toLowerCase()}',
    );
    if (note == null || !mounted) return;
    setState(() => _busy.add(p.paymentId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(tableServiceServiceProvider)
          .verify(p.paymentId, note: note);
      messenger.showSnackBar(
        const SnackBar(content: Text('Payment marked as checked.')),
      );
    } on TableServiceActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      // Always read the queue again: after a refusal (someone else checked it first) it shows where the payment stands now.
      ref.invalidate(pendingPaymentsProvider(widget.workspace.venueId ?? ''));
      if (mounted) setState(() => _busy.remove(p.paymentId));
    }
  }

  Future<void> _flag(PendingPayment p) async {
    final reason = await showTextDialog(
      context,
      title: 'Flag this payment',
      message: '${p.tableName} · ${p.customerName}: ${formatDollars(p.paidCents)} by ${p.methodLabel.toLowerCase()}. A manager will look at it.',
      hint: 'What is wrong with it?',
      confirmLabel: 'Flag it',
      validate: checkFlagReason,
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final venue = widget.workspace.venueId ?? '';
    try {
      await ref.read(cashServiceProvider).flagPayment(p.paymentId, reason);
      messenger.showSnackBar(const SnackBar(content: Text('Payment flagged. A manager will resolve it.')));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
    ref.invalidate(flagsProvider((venueId: venue, resolved: false)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = widget.workspace.venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This workspace is not tied to a club, so there are no payments to check.',
            key: Key('review-no-venue'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final async = ref.watch(pendingPaymentsProvider(venueId));
    final now = widget.clock();

    // One entry per row, built only when it scrolls into view: a long queue can have hundreds of payments.
    final items = <Widget Function()>[
      () => Text('Payments to check', style: theme.textTheme.headlineSmall),
      () =>
          widget.workspace.venueName == null
              ? const SizedBox.shrink()
              : Text(
                widget.workspace.venueName!,
                style: theme.textTheme.bodyMedium,
              ),
      () => const SizedBox(height: 8),
    ];
    async.when<void>(
      loading:
          () => items.add(
            () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      error: (error, _) {
        final e = loadFailureFor(error, 'payments');
        items.add(
          () => Column(
            children: [
              Text(
                e.message,
                key: const Key('review-error'),
                textAlign: TextAlign.center,
              ),
              if (!e.unavailable)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    key: const Key('review-retry'),
                    onPressed:
                        () => ref.invalidate(pendingPaymentsProvider(venueId)),
                    child: const Text('Try again'),
                  ),
                ),
            ],
          ),
        );
      },
      data: (rows) {
        if (rows.isEmpty) {
          items.add(
            () => const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'Nothing is waiting to be checked.',
                key: Key('review-empty'),
                textAlign: TextAlign.center,
              ),
            ),
          );
          return;
        }
        items.add(
          () => Text(
            '${rows.length} ${rows.length == 1 ? 'payment' : 'payments'} waiting',
            key: const Key('review-summary'),
            style: theme.textTheme.bodyMedium,
          ),
        );
        for (final p in rows) {
          items.add(() => _card(context, p, now, theme));
        }
        if (rows.length >= 300) {
          items.add(
            () => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Showing the first 300 payments.',
                key: const Key('review-cutoff'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          );
        }
      },
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingPaymentsProvider(venueId));
        try {
          await ref.read(pendingPaymentsProvider(venueId).future);
        } catch (_) {
          // The screen shows the failure itself.
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i](),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    PendingPayment p,
    DateTime now,
    ThemeData theme,
  ) {
    final reason = p.cannotVerifyBecause;
    final verification =
        p.disputed ? Verification.disputed : Verification.pending;
    return Card(
      key: Key('review-${p.paymentId}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.customerName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                DeskChip(
                  key: Key('review-state-${p.paymentId}'),
                  text: p.disputed ? 'Disputed' : 'Pending',
                  color: verificationColor(verification),
                ),
              ],
            ),
            Text(
              [
                p.tableName,
                if (p.confirmationCode != null) p.confirmationCode!,
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${p.methodLabel} · collected ${formatDollars(p.paidCents)}',
              style: theme.textTheme.titleSmall,
            ),
            if (p.billedCents != p.paidCents)
              Text(
                'Bill ${formatDollars(p.billedCents)}',
                style: theme.textTheme.bodySmall,
              ),
            if (p.posReference != null)
              Text(
                'Till receipt no. ${p.posReference}',
                style: theme.textTheme.bodySmall,
              ),
            Text(
              'Recorded ${waitedLabel(p.recordedAt, now)} ago by ${p.recordedByMe ? 'you' : (p.recordedByName ?? 'a colleague')}',
              style: theme.textTheme.bodySmall,
            ),
            if (p.disputed && p.disputeReason != null)
              Text(
                'Guest says: ${p.disputeReason}',
                key: Key('dispute-${p.paymentId}'),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            if (p.receiptPath != null)
              TextButton.icon(
                key: Key('review-receipt-${p.paymentId}'),
                onPressed: () => showReceipt(context, ref, p.receiptPath!),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('View receipt'),
              )
            else
              Text(
                'No receipt${p.missingReceiptReason == null ? '' : ': ${p.missingReceiptReason}'}',
                key: Key('review-no-receipt-${p.paymentId}'),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            if (reason != null)
              Text(
                reason,
                key: Key('review-why-${p.paymentId}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFFFB300),
                ),
              )
            else
              FilledButton(
                key: Key('verify-${p.paymentId}'),
                onPressed:
                    _busy.contains(p.paymentId) ? null : () => _verify(p),
                child: const Text('Check it against the till'),
              ),
            if (!p.recordedByMe)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: Key('flag-${p.paymentId}'),
                  onPressed: () => _flag(p),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Flag a problem'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
