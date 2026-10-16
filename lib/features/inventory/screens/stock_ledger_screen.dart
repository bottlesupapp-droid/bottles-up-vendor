import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../logic/inventory_rules.dart';
import '../providers/inventory_providers.dart';

/// The record of how stock was changed by hand, newest first: who, when, why, and the level before and after. When one movement starts
/// from a different level than the previous one of the same bottle ended on, the difference is shown as what was taken outside the list
/// (bottles ordered). Entries are never edited or removed.
class StockLedgerScreen extends ConsumerStatefulWidget {
  const StockLedgerScreen({super.key, required this.venueId, this.bottleId, this.title = 'Stock history'});

  final String venueId;

  /// Empty or null: the whole club.
  final String? bottleId;
  final String title;

  @override
  ConsumerState<StockLedgerScreen> createState() => _StockLedgerScreenState();
}

class _StockLedgerScreenState extends ConsumerState<StockLedgerScreen> {
  final List<StockMovement> _older = [];
  bool _more = true;
  bool _loadingMore = false;

  ({String venueId, String bottleId}) get _query => (venueId: widget.venueId, bottleId: widget.bottleId ?? '');

  Future<void> _loadMore(List<StockMovement> first) async {
    final last = _older.isNotEmpty ? _older.last : first.last;
    if (last.createdAt == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(inventoryServiceProvider).movements(widget.venueId, bottleId: widget.bottleId, before: last.createdAt);
      if (!mounted) return;
      setState(() {
        _older.addAll(page);
        _more = page.length >= 50;
      });
    } on OpsLoadException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movements = ref.watch(movementsProvider(_query));
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          key: const Key('ledger-list'),
          padding: const EdgeInsets.all(16),
          children: [
            OpsAsyncView<List<StockMovement>>(
              value: movements,
              what: 'the stock history',
              isEmpty: (d) => d.isEmpty,
              emptyText: 'Nothing has been recorded yet.',
              emptyKey: const Key('ledger-empty'),
              errorKey: const Key('ledger-error'),
              onRetry: () => ref.invalidate(movementsProvider(_query)),
              builder: (first) {
                final all = [...first, ..._older];
                return Column(
                  children: [
                    for (final (i, m) in all.indexed) ...[
                      Card(
                        key: Key('movement-${m.id}'),
                        child: ListTile(
                          title: Text(widget.bottleId == null || widget.bottleId!.isEmpty ? '${m.title}: ${m.sentence}' : m.sentence),
                          subtitle: Text('${m.byMe ? 'You' : m.byName} · ${stockTime(m.createdAt)}${m.note == null ? '' : '\n${m.note}'}'),
                          isThreeLine: m.note != null,
                        ),
                      ),
                      if (i + 1 < all.length && gapBetween(m, all[i + 1]) != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Text(gapSentence(gapBetween(m, all[i + 1])!), key: Key('gap-${m.id}'), style: theme.textTheme.bodySmall),
                        ),
                    ],
                    if (first.length >= 50 && _more)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _loadingMore
                            ? const CircularProgressIndicator()
                            : OutlinedButton(key: const Key('ledger-more'), onPressed: () => _loadMore(first), child: const Text('Load earlier')),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
