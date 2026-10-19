import 'package:bottles_up_vendor/features/door_staff/services/door_staff_service.dart';
import 'package:bottles_up_vendor/features/team/services/team_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../team/fake_team_backend.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

/// The website's organizer door staff functions (20261020130000_organizer_door_staff.sql) as a fake with the same sentences and the same rule: an
/// invitation for an event is refused unless the event has no club or the club has allowed door staff on its approved agreement. The team calls
/// (list_team, invite_member, revoke_membership, ...) are the existing fake team backend's, with the rule put in front of invite_member.
class FakeDoorStaffBackend {
  final FakeTeamBackend team = FakeTeamBackend();
  final List<(String, Map<String, dynamic>?)> calls = [];

  /// organizer_event_door_status rows: event_id, event_title, state, agreement_id, club_name.
  final List<Map<String, dynamic>> statuses = [];

  /// venue_door_permissions rows, by venue: agreement_id, event_id, event_title, event_start, organizer_name, agreement_status, approved, door_staff_allowed.
  final Map<String, List<Map<String, dynamic>>> permissions = {};

  /// venue_event_door_staff rows, by venue: membership_id, invitation_id, event_id, event_title, organizer_name, person, state, access_start_at, access_end_at.
  final Map<String, List<Map<String, dynamic>>> clubStaff = {};

  Object? failAll;
  Object? failTeam;
  void Function(String function)? beforeCall;
  Future<void>? hold;

  DoorStaffService get doorService => DoorStaffService(caller: call);

  TeamService get teamService => TeamService(rpc: teamCall, emailer: (invitationId, token) async {
        team.emailed.add((invitationId, token));
        return team.emailAnswer;
      });

  Future<dynamic> teamCall(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failTeam;
    if (broken != null && (function == 'list_team' || function == 'list_team_invitations')) throw broken;
    final p = params ?? const {};
    if (function == 'invite_member' && p['p_event'] != null) {
      final s = statuses.where((x) => x['event_id'] == p['p_event']).toList();
      final state = s.isEmpty ? 'own_event' : s.first['state'];
      if (state != 'own_event' && state != 'allowed') throw refuse('the club has not allowed door staff for this event');
      final out = await team.call(function, params: params);
      final inv = team.invitations.first;
      inv['event_id'] = p['p_event'];
      inv['event_title'] = s.isEmpty ? 'Event' : s.first['event_title'];
      inv['venue_id'] = null;
      inv['venue_name'] = null;
      return out;
    }
    return team.call(function, params: params);
  }

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final broken = failAll;
    if (broken != null) throw broken;
    beforeCall?.call(function);
    final waiting = hold;
    if (waiting != null) await waiting;
    final p = params ?? const {};
    switch (function) {
      case 'organizer_event_door_status':
        return [for (final s in statuses) Map<String, dynamic>.from(s)];
      case 'venue_door_permissions':
        return [for (final x in permissions[p['p_venue']] ?? const <Map<String, dynamic>>[]) Map<String, dynamic>.from(x)];
      case 'venue_event_door_staff':
        return [for (final x in clubStaff[p['p_venue']] ?? const <Map<String, dynamic>>[]) Map<String, dynamic>.from(x)];
      case 'set_organizer_door_staff':
        for (final list in permissions.values) {
          for (final x in list) {
            if (x['agreement_id'] == p['p_agreement']) {
              if (p['p_allowed'] == null) throw refuse('choose yes or no');
              x['door_staff_allowed'] = p['p_allowed'];
              return p['p_allowed'];
            }
          }
        }
        throw refuse('not allowed');
      case 'revoke_event_door_access':
        final m = p['p_membership'];
        final i = p['p_invitation'];
        if ((m == null) == (i == null)) throw refuse('choose one person or one invitation');
        for (final list in clubStaff.values) {
          final at = list.indexWhere((x) => (m != null && x['membership_id'] == m) || (i != null && x['invitation_id'] == i));
          if (at >= 0) {
            list.removeAt(at);
            return null;
          }
        }
        throw refuse('not allowed');
    }
    throw StateError('no handler for $function');
  }

  int count(String fn) => calls.where((c) => c.$1 == fn).length;
  List<Map<String, dynamic>?> paramsOf(String fn) => [for (final c in calls) if (c.$1 == fn) c.$2];
}

Map<String, dynamic> statusRow(String id, String title, String state, {String? club, String? agreement}) =>
    {'event_id': id, 'event_title': title, 'state': state, 'agreement_id': agreement, 'club_name': club};

Map<String, dynamic> permissionRow(String agreement, String event, String title, {String organizer = 'Night Events', bool approved = true, bool allowed = false, String start = '2031-10-24T22:00:00Z'}) => {
      'agreement_id': agreement, 'event_id': event, 'event_title': title, 'event_start': start, 'organizer_name': organizer,
      'agreement_status': approved ? 'active' : 'requested', 'approved': approved, 'door_staff_allowed': allowed,
    };

Map<String, dynamic> clubStaffRow({String? member, String? invitation, String event = 'e1', String title = 'Rooftop Sessions', String organizer = 'Night Events', String person = 'Dan Door', String state = 'active'}) => {
      'membership_id': member, 'invitation_id': invitation, 'event_id': event, 'event_title': title, 'organizer_name': organizer, 'person': person, 'state': state,
      'access_start_at': null, 'access_end_at': null,
    };
