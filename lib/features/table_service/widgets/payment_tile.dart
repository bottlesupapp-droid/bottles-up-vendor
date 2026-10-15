import 'package:flutter/material.dart';

import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/table_service_rules.dart';

Color verificationColor(Verification v) => switch (v) {
  Verification.pending => const Color(0xFFFFB300),
  Verification.verified => const Color(0xFF66BB6A),
  Verification.customerConfirmed => const Color(0xFF42A5F5),
  Verification.disputed => const Color(0xFFEF5350),
};

/// One payment recorded for a table: how, how much, when, on what evidence, and where it stands. A recorded payment reads "Recorded -
/// verification pending" until someone else has checked it; a photo alone never makes it verified.
class PaymentTile extends StatelessWidget {
  const PaymentTile({
    super.key,
    required this.payment,
    required this.now,
    required this.onViewReceipt,
  });

  final PaymentEntry payment;
  final DateTime now;
  final ValueChanged<String> onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = payment;
    return Card(
      key: Key('payment-${p.id}'),
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
                    '${p.methodLabel} · ${formatDollars(p.paidCents)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                DeskChip(
                  key: Key('verification-${p.id}'),
                  text: p.verification.label,
                  color: verificationColor(p.verification),
                ),
              ],
            ),
            if (p.billedCents != p.paidCents)
              Text(
                'Bill ${formatDollars(p.billedCents)}',
                style: theme.textTheme.bodySmall,
              ),
            if (p.tipCents > 0)
              Text(
                'Tip ${formatDollars(p.tipCents)}',
                style: theme.textTheme.bodySmall,
              ),
            Text(
              'Recorded ${waitedLabel(p.recordedAt, now)} ago${p.recordedByMe ? ' by you' : ''}'
              '${p.payerName == null ? '' : ' · ${p.payerName}'}',
              style: theme.textTheme.bodySmall,
            ),
            if (p.posReference != null)
              Text(
                'Receipt no. ${p.posReference}',
                style: theme.textTheme.bodySmall,
              ),
            if (p.verifiedNote != null)
              Text(
                'Checked: ${p.verifiedNote}',
                key: Key('verified-note-${p.id}'),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            if (p.receiptPath != null)
              TextButton.icon(
                key: Key('receipt-${p.id}'),
                onPressed: () => onViewReceipt(p.receiptPath!),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('View receipt'),
              )
            else
              Text(
                'No receipt${p.missingReceiptReason == null ? '' : ': ${p.missingReceiptReason}'}',
                key: Key('no-receipt-${p.id}'),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
