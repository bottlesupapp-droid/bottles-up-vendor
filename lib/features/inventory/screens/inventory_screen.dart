import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../workspace/models/workspace.dart';
import '../logic/inventory_rules.dart';
import '../providers/inventory_providers.dart';
import '../widgets/movement_dialog.dart';
import 'stock_ledger_screen.dart';

/// Inventory (manager, and the owner for any of their clubs): each bottle's level, which ones are low, and a way to record a delivery,
/// wastage, an adjustment or a count. Every change goes in the history with who made it and why. A bottle nobody has counted has no
/// level yet: the first count starts it.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String? _chosenVenue;
  final Set<String> _busy = {};

  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  void _say(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  void _refresh() => ref.invalidate(stockProvider(_venueId ?? ''));

  Future<void> _send(StockItem item, MoveDraft draft) async {
    final venue = _venueId;
    if (venue == null) return;
    setState(() => _busy.add(item.bottleId));
    try {
      final outcome = await ref.read(inventoryServiceProvider).move(
            venue,
            item.bottleId,
            draft.kind,
            draft.quantity,
            reason: draft.reason,
            note: draft.note,
            clientKey: draft.clientKey,
            night: currentNight(widget.clock()),
          );
      _say(moveOutcomeMessage(draft.kind, outcome, name: item.name));
    } on OpsActionException catch (e) {
      // The same draft, with the same key, is sent again: if the first try did arrive, nothing is added twice.
      _say(e.message, action: SnackBarAction(label: 'Try again', onPressed: () => _send(item, draft)));
    } finally {
      if (mounted) setState(() => _busy.remove(item.bottleId));
      _refresh();
    }
  }

  Future<void> _record(StockItem item, StockKind kind) async {
    final draft = await showMovementDialog(context, kind: kind, bottleTitle: item.title, current: item.quantity);
    if (draft == null || !mounted) return;
    await _send(item, draft);
  }

  Future<void> _threshold(StockItem item) async {
    final venue = _venueId;
    if (venue == null) return;
    final text = await showTextDialog(
      context,
      title: 'Low-stock level',
      hint: 'For example 6 (empty clears it)',
      confirmLabel: 'Save',
      message: item.lowThreshold == null ? 'No level set. A bottle at or below its level is shown as low.' : 'It is low at ${item.lowThreshold} or fewer now.',
      validate: (t) => checkThreshold(t).error,
    );
    if (text == null || !mounted) return;
    final checked = checkThreshold(text);
    try {
      await ref.read(inventoryServiceProvider).setThreshold(venue, item.bottleId, checked.level);
      _say(checked.clear ? 'Level cleared.' : 'Low-stock level saved.');
    } on OpsActionException catch (e) {
      _say(e.message);
    }
    _refresh();
  }

  void _history(StockItem? item) {
    final venue = _venueId;
    if (venue == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StockLedgerScreen(venueId: venue, bottleId: item?.bottleId, title: item == null ? 'Stock history' : item.title),
    ));
  }

  Future<void> _open(StockItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.title, style: Theme.of(ctx).textTheme.titleMedium),
            Text(item.tracked ? 'In stock: ${item.quantity}' : 'Not counted yet', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final k in StockKind.values)
              ListTile(key: Key('stock-action-${k.id}'), contentPadding: EdgeInsets.zero, title: Text(k.label), onTap: () => Navigator.of(ctx).pop(k.id)),
            ListTile(key: const Key('stock-action-threshold'), contentPadding: EdgeInsets.zero, title: const Text('Low-stock level'), onTap: () => Navigator.of(ctx).pop('threshold')),
            ListTile(key: const Key('stock-action-history'), contentPadding: EdgeInsets.zero, title: const Text('History'), onTap: () => Navigator.of(ctx).pop('history')),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'threshold':
        await _threshold(item);
      case 'history':
        _history(item);
      default:
        await _record(item, StockKind.values.firstWhere((k) => k.id == action));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = _venueId;
    if (venueId == null) {
      return VenuePicker(workspace: widget.workspace, title: 'Inventory', listKey: const Key('inventory-pick-club'), itemKeyPrefix: 'inventory-club-', onPick: (id) => setState(() => _chosenVenue = id));
    }
    final stock = ref.watch(stockProvider(venueId));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        key: const Key('inventory-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Row(
            children: [
              Expanded(child: Text('Inventory', style: theme.textTheme.headlineSmall)),
              TextButton.icon(key: const Key('stock-history-all'), onPressed: () => _history(null), icon: const Icon(Icons.history, size: 18), label: const Text('History')),
            ],
          ),
          if (widget.workspace.venueName != null && widget.workspace.venueId != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          if (widget.workspace.venueId == null)
            TextButton(key: const Key('inventory-change-club'), onPressed: () => setState(() => _chosenVenue = null), child: const Text('Choose another club')),
          const SizedBox(height: 8),
          OpsAsyncView<List<StockItem>>(
            value: stock,
            what: 'stock',
            isEmpty: (d) => d.isEmpty,
            emptyText: 'No bottles on the menu yet. Add them in the venue setup, then count them here.',
            emptyKey: const Key('inventory-empty'),
            errorKey: const Key('inventory-error'),
            onRetry: _refresh,
            builder: (items) {
              final low = lowStockCount(items);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(low == 0 ? 'Nothing is low.' : '$low ${low == 1 ? 'bottle is' : 'bottles are'} low.', key: const Key('inventory-summary'), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  for (final i in items)
                    Card(
                      key: Key('stock-${i.bottleId}'),
                      child: ListTile(
                        onTap: _busy.contains(i.bottleId) ? null : () => _open(i),
                        title: Text(i.title),
                        subtitle: Text(
                          i.tracked ? 'In stock: ${i.quantity}${i.lowThreshold == null ? '' : ' · low at ${i.lowThreshold}'}' : 'Not counted yet',
                          key: Key('stock-level-${i.bottleId}'),
                        ),
                        trailing: i.isLow
                            ? Chip(key: Key('stock-low-${i.bottleId}'), label: const Text('LOW'), backgroundColor: theme.colorScheme.errorContainer)
                            : (i.isSoldOut ? Chip(key: Key('stock-soldout-${i.bottleId}'), label: const Text('Sold out')) : null),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
