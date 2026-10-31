import 'package:bottles_up_vendor/features/workspace/services/invitation_check_service.dart';
import 'package:bottles_up_vendor/features/workspace/services/workspace_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// The database's invitation functions and the code e-mail function as a fake, with the rules and outcomes of the SQL (website repo, 20261118100000_temporary_staff_links.sql, tested there):
/// the same order of checks, wrong guesses counted, five lock a code, a code lives until it is replaced. The code is only ever handed over through [lastEmailedCode], as the e-mail would.
class FakeInviteCheck {
  /// 'pending', 'revoked' or 'accepted'.
  String status = 'pending';
  bool expired = false;
  bool temporary = true;
  bool emailMatches = true;
  bool verified = false;
  bool renewalRequested = false;
  String? code;
  int attempts = 0;
  bool codeExpired = false;

  /// What the e-mail function answers: 200, or a failure status (with `sendError`).
  int sendStatus = 200;
  String? sendError;
  bool sendNotConfigured = false;
  bool sendThrows = false;

  /// What the database does for the whole feature: false = the server does not have the functions yet.
  bool previewAvailable = true;
  bool offline = false;

  final List<({String function, Map<String, dynamic>? params})> calls = [];
  final List<String> emailed = [];
  int get emailCount => emailed.length;
  String? get lastEmailedCode => emailed.isEmpty ? null : emailed.last;

  WorkspaceService get workspaceService => WorkspaceService(rpc: call);
  InvitationCheckService get service => InvitationCheckService(caller: call, invoker: invoke);

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  Future<dynamic> invoke(String name, Map<String, dynamic> body) async {
    calls.add((function: name, params: body));
    if (sendThrows) throw Exception('SocketException');
    if (sendStatus != 200) {
      throw FunctionException(status: sendStatus, details: sendError == null ? null : {'error': sendError});
    }
    if (sendNotConfigured) return {'sent': false, 'reason': 'not_configured'};
    code = '482913';
    attempts = 0;
    codeExpired = false;
    emailed.add(code!);
    return {'sent': true, 'to_hint': 't***@club.example'};
  }

  Map<String, dynamic> _details() => {
        'kind': temporary ? 'temporary' : 'permanent',
        'email_hint': 't***@club.example',
        'role': 'door',
        'org_name': 'Club Co',
        'venue_name': 'Club A',
        'event_title': null,
        'shift_name': 'Friday late',
        'access_start_at': null,
        'access_end_at': '2031-10-25T03:00:00Z',
        'expires_at': '2031-10-25T12:00:00Z',
        'renewal_requested': renewalRequested,
      };

  bool get _needsCode => temporary && !expired && !verified;

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    switch (function) {
      case 'invitation_preview':
        {
          if (!previewAvailable) throw PostgrestException(message: 'function $function does not exist', code: '42883');
          if (status == 'revoked') return {'outcome': 'revoked'};
          if (status == 'accepted') return {'outcome': 'already_accepted'};
          if (!emailMatches) return {'outcome': 'email_mismatch'};
          return {'outcome': expired ? 'expired' : 'ok', ..._details(), 'needs_code': _needsCode};
        }
      case 'verify_invitation_code':
        {
          if (!previewAvailable) throw PostgrestException(message: 'function $function does not exist', code: '42883');
          final given = params!['p_code'] as String;
          List<Map<String, dynamic>> answer(String o, [int? left]) => [{'outcome': o, 'attempts_left': left}];
          if (status == 'revoked') return answer('revoked');
          if (status == 'accepted') return answer('already_accepted');
          if (expired) return answer('expired');
          if (!emailMatches) return answer('email_mismatch');
          if (!temporary) return answer('not_needed');
          if (verified) return answer('ok');
          if (code == null) return answer('no_code');
          if (codeExpired) return answer('code_expired');
          if (attempts >= 5) return answer('locked', 0);
          if (!RegExp(r'^[0-9]{6}$').hasMatch(given)) return answer('malformed', 5 - attempts);
          if (given != code) {
            attempts++;
            return answer('wrong', 5 - attempts);
          }
          verified = true;
          code = null;
          return answer('ok');
        }
      case 'request_invitation_renewal':
        {
          if (!previewAvailable) throw PostgrestException(message: 'function $function does not exist', code: '42883');
          if (status == 'revoked') return 'revoked';
          if (status == 'accepted') return 'accepted';
          if (!emailMatches) return 'email_mismatch';
          if (!expired) return 'not_expired';
          if (renewalRequested) return 'already_requested';
          renewalRequested = true;
          return 'requested';
        }
      case 'accept_invitation':
        {
          if (temporary && !verified && status == 'pending' && !expired && emailMatches) throw refuse('confirm your e-mail with the code we sent before using this link');
          final outcome = status == 'revoked'
              ? 'revoked'
              : status == 'accepted'
                  ? 'already_accepted'
                  : expired
                      ? 'expired'
                      : !emailMatches
                          ? 'email_mismatch'
                          : 'ok';
          if (outcome == 'ok') status = 'accepted';
          return [{'outcome': outcome, 'joined_membership_id': outcome == 'ok' ? 'm1' : null, 'joined_org_id': outcome == 'ok' ? 'o1' : null}];
        }
    }
    throw StateError('unexpected call $function');
  }
}
