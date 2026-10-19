import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../logic/bottle_orders_rules.dart';
import '../providers/table_service_providers.dart';
import '../services/table_service_service.dart';

/// What the screen hands back when bottles were added.
class AddedBottles {
  const AddedBottles(this.count, this.subtotalCents);

  final int count;
  final int subtotalCents;
}

/// Add bottles to a table (manager, owner, or the table's server). The menu is what the club offers right now with how many are left where the club counts;
/// the chosen bottles are added in ONE call to the website, which prices them, checks stock, works out the table's new total and tells the guest. Added bottles are
/// always paid for at the club (a person is here and takes the money), so they are due, not paid; payment is recorded on the table's page as usual.
///
/// While the call is on its way the button waits. A refusal says why in the database's own words and keeps the basket (and reads the menu again when stock moved).
/// A call that never got an answer may have gone through: the screen says so, and offers to look at the table's orders first, so nothing is added twice.
class AddBottlesScreen extends ConsumerStatefulWidget {
  const AddBottlesScreen({super.key, required this.bookingId, required this.tableLabel});

  final String bookingId;
  final String tableLabel;

  @override
  ConsumerState<AddBottlesScreen> createState() => _AddBottlesScreenState();
}

class _AddBottlesScreenState extends ConsumerState<AddBottlesScreen> {
  Basket _basket = {};
  bool _busy = false;
  bool _unsure = false;
  String? _problem;

  Future<void> _add(List<MenuBottle> menu) async {
    if (_busy || _unsure) return;
    final basket = pruneBasket(menu, _basket);
    final problem = basketProblem(menu, basket);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await ref.read(tableServiceServiceProvider).addBottles(widget.bookingId, menu, basket);
      if (!mounted) return;
      Navigator.of(context).pop(AddedBottles(basketCount(basket), basketSubtotalCents(menu, basket)));
    } on TableServiceActionException catch (e) {
      if (!mounted) return;
      final stale = refusalMeansStaleMenu(e.message);
      if (stale) ref.invalidate(bottleMenuProvider(widget.bookingId));
      setState(() {
        _problem = e.message;
        _busy = false;
        // No answer at all, or the server failed part way: the bottles may be on the table already.
        _unsure = e.outcomeUnknown;
      });
    }
  }

  Widget _row(MenuBottle m, int n, ThemeData theme) {
    final sub = [
      if (m.category != null) m.category!,
      formatDollars(m.priceCents),
      if (m.leftCount != null) (m.soldOutByCount ? 'none left' : '${m.leftCount} left'),
    ].join(' · ');
    return Card(
      key: Key('bottle-${m.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(m.title, style: theme.textTheme.titleMedium), Text(sub, style: theme.textTheme.bodySmall)],
              ),
            ),
            IconButton(
              key: Key('bottle-less-${m.id}'),
              onPressed: _busy || _unsure || n < 1 ? null : () => setState(() => _basket = withQuantity(_menuCache, pruneBasket(_menuCache, _basket), m.id, n - 1)),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(width: 28, child: Text('$n', key: Key('bottle-qty-${m.id}'), textAlign: TextAlign.center)),
            IconButton(
              key: Key('bottle-more-${m.id}'),
              onPressed: _busy || _unsure || n >= m.most ? null : () => setState(() => _basket = withQuantity(_menuCache, pruneBasket(_menuCache, _basket), m.id, n + 1)),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  List<MenuBottle> _menuCache = const [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final menu = ref.watch(bottleMenuProvider(widget.bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Add bottles')),
      body: SafeArea(
        child: menu.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            if (error is TableServiceActionException) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error.message, key: const Key('menu-refused'), textAlign: TextAlign.center)));
            }
            final e = loadFailureFor(error, 'bottles');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.message, key: const Key('menu-error'), textAlign: TextAlign.center),
                    if (!e.unavailable && !e.accessEnded)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton(key: const Key('menu-retry'), onPressed: () => ref.invalidate(bottleMenuProvider(widget.bookingId)), child: const Text('Try again')),
                      ),
                  ],
                ),
              ),
            );
          },
          data: (list) {
            _menuCache = list;
            final basket = pruneBasket(list, _basket);
            final count = basketCount(basket);
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('This club has no bottles on sale right now. Bottles are set up in the venue setup.', key: const Key('menu-empty'), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                ),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const Key('menu-list'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      Text(widget.tableLabel, style: theme.textTheme.titleMedium),
                      Text('Bottles are paid for at the club. The table\'s total goes up when you add them.', style: theme.textTheme.bodySmall),
                      for (final m in list) _row(m, basket[m.id] ?? 0, theme),
                    ],
                  ),
                ),
                Material(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_problem != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: ProblemsBox(problems: [_problem!])),
                        Text(
                          count == 0 ? 'Nothing chosen yet' : '$count ${count == 1 ? 'bottle' : 'bottles'} · ${formatDollars(basketSubtotalCents(list, basket))} before tax',
                          key: const Key('basket-summary'),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (_unsure) ...[
                          FilledButton(key: const Key('check-orders'), onPressed: () => Navigator.of(context).pop(), child: const Text('Look at the table\'s orders')),
                          TextButton(key: const Key('try-anyway'), onPressed: () => setState(() => _unsure = false), child: const Text('They are not there: try again')),
                        ] else
                          FilledButton(
                            key: const Key('add-confirm'),
                            onPressed: _busy || count == 0 ? null : () => _add(list),
                            child: Text(_busy ? 'Adding...' : 'Add to the table'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
