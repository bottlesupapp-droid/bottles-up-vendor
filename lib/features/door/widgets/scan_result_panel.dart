import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../logic/door_rules.dart';

/// The answer to a scan. Only "Admit" is green: unpaid, wrong event, expired and unknown tickets are red stops, and
/// already used or code required are amber "one more step", each with the next step in words. A wrong-event answer
/// carries no guest details (the database does not return any), so none can be shown.
class ScanResultPanel extends StatefulWidget {
  const ScanResultPanel({
    super.key,
    required this.outcome,
    required this.onVerify,
    required this.onNext,
    this.verifying = false,
    this.nextLabel = 'Scan next',
  });

  final ScanOutcome outcome;

  /// Called with the code the guest read out. The parent runs the check and replaces [outcome].
  final ValueChanged<String> onVerify;
  final VoidCallback onNext;

  /// A code check is running: the button is disabled so it cannot be sent twice.
  final bool verifying;
  final String nextLabel;

  @override
  State<ScanResultPanel> createState() => _ScanResultPanelState();
}

class _ScanResultPanelState extends State<ScanResultPanel> {
  final _code = TextEditingController();

  @override
  void didUpdateWidget(ScanResultPanel old) {
    super.didUpdateWidget(old);
    // A new answer starts with an empty code box; a wrong code is not left in it to be sent again by accident.
    if (!identical(old.outcome, widget.outcome)) _code.clear();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Color _tone(Tone tone) => switch (tone) {
        Tone.ok => const Color(0xFF2E7D32),
        Tone.warn => const Color(0xFFF9A825),
        Tone.error => const Color(0xFFC62828),
      };

  IconData _icon(Tone tone) => switch (tone) {
        Tone.ok => Ionicons.checkmark_circle,
        Tone.warn => Ionicons.warning,
        Tone.error => Ionicons.close_circle,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = widget.outcome;
    final copy = resultCopy[o.result]!;
    final color = _tone(copy.tone);
    final hasDetails = o.customerName != null || o.tierName != null || o.eventTitle != null;

    return Container(
      key: const Key('scan-result'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(copy.tone), color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(child: Text(copy.label, key: const Key('scan-result-label'), style: theme.textTheme.headlineSmall)),
            ],
          ),
          const SizedBox(height: 8),
          Text(copy.hint, style: theme.textTheme.bodyLarge),
          if (hasDetails) ...[
            const SizedBox(height: 12),
            if (o.customerName != null) Text(o.customerName!, key: const Key('scan-result-name'), style: theme.textTheme.titleMedium),
            if (o.tierName != null || o.quantity != null)
              Text(
                [if (o.tierName != null) o.tierName!, if (o.quantity != null) '× ${o.quantity}'].join(' '),
                key: const Key('scan-result-ticket'),
              ),
            if (o.eventTitle != null) Text(o.eventTitle!, style: theme.textTheme.bodySmall),
          ],
          if (canRetryCode(o.result)) ...[
            const SizedBox(height: 14),
            TextField(
              key: const Key('entry-code-field'),
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 12,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Entry code', counterText: '', border: OutlineInputBorder()),
              onSubmitted: (v) => _submit(),
            ),
            if (o.attemptsRemaining != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${o.attemptsRemaining} ${o.attemptsRemaining == 1 ? 'try' : 'tries'} left',
                  key: const Key('attempts-left'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('verify-code'),
              onPressed: widget.verifying ? null : _submit,
              child: Text(widget.verifying ? 'Checking…' : 'Check code'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(key: const Key('scan-next'), onPressed: widget.verifying ? null : widget.onNext, child: Text(widget.nextLabel)),
        ],
      ),
    );
  }

  void _submit() {
    final code = _code.text.trim();
    if (code.isEmpty || widget.verifying) return;
    widget.onVerify(code);
  }
}
