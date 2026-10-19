import 'package:flutter/material.dart';

import '../logic/server_desk_rules.dart';
import 'desk_chip.dart';

/// One service request: what is wanted, for which table, how long it has waited, who has it, and the buttons that make sense next.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.now,
    required this.actions,
    required this.busy,
    required this.onAction,
  });

  final ServiceRequestRow request;

  /// The clock, so the waiting time is not read inside the widget.
  final DateTime now;
  final List<RequestAction> actions;

  /// A move on this request is on its way: the buttons wait, so a second tap cannot send it twice.
  final bool busy;
  final ValueChanged<RequestAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    final open = r.status.isOpen;
    final closedAt = r.closedAt;
    return Card(
      key: Key('request-${r.requestId}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r.kind.label, style: theme.textTheme.titleMedium)),
                DeskChip(key: Key('status-${r.requestId}'), text: r.status.label, color: requestStatusColor(r.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [r.tableName, if (r.customerName.isNotEmpty) r.customerName, if (r.confirmationCode != null) r.confirmationCode!].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
            if (r.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('“${r.note}”', key: Key('note-${r.requestId}'), style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 4),
            Text(
              open
                  ? 'Waiting ${waitingLabel(r.createdAt, now)} · ${holderLabel(r)}'
                  : (closedAt == null ? r.status.label : '${r.status.label} ${waitingLabel(closedAt, now)} ago'),
              key: Key('when-${r.requestId}'),
              style: theme.textTheme.bodySmall,
            ),
            if (r.statusNote != null)
              Text('Reason: ${r.statusNote}', key: Key('reason-${r.requestId}'), style: theme.textTheme.bodySmall),
            if (r.status == RequestStatus.escalated && actions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Passed to a manager.', key: Key('passed-${r.requestId}'), style: theme.textTheme.bodySmall),
              ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < actions.length; i++)
                      if (i == 0)
                        FilledButton(
                          key: Key('act-${r.requestId}-${actions[i].value}'),
                          onPressed: busy ? null : () => onAction(actions[i]),
                          child: Text(actions[i].label),
                        )
                      else
                        OutlinedButton(
                          key: Key('act-${r.requestId}-${actions[i].value}'),
                          onPressed: busy ? null : () => onAction(actions[i]),
                          child: Text(actions[i].label),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
