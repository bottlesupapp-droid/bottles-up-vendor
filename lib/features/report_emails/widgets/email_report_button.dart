import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/report_email_rules.dart';
import '../providers/report_email_providers.dart';
import 'recipients_editor.dart';

/// "E-mail this report": opens a sheet with the list this report goes to (and a way to change it), sends the PDF the screen makes, and shows what happened to each address. The
/// PDF is made here, on the phone, from what the screen shows; the server only sends it to the people on the list.
class EmailReportButton extends StatelessWidget {
  const EmailReportButton({super.key, required this.target, required this.buildPdf, this.keyPrefix = 'email-report'});

  final ReportTarget target;
  final Future<Uint8List> Function() buildPdf;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: Key(keyPrefix),
      icon: const Icon(Ionicons.mail_outline, size: 18),
      label: const Text('E-mail this report'),
      onPressed:
          () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => EmailReportSheet(target: target, buildPdf: buildPdf, keyPrefix: keyPrefix),
          ),
    );
  }
}

class EmailReportSheet extends ConsumerStatefulWidget {
  const EmailReportSheet({super.key, required this.target, required this.buildPdf, required this.keyPrefix});

  final ReportTarget target;
  final Future<Uint8List> Function() buildPdf;
  final String keyPrefix;

  @override
  ConsumerState<EmailReportSheet> createState() => _EmailReportSheetState();
}

class _EmailReportSheetState extends ConsumerState<EmailReportSheet> {
  bool _sending = false;
  String? _result;
  bool _resultIsError = false;

  Future<void> _send({required bool again}) async {
    setState(() {
      _sending = true;
      _result = null;
    });
    try {
      final bytes = await widget.buildPdf();
      final out = await ref.read(reportEmailServiceProvider).send(widget.target, bytes, again: again);
      _result = sendResultMessage(out);
      _resultIsError = out.sent == 0;
    } on OpsActionException catch (e) {
      _result = e.message;
      _resultIsError = true;
    } catch (_) {
      _result = 'The PDF could not be made. Try again.';
      _resultIsError = true;
    } finally {
      ref.invalidate(reportDeliveriesProvider(widget.target));
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = widget.keyPrefix;
    final recipients = ref.watch(reportRecipientsProvider(widget.target.list));
    final log = ref.watch(reportDeliveriesProvider(widget.target));
    final people = recipients.valueOrNull ?? const <ReportRecipient>[];
    final deliveries = log.valueOrNull ?? const <ReportDelivery>[];
    final failed = failedAddresses(deliveries);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('E-mail this report', key: Key('$k-title'), style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(widget.target.fileName, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('It goes to', style: theme.textTheme.titleSmall),
            Text(listExplainer(widget.target.kind), key: Key('$k-explainer'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            RecipientsEditor(scope: widget.target.list, keyPrefix: '$k-list'),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: Key('$k-send'),
              icon: const Icon(Ionicons.send_outline, size: 18),
              label: Text(_sending ? 'Sending…' : (people.isEmpty ? 'E-mail this report' : 'E-mail to ${people.length == 1 ? '1 person' : '${people.length} people'}')),
              onPressed: _sending || people.isEmpty ? null : () => _send(again: false),
            ),
            if (failed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(key: Key('$k-again'), onPressed: _sending ? null : () => _send(again: true), child: Text('Send again to the ${failed.length} that failed')),
              ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_result!, key: Key('$k-result'), style: theme.textTheme.bodyMedium?.copyWith(color: _resultIsError ? theme.colorScheme.error : null)),
              ),
            if (deliveries.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Already e-mailed', style: theme.textTheme.titleSmall),
              for (final (i, d) in deliveries.indexed)
                Padding(
                  key: Key('$k-log-$i'),
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(deliveryLine(d), style: theme.textTheme.bodySmall?.copyWith(color: d.status == DeliveryStatus.failed ? theme.colorScheme.error : null)),
                ),
            ],
            const SizedBox(height: 8),
            Text(reportEmailNote, key: Key('$k-note'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
