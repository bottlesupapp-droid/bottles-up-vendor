import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../ops/services/ops_rpc.dart';
import '../logic/invitation_check.dart';
import 'workspace_service.dart' show RpcCaller;

/// The calls behind opening an invitation link: what the link is, the code for a temporary one, and asking for a new link (website repo, 20261118100000_temporary_staff_links.sql and
/// the `send-invitation-code` edge function). The database decides whether a code is needed and whether it is right; nothing here does.
class InvitationCheckService {
  InvitationCheckService({OpsRpc? rpc, RpcCaller? caller, EdgeInvoker? invoker}) : _rpc = rpc ?? OpsRpc(rpc: caller, invoker: invoker);

  final OpsRpc _rpc;

  /// What this link is. Throws an [OpsLoadException] where the server does not have it (the caller then uses the link as it always did).
  Future<InvitationPreview> preview(String token) => _rpc.one('invitation_preview', {'p_token': token}, parseInvitationPreview, 'the invitation');

  /// Asks for the code to be e-mailed. Never throws: the answer says what to tell the person. The code itself never comes back here.
  Future<CodeSendResult> sendCode(String token) async {
    try {
      final data = await _rpc.invoke('send-invitation-code', {'token': token});
      final m = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
      if (m['sent'] == true) return codeSentResult(m['to_hint']?.toString());
      return codeNotSent(m['reason'] == 'not_configured'
          ? 'We cannot send e-mail right now. Ask the person who invited you for help.'
          : 'We could not send the e-mail. Try again in a moment.');
    } on FunctionException catch (e) {
      final details = e.details;
      final said = details is Map && details['error'] is String ? details['error'] as String : null;
      switch (e.status) {
        case 429:
          return codeNotSent(said ?? 'Please wait a minute before asking for another code.', codeMayExist: (said ?? '').toLowerCase().contains('wait a minute'));
        case 401:
          return codeNotSent('Sign in with the address your invitation was sent to.');
        case 403:
          return codeNotSent(said ?? 'This link was not sent to the address you are signed in with.');
        case 409:
          return codeNotSent(said ?? 'This link was already used, cancelled or has expired.');
        default:
          return codeNotSent('We could not send the code. Check your connection and try again.');
      }
    } catch (_) {
      return codeNotSent('We could not send the code. Check your connection and try again.');
    }
  }

  /// Checks the code. A wrong guess is counted by the database, which answers rather than raising.
  Future<CodeCheck> verify(String token, String code) async {
    try {
      final rows = OpsRpc.rows(await _rpc.call('verify_invitation_code', {'p_token': token, 'p_code': cleanCode(code)}));
      final parsed = rows.isEmpty ? null : parseCodeCheck(rows.first);
      return parsed ?? const CodeCheck(CodeOutcome.failed);
    } catch (_) {
      return const CodeCheck(CodeOutcome.failed);
    }
  }

  /// The invitee of an expired link asks for a new one.
  Future<RenewalOutcome> requestRenewal(String token, {String? note}) async {
    try {
      final data = await _rpc.call('request_invitation_renewal', {'p_token': token, 'p_note': note == null || note.trim().isEmpty ? null : note.trim()});
      return RenewalOutcome.fromDb(data);
    } catch (_) {
      return RenewalOutcome.failed;
    }
  }
}
