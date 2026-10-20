import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../logic/table_map_rules.dart';
import '../providers/table_map_providers.dart';

/// Move a confirmed booking to another table of the same club for the same arrival time (club manager or owner). The list shows every table with whether the party fits and
/// how many are free; only a table that is really free can be chosen, and the database re-checks all of it while it holds the tables. The guest, the status and the amounts
/// they agreed to do not change; who moved it, from where, to where and why is kept on the booking. Pops with the [MoveResult] on success.
class MoveBookingSheet extends ConsumerStatefulWidget {
  const MoveBookingSheet({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<MoveBookingSheet> createState() => _MoveBookingSheetState();
}

class _MoveBookingSheetState extends ConsumerState<MoveBookingSheet> {
  final _reason = TextEditingController();
  String? _to;
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final found = validateMove(toTableTypeId: _to, reason: _reason.text);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(tableMapServiceProvider).move(widget.bookingId, _to!, _reason.text);
      if (!mounted) return;
      Navigator.of(context).pop(r);
    } on OpsActionException catch (e) {
      if (!mounted) return;
      // Whatever went wrong, what is free now may be different: read it again, and keep what was typed.
      ref.invalidate(moveOptionsProvider(widget.bookingId));
      setState(() {
        _problems = [e.message];
        _busy = false;
        _to = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = ref.watch(moveOptionsProvider(widget.bookingId));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('move-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move to another table', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Same arrival time. The guest and what they agreed to pay stay as they are; who moved the booking and why is recorded.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            options.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (error, _) {
                final e = opsLoadFailureFor(error, 'the tables');
                return Column(
                  children: [
                    Text(e.message, key: const Key('move-error'), textAlign: TextAlign.center),
                    if (!e.unavailable && !e.accessEnded)
                      Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton(key: const Key('move-retry'), onPressed: () => ref.invalidate(moveOptionsProvider(widget.bookingId)), child: const Text('Try again'))),
                  ],
                );
              },
              data: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final o in list)
                    Card(
                      key: Key('move-option-${o.tableTypeId}'),
                      color: o.tableTypeId == _to ? theme.colorScheme.primary.withValues(alpha: 0.12) : null,
                      child: ListTile(
                        enabled: o.canChoose && !_busy,
                        selected: o.tableTypeId == _to,
                        title: Text(o.name),
                        subtitle: Text(
                          o.canChoose
                              ? [
                                  '${o.available} free',
                                  'up to ${o.maxGuests} guests',
                                  if (priceDifferenceLine(o.priceDifferenceCents) != null) priceDifferenceLine(o.priceDifferenceCents)!,
                                ].join(' · ')
                              : o.whyNot!,
                        ),
                        trailing: o.tableTypeId == _to ? const Icon(Icons.check_circle) : null,
                        onTap: o.canChoose && !_busy ? () => setState(() {
                              _to = o.tableTypeId;
                              _problems = const [];
                            }) : null,
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('move-reason'),
                    controller: _reason,
                    enabled: !_busy,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Why is it being moved?', border: OutlineInputBorder(), counterText: ''),
                  ),
                  if (_problems.isNotEmpty) ...[const SizedBox(height: 8), ProblemsBox(problems: _problems)],
                  const SizedBox(height: 12),
                  FilledButton(key: const Key('move-confirm'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Moving...' : 'Move the booking')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
