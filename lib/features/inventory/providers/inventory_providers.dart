import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/inventory_rules.dart';
import '../logic/stock_overview_rules.dart';
import '../services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) => InventoryService());

final stockProvider = FutureProvider.autoDispose.family<List<StockItem>, String>(
  (ref, venueId) => ref.watch(inventoryServiceProvider).list(venueId),
);

/// The stock overview of a club, with "sold" counted over the last [days] days. Read again every time the screen opens or the period changes; never kept once it is gone.
final stockOverviewProvider = FutureProvider.autoDispose.family<List<StockOverviewItem>, ({String venueId, int days})>((ref, q) {
  final now = DateTime.now();
  return ref.watch(inventoryServiceProvider).overview(q.venueId, from: now.subtract(Duration(days: q.days)), to: now);
});

/// One bottle's recent movements (or the whole club's when [bottleId] is empty).
final movementsProvider = FutureProvider.autoDispose.family<List<StockMovement>, ({String venueId, String bottleId})>(
  (ref, q) => ref.watch(inventoryServiceProvider).movements(q.venueId, bottleId: q.bottleId.isEmpty ? null : q.bottleId),
);
