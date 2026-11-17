import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/inventory_rules.dart';
import '../logic/stock_overview_rules.dart';

/// The calls to the website's stock functions (website repo, 20261018150000_inventory_ledger.sql). The database decides who may read or
/// change stock and that it never goes below 0; nothing here decides any of it.
class InventoryService {
  InventoryService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<StockItem>> list(String venueId) => _rpc.list('stock_list', {'p_venue': venueId}, parseStockItem, 'stock');

  /// Records one movement. [clientKey] makes a retry or a double tap the same movement.
  Future<MoveOutcome> move(
    String venueId,
    String bottleId,
    StockKind kind,
    int quantity, {
    String? reason,
    String? note,
    required String clientKey,
    String? night,
  }) =>
      _rpc.act(() async {
        final data = await _rpc.call('stock_move', {
          'p_venue': venueId,
          'p_bottle': bottleId,
          'p_kind': kind.id,
          'p_quantity': quantity,
          'p_reason': reason == null || reason.trim().isEmpty ? null : reason.trim(),
          'p_note': note == null || note.trim().isEmpty ? null : note.trim(),
          'p_client_key': clientKey,
          'p_night': night,
        });
        return parseMoveOutcome(data);
      }, generic: 'That could not be recorded. Check your connection and try again.');

  Future<void> setThreshold(String venueId, String bottleId, int? level) => _rpc.act(() async {
        await _rpc.call('stock_set_threshold', {'p_venue': venueId, 'p_bottle': bottleId, 'p_threshold': level});
      }, generic: 'The level could not be saved. Check your connection and try again.');

  /// Each bottle's on-hand, reserved, handed-over and available figures, and how many sold in the period (website 20261122110000_stock_overview.sql). Read only. A server without the
  /// migration makes this an "unavailable" load failure, which the screen says in words.
  Future<List<StockOverviewItem>> overview(String venueId, {DateTime? from, DateTime? to}) => _rpc.list(
        'stock_overview',
        {'p_venue': venueId, 'p_from': from?.toUtc().toIso8601String(), 'p_to': to?.toUtc().toIso8601String()},
        parseStockOverviewItem,
        'the stock figures',
      );

  Future<List<StockMovement>> movements(String venueId, {String? bottleId, DateTime? before, int limit = 50}) => _rpc.list(
        'stock_movements',
        {'p_venue': venueId, 'p_bottle': bottleId, 'p_limit': limit, 'p_before': before?.toUtc().toIso8601String()},
        parseMovement,
        'the stock history',
      );
}
