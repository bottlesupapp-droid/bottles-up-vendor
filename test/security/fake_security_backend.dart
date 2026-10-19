import 'package:bottles_up_vendor/features/security/services/security_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakeAlert {
  FakeAlert(this.id, this.kind, this.location, {this.urgent = false, this.details, this.raisedBy = 'Sam Server', this.raisedByMe = false, DateTime? at, this.status = 'open'})
      : raisedAt = at ?? DateTime.utc(2026, 10, 9, 21, 0);

  final String id;
  final String kind;
  final String location;
  final bool urgent;
  final String? details;
  final String raisedBy;
  final bool raisedByMe;
  final DateTime raisedAt;
  String status;
  String? ackBy;
  bool ackByMe = false;
  String? resolvedBy;
  String? resolution;
  String? escalatedBy;
  String? escalation;
}

class FakeTask {
  FakeTask(this.id, this.title, {this.assignedTo, this.assignedToMe = false, this.status = 'open', this.details});

  final String id;
  final String title;
  final String? details;
  String? assignedTo;
  bool assignedToMe;
  String status;
  String? closingNote;
}

class FakeNote {
  FakeNote(this.author, this.mine, this.body);

  final String author;
  final bool mine;
  final String body;
}

class FakeIncident {
  FakeIncident(this.id, this.kind, this.location, this.details, {this.reportedBy = 'Sid Security', this.reportedByMe = false, this.status = 'submitted', DateTime? at})
      : createdAt = at ?? DateTime.utc(2026, 10, 9, 22, 0);

  final String id;
  final String kind;
  final String location;
  final String details;
  final String reportedBy;
  final bool reportedByMe;
  final DateTime createdAt;
  String status;
  String? reviewedBy;
  String? reviewNote;
  final List<FakeNote> notes = [];
}

/// The database's security functions, as a fake with the same sentences the SQL raises. [role] is who is signed in ('me'): 'security', 'manager' or 'server'.
class FakeSecurityBackend {
  FakeSecurityBackend({this.role = 'security'});

  String role;
  final List<FakeAlert> alerts = [];
  final List<FakeTask> tasks = [];
  final List<FakeIncident> incidents = [];
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;
  DateTime now = DateTime.utc(2026, 10, 9, 22, 30);
  int _ids = 100;

  /// Make the next call to [acknowledgeRace] find the alert already taken by someone else (a race the person lost).
  String? takenByOtherOnNextAcknowledge;

  SecurityService get service => SecurityService(rpc: OpsRpc(rpc: call));

  bool get _manager => role == 'manager';
  bool get _worker => role == 'manager' || role == 'security';

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  FakeAlert _alert(Object? id) => alerts.where((a) => a.id == id).firstOrNull ?? (throw refuse('not allowed'));

  Map<String, dynamic> _alertRow(FakeAlert a) => {
        'alert_id': a.id,
        'kind': a.kind,
        'urgent': a.urgent,
        'location': a.location,
        'details': a.details,
        'status': a.status,
        'raised_by_name': a.raisedBy,
        'raised_by_me': a.raisedByMe,
        'raised_at': a.raisedAt.toIso8601String(),
        'acknowledged_by_name': a.ackBy,
        'acknowledged_at': a.ackBy == null ? null : a.raisedAt.add(const Duration(minutes: 1)).toIso8601String(),
        'resolved_by_name': a.resolvedBy,
        'resolved_at': null,
        'resolution_note': a.resolution,
        'escalated_by_name': a.escalatedBy,
        'escalated_at': null,
        'escalation_note': a.escalation,
        'acknowledged_by_me': a.ackByMe,
        'can_act': _worker,
      };

