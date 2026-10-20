import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/table_map_rules.dart';

/// The floor map, placement, moving a booking and deposit-terms calls (website repo, 20261021100000_floor_plan_and_table_states.sql). The database decides who may do
/// what (the club's manager or owner), counts what is free while it holds the table type, and refuses with a plain sentence; nothing here decides any of it.
class TableMapService {
  TableMapService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  // --- the map and its blocks ----------------------------------------------

  /// Every arrival time of [night] ('YYYY-MM-DD') with each table type's counts: available, booked, occupied, held, unavailable.
  Future<List<MapSlot>> states(String venueId, String night) async {
    final rows = await _rpc.list<Map<String, dynamic>>('desk_table_states', {'p_venue': venueId, 'p_night': night}, (r) => r, 'the tables');
    return parseTableStates(rows);
  }

  /// The holds and unavailable tables in force that night.
  Future<List<TableBlock>> blocks(String venueId, String night) =>
      _rpc.list('desk_table_blocks', {'p_venue': venueId, 'p_night': night}, parseBlock, 'the holds');

  /// Holds ([BlockForm.kind] 'held') or takes out of use ('unavailable') some free tables of one kind for one arrival time. Returns how many are left to sell.
  Future<int> block({required String venueId, required String night, required String tableTypeId, required String slotId, required BlockForm form}) => _rpc.act(() async {
        final data = await _rpc.call('desk_table_block', {
          'p_venue': venueId,
          'p_night': night,
          'p_type': tableTypeId,
          'p_slot': slotId,
          'p_kind': form.kind,
          'p_quantity': form.quantity,
          'p_reason': form.reason.trim(),
          'p_minutes': form.kind == 'held' ? form.minutes : null,
        });
        final left = data is Map ? data['free_after'] : null;
        if (left is! num) throw const OpsActionException('We could not tell whether that went through. Look at the map before trying again.');
        return left.toInt();
      }, generic: 'The tables could not be held. Check your connection and look at the map before trying again.');

  /// Reopens the tables of a block. True when it was ended now, false when it had already ended (reopened by someone else, or a hold that ran out).
  Future<bool> release(String blockId) => _rpc.act(() async {
        final data = await _rpc.call('desk_table_release', {'p_block': blockId});
        return data == true;
      }, generic: 'The tables could not be reopened. Check your connection and try again.');

  // --- moving a booking -----------------------------------------------------

  Future<List<MoveOption>> moveOptions(String bookingId) => _rpc.list('desk_booking_move_options', {'p_booking': bookingId}, parseMoveOption, 'the tables');

  Future<MoveResult> move(String bookingId, String toTableTypeId, String reason) => _rpc.act(() async {
        final data = await _rpc.call('desk_move_booking', {'p_booking': bookingId, 'p_to_type': toTableTypeId, 'p_reason': reason.trim()});
        final result = data is Map ? parseMoveResult(Map<String, dynamic>.from(data)) : null;
        if (result == null) throw const OpsActionException('We could not tell whether the move went through. Look at the booking before trying again.');
        return result;
      }, generic: 'The booking could not be moved. Check your connection and look at the booking before trying again.');

  Future<List<BookingMove>> moves(String bookingId) => _rpc.list('desk_booking_moves', {'p_booking': bookingId}, parseBookingMove, 'the moves');

  // --- what a booking was sold under -----------------------------------------

  Future<BookingTerms> bookingTerms(String bookingId) => _rpc.one('desk_booking_terms', {'p_booking': bookingId}, parseBookingTerms, 'the terms');

  // --- placement (owner or manager) -------------------------------------------

  Future<List<TableLayout>> layout(String venueId) => _rpc.list('list_venue_table_layout', {'p_venue': venueId}, parseLayout, 'the tables');

  Future<void> place(String venueId, String tableTypeId, String floorId, PlacedBox b) => _rpc.act(
        () async => await _rpc.call('place_venue_table', {'p_venue': venueId, 'p_type': tableTypeId, 'p_floor': floorId, 'p_x': b.x, 'p_y': b.y, 'p_w': b.w, 'p_h': b.h}),
        generic: 'The table could not be placed. Check your connection and try again.',
      );

  Future<void> unplace(String venueId, String tableTypeId) => _rpc.act(
        () async => await _rpc.call('unplace_venue_table', {'p_venue': venueId, 'p_type': tableTypeId}),
        generic: 'The table could not be taken off the floor plan. Check your connection and try again.',
      );

  /// [count] null = not stated.
  Future<void> setIncludedAdmissions(String venueId, String tableTypeId, int? count) => _rpc.act(
        () async => await _rpc.call('set_table_included_admissions', {'p_venue': venueId, 'p_type': tableTypeId, 'p_count': count}),
        generic: 'The included admissions could not be saved. Check your connection and try again.',
      );

  // --- deposit terms (owner or manager) ----------------------------------------

  Future<DepositSettings> depositSettings(String venueId) => _rpc.one('venue_deposit_terms', {'p_venue': venueId}, parseDepositSettings, 'the deposit terms');

  /// Changes the terms of bookings made from now on; bookings that exist keep the terms they were made under.
  Future<void> saveDepositTerms(String venueId, DepositTermsForm form) => _rpc.act(
        () async => await _rpc.call('save_venue_deposit_terms', {'p_venue': venueId, 'p_details': depositTermsPayload(form)}),
        generic: 'The deposit terms could not be saved. Check your connection and try again.',
      );
}
