import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_coming_soon.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../core/utils/plain_error.dart';
import '../providers/inventory_provider.dart';

/// The filters over the stock list.
const stockFilters = ['All', 'Low', 'Out'];

/// How many is "low": a bottle with this many or fewer (but not none) is running out.
const lowStockAt = 5;

/// Inventory, as the design draws it: three figures (items, low, out), the filters as pill tabs and one card per bottle with how many are left. Adding, editing and
/// removing a bottle are not built for this kind of account yet: each says "Coming soon".
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _filter = stockFilters.first;

  int _quantity(Map<String, dynamic> b) => (b['quantity'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final bu = context.bu;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: BuDetailAppBar(
        eyebrow: 'Operations',
        title: 'Inventory',
        actions: [
          IconButton(
            key: const Key('inventory-add'),
            tooltip: 'Add a bottle, coming soon',
            icon: const Icon(Ionicons.add),
            onPressed: () => showComingSoon(context, title: 'Add a bottle', text: 'Add a bottle to your stock with its price, size and how many you have.'),
          ),
        ],
      ),
      body: inventoryAsync.when(
        data: (inventory) {
          if (inventory.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BuIconTile(icon: Ionicons.wine_outline, size: 56),
                    const SizedBox(height: BuSpace.l),
                    Text('No inventory found', style: text.titleLarge),
                    const SizedBox(height: BuSpace.s),
                    Text('Add bottles to your inventory', style: text.bodyMedium?.copyWith(color: bu.muted)),
                  ],
                ),
              ),
            );
          }

          final low = inventory.where((b) => _quantity(b) > 0 && _quantity(b) <= lowStockAt).length;
          final out = inventory.where((b) => _quantity(b) == 0).length;
          final shown = switch (_filter) {
            'Low' => inventory.where((b) => _quantity(b) > 0 && _quantity(b) <= lowStockAt).toList(),
            'Out' => inventory.where((b) => _quantity(b) == 0).toList(),
            _ => inventory,
          };

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(inventoryProvider),
            child: ListView(
              key: const Key('inventory-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
              children: [
                Row(
                  children: [
                    Expanded(child: _Figure(label: 'Items', value: '${inventory.length}', figureKey: const Key('inventory-items'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'Running low', value: '$low', color: low > 0 ? bu.amber : null, figureKey: const Key('inventory-low'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'Out', value: '$out', color: out > 0 ? bu.red : null, figureKey: const Key('inventory-out'))),
                  ],
                ),
                const SizedBox(height: BuSpace.l),
                BuPillTabs(labels: stockFilters, selected: _filter, tabKeyPrefix: 'stock-filter', onSelected: (f) => setState(() => _filter = f)),
                const SizedBox(height: BuSpace.m),
                if (shown.isEmpty)
                  BuCard(key: const Key('inventory-none'), child: Text(_filter == 'Low' ? 'Nothing is running low.' : 'Nothing is out of stock.', style: text.bodyMedium?.copyWith(color: bu.muted)))
                else
                  for (final b in shown) _BottleCard(bottle: b),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Ionicons.alert_circle, size: 56, color: bu.red),
                    const SizedBox(height: BuSpace.l),
                    Text(couldNotLoad('inventory', error), textAlign: TextAlign.center),
                    const SizedBox(height: BuSpace.l),
                    FilledButton(onPressed: () => ref.invalidate(inventoryProvider), child: const Text('Retry')),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.figureKey, this.color});

  final String label;
  final String value;
  final Key figureKey;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.m, vertical: BuSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, key: figureKey, style: text.headlineSmall?.copyWith(color: color ?? bu.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BottleCard extends StatelessWidget {
  final Map<String, dynamic> bottle;

  const _BottleCard({required this.bottle});

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final price = bottle['price'] as num? ?? 0;
    final quantity = (bottle['quantity'] as num?)?.toInt() ?? 0;
    final volume = (bottle['volume'] as num?)?.toInt() ?? 750;
    final isFeatured = bottle['featured'] == true;
    final imageUrl = bottle['imageUrl'] as String?;
    final (stockLabel, tone) =
        quantity == 0
            ? ('Out of stock', BuTone.bad)
            : quantity <= lowStockAt
            ? ('$quantity left', BuTone.attention)
            : ('$quantity in stock', BuTone.good);

    Widget fact(String label, String value) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: text.bodySmall?.copyWith(color: bu.muted)), const SizedBox(height: 2), Text(value, style: text.titleSmall)]);

    return Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.m),
      child: BuCard(
        key: Key('bottle-${bottle['id'] ?? bottle['name']}'),
        padding: const EdgeInsets.all(BuSpace.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 104,
              decoration: BoxDecoration(
                color: bu.panel2,
                borderRadius: BorderRadius.circular(BuRadius.control),
                image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover, onError: (exception, stackTrace) {}) : null,
              ),
              child: imageUrl == null ? Icon(Ionicons.wine_outline, size: 30, color: bu.orangeSoft) : null,
            ),
            const SizedBox(width: BuSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Expanded(child: BuEyebrow('${bottle['brand'] ?? 'Unknown Brand'}')), if (isFeatured) const BuStatusPill('Featured', tone: BuTone.attention)]),
                  const SizedBox(height: 4),
                  Text('${bottle['name'] ?? 'Unknown Bottle'}', style: text.titleMedium),
                  if (bottle['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text('${bottle['description']}', style: text.bodySmall?.copyWith(color: bu.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: BuSpace.m),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [fact('Price', '\$${price.toStringAsFixed(0)}'), const SizedBox(width: BuSpace.xl), fact('Volume', '${volume}ml'), const Spacer(), BuStatusPill(stockLabel, tone: tone)],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  key: const Key('bottle-edit'),
                  tooltip: 'Edit, coming soon',
                  icon: Icon(Ionicons.create_outline, color: bu.soft),
                  onPressed: () => showComingSoon(context, title: 'Edit a bottle', text: 'Change the price, the size or how many you have.'),
                ),
                IconButton(
                  key: const Key('bottle-delete'),
                  tooltip: 'Remove, coming soon',
                  icon: Icon(Ionicons.trash_outline, color: bu.red),
                  onPressed: () => showComingSoon(context, title: 'Remove a bottle', text: 'Take a bottle out of your stock list.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
