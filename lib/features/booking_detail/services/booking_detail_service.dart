import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/booking_detail_rules.dart';

/// A booking's guests and activity: the website's `desk_booking_guests` and `desk_booking_activity`
/// (20261020110000_booking_guests_and_activity.sql). The database decides who may see them; nothing here decides anything.
class BookingDetailService {
  BookingDetailService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<BookingGuests> guests(String bookingId) => _rpc.one('desk_booking_guests', {'p_booking': bookingId}, parseBookingGuests, 'the guests');

  Future<List<ActivityEntry>> activity(String bookingId, {int limit = 100}) =>
      _rpc.list('desk_booking_activity', {'p_booking': bookingId, 'p_limit': limit}, parseActivityEntry, 'the activity');
}
