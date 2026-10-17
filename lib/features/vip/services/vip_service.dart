import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/vip_rules.dart';

/// The calls to the website's VIP functions (website repo, 20261018160000_vip_guests.sql). The database decides who may keep the list, who
/// sees which perks and that a limited perk cannot be used past its limit; nothing here decides any of it.
class VipService {
  VipService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<List<VipMember>> list(String venueId, {String? search, bool includeEnded = false, String? night}) => _rpc.list(
        'vip_list',
        {'p_venue': venueId, 'p_search': search == null || search.trim().isEmpty ? null : search.trim(), 'p_include_ended': includeEnded, 'p_night': night},
        parseVipMember,
        'VIP guests',
      );

  Future<VipProfile> detail(String memberId, {String? night}) => _rpc.one('vip_detail', {'p_member': memberId, 'p_night': night}, parseVipProfile, 'the guest');

  Future<String> add(String venueId, Map<String, dynamic> details) => _rpc.act(() async {
        final data = await _rpc.call('vip_add', {'p_venue': venueId, 'p_details': details});
        return data.toString();
      }, generic: 'The guest could not be saved. Check your connection and try again.');

  Future<void> update(String memberId, Map<String, dynamic> details) => _rpc.act(() async {
        await _rpc.call('vip_update', {'p_member': memberId, 'p_details': details});
      }, generic: 'The changes could not be saved. Check your connection and try again.');

  Future<void> end(String memberId, String reason) => _rpc.act(() async {
        await _rpc.call('vip_end', {'p_member': memberId, 'p_reason': reason.trim()});
      }, generic: 'The membership could not be ended. Check your connection and try again.');

  Future<void> reinstate(String memberId) => _rpc.act(() async {
        await _rpc.call('vip_reinstate', {'p_member': memberId});
      }, generic: 'The membership could not be restored. Check your connection and try again.');

  Future<String> addPerk(String memberId, String kind, String label, {int? maxUses, String period = 'night'}) => _rpc.act(() async {
        final data = await _rpc.call('vip_add_perk', {'p_member': memberId, 'p_kind': kind, 'p_label': label.trim(), 'p_max_uses': maxUses, 'p_period': period});
        return data.toString();
      }, generic: 'The perk could not be added. Check your connection and try again.');

  Future<void> endPerk(String perkId) => _rpc.act(() async {
        await _rpc.call('vip_end_perk', {'p_perk': perkId});
      }, generic: 'The perk could not be ended. Check your connection and try again.');

  /// Queues the invitation. Nothing is sent from here.
  Future<void> invite(String memberId) => _rpc.act(() async {
        await _rpc.call('vip_invite', {'p_member': memberId});
      }, generic: 'The invitation could not be queued. Check your connection and try again.');

  Future<List<VipLookupResult>> lookup(String venueId, String query, {String? night}) => _rpc.act(() async {
        final data = await _rpc.call('vip_lookup', {'p_venue': venueId, 'p_query': query.trim(), 'p_night': night});
        return [for (final r in OpsRpc.rows(data)) parseVipLookup(r)].whereType<VipLookupResult>().toList();
      }, generic: 'The search could not be done. Check your connection and try again.');

  Future<RedeemOutcome> redeem(String perkId, {String? night, String? note}) => _rpc.act(() async {
        final data = await _rpc.call('vip_redeem', {'p_perk': perkId, 'p_night': night, 'p_note': note == null || note.trim().isEmpty ? null : note.trim()});
        return parseRedeemOutcome(data);
      }, generic: 'That could not be recorded. Check your connection and try again.');
}
