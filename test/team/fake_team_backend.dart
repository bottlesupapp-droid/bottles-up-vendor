import 'dart:async';

import 'package:bottles_up_vendor/features/team/logic/team_rules.dart';
import 'package:bottles_up_vendor/features/team/services/team_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// A stand-in for the website's team functions that behaves the way they do: it keeps invitations and members, hands out a link
/// token only when one is issued, refuses what the database refuses (in its own sentences, raised as P0001), and answers a
/// state in the words the database uses.
class FakeTeamBackend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  final List<Map<String, dynamic>> members = [];
  final List<Map<String, dynamic>> invitations = [];
  final List<Map<String, dynamic>> shifts = [];

  /// The roles the caller may appoint, per club. A club not listed gets [defaultRoles].
  final Map<String, List<String>> rolesByVenue = {};
  List<String> defaultRoles = ['manager', 'server', 'door'];

  Object? failAll;
  void Function(String function)? beforeCall;
  Future<void>? hold;

  /// Every email the fake "server" was asked to send, and what it answers.
  final List<(String, String)> emailed = [];
  EmailOutcome emailAnswer = const EmailOutcome(sent: true);

  int _next = 1;
  String id(String p) => '$p${_next++}';

  TeamService get service => TeamService(rpc: call, emailer: (invitationId, token) async {
        emailed.add((invitationId, token));
        return emailAnswer;
      });

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'list_team':
        return [for (final m in members) Map<String, dynamic>.from(m)];
      case 'list_team_invitations':
        return [for (final i in invitations) Map<String, dynamic>.from(i)];
      case 'list_shifts':
        return [for (final s in shifts) if ((s['venue_id'] ?? 'v1') == p['p_venue']) Map<String, dynamic>.from(s)];
      case 'invitable_roles':
        return rolesByVenue[p['p_venue']] ?? defaultRoles;
      case 'invite_member':
        final email = (p['p_email'] as String).trim().toLowerCase();
        if (!email.contains('@')) throw refuse('valid email required');
        final role = p['p_role'] as String;
        final roles = rolesByVenue[p['p_venue']] ?? defaultRoles;
        if (!roles.contains(role)) throw refuse('not allowed');
        final start = p['p_access_start'] as String?;
        final end = p['p_access_end'] as String?;
        if ((start == null) != (end == null) || (start != null && !DateTime.parse(end!).isAfter(DateTime.parse(start)))) {
          throw refuse('invalid access window');
        }
        final invId = id('i');
        invitations.insert(0, {
          'invitation_id': invId, 'email': email, 'role': role, 'venue_id': p['p_venue'], 'venue_name': 'Club A', 'shift_id': p['p_shift'],
          'access_start_at': start, 'access_end_at': end, 'state': 'pending', 'expires_at': '2031-01-08T12:00:00Z', 'emails_sent': 0,
        });
        return [{'invitation_id': invId, 'token': 'tok-$invId', 'valid_until': '2031-01-08T12:00:00Z'}];
      case 'resend_invitation':
        final i = invitations.indexWhere((x) => x['invitation_id'] == p['p_invitation']);
        if (i < 0) throw refuse('not allowed');
        if (invitations[i]['state'] == 'accepted') throw refuse('already accepted');
        if (invitations[i]['state'] == 'revoked') throw refuse('invitation was revoked');
        invitations[i] = {...invitations[i], 'state': 'pending'};
        return [{'invitation_id': p['p_invitation'], 'token': 'new-${p['p_invitation']}', 'valid_until': '2031-01-15T12:00:00Z'}];
      case 'revoke_invitation':
        final i = invitations.indexWhere((x) => x['invitation_id'] == p['p_invitation']);
        if (i < 0) throw refuse('not allowed');
        if (invitations[i]['state'] != 'pending' && invitations[i]['state'] != 'expired') throw refuse('only a pending invitation can be revoked');
        invitations[i] = {...invitations[i], 'state': 'revoked'};
        return null;
      case 'create_shift':
        final name = (p['p_name'] as String).trim();
        if (name.isEmpty) throw refuse('name required');
        if (!DateTime.parse(p['p_ends'] as String).isAfter(DateTime.parse(p['p_starts'] as String))) throw refuse('new row for relation "site_shifts" violates check constraint "site_shifts_check"');
        final sid = id('s');
        shifts.add(shiftRow(sid, name, venue: p['p_venue'] as String, starts: p['p_starts'] as String, ends: p['p_ends'] as String));
        return sid;
      case 'change_member_role':
        final i = members.indexWhere((x) => x['membership_id'] == p['p_membership']);
        if (i < 0 || members[i]['state'] == 'revoked') throw refuse('membership not found');
        if (members[i]['role'] == 'owner' || members[i]['role'] == 'organizer') throw refuse('not allowed');
        if (members[i]['role'] == p['p_new_role']) throw refuse('they already have that role');
        if (p['p_new_role'] == 'manager' && !(rolesByVenue['v1'] ?? defaultRoles).contains('manager')) throw refuse('not allowed');
        final old = members[i];
        members[i] = {...old, 'state': 'revoked'};
        final nid = id('m');
        members.add({...old, 'membership_id': nid, 'role': p['p_new_role'], 'state': 'active'});
        return nid;
      case 'revoke_membership':
        final i = members.indexWhere((x) => x['membership_id'] == p['p_membership']);
        if (i < 0 || members[i]['state'] == 'revoked') throw refuse('membership not found');
        if (members[i]['role'] == 'owner' || members[i]['role'] == 'organizer') throw refuse('not allowed');
        members[i] = {...members[i], 'state': 'revoked'};
        return null;
    }
    throw StateError('no handler for $function');
  }

  int count(String fn) => calls.where((c) => c.$1 == fn).length;
  List<Map<String, dynamic>?> paramsOf(String fn) => [for (final c in calls) if (c.$1 == fn) c.$2];
}

Map<String, dynamic> memberRow(String id, {String? name, String? email, String role = 'manager', String state = 'active', String? venue = 'Club A', String? start, String? end}) => {
      'membership_id': id, 'user_id': 'u-$id', 'email': email ?? '$id@club.example', 'name': name, 'role': role, 'venue_id': venue == null ? null : 'v1',
      'venue_name': venue, 'state': state, 'access_start_at': start, 'access_end_at': end,
    };

Map<String, dynamic> invitationRow(String id, {String email = 'new@club.example', String role = 'door', String state = 'pending', int sent = 0, String? start, String? end}) => {
      'invitation_id': id, 'email': email, 'role': role, 'venue_id': 'v1', 'venue_name': 'Club A', 'state': state, 'expires_at': '2031-01-08T12:00:00Z',
      'emails_sent': sent, 'access_start_at': start, 'access_end_at': end,
    };

Map<String, dynamic> shiftRow(String id, String name, {String venue = 'v1', String starts = '2031-01-02T20:00:00Z', String ends = '2031-01-03T04:00:00Z'}) =>
    {'shift_id': id, 'venue_id': venue, 'name': name, 'starts_at': starts, 'ends_at': ends, 'event_title': null};
