import '../../ops/services/ops_rpc.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/security_rules.dart';

/// The calls to the website's security functions (website repo, 20261018130000_security.sql). The database decides who may raise, take,
/// resolve or escalate an alert, that each step happens once, and that an incident report is kept; nothing here decides any of it.
class SecurityService {
  SecurityService({OpsRpc? rpc, RpcCaller? caller}) : _rpc = rpc ?? OpsRpc(rpc: caller);

  final OpsRpc _rpc;

  Future<String> raiseAlert(String venueId, String night, {required String kind, required bool urgent, required String location, String? details}) =>
      _rpc.act(() async {
        final data = await _rpc.call('security_raise_alert', {
          'p_venue': venueId,
          'p_night': night,
          'p_kind': kind,
          'p_urgent': urgent,
          'p_location': location.trim(),
          'p_details': details == null || details.trim().isEmpty ? null : details.trim(),
        });
        return data.toString();
      }, generic: 'The alert could not be sent. Check your connection and try again.');

  Future<List<SecurityAlert>> alerts(String venueId, String night) =>
      _rpc.list('security_alerts', {'p_venue': venueId, 'p_night': night}, parseAlert, 'alerts');

  Future<AlertOutcome> alertStep(String alertId, AlertStep step, {String? note}) => _rpc.act(() async {
        final data = await _rpc.call('security_alert_act', {
          'p_alert': alertId,
          'p_action': step.id,
          'p_note': note == null || note.trim().isEmpty ? null : note.trim(),
        });
        return parseAlertOutcome(data);
      }, generic: 'That could not be done. Check your connection and try again.');

  Future<String> createTask(String venueId, String night, {required String title, String? details, String? assigneeId}) => _rpc.act(() async {
        final data = await _rpc.call('security_create_task', {
          'p_venue': venueId,
          'p_night': night,
          'p_title': title.trim(),
          'p_details': details == null || details.trim().isEmpty ? null : details.trim(),
          'p_assignee': assigneeId,
        });
        return data.toString();
      }, generic: 'The task could not be saved. Check your connection and try again.');

  Future<List<SecurityTask>> tasks(String venueId, String night) =>
      _rpc.list('security_tasks', {'p_venue': venueId, 'p_night': night}, parseTask, 'tasks');

  /// Returns whether anything changed (a repeated tap changes nothing).
  Future<bool> taskStep(String taskId, TaskStep step, {String? note}) => _rpc.act(() async {
        final data = await _rpc.call('security_task_act', {
          'p_task': taskId,
          'p_action': step.id,
          'p_note': note == null || note.trim().isEmpty ? null : note.trim(),
        });
        return data is Map && data['changed'] == true;
      }, generic: 'That could not be done. Check your connection and try again.');

  Future<String> reportIncident(
    String venueId,
    String night, {
    required String kind,
    required DateTime occurredAt,
    required String location,
    required String details,
    String? actionsTaken,
  }) =>
      _rpc.act(() async {
        final data = await _rpc.call('security_report_incident', {
          'p_venue': venueId,
          'p_night': night,
          'p_kind': kind,
          'p_occurred_at': occurredAt.toUtc().toIso8601String(),
          'p_location': location.trim(),
          'p_details': details.trim(),
          'p_actions_taken': actionsTaken == null || actionsTaken.trim().isEmpty ? null : actionsTaken.trim(),
        });
        return data.toString();
      }, generic: 'The report could not be sent. Check your connection and try again. Nothing was lost: your text is still on the screen.');

  Future<List<IncidentRow>> incidents(String venueId, {DateTime? before, int limit = 50}) => _rpc.list(
        'security_incidents',
        {'p_venue': venueId, 'p_limit': limit, 'p_before': before?.toUtc().toIso8601String()},
        parseIncidentRow,
        'incident reports',
      );

  Future<IncidentDetail> incident(String incidentId) =>
      _rpc.one('security_incident_detail', {'p_incident': incidentId}, parseIncidentDetail, 'the incident report');

  Future<void> addNote(String incidentId, String body) => _rpc.act(() async {
        await _rpc.call('security_incident_note', {'p_incident': incidentId, 'p_body': body.trim()});
      }, generic: 'The note could not be saved. Check your connection and try again.');

  Future<void> review(String incidentId, {String? note}) => _rpc.act(() async {
        await _rpc.call('security_review_incident', {'p_incident': incidentId, 'p_note': note == null || note.trim().isEmpty ? null : note.trim()});
      }, generic: 'The review could not be saved. Check your connection and try again.');

  Future<SecuritySummary> summary(String venueId, String night) =>
      _rpc.one('security_summary', {'p_venue': venueId, 'p_night': night}, parseSecuritySummary, 'the security summary');
}
