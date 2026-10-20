import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../logic/refund_rules.dart';
import '../providers/refund_providers.dart';

/// Record that an approved refund was paid back at the club (cash or the club's own terminal). The terminal or receipt reference is the evidence; the booking's paid amount goes
/// down in the same step. A repeated tap changes nothing (the database answers the same for a request that is already recorded). Pops true once recorded.
class ClubRefundDialog extends ConsumerStatefulWidget {
  const ClubRefundDialog({super.key, required this.request});

  final RefundRequest request;

  @override
  ConsumerState<ClubRefundDialog> createState() => _ClubRefundDialogState();
}

class _ClubRefundDialogState extends ConsumerState<ClubRefundDialog> {
  final _reference = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem = validateClubReference(_reference.text);
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(refundServiceProvider).completeClubRefund(widget.request.requestId, _reference.text);
      if (mounted) Navigator.of(context).pop(true);
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
    final r = widget.request;
    return AlertDialog(
      title: Text('Paid back ${formatDollars(r.approvedCents ?? 0)} at the club'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${r.guestName} · ${r.tableName}. Record this only once the guest has the money. Add the terminal or receipt reference as evidence.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('club-reference'),
            controller: _reference,
            enabled: !_busy,
            maxLength: 200,
            decoration: InputDecoration(labelText: 'Terminal or receipt reference', errorText: _problem, errorMaxLines: 3, border: const OutlineInputBorder(), counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(key: const Key('club-cancel'), onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Not yet')),
        FilledButton(key: const Key('club-save'), onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'It has been paid back')),
      ],
    );
  }
}
