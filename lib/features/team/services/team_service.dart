import 'package:supabase_flutter/supabase_flutter.dart';

import '../../owner/services/db_errors.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/team_rules.dart';

/// Loading the team failed. Carries what the screen needs to say, not a stack trace.
class TeamLoadException implements Exception {
  const TeamLoadException({required this.unavailable, required this.accessEnded});

  /// The backend has not been given the team migration yet. Nothing the person can fix.
  final bool unavailable;

  /// The database says this person no longer has access (removed, access ended, signed out).
  final bool accessEnded;

  String get message {
    if (unavailable) return 'The team is not set up on this server yet.';
    if (accessEnded) return 'Your access has ended, or you are signed out.';
    return 'The team could not be loaded. Check your connection and try again.';
  }

  @override
  String toString() => 'TeamLoadException($message)';
}

/// An invitation or a removal was refused or failed; the message is a plain sentence for the person.
class TeamActionException implements Exception {
  const TeamActionException(this.message);

  final String message;

  @override
  String toString() => 'TeamActionException($message)';
}

/// The link of an invitation. The database keeps only a hash of the token, so it exists only now and cannot be shown again.
class IssuedLink {
  const IssuedLink({required this.invitationId, required this.token});

  final String invitationId;
  final String token;
}

/// Asks the server to email an invitation link. Replaced in tests; in the app it is the `send-team-invitation` edge function,
/// which runs as the signed-in person and can only email the address stored on the invitation.
typedef EmailSender = Future<EmailOutcome> Function(String invitationId, String token);

/// The Team screen's calls to the website's database functions (`list_team`, `list_team_invitations`, `list_shifts`,
/// `invitable_roles`, `invite_member`, `resend_invitation`, `revoke_invitation`, `revoke_membership`, `change_member_role`, `create_shift`, defined in the website repo's
/// 20261006120000_tenancy_foundation.sql and 20261008100000_team_invitations.sql). They check in the database what this person may
/// see and do: an owner sees everyone, a manager only the staff of their own club. Nothing here decides that.
class TeamService {
  TeamService({SupabaseClient? client, RpcCaller? rpc, EmailSender? emailer})
      : _client = client,
        _rpcOverride = rpc,
        _emailer = emailer;

  final SupabaseClient? _client;
  final RpcCaller? _rpcOverride;
  final EmailSender? _emailer;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<dynamic> _rpc(String function, {Map<String, dynamic>? params}) async {
    final override = _rpcOverride;
    if (override != null) return override(function, params: params);
    return await _db.rpc(function, params: params);
  }

  List<Map<String, dynamic>> _rows(dynamic data) => data is List
      ? [
          for (final r in data)
            if (r is Map) Map<String, dynamic>.from(r),
        ]
      : const [];

  Future<List<T>> _list<T>(String function, Map<String, dynamic> params, T? Function(Map<String, dynamic>) parse) async {
    try {
      return _rows(await _rpc(function, params: params)).map(parse).whereType<T>().toList();
    } catch (error) {
      throw TeamLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error));
    }
  }

  Future<T> _act<T>(Future<T> Function() call, {String generic = 'This could not be done. Check your connection and try again.'}) async {
    try {
      return await call();
    } on TeamActionException {
      rethrow;
    } catch (error) {
      throw TeamActionException(sentence(actionMessage(error, generic: generic)));
    }
  }

  Future<List<TeamMember>> team(String orgId) => _list('list_team', {'p_org': orgId}, parseTeamMember);

  Future<List<TeamInvitation>> invitations(String orgId) => _list('list_team_invitations', {'p_org': orgId}, parseTeamInvitation);

  /// The shifts of a club, for the invite form's picker. A failure is an empty list: a shift is optional.
  Future<List<Shift>> shifts(String venueId) async {
    try {
      return _rows(await _rpc('list_shifts', params: {'p_venue': venueId})).map(parseShift).whereType<Shift>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// The roles this person may appoint at this club, as decided by the database.
  Future<List<String>> invitableRoles(String orgId, String venueId) async {
    try {
      final data = await _rpc('invitable_roles', params: {'p_org': orgId, 'p_venue': venueId});
      return data is List ? [for (final r in data) if (r is String) r] : const [];
    } catch (error) {
      throw TeamLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error));
    }
  }

  IssuedLink _issued(dynamic data, String? fallbackId, String failure) {
    final rows = _rows(data);
    final row = rows.isEmpty ? null : rows.first;
    final token = row?['token'];
    final id = row?['invitation_id'] ?? fallbackId;
    if (token is String && token.isNotEmpty && id is String && id.isNotEmpty) return IssuedLink(invitationId: id, token: token);
    throw TeamActionException(failure);
  }

  Future<IssuedLink> invite(String orgId, InvitePayload payload) => _act(() async {
        final data = await _rpc('invite_member', params: inviteParams(orgId, payload));
        return _issued(data, null, 'The invitation could not be created.');
      });

  /// A new link for an invitation that is waiting or has expired. The old link stops working.
  Future<IssuedLink> sendNewLink(String invitationId) => _act(() async {
        final data = await _rpc('resend_invitation', params: {'p_invitation': invitationId});
        return _issued(data, invitationId, 'A new link could not be created.');
      });

  Future<void> cancelInvitation(String invitationId) => _act(
        () async => await _rpc('revoke_invitation', params: {'p_invitation': invitationId}),
        generic: 'The invitation could not be cancelled. Try again.',
      );

  Future<void> removeMember(String membershipId) => _act(
        () async => await _rpc('revoke_membership', params: {'p_membership': membershipId}),
        generic: 'Access could not be removed. Try again.',
      );

  /// Moves someone to another role at the same club in one step: the old access ends and the new one starts now. The database applies the
  /// same rules as inviting and removing, so a manager is refused what only an owner may do.
  Future<void> changeRole(String membershipId, String newRole) => _act(
        () async => await _rpc('change_member_role', params: {'p_membership': membershipId, 'p_new_role': newRole}),
        generic: 'The role could not be changed. Try again.',
      );

  /// A shift at a club (a night or part of one) that people can be invited to. Times are sent in UTC.
  Future<String> createShift(String venueId, String name, DateTime startsAt, DateTime endsAt) => _act(
        () async {
          final data = await _rpc('create_shift', params: {
            'p_venue': venueId,
            'p_name': name.trim(),
            'p_starts': startsAt.toUtc().toIso8601String(),
            'p_ends': endsAt.toUtc().toIso8601String(),
          });
          return data.toString();
        },
        generic: 'The shift could not be saved. Try again.',
      );

  /// Emails the link to the address on the invitation. Never throws: the invitation already exists and the screen shows the link
  /// either way, so the only question is what to say about the email.
  Future<EmailOutcome> emailInvitation(String invitationId, String token) async {
    try {
      final custom = _emailer;
      if (custom != null) return await custom(invitationId, token);
      final response = await _db.functions.invoke('send-team-invitation', body: {'invitation_id': invitationId, 'token': token});
      return emailOutcomeFromResponse(response.data);
    } on FunctionException catch (e) {
      return emailOutcomeFromStatus(e.status);
    } catch (_) {
      return const EmailOutcome(sent: false, reason: 'send_failed');
    }
  }
}

/// The database writes short lower-case sentences for developers ("invalid access window"). This makes one a sentence for a person.
String sentence(String message) {
  final t = message.trim();
  if (t.isEmpty) return 'Please try again.';
  final s = t[0].toUpperCase() + t.substring(1);
  return RegExp(r'[.!?]$').hasMatch(s) ? s : '$s.';
}
