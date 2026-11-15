import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../logic/stock_overview_rules.dart';
import '../providers/inventory_providers.dart';

/// Stock overview (brief section 22): Available / Reserved / Low stock, and the most-sold bottles of a chosen period. Read only: it shows what the database counts and changes
/// nothing. Reserving and issuing by hand, and packages that reserve their parts, are shown as "Coming soon" and say what they will do.
class StockOverviewScreen extends ConsumerStatefulWidget {
  const StockOverviewScreen({super.key, required this.venueId, this.venueName});

  final String venueId;
  final String? venueName;

  @override
  ConsumerState<StockOverviewScreen> createState() => _StockOverviewScreenState();
}

class _StockOverviewScreenState extends ConsumerState<StockOverviewScreen> {
  OverviewTab _tab = OverviewTab.available;
  SoldPeriod _period = SoldPeriod.month;

  ({String venueId, int days}) get _query => (venueId: widget.venueId, days: _period.days);

  Widget _pills(StockOverviewItem i) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (i.isLow) BuStatusPill('LOW', key: Key('overview-low-${i.bottleId}'), tone: BuTone.attention),
        if (i.isSoldOut) BuStatusPill('Sold out', key: Key('overview-soldout-${i.bottleId}')),
      ],
    );
  }

  Widget _soon(String key, String label, String text) {
    return ActionChip(
      key: Key(key),
      label: Row(mainAxisSize: MainAxisSize.min, children: [Text(label), const SizedBox(width: 6), const BuComingSoonPill()]),
      onPressed: () => showComingSoon(context, title: label, text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overview = ref.watch(stockOverviewProvider(_query));
    return Scaffold(
      appBar: const BuDetailAppBar(eyebrow: 'Stock', title: 'Stock overview'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(stockOverviewProvider(_query)),
          child: ListView(
            key: const Key('overview-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.m, BuSpace.page, BuSpace.xl),
            children: [
              if (widget.venueName != null) Text(widget.venueName!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: BuSpace.s),
              OpsAsyncView<List<StockOverviewItem>>(
                value: overview,
                what: 'the stock figures',
                isEmpty: (d) => d.isEmpty,
                emptyText: 'No bottles on the menu yet. Add them in the venue setup, then count them in Inventory.',
                emptyKey: const Key('overview-empty'),
                errorKey: const Key('overview-error'),
                onRetry: () => ref.invalidate(stockOverviewProvider(_query)),
                builder: (items) {
                  final shown = itemsFor(_tab, items);
                  final top = mostSold(items);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(overviewSummary(items), key: const Key('overview-summary'), style: theme.textTheme.bodyMedium),
                      const SizedBox(height: BuSpace.m),
                      BuPillTabs(
                        labels: [for (final t in OverviewTab.values) t.label],
                        selected: _tab.label,
                        tabKeyPrefix: 'overview-tab',
                        onSelected: (l) => setState(() => _tab = OverviewTab.byLabel(l)),
                      ),
                      const SizedBox(height: BuSpace.m),
                      if (shown.isEmpty)
                        BuCard(child: Text(overviewEmpty(_tab), key: const Key('overview-tab-empty')))
                      else
                        BuListCard(
                          children: [
                            for (final i in shown)
                              BuListRow(
                                key: Key('overview-row-${i.bottleId}'),
                                title: i.title,
                                subtitle: overviewLine(_tab, i),
                                maxSubtitleLines: 3,
                                showChevron: false,
                                trailing: i.isLow || i.isSoldOut ? _pills(i) : null,
                              ),
                          ],
                        ),
                      const SizedBox(height: BuSpace.xl),
                      const BuSectionHeader(title: 'Most sold'),
                      const SizedBox(height: BuSpace.s),
                      BuPillTabs(
                        labels: [for (final p in SoldPeriod.values) p.label],
                        selected: _period.label,
                        tabKeyPrefix: 'overview-period',
                        onSelected: (l) => setState(() => _period = SoldPeriod.byLabel(l)),
                      ),
                      const SizedBox(height: BuSpace.m),
                      if (top.isEmpty)
                        BuCard(child: Text('Nothing was sold in the last ${_period.label}.', key: const Key('overview-sold-empty')))
                      else
                        BuListCard(children: [for (final i in top) BuListRow(key: Key('overview-sold-${i.bottleId}'), title: i.title, subtitle: soldLine(i, _period), showChevron: false)]),
                    ],
                  );
                },
              ),
              const SizedBox(height: BuSpace.xl),
              const BuSectionHeader(title: 'Stock actions'),
              const SizedBox(height: BuSpace.s),
              Text(
                'Receiving, adjusting and counting stock are in Inventory. Reserving and issuing happen from table orders for now: a bottle is reserved when a table is sold, and handed over on the table\'s order.',
                key: const Key('overview-actions-note'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: BuSpace.m),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _soon('overview-soon-reserve', 'Reserve', 'Set bottles aside by hand, for a table, a promoter or an event. Until then, bottles are reserved when a table is sold.'),
                  _soon(
                    'overview-soon-issue',
                    'Issue',
                    'Record bottles handed out by hand and take them off the shelf count. Until then, handing a bottle over is recorded on the table\'s order and does not change the count.',
                  ),
                  _soon('overview-soon-packages', 'Package components', 'Packages that reserve and issue their parts together (for example a bottle, mixers and glasses).'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
