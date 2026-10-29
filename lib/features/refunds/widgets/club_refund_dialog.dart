import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/logic/media_rules.dart' show imageProblem;
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../table_service/providers/table_service_providers.dart' show receiptServiceProvider;
import '../../table_service/screens/record_payment_screen.dart' show receiptPhotoPickerProvider;
import '../../table_service/services/receipt_service.dart';
import '../logic/refund_rules.dart';
import '../providers/refund_providers.dart';

/// Record that an approved refund was paid back at the club (cash or the club's own terminal). The evidence is the terminal or receipt reference, a photo of the receipt, or both; the
/// photo goes into the private receipts bucket under the booking's own folder and stays uploaded across a retry, so a lost answer sent again is a repeat, not a second photo. The
/// booking's paid amount goes down in the same step. A repeated tap changes nothing (the database answers the same for a request that is already recorded). Pops true once recorded.
class ClubRefundDialog extends ConsumerStatefulWidget {
  const ClubRefundDialog({super.key, required this.request});

  final RefundRequest request;

  @override
  ConsumerState<ClubRefundDialog> createState() => _ClubRefundDialogState();
}

class _ClubRefundDialogState extends ConsumerState<ClubRefundDialog> {
  final _reference = TextEditingController();
  Uint8List? _photo;
  ReceiptUpload? _uploaded;
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool camera}) async {
    final bytes = await ref.read(receiptPhotoPickerProvider)(context, camera: camera);
    if (bytes == null || !mounted) return;
    final problem = imageProblem(bytes);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _photo = bytes;
      _uploaded = null;
      _problem = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem = validateClubReference(_reference.text, hasPhoto: _photo != null);
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      var up = _uploaded;
      final photo = _photo;
      if (photo != null && up == null) {
        up = await ref.read(receiptServiceProvider).upload(widget.request.bookingId, photo);
        _uploaded = up;
      }
      await ref.read(refundServiceProvider).completeClubRefund(widget.request.requestId, _reference.text, receiptPath: up?.path);
      if (mounted) Navigator.of(context).pop(true);
    } on ReceiptException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e.message;
          _busy = false;
        });
      }
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
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Paid back ${formatDollars(r.approvedCents ?? 0)} at the club'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${r.guestName} · ${r.tableName}. Record this only once the guest has the money. Add the terminal or receipt reference, a photo of the receipt, or both, as evidence.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('club-reference'),
              controller: _reference,
              enabled: !_busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Terminal or receipt reference', border: OutlineInputBorder(), counterText: ''),
            ),
            const SizedBox(height: 8),
            if (_photo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_photo!, key: const Key('club-photo-preview'), height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 120, child: Center(child: Text('Photo chosen (no preview).', key: Key('club-photo-nopreview')))))),
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(key: const Key('club-photo-camera'), onPressed: _busy ? null : () => _pick(camera: true), icon: const Icon(Icons.photo_camera_outlined, size: 18), label: Text(_photo == null ? 'Take a photo' : 'Take another')),
                OutlinedButton.icon(key: const Key('club-photo-gallery'), onPressed: _busy ? null : () => _pick(camera: false), icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Choose a photo')),
                if (_photo != null) TextButton(key: const Key('club-photo-remove'), onPressed: _busy ? null : () => setState(() => _photo = _uploaded = null), child: const Text('Remove')),
              ],
            ),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('club-problem'), style: TextStyle(color: theme.colorScheme.error))),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('club-cancel'), onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Not yet')),
        FilledButton(key: const Key('club-save'), onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'It has been paid back')),
      ],
    );
  }
}
