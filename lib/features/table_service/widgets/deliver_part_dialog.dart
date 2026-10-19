import 'package:flutter/material.dart';

import '../logic/bottle_orders_rules.dart';
import '../logic/table_service_rules.dart';

/// "Deliver some": how many of this line were handed over now. Answers the number (1 to what is left), or null when cancelled. The line says how many were already
/// handed over, and the call carries that number so a repeated or out-of-date hand-over is refused by the database instead of counted twice.
class DeliverPartDialog extends StatefulWidget {
  const DeliverPartDialog({super.key, required this.line});

  final OrderLine line;

  @override
  State<DeliverPartDialog> createState() => _DeliverPartDialogState();
}

class _DeliverPartDialogState extends State<DeliverPartDialog> {
  int _n = 1;

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    final left = remainingToDeliver(l);
    return AlertDialog(
      title: const Text('Deliver some'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.title),
          if (l.deliveredQuantity > 0) Text('${l.deliveredQuantity} of ${l.quantity} already delivered.', key: const Key('deliver-already')),
          const SizedBox(height: 12),
          const Text('How many are being handed over now?'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(key: const Key('deliver-less'), onPressed: _n <= 1 ? null : () => setState(() => _n--), icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(width: 40, child: Text('$_n', key: const Key('deliver-n'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
              IconButton(key: const Key('deliver-more'), onPressed: _n >= left ? null : () => setState(() => _n++), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          if (_n >= left) Text('That is all that is left: the order will be marked Delivered.', key: const Key('deliver-all'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(key: const Key('deliver-cancel'), onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(key: const Key('deliver-confirm'), onPressed: () => Navigator.of(context).pop(_n), child: const Text('Record delivery')),
      ],
    );
  }
}
