import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/workspace_routing.dart';
import '../models/workspace.dart';

/// What happened when someone opened an invitation link. Mirrors the
/// `outcome` the database function returns.
enum InvitationOutcome {
  ok,
  alreadyAccepted,
  invalid,
  revoked,
  expired,
  emailMismatch,
  failed;

  static InvitationOutcome fromDb(String? value) {
    switch (value) {
      case 'ok':
        return InvitationOutcome.ok;
      case 'already_accepted':
        return InvitationOutcome.alreadyAccepted;
      case 'invalid':
        return InvitationOutcome.invalid;
      case 'revoked':
        return InvitationOutcome.revoked;
      case 'expired':
        return InvitationOutcome.expired;
      case 'email_mismatch':
        return InvitationOutcome.emailMismatch;
      default:
        return InvitationOutcome.failed;
    }
  }

  bool get grantedAccess => this == InvitationOutcome.ok || this == InvitationOutcome.alreadyAccepted;
}

/// Turns a database error into the right snapshot. "Function does not exist"
/// means the backend has not been given the tenancy migration yet; that is not an
/// error the user can fix, so it must not look like one.
WorkspaceSnapshot classifyWorkspaceError(Object error) {
  if (error is PostgrestException) {
    final code = error.code;
    if (code == '42883' || code == 'PGRST202' || code == '42P01') {
      return const WorkspaceSnapshot.unavailable('Workspaces are not set up on this server yet.');
    }
    return WorkspaceSnapshot.error(error.message);
  }
  return WorkspaceSnapshot.error(error.toString());
}

/// How the service calls a database function. Replaced in tests; in the app it
/// is Supabase's own `rpc`.
typedef RpcCaller = Future<dynamic> Function(String function, {Map<String, dynamic>? params});

class WorkspaceService {
  WorkspaceService({SupabaseClient? client, RpcCaller? rpc})
      : _client = client,
        _rpcOverride = rpc;

  final SupabaseClient? _client;
  final RpcCaller? _rpcOverride;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<dynamic> _rpc(String function, {Map<String, dynamic>? params}) async {
    final override = _rpcOverride;
    if (override != null) return override(function, params: params);
    return await _db.rpc(function, params: params);
  }

  /// Every workspace the signed-in user can open right now.
  Future<WorkspaceSnapshot> load() async {
    try {
      final rows = await _rpc('my_workspaces');
      final parsed = <Workspace>[];
      if (rows is List) {
        for (final row in rows) {
          if (row is Map) {
            final workspace = Workspace.tryParse(Map<String, dynamic>.from(row));
            if (workspace != null) parsed.add(workspace);
          }
        }
      }
      return WorkspaceSnapshot.ready(parsed);
    } catch (error) {
      return classifyWorkspaceError(error);
    }
  }

  Future<InvitationOutcome> acceptInvitation(String token) async {
    try {
      final rows = await _rpc('accept_invitation', params: {'p_token': token});
      if (rows is List && rows.isNotEmpty && rows.first is Map) {
        return InvitationOutcome.fromDb((rows.first as Map)['outcome']?.toString());
      }
      return InvitationOutcome.failed;
    } catch (_) {
      return InvitationOutcome.failed;
    }
  }
}
