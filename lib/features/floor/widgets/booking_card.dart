import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../logic/bookings_rules.dart';

/// One booking: when, who, which table, how many, whether it is paid, how to reach the guest, and whether they have arrived.
/// Amounts are what was booked, not what was collected (the database only holds the booked total and deposit here).
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onContact});

  final BookingRow booking;

  /// Opens a phone or email link. A failure is the caller's to report.
  final ValueChanged<Uri> onContact;

  Color _tone(StatusTone tone) => switch (tone) {
        StatusTone.good => const Color(0xFF66BB6A),
        StatusTone.wait => const Color(0xFFFFB300),
        StatusTone.bad => const Color(0xFFEF5350),
        StatusTone.neutral => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = booking;
    final info = statusInfo(b.status);
    final tone = _tone(info.tone);

    Widget chip(Key key, String text, Color color, {IconData? icon}) => Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.7)), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
            Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color)),
          ]),
        );

    Widget link(Key key, String text, Uri uri) => InkWell(
          key: key,
          onTap: () => onContact(uri),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(text, style: theme.textTheme.bodySmall?.copyWith(decoration: TextDecoration.underline)),
          ),
        );

    return Card(
      key: Key('booking-${b.bookingId}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(formatTimeSlot(b.startTime), style: theme.textTheme.titleSmall),
                if (b.slotLabel != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: Text(b.slotLabel!, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                ],
                const Spacer(),
                if (b.checkedInAt != null && info.confirmed) ...[
                  chip(const Key('arrived'), 'Arrived', const Color(0xFF66BB6A), icon: Ionicons.checkmark_circle),
                  const SizedBox(width: 6),
                ],
                chip(Key('status-${b.bookingId}'), info.label, tone),
              ],
            ),
            const SizedBox(height: 8),
            Text(b.customerName, style: theme.textTheme.titleMedium),
            Text('${b.tableName} · ${b.guestCount} ${b.guestCount == 1 ? 'guest' : 'guests'}', style: theme.textTheme.bodyMedium),
            if ((b.customerPhone != null && dialable(b.customerPhone!) != null) || b.customerEmail.isNotEmpty)
              Wrap(
                spacing: 16,
                children: [
                  if (b.customerPhone != null && dialable(b.customerPhone!) != null)
                    link(Key('phone-${b.bookingId}'), b.customerPhone!, Uri(scheme: 'tel', path: dialable(b.customerPhone!))),
                  if (b.customerEmail.isNotEmpty) link(Key('email-${b.bookingId}'), b.customerEmail, Uri(scheme: 'mailto', path: b.customerEmail)),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              'Booked ${formatMoney(b.amountTotalCents, b.currency)}'
              '${b.depositCents > 0 ? ' · deposit ${formatMoney(b.depositCents, b.currency)}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (b.confirmationCode != null)
              Text(b.confirmationCode!, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}
