import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/inventory_rules.dart';
import '../services/inventory_service.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) => InventoryService());

final stockProvider = FutureProvider.autoDispose.family<List<StockItem>, String>(
  (ref, venueId) => ref.watch(inventoryServiceProvider).list(venueId),
);

/// One bottle's recent movements (or the whole club's when [bottleId] is empty).
final movementsProvider = FutureProvider.autoDispose.family<List<StockMovement>, ({String venueId, String bottleId})>(
  (ref, q) => ref.watch(inventoryServiceProvider).movements(q.venueId, bottleId: q.bottleId.isEmpty ? null : q.bottleId),
);