  Map<String, dynamic> _taskRow(FakeTask t) => {
        'task_id': t.id,
        'title': t.title,
        'details': t.details,
        'status': t.status,
        'assigned_to_name': t.assignedTo,
        'assigned_to_me': t.assignedToMe,
        'unassigned': t.assignedTo == null && !t.assignedToMe,
        'created_by_name': 'Mia Manager',
        'created_at': DateTime.utc(2026, 10, 9, 20).toIso8601String(),
        'closed_by_name': t.status == 'open' ? null : (t.assignedTo ?? 'Sid Security'),
        'closed_at': null,
        'closing_note': t.closingNote,
        'can_manage': _manager,
      };

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    switch (function) {
      case 'security_raise_alert':
        {
          if (role == 'verifier') throw refuse('not allowed');
          if (params!['p_kind'] == null) throw refuse('choose what kind of alert this is');
          final where = (params['p_location'] as String).trim();
          if (where.length < 2) throw refuse('say where it is');
          final a = FakeAlert('a${_ids++}', params['p_kind'] as String, where, urgent: params['p_urgent'] == true, details: params['p_details'] as String?, raisedBy: 'Me', raisedByMe: true, at: now);
          alerts.add(a);
          return a.id;
        }
      case 'security_alerts':
        {
          if (role == 'stranger') throw refuse('not allowed');
          final list = role == 'server' ? alerts.where((a) => a.raisedByMe) : alerts;
          final sorted = [...list]..sort((a, b) {
              final r = (a.status == 'resolved' ? 1 : 0).compareTo(b.status == 'resolved' ? 1 : 0);
              if (r != 0) return r;
              final u = (b.urgent ? 1 : 0).compareTo(a.urgent ? 1 : 0);
              return u != 0 ? u : b.raisedAt.compareTo(a.raisedAt);
            });
          return [for (final a in sorted) _alertRow(a)];
        }
      case 'security_alert_act':
        {
          if (!_worker) throw refuse('not allowed');
          final a = _alert(params!['p_alert']);
          final step = params['p_action'];
          final note = (params['p_note'] as String?)?.trim();
          if (step is! String || !const {'acknowledge', 'respond', 'resolve', 'escalate'}.contains(step)) throw refuse('choose what to do with this alert');
          if (a.status == 'resolved') throw refuse('this alert is already resolved');
          if (step == 'acknowledge') {
            final other = takenByOtherOnNextAcknowledge;
            if (other != null) {
              takenByOtherOnNextAcknowledge = null;
              a.status = 'acknowledged';
              a.ackBy = other;
            }
            if (a.status != 'open') return {'changed': false, 'status': a.status, 'by_name': a.ackBy ?? a.escalatedBy ?? 'Staff member'};
            a.status = 'acknowledged';
            a.ackBy = 'Me';
            a.ackByMe = true;
            return {'changed': true, 'status': 'acknowledged'};
          }
          if (step == 'respond') {
            if (a.status == 'responding') return {'changed': false, 'status': a.status};
            if (a.status == 'open') throw refuse('take the alert first');
            if (a.status == 'escalated') throw refuse('this alert was escalated to a manager');
            a.status = 'responding';
            return {'changed': true, 'status': 'responding'};
          }
          if (step == 'resolve') {
            if (a.status == 'open') throw refuse('take the alert first');
            if (a.status == 'escalated' && !_manager) throw refuse('this alert was escalated: a manager resolves it');
            if (a.status != 'escalated' && !_manager && !a.ackByMe) throw refuse('only the person who took this alert, or a manager, can resolve it');
            if (note == null || note.length < 3) throw refuse('say what was done');
            a.status = 'resolved';
            a.resolvedBy = 'Me';
            a.resolution = note;
            return {'changed': true, 'status': 'resolved'};
          }
          if (a.status == 'escalated') return {'changed': false, 'status': a.status};
          if (note == null || note.length < 3) throw refuse('say why this needs a manager');
          a.status = 'escalated';
          a.escalatedBy = 'Me';
          a.escalation = note;
          return {'changed': true, 'status': 'escalated'};
        }
      case 'security_create_task':
        {
          if (!_manager) throw refuse('not allowed');
          final title = (params!['p_title'] as String).trim();
          if (title.length < 3) throw refuse('say what the task is');
          final assignee = params['p_assignee'] as String?;
          if (assignee != null && assignee != 'sec1' && assignee != 'sec2') throw refuse('a task can only be given to someone on the security team of this club');
          final t = FakeTask('t${_ids++}', title, assignedTo: assignee == null ? null : (assignee == 'sec1' ? 'Sid Security' : 'Sue Security'), details: params['p_details'] as String?);
          tasks.add(t);
          return t.id;
        }
      case 'security_tasks':
        {
          if (!_worker) throw refuse('not allowed');
          return [for (final t in tasks) if (_manager || t.assignedToMe || (t.assignedTo == null)) _taskRow(t)];
        }
      case 'security_task_act':
        {
          if (!_worker) throw refuse('not allowed');
          final t = tasks.where((t) => t.id == params!['p_task']).firstOrNull ?? (throw refuse('not allowed'));
          final step = params!['p_action'];
          if (step is! String || !const {'claim', 'done', 'cancel'}.contains(step)) throw refuse('choose what to do with this task');
          if (t.status != 'open') return {'changed': false, 'status': t.status};
          if (!_manager && t.assignedTo != null && !t.assignedToMe) throw refuse('not allowed');
          if (step == 'claim') {
            if (t.assignedTo != null || t.assignedToMe) return {'changed': false, 'status': 'open'};
            if (!_worker || _manager) throw refuse('only the security team takes tasks');
            t.assignedTo = 'Me';
            t.assignedToMe = true;
            return {'changed': true, 'status': 'open'};
          }
          if (step == 'done') {
            t.status = 'done';
            t.closingNote = params['p_note'] as String?;
            return {'changed': true, 'status': 'done'};
          }
          if (!_manager) throw refuse('only a manager or the owner cancels a task');
          t.status = 'cancelled';
          t.closingNote = params['p_note'] as String?;
          return {'changed': true, 'status': 'cancelled'};
        }
      case 'security_report_incident':
        {
          if (!_worker) throw refuse('not allowed');
          if (params!['p_kind'] == null) throw refuse('choose what kind of incident this is');
          if ((params['p_location'] as String).trim().length < 2) throw refuse('say where it happened');
          final details = (params['p_details'] as String).trim();
          if (details.length < 10) throw refuse('describe what happened (at least 10 characters)');
          final i = FakeIncident('i${_ids++}', params['p_kind'] as String, (params['p_location'] as String).trim(), details, reportedBy: 'Me', reportedByMe: true, at: now);
          incidents.add(i);
          return i.id;
        }
      case 'security_incidents':
        {
          if (!_worker) throw refuse('not allowed');
          final before = params!['p_before'] == null ? null : DateTime.parse(params['p_before'] as String);
          final limit = ((params['p_limit'] as int?) ?? 50).clamp(1, 100);
          final sorted = [...incidents]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return [
            for (final i in sorted.where((i) => before == null || i.createdAt.isBefore(before)).take(limit))
              {
                'incident_id': i.id,
                'business_night': '2026-10-09',
                'kind': i.kind,
                'occurred_at': i.createdAt.toIso8601String(),
                'location': i.location,
                'status': i.status,
                'reported_by_name': i.reportedBy,
                'reported_by_me': i.reportedByMe,
                'created_at': i.createdAt.toIso8601String(),
                'note_count': i.notes.length,
                'reviewed_by_name': i.reviewedBy,
                'reviewed_at': null,
                'can_review': _manager && i.status == 'submitted' && !i.reportedByMe,
              },
          ];
        }
      case 'security_incident_detail':
        {
          if (!_worker) throw refuse('not allowed');
          final i = incidents.where((i) => i.id == params!['p_incident']).firstOrNull ?? (throw refuse('not allowed'));
          return {
            'incident_id': i.id,
            'kind': i.kind,
            'occurred_at': i.createdAt.toIso8601String(),
            'location': i.location,
            'details': i.details,
            'actions_taken': null,
            'status': i.status,
            'reported_by_name': i.reportedBy,
            'reviewed_by_name': i.reviewedBy,
            'review_note': i.reviewNote,
            'can_review': _manager && i.status == 'submitted' && !i.reportedByMe,
            'notes': [for (final n in i.notes) {'author_name': n.author, 'is_mine': n.mine, 'body': n.body, 'created_at': now.toIso8601String()}],
          };
        }
      case 'security_incident_note':
        {
          if (!_worker) throw refuse('not allowed');
          final i = incidents.where((i) => i.id == params!['p_incident']).firstOrNull ?? (throw refuse('not allowed'));
          final body = (params!['p_body'] as String).trim();
          if (body.isEmpty) throw refuse('write the note first');
          if (body.length > 1000) throw refuse('keep a note to 1000 characters or fewer');
          i.notes.add(FakeNote('Me', true, body));
          return 'n${_ids++}';
        }
      case 'security_review_incident':
        {
          if (!_manager) throw refuse('not allowed');
          final i = incidents.where((i) => i.id == params!['p_incident']).firstOrNull ?? (throw refuse('not allowed'));
          if (i.status != 'submitted') throw refuse('this report was already reviewed');
          if (i.reportedByMe) throw refuse('you wrote this report, so someone else has to review it');
          i.status = 'reviewed';
          i.reviewedBy = 'Me';
          i.reviewNote = params!['p_note'] as String?;
          return null;
        }
      case 'security_summary':
        {
          if (!_worker) throw refuse('not allowed');
          return {
            'alerts_unresolved': alerts.where((a) => a.status != 'resolved').length,
            'alerts_waiting': alerts.where((a) => a.status == 'open').length,
            'alerts_urgent': alerts.where((a) => a.urgent && a.status != 'resolved').length,
            'alerts_escalated': alerts.where((a) => a.status == 'escalated').length,
            'tasks_open': tasks.where((t) => t.status == 'open').length,
            'incidents_to_review': incidents.where((i) => i.status == 'submitted').length,
          };
        }
    }
    throw StateError('unexpected call $function');
  }
}
