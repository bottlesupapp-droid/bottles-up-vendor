import '../../ops/services/ops_rpc.dart';
import '../../owner/services/db_errors.dart' show isMissingFunction, isNoAccess;
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/booking_detail_rules.dart';

/// A booking's guests, activity and bottle sign: the website's `desk_booking_guests` and `desk_booking_activity`
/// (20261020110000_booking_guests_and_activity.sql) and `desk_booking_sign` (20261114100000_booking_sign_text.sql). The database decides who may see them; nothing here decides anything.
class BookingDetailService {
  BookingDetailService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<BookingGuests> guests(String bookingId) => _rpc.one('desk_booking_guests', {'p_booking': bookingId}, parseBookingGuests, 'the guests');

  /// The short sign the guest asked for on their bottles at checkout ("Happy Birthday"), or null when there is none. The database lets only the club's manager or owner and the
  /// table's own server read it.
  Future<String?> sign(String bookingId) async {
    try {
      final data = await _rpc.call('desk_booking_sign', {'p_booking': bookingId});
      final text = data is String ? data.trim() : '';
      return text.isEmpty ? null : text;
    } catch (error) {
      throw OpsLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error), what: 'the bottle sign');
    }
  }

  Future<List<ActivityEntry>> activity(String bookingId, {int limit = 100}) =>
      _rpc.list('desk_booking_activity', {'p_booking': bookingId, 'p_limit': limit}, parseActivityEntry, 'the activity');
}
