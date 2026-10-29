import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../logic/table_map_rules.dart';
import '../providers/table_map_providers.dart';

/// Hold some free tables for a while, or take them out of use until reopened (club manager or owner). Only tables that are free right now can be blocked: a table somebody
/// has booked is never silently taken away, and the database refuses it with a sentence. What was typed is kept when anything fails. Pops with a message on success.
class BlockTablesSheet extends ConsumerStatefulWidget {
  const BlockTablesSheet({super.key, required this.venueId, required this.night, required this.slotTitle, required this.table});

  final String venueId;

  /// The business night, 'YYYY-MM-DD'.
  final String night;
  final String slotTitle;
  final TableState table;

  @override
  ConsumerState<BlockTablesSheet> createState() => _BlockTablesSheetState();
}

class _BlockTablesSheetState extends ConsumerState<BlockTablesSheet> {
  final _reason = TextEditingController();
  String _kind = 'held';
  int _quantity = 1;
  int _minutes = 60;
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  BlockForm get _form => BlockForm(kind: _kind, quantity: _quantity, reason: _reason.text, minutes: _kind == 'held' ? _minutes : null);

  Future<void> _submit() async {
    if (_busy) return;
    final found = validateBlock(_form, widget.table.available);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final left = await ref.read(tableMapServiceProvider).block(
            venueId: widget.venueId,
            night: widget.night,
            tableTypeId: widget.table.tableTypeId,
            slotId: widget.table.slotId,
            form: _form,
          );
      if (!mounted) return;
      Navigator.of(context).pop(blockedMessage(_form, widget.table.tableName, left));
    } on OpsActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _problems = [e.message];
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.table;
    final max = t.available < 1 ? 1 : t.available;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('block-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.tableName, style: theme.textTheme.titleLarge),
            Text('${widget.slotTitle} · ${countsLine(t)}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              key: const Key('block-kind'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'held', label: Text('Hold for a while')),
                ButtonSegment(value: 'unavailable', label: Text('Out of use')),
              ],
              selected: {_kind},
              onSelectionChanged: _busy ? null : (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _kind == 'held'
                  ? 'Nobody can book these tables until the hold runs out or you reopen them.'
                  : 'These tables stay out of sale until you reopen them.',
              key: const Key('block-kind-note'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('How many tables')),
                IconButton(key: const Key('block-less'), onPressed: _busy || _quantity <= 1 ? null : () => setState(() => _quantity--), icon: const Icon(Icons.remove_circle_outline)),
                SizedBox(width: 32, child: Text('$_quantity', key: const Key('block-quantity'), textAlign: TextAlign.center)),
                IconButton(key: const Key('block-more'), onPressed: _busy || _quantity >= max ? null : () => setState(() => _quantity++), icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            if (_kind == 'held') ...[
              Text('For how long', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in holdMinutesChoices)
                    ChoiceChip(key: Key('hold-$m'), label: Text(holdLabel(m)), selected: _minutes == m, onSelected: _busy ? null : (_) => setState(() => _minutes = m)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('block-reason'),
              controller: _reason,
              enabled: !_busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Reason', helperText: 'Kept with who did it and when.', border: OutlineInputBorder(), counterText: ''),
            ),
            if (_problems.isNotEmpty) ...[const SizedBox(height: 8), ProblemsBox(problems: _problems)],
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('block-confirm'),
              onPressed: _busy || t.available < 1 ? null : _submit,
              child: Text(_busy ? 'Saving...' : (_kind == 'held' ? 'Hold ${_quantity == 1 ? 'the table' : '$_quantity tables'}' : 'Take ${_quantity == 1 ? 'the table' : '$_quantity tables'} out of use')),
            ),
            if (t.available < 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No table of this kind is free for that time. Tables that are booked or already held cannot be blocked.', key: const Key('block-none-free'), style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
