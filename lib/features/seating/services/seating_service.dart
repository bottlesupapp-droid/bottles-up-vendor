import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/seating_rules.dart';

/// The calls to the website's seating functions (website repo, 20261018110000_seating_and_outbox.sql): `desk_find_booking`,
/// `desk_mark_seated`, `desk_set_estimate`, `desk_unseat`, `desk_booking_seating` and `desk_booking_messages`. The database decides who may
/// seat which table and that it happens once; the message to the guest is only ever queued there.
class SeatingService {
  SeatingService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<BookingMatch>> find(String venueId, String night, String query) => _rpc.act(() async {
        final data = await _rpc.call('desk_find_booking', {'p_venue': venueId, 'p_night': night, 'p_query': query.trim()});
        return [for (final r in OpsRpc.rows(data)) parseBookingMatch(r)].whereType<BookingMatch>().toList();
      }, generic: 'The search could not be done. Check your connection and try again.');

  Future<SeatingState> state(String bookingId) =>
      _rpc.one('desk_booking_seating', {'p_booking': bookingId}, parseSeatingState, 'the seating');

  Future<List<GuestMessage>> messages(String bookingId) =>
      _rpc.list('desk_booking_messages', {'p_booking': bookingId}, parseGuestMessage, 'guest messages');

  /// Seats the guest. [manual] is a booking found by name: the detail checked with the guest is then required and recorded.
  Future<SeatOutcome> seat(String bookingId, {bool manual = false, String? detail, int? estimateMinutes}) => _rpc.act(() async {
        final data = await _rpc.call('desk_mark_seated', {
          'p_booking': bookingId,
          'p_method': manual ? 'manual' : 'scan',
          'p_confirmation': detail == null || detail.trim().isEmpty ? null : detail.trim(),
          'p_estimate_minutes': estimateMinutes,
        });
        return parseSeatOutcome(data);
      }, generic: 'The guest could not be seated. Check your connection and try again.');

  /// Sets or changes the service estimate (null clears it). Returns whether anything changed.
  Future<bool> setEstimate(String bookingId, int? minutes) => _rpc.act(() async {
        final data = await _rpc.call('desk_set_estimate', {'p_booking': bookingId, 'p_minutes': minutes});
        return data is Map && data['changed'] == true;
      }, generic: 'The estimate could not be saved. Check your connection and try again.');

  Future<void> unseat(String bookingId, String reason) => _rpc.act(() async {
        await _rpc.call('desk_unseat', {'p_booking': bookingId, 'p_reason': reason.trim()});
      }, generic: 'The guest could not be un-seated. Check your connection and try again.');
}
