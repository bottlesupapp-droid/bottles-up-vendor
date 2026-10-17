import '../../ops/logic/ops_json.dart';
import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/agreement_rules.dart';

/// A club found when an organizer looks for one to host an event.
class ClubMatch {
  const ClubMatch({required this.venueId, required this.name, this.address});

  final String venueId;
  final String name;
  final String? address;
}

ClubMatch? _parseClub(Map<String, dynamic> r) {
  final id = opsStr(r, 'venue_id');
  // Only a club that belongs to a business can be asked: the database refuses the rest.
  if (id == null || !opsBool(r, 'is_claimed')) return null;
  return ClubMatch(venueId: id, name: opsStr(r, 'name') ?? 'Club', address: opsStr(r, 'address'));
}

/// The calls to the website's agreement functions (website repo, 20261018180000_event_agreements.sql). The database decides who may ask,
/// propose, accept or close and that the two acceptances come from two different people; nothing here decides any of it.
class AgreementService {
  AgreementService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<AgreementRow>> listForVenue(String venueId) => _rpc.list('agreement_list', {'p_venue': venueId, 'p_org': null}, parseAgreementRow, 'agreements');

  Future<List<AgreementRow>> listForOrg(String orgId) => _rpc.list('agreement_list', {'p_venue': null, 'p_org': orgId}, parseAgreementRow, 'agreements');

  Future<AgreementDetail> detail(String agreementId) => _rpc.one('agreement_detail', {'p_agreement': agreementId}, parseAgreementDetail, 'the agreement');

  Future<List<ClubMatch>> searchClubs(String query) => _rpc.act(() async {
        final data = await _rpc.call('search_venues', {'p_query': query.trim()});
        return [for (final r in OpsRpc.rows(data)) _parseClub(r)].whereType<ClubMatch>().toList();
      }, generic: 'The search could not be done. Check your connection and try again.');

  Future<String> request(String eventId, String venueId, {String? message}) => _rpc.act(() async {
        final data = await _rpc.call('agreement_request', {'p_event': eventId, 'p_venue': venueId, 'p_message': message == null || message.trim().isEmpty ? null : message.trim()});
        return data.toString();
      }, generic: 'The request could not be sent. Check your connection and try again.');

  /// A new version of the terms. Returns its number.
  Future<int> propose(String agreementId, Map<String, dynamic> terms, {String? note}) => _rpc.act(() async {
        final data = await _rpc.call('agreement_propose', {'p_agreement': agreementId, 'p_terms': terms, 'p_note': note == null || note.trim().isEmpty ? null : note.trim()});
        return data is int ? data : int.tryParse('$data') ?? 0;
      }, generic: 'The proposal could not be sent. Check your connection and try again.');

  /// Accepts the version that was on screen. Returns whether anything changed (accepting twice changes nothing).
  Future<bool> accept(String agreementId, int version) => _rpc.act(() async {
        final data = await _rpc.call('agreement_accept', {'p_agreement': agreementId, 'p_version': version});
        return data is Map && data['changed'] == true;
      }, generic: 'That could not be recorded. Check your connection and try again.');

  Future<void> note(String agreementId, String body) => _rpc.act(() async {
        await _rpc.call('agreement_note', {'p_agreement': agreementId, 'p_body': body.trim()});
      }, generic: 'The note could not be saved. Check your connection and try again.');

  Future<void> close(String agreementId, String reason) => _rpc.act(() async {
        await _rpc.call('agreement_close', {'p_agreement': agreementId, 'p_reason': reason.trim()});
      }, generic: 'That could not be done. Check your connection and try again.');
}
