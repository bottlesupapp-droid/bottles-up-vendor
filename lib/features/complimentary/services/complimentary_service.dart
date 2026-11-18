import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/complimentary_rules.dart';

/// The calls to the website's offer functions (website repo, 20261123100000_complimentary_offers.sql). The database decides who may do each (the club's owner and manager), which steps are open
/// for an offer (`actions`), and that the club's own free-bottle limits apply when an offer is accepted; nothing here decides any of it. A server without the migration makes the list an
/// "unavailable" load failure, which the screen says in words.
class ComplimentaryService {
  ComplimentaryService({OpsRpc? rpc, RpcCaller? caller, EdgeInvoker? invoker}) : _rpc = rpc ?? OpsRpc(rpc: caller, invoker: invoker);

  final OpsRpc _rpc;

  Future<List<OfferRow>> list(String venueId) => _rpc.list('comp_offers_list', {'p_venue': venueId}, parseOfferRow, 'the offers');

  Future<List<OfferTable>> tables(String venueId) => _rpc.list('comp_offer_tables', {'p_venue': venueId}, parseOfferTable, 'the club\'s tables');

  /// The confirmed bookings at the table the recipient chose, on the business night [night] (yyyy-mm-dd).
  Future<List<OfferBooking>> bookings(String offerId, String night) => _rpc.list('comp_offer_bookings', {'p_offer': offerId, 'p_night': night}, parseOfferBooking, 'the bookings');

  /// Makes the offer. Returns its id.
  Future<String> create(String venueId, OfferDraft d, {String? eventId}) => _rpc.act(() async {
    final data = await _rpc.call('comp_offer_create', {
      'p_venue': venueId,
      'p_bottle': d.bottleId,
      'p_quantity': d.quantity,
      'p_email': d.email,
      'p_name': d.name,
      'p_reason': d.reason,
      'p_sign': d.sign,
      'p_event': eventId,
      'p_expires_hours': d.expiresHours,
    });
    return '$data';
  }, generic: 'The offer could not be made. Check your connection and look at the list before trying again.');

  Future<void> setLocation(String offerId, String tableId) => _rpc.act(() async {
    await _rpc.call('comp_offer_set_location', {'p_offer': offerId, 'p_table': tableId});
  }, generic: 'The place could not be saved. Check your connection and look at the offer before trying again.');

  /// Accepts the offer at a booking: it becomes a free bottle there. The answer says whether the free bottle was applied or is waiting for the owner.
  Future<AcceptOutcome> accept(String offerId, String bookingId) => _rpc.act(() async {
    final data = await _rpc.call('comp_offer_accept', {'p_offer': offerId, 'p_booking': bookingId});
    return parseAcceptOutcome(data) ?? const AcceptOutcome(concessionStatus: null);
  }, generic: 'This could not be done. Check your connection and look at the offer before trying again.');

  Future<void> markDelivered(String offerId) => _rpc.act(() async {
    await _rpc.call('comp_offer_mark_delivered', {'p_offer': offerId});
  }, generic: 'This could not be done. Check your connection and look at the offer before trying again.');

  Future<void> cancel(String offerId, String reason) => _rpc.act(() async {
    await _rpc.call('comp_offer_cancel', {'p_offer': offerId, 'p_reason': reason.trim()});
  }, generic: 'The offer could not be cancelled. Check your connection and look at the offer before trying again.');

  /// The latest attempts to e-mail this offer's link, newest first.
  Future<List<OfferSend>> sends(String offerId) => _rpc.list('comp_offer_sends', {'p_offer': offerId}, parseOfferSend, 'the e-mails sent');

  /// Asks the e-mail function to send the link. The request carries only the offer's id: the address is the offer's own and the database decides whether this person may send it now. A refusal
  /// (not allowed, the offer has moved on, sent too often) is the function's own sentence in an [OpsActionException].
  Future<LinkSendResult> sendLink(String offerId) async {
    try {
      final data = await _rpc.invoke('send-complimentary-offer', {'offerId': offerId});
      final parsed = parseLinkSendResult(data);
      if (parsed == null) throw const OpsActionException('The link could not be sent. Look at the offer before trying again.');
      return parsed;
    } on OpsActionException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      final said = details is Map && details['error'] is String ? details['error'] as String : null;
      throw OpsActionException(
        said ??
            switch (e.status) {
              401 => 'Sign in again to send this link.',
              403 => 'You cannot send this link.',
              429 => 'This link was sent too often. Wait before sending it again.',
              _ => 'The link could not be sent. Check your connection and look at the offer before trying again.',
            },
      );
    } catch (_) {
      throw const OpsActionException('The link could not be sent. Check your connection and look at the offer before trying again.');
    }
  }
}
