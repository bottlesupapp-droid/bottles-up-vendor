import '../../ops/services/ops_rpc.dart';
import '../../owner/services/db_errors.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/door_sales_rules.dart';

/// The door's sales (website repo, 20261026100000_door_sales.sql). The database decides everything that matters: that the person holds a door role for the event, that selling is open, that
/// the tickets are still there (the last ones can never be sold twice), and that the same key from the same person is one sale. Nothing here grants anything.
class DoorSalesService {
  DoorSalesService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  /// The ticket types the door may sell for [eventId], with what is left. When the database says selling is not open for the event the answer is [SaleOptions.closed], not an error.
  Future<SaleOptions> options(String eventId) async {
    try {
      final rows = OpsRpc.rows(await _rpc.call('door_sale_options', {'p_event': eventId}));
      return SaleOptions(closed: false, options: rows.map(parseSaleOption).whereType<SaleOption>().toList());
    } catch (error) {
      if (messageOf(error).toLowerCase().contains('not open for this event')) return const SaleOptions(closed: true, options: []);
      throw OpsLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error), what: 'ticket types');
    }
  }

  /// Sells [quantity] tickets of one type to one guest and checks them in, once. [key] identifies this attempt: sending the same sale again with the same key returns the sale already
  /// made ([DoorSale.repeated]). An email and a phone number are optional and only kept with the sale; a card machine sale needs its receipt number.
  Future<DoorSale> sell({
    required String eventId,
    required String tierId,
    required int quantity,
    required DoorPayMethod method,
    required String name,
    required String email,
    required String phone,
    required String reference,
    required String key,
  }) =>
      _rpc.act(() async {
        final data = await _rpc.call('door_sell_ticket', {
          'p_event': eventId,
          'p_tier': tierId,
          'p_quantity': quantity,
          'p_method': method.db,
          'p_name': name.trim(),
          'p_email': email.trim().isEmpty ? null : email.trim(),
          'p_phone': phone.trim().isEmpty ? null : phone.trim(),
          'p_reference': reference.trim().isEmpty ? null : reference.trim(),
          'p_client_key': key,
        });
        final sale = data is Map ? parseDoorSale(Map<String, dynamic>.from(data)) : null;
        if (sale == null) throw const OpsActionException('The sale could not be confirmed. Check your connection, then try again: the same sale will not be made twice.');
        return sale;
      }, generic: 'The sale could not be confirmed. Check your connection, then try again: the same sale will not be made twice.');

  /// This person's own shift at the event.
  Future<ShiftSummary> summary(String eventId) => _rpc.one('door_shift_summary', {'p_event': eventId}, parseShiftSummary, 'your shift');
}
