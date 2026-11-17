import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../logic/report_email_rules.dart';
import '../providers/report_email_providers.dart';

/// "Send automatically when the night is closed" for one list (website 20261126100000_auto_report_jobs.sql). Off until someone who may e-mail this report switches it on. The report is then sent AS the
/// person who switched it on, by the same checks as the button, so it stops (and says so here) if they lose access. The database decides who may switch it; a refusal is shown as its sentence.
class AutoSendSwitch extends ConsumerStatefulWidget {
  const AutoSendSwitch({super.key, required this.scope, required this.keyPrefix});

  final ReportListScope scope;

  /// Keys of the parts, so a screen with several lists can tell them apart.
  final String keyPrefix;

  @override
  ConsumerState<AutoSendSwitch> createState() => _AutoSendSwitchState();
}

class _AutoSendSwitchState extends ConsumerState<AutoSendSwitch> {
  bool _busy = false;
  String? _message;

  Future<bool> _confirm(ReportAutoStatus s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(autoSwitchTitle(widget.scope.kind)),
            content: Text(autoConfirmMessage(widget.scope.kind, s.recipients), key: const Key('auto-confirm-message')),
            actions: [
              TextButton(key: const Key('auto-confirm-back'), onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back')),
              FilledButton(key: const Key('auto-confirm-yes'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Switch on')),
            ],
          ),
    );
    return yes == true;
  }

  /// Switches on (after saying what it will do) or off (at once). Either way the status is read again, so the screen shows what the database says now.
  Future<void> _set(ReportAutoStatus s, bool enabled) async {
    if (_busy) return;
    if (enabled && !await _confirm(s)) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(reportEmailServiceProvider).setAuto(widget.scope, enabled);
    } on OpsActionException catch (e) {
      _message = e.message;
    } finally {
      ref.invalidate(reportAutoStatusProvider(widget.scope));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = widget.keyPrefix;
    final status = ref.watch(reportAutoStatusProvider(widget.scope));
    return OpsAsyncView<ReportAutoStatus>(
      value: status,
      what: 'the automatic sending settings',
      keepWhileReloading: true,
      errorKey: Key('$k-auto-error'),
      onRetry: () => ref.invalidate(reportAutoStatusProvider(widget.scope)),
      builder: (s) {
        final last = autoLastLine(s, widget.scope.kind);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            SwitchListTile(
              key: Key('$k-auto-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(autoSwitchTitle(widget.scope.kind)),
              subtitle: Text(autoStateLine(s), key: Key('$k-auto-state')),
              value: s.enabled,
              onChanged: _busy ? null : (v) => _set(s, v),
            ),
            if (s.enabled && !s.mine)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(key: Key('$k-auto-takeover'), onPressed: _busy ? null : () => _set(s, true), child: const Text('Send as me instead')),
              ),
            if (s.enabled && s.recipients == 0) Text(autoNoRecipientsText, key: Key('$k-auto-no-recipients'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            if (last != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  last,
                  key: Key('$k-auto-last'),
                  style: theme.textTheme.bodySmall?.copyWith(color: s.lastStatus == 'failed' ? theme.colorScheme.error : null),
                ),
              ),
            if (_message != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_message!, key: Key('$k-auto-message'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))),
          ],
        );
      },
    );
  }
}
