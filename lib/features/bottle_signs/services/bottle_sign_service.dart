import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/sign_rules.dart';

/// The calls to the website's bottle sign functions (website repo, 20261116100000_bottle_signs.sql). The database decides who may set or review a sign, on which bottles, and whether an
/// order may go on; nothing here decides any of it.
class BottleSignService {
  BottleSignService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<SignSettings> settings(String venueId) => _rpc.one('venue_sign_settings', {'p_venue': venueId}, parseSignSettings, 'the bottle sign settings');

  /// Changes how signs work at a club: either or both of the mode and whether a manager approves servers' signs. Returns the settings as they now are.
  Future<SignSettings> save(String venueId, {SignMode? mode, bool? reviewRequired}) => _rpc.act(() async {
        final data = await _rpc.call('save_venue_sign_settings', {
          'p_venue': venueId,
          'p_details': {if (mode != null) 'mode': mode.value, if (reviewRequired != null) 'review_required': reviewRequired},
        });
        final saved = data is Map ? parseSignSettings(Map<String, dynamic>.from(data)) : null;
        if (saved == null) throw StateError('no settings in the answer');
        return saved;
      }, generic: 'That could not be saved. Check your connection and try again.');

  /// Marks a bottle as one that may carry a sign. Returns whether anything changed.
  Future<bool> setEligible(String venueId, String bottleId, bool eligible) => _rpc.act(() async {
        final data = await _rpc.call('set_bottle_sign_eligible', {'p_venue': venueId, 'p_bottle': bottleId, 'p_eligible': eligible});
        return data == true;
      }, generic: 'That could not be saved. Check your connection and try again.');

  /// The signs (and whether a sign can be put on) for the lines the screen holds. Asked in groups, because the database answers for at most 500 at a time.
  Future<Map<String, LineSign>> lineSigns(List<String> lineIds) async {
    final out = <String, LineSign>{};
    for (var i = 0; i < lineIds.length; i += lineSignsBatch) {
      final chunk = lineIds.sublist(i, i + lineSignsBatch > lineIds.length ? lineIds.length : i + lineSignsBatch);
      for (final s in await _rpc.list('desk_line_signs', {'p_lines': chunk}, parseLineSign, 'the bottle signs')) {
        out[s.lineId] = s;
      }
    }
    return out;
  }

  /// Sets the sign on a line; empty text removes it.
  Future<SignChange> setSign(String lineId, String text) => _rpc.act(() async {
        final data = await _rpc.call('desk_set_bottle_sign', {'p_line': lineId, 'p_text': text.trim()});
        return parseSignChange(data);
      }, generic: 'The sign could not be saved. Check your connection and try again.');

  /// A manager's decision on a waiting sign. A decline needs a reason.
  Future<SignChange> review(String lineId, {required bool approve, String? note}) => _rpc.act(() async {
        final data = await _rpc.call('desk_review_bottle_sign', {
          'p_line': lineId,
          'p_decision': approve ? 'approve' : 'reject',
          'p_note': approve || note == null || note.trim().isEmpty ? null : note.trim(),
        });
        return parseSignChange(data);
      }, generic: 'That could not be recorded. Check your connection and try again.');

  Future<List<PendingSign>> pending(String venueId) => _rpc.list('desk_pending_sign_reviews', {'p_venue': venueId}, parsePendingSign, 'the signs waiting for approval');
}

/// The most lines the database answers for in one call.
const int lineSignsBatch = 500;
