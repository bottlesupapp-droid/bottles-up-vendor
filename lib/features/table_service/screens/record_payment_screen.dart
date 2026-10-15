import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../owner/logic/media_rules.dart' show imageProblem;
import '../../owner/logic/setup_forms.dart'
    show formatDollars, moneyInput, parseMoney;
import '../logic/table_service_rules.dart';
import '../providers/table_service_providers.dart';
import '../services/receipt_service.dart';
import '../services/table_service_service.dart';

/// Takes a receipt photo. Replaced in tests; in the app it is the phone's camera or gallery. A large photo is shrunk to at most 2400
/// pixels wide and re-encoded, which also turns an iPhone HEIC photo into a JPEG the bucket accepts.
typedef ReceiptPhotoPicker =
    Future<Uint8List?> Function(BuildContext context, {required bool camera});

Future<Uint8List?> pickReceiptPhoto(
  BuildContext context, {
  required bool camera,
}) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 2400,
    imageQuality: 88,
  );
  return file?.readAsBytes();
}

final receiptPhotoPickerProvider = Provider<ReceiptPhotoPicker>(
  (ref) => pickReceiptPhoto,
);

/// Records a payment taken at the club (brief section 15): the bill, what was collected, how, the till's receipt number, and the
/// receipt photo as evidence. A server must attach a photo; a manager may instead say why there is none. Nothing is "verified" by
/// recording it: it reads "Recorded - verification pending" until someone else checks it. Pops with the [RecordedPayment] on success.
class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({
    super.key,
    required this.bookingId,
    required this.tableLabel,
    required this.balanceDueCents,
    required this.manager,
  });

  final String bookingId;
  final String tableLabel;
  final int balanceDueCents;
  final bool manager;

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _SplitRow {
  _SplitRow(this.method);

  PayMethod method;
  final TextEditingController amount = TextEditingController();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  late final TextEditingController _billed = TextEditingController(
    text: widget.balanceDueCents > 0 ? moneyInput(widget.balanceDueCents) : '',
  );
  late final TextEditingController _collected = TextEditingController(
    text: widget.balanceDueCents > 0 ? moneyInput(widget.balanceDueCents) : '',
  );
  final _pos = TextEditingController();
  final _payer = TextEditingController();
  final _bottles = TextEditingController();
  final _discount = TextEditingController();
  final _tax = TextEditingController();
  final _tip = TextEditingController();
  final _reason = TextEditingController();
  final List<_SplitRow> _split = [];

  PayMethod? _method;
  Uint8List? _photo;
  bool _readable = false;
  bool _noReceipt = false;
  bool _showProblems = false;
  bool _busy = false;
  String? _error;

  /// The photo, once it is in storage. Kept across a retry, so a lost answer sent again with the same photo is a repeat (the database
  /// says "already recorded") instead of a second payment.
  ReceiptUpload? _uploaded;

  @override
  void dispose() {
    for (final c in [
      _billed,
      _collected,
      _pos,
      _payer,
      _bottles,
      _discount,
      _tax,
      _tip,
      _reason,
    ]) {
      c.dispose();
    }
    for (final r in _split) {
      r.amount.dispose();
    }
    super.dispose();
  }

  PaymentInput _input() => PaymentInput(
    billed: _billed.text,
    collected: _collected.text,
    method: _method,
    split: [
      for (final r in _split)
        SplitPart(r.method, parseMoney(r.amount.text) ?? 0),
    ],
    posReference: _pos.text,
    payerName: _payer.text,
    bottles: _bottles.text,
    discount: _discount.text,
    tax: _tax.text,
    tip: _tip.text,
    hasReceiptPhoto: _photo != null,
    receiptReadable: _readable,
    noReceipt: _noReceipt,
    noReceiptReason: _reason.text,
  );

  Future<void> _takePhoto({required bool camera}) async {
    final bytes = await ref.read(receiptPhotoPickerProvider)(
      context,
      camera: camera,
    );
    if (bytes == null || !mounted) return;
    final problem = imageProblem(bytes);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _photo = bytes;
      _readable = false;
      _uploaded = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _showProblems = true;
      _error = null;
    });
    final input = _input();
    if (paymentProblems(input, manager: widget.manager).isNotEmpty) return;
    setState(() => _busy = true);
    try {
      String? path;
      String? hash;
      if (!_noReceipt) {
        var up = _uploaded;
        if (up == null) {
          up = await ref
              .read(receiptServiceProvider)
              .upload(widget.bookingId, _photo!);
          _uploaded = up;
        }
        path = up.path;
        hash = up.hash;
      }
      final result = await ref
          .read(tableServiceServiceProvider)
          .recordPayment(
            widget.bookingId,
            input,
            manager: widget.manager,
            receiptPath: path,
            receiptHash: hash,
          );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on ReceiptException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TableServiceActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _money(
    String key,
    TextEditingController c,
    String label,
    Map<String, String> problems, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      key: Key('pay-$key'),
      controller: c,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$ ',
        hintText: hint,
        border: const OutlineInputBorder(),
        errorText: _showProblems ? problems[key] : null,
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problems = paymentProblems(_input(), manager: widget.manager);
    final shown = _showProblems ? problems : const <String, String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Record a payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          Text(widget.tableLabel, style: theme.textTheme.titleMedium),
          if (widget.balanceDueCents > 0)
            Text(
              'Still due on the booking: ${formatDollars(widget.balanceDueCents)}',
              key: const Key('pay-still-due'),
              style: theme.textTheme.bodyMedium,
            ),
          _money('billed', _billed, 'Bill total (from the till)', problems),
          _money('collected', _collected, 'Amount collected now', problems),
          const SizedBox(height: 16),
          Text('How was it paid?', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              for (final m in PayMethod.values)
                ChoiceChip(
                  key: Key('method-${m.value}'),
                  label: Text(m.label),
                  selected: _method == m,
                  onSelected:
                      _busy
                          ? null
                          : (_) => setState(() {
                            _method = m;
                            if (m == PayMethod.split && _split.isEmpty) {
                              _split
                                ..add(_SplitRow(PayMethod.cash))
                                ..add(_SplitRow(PayMethod.debit));
                            }
                          }),
                ),
            ],
          ),
          if (shown['method'] != null)
            Text(
              shown['method']!,
              key: const Key('pay-method-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFEF5350),
              ),
            ),
          if (_method == PayMethod.split) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < _split.length; i++)
              Row(
                key: Key('split-row-$i'),
                children: [
                  DropdownButton<PayMethod>(
                    key: Key('split-method-$i'),
                    value: _split[i].method,
                    items: [
                      for (final m in PayMethod.values)
                        if (m != PayMethod.split)
                          DropdownMenuItem(value: m, child: Text(m.label)),
                    ],
                    onChanged:
                        _busy
                            ? null
                            : (m) => setState(
                              () => _split[i].method = m ?? _split[i].method,
                            ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: Key('split-amount-$i'),
                      controller: _split[i].amount,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        hintText: 'Amount',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_split.length > 2)
                    IconButton(
                      key: Key('split-remove-$i'),
                      tooltip: 'Remove this part',
                      icon: const Icon(Icons.close),
                      onPressed:
                          _busy
                              ? null
                              : () => setState(() {
                                _split.removeAt(i).amount.dispose();
                              }),
                    ),
                ],
              ),
            TextButton.icon(
              key: const Key('split-add'),
              onPressed:
                  _busy
                      ? null
                      : () =>
                          setState(() => _split.add(_SplitRow(PayMethod.cash))),
              icon: const Icon(Icons.add),
              label: const Text('Add a part'),
            ),
            if (shown['split'] != null)
              Text(
                shown['split']!,
                key: const Key('pay-split-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFEF5350),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              key: const Key('pay-pos'),
              controller: _pos,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Receipt number (optional)',
                border: const OutlineInputBorder(),
                errorText: shown['pos'],
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              key: const Key('pay-payer'),
              controller: _payer,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Paid by (optional)',
                border: const OutlineInputBorder(),
                errorText: shown['payer'],
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          ExpansionTile(
            key: const Key('pay-details'),
            title: const Text('Bill details (optional)'),
            tilePadding: EdgeInsets.zero,
            children: [
              _money('bottles', _bottles, 'Bottle subtotal', problems),
              _money('discount', _discount, 'Discount', problems),
              _money('tax', _tax, 'Tax', problems),
              _money('tip', _tip, 'Tip', problems),
            ],
          ),
          const SizedBox(height: 16),
          Text('Receipt', style: theme.textTheme.titleSmall),
          if (_noReceipt) ...[
            TextField(
              key: const Key('receipt-reason'),
              controller: _reason,
              enabled: !_busy,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Why is there no receipt?',
                border: const OutlineInputBorder(),
                errorText: shown['receipt'],
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else if (_photo == null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('receipt-take'),
                  onPressed: _busy ? null : () => _takePhoto(camera: true),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take a photo of the receipt'),
                ),
                if (widget.manager)
                  OutlinedButton.icon(
                    key: const Key('receipt-gallery'),
                    onPressed: _busy ? null : () => _takePhoto(camera: false),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose a photo'),
                  ),
              ],
            ),
            if (shown['receipt'] != null)
              Text(
                shown['receipt']!,
                key: const Key('receipt-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFEF5350),
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _photo!,
                key: const Key('receipt-preview'),
                height: 200,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Center(child: Icon(Icons.image_outlined)),
                    ),
              ),
            ),
            CheckboxListTile(
              key: const Key('receipt-readable'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _readable,
              onChanged:
                  _busy ? null : (v) => setState(() => _readable = v ?? false),
              title: const Text(
                'I can read the total and the date on this photo',
              ),
            ),
            TextButton(
              key: const Key('receipt-retake'),
              onPressed: _busy ? null : () => _takePhoto(camera: true),
              child: const Text('Take it again'),
            ),
            if (shown['receipt'] != null)
              Text(
                shown['receipt']!,
                key: const Key('receipt-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFEF5350),
                ),
              ),
          ],
          if (widget.manager)
            SwitchListTile(
              key: const Key('receipt-none'),
              contentPadding: EdgeInsets.zero,
              value: _noReceipt,
              onChanged: _busy ? null : (v) => setState(() => _noReceipt = v),
              title: const Text('There is no receipt'),
              subtitle: const Text(
                'For cash without a printed receipt. Say why.',
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Recording a payment does not verify it. Someone else has to check it against the till.',
            style: theme.textTheme.bodySmall,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const Key('pay-error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFEF5350),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('pay-submit'),
            onPressed: _busy ? null : _submit,
            child:
                _busy
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Record payment'),
          ),
        ],
      ),
    );
  }
}
