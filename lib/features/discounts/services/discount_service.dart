import '../../ops/services/ops_rpc.dart';
import '../../table_service/logic/bottle_orders_rules.dart' show MenuBottle, parseMenuBottle;
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/discount_rules.dart';

/// The discount and free-bottle calls (website repo, 20261024100000_staff_discounts_and_complimentary.sql). The database decides who may give what: within a person's own limit it is
/// applied at once, above it it waits for someone with the authority, nobody approves their own, and nothing can be given until the owner has set limits. Nothing here decides any of it.
class DiscountService {
  DiscountService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  // --- on one table ----------------------------------------------------------------

  /// What the caller may give tonight on this table.
  Future<ConcessionLimits> limits(String bookingId) => _rpc.one('desk_concession_limits', {'p_booking': bookingId}, (r) => parseConcessionLimits(r), 'the discount limits');

  /// What has been given on this table, with who asked and who approved.
  Future<List<Concession>> given(String bookingId) => _rpc.list('desk_booking_concessions', {'p_booking': bookingId}, parseConcession, 'the discounts');

  /// The bottles that can be given for free: the club's menu as it stands.
  Future<List<MenuBottle>> menu(String bookingId) => _rpc.list('desk_bottle_menu', {'p_booking': bookingId}, parseMenuBottle, 'the bottles');

  /// Asks for a discount. Within the person's own limit it is applied at once; above it, it waits.
  Future<ConcessionResult> giveDiscount(String bookingId, DiscountForm form, ConcessionLimits limits, List<Concession> existing) => _rpc.act(() async {
        final found = validateDiscount(form, limits, existing);
        if (found.isNotEmpty) throw OpsActionException(found.first);
        final data = await _rpc.call('desk_request_discount', discountParams(bookingId, form, limits.bottleSubtotalCents));
        final result = parseConcessionResult(data);
        if (result == null) throw const OpsActionException('We could not tell whether the discount was recorded. Look at the table before trying again, so nothing is given twice.');
        return result;
      }, generic: 'The discount could not be recorded. Check your connection and look at the table before trying again.');

  /// Asks for free bottles. Within the person's allowance for the night it is applied at once (a real bottle at no charge, counted in stock); above it, it waits.
  Future<ConcessionResult> giveFreeBottle(String bookingId, FreeBottleForm form, ConcessionLimits limits) => _rpc.act(() async {
        final found = validateFreeBottle(form, limits);
        if (found.isNotEmpty) throw OpsActionException(found.first);
        final data = await _rpc.call('desk_request_free_bottle', freeBottleParams(bookingId, form));
        final result = parseConcessionResult(data);
        if (result == null) throw const OpsActionException('We could not tell whether the free bottle was recorded. Look at the table before trying again, so nothing is given twice.');
        return result;
      }, generic: 'The free bottle could not be recorded. Check your connection and look at the table before trying again.');

  /// Takes an applied discount or free bottle back (manager or owner). A bottle that has already been served cannot be.
  Future<void> takeBack(String id, String note) => _rpc.act(() async {
        final problem = validateTakeBackNote(note);
        if (problem != null) throw OpsActionException(problem);
        await _rpc.call('desk_void_concession', {'p_id': id, 'p_note': note.trim()});
      }, generic: 'It could not be taken back. Check your connection and look at the table before trying again.');

  // --- what waits for approval (manager or owner) ----------------------------------

  Future<List<PendingConcession>> pending(String venueId) => _rpc.list('desk_pending_concessions', {'p_venue': venueId}, parsePending, 'the requests');

  /// Approves or declines a waiting request. Answers 'applied' or 'declined'.
  Future<String> decide(String id, bool approve, String note) => _rpc.act(() async {
        final problem = validateConcessionDecision(approve: approve, note: note);
        if (problem != null) throw OpsActionException(problem);
        final data = await _rpc.call('desk_decide_concession', decisionParams(id, approve, note));
        if (data == 'applied' || data == 'declined') return data as String;
        throw const OpsActionException('We could not tell whether the decision was recorded. Look at the request before trying again.');
      }, generic: 'The decision could not be recorded. Check your connection and look at the request before trying again.');

  // --- the limits (the owner sets them) ---------------------------------------------

  Future<DiscountLimits> venueLimits(String venueId) => _rpc.one('venue_discount_limits', {'p_venue': venueId}, parseDiscountLimits, 'the limits');

  Future<void> saveLimits(String venueId, LimitsForm form) => _rpc.act(() async {
        final found = validateLimits(form);
        if (found.isNotEmpty) throw OpsActionException(found.first);
        await _rpc.call('save_venue_discount_limits', {'p_venue': venueId, 'p_details': limitsPayload(form)});
      }, generic: 'The limits could not be saved. Check your connection and try again.');
}
