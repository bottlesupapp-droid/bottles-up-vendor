import 'package:intl/intl.dart';

import '../../ops/logic/ops_json.dart';

/// Security: alerts, tasks and incident reports. Who may raise, take, resolve or escalate, that each step happens once, that a report is
/// kept and nobody reviews their own, and that security sees nothing about money are the database's rules. This file reads what it sends
/// and checks what a person typed before it is sent.

class KindOption {
  const KindOption(this.id, this.label);

  final String id;
  final String label;
}

const List<KindOption> alertKinds = [
  KindOption('fight', 'Fight'),
  KindOption('medical', 'Medical'),
  KindOption('intoxicated', 'Intoxicated guest'),
  KindOption('theft', 'Theft'),
  KindOption('crowd', 'Crowd'),
  KindOption('other', 'Other'),
];

const List<KindOption> incidentKinds = [
  KindOption('fight', 'Fight'),
  KindOption('medical', 'Medical'),
  KindOption('intoxicated', 'Intoxicated guest'),
  KindOption('theft', 'Theft'),
  KindOption('harassment', 'Harassment'),
  KindOption('weapon', 'Weapon'),
  KindOption('crowd', 'Crowd'),
  KindOption('property', 'Property damage'),
  KindOption('other', 'Other'),
];

String kindLabel(String id) => [...alertKinds, ...incidentKinds].where((k) => k.id == id).firstOrNull?.label ?? id;

// -------------------------------------------------------------------------------------------------------------------------------------
// Alerts
// -------------------------------------------------------------------------------------------------------------------------------------

class SecurityAlert {
  const SecurityAlert({
    required this.id,
    required this.kind,
    required this.urgent,
    required this.location,
    required this.status,
    required this.raisedByName,
    required this.raisedByMe,
    required this.acknowledgedByMe,
    required this.canAct,
    this.details,
    this.raisedAt,
    this.acknowledgedByName,
    this.acknowledgedAt,
    this.resolvedByName,
    this.resolvedAt,
    this.resolutionNote,
    this.escalatedByName,
    this.escalatedAt,
    this.escalationNote,
  });

  final String id;
  final String kind;
  final bool urgent;
  final String location;
  final String? details;

  /// 'open', 'acknowledged', 'responding', 'resolved' or 'escalated'.
  final String status;
  final String raisedByName;
  final bool raisedByMe;
  final DateTime? raisedAt;
  final String? acknowledgedByName;
  final DateTime? acknowledgedAt;
  final bool acknowledgedByMe;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final String? escalatedByName;
  final DateTime? escalatedAt;
  final String? escalationNote;

  /// Security, manager and owner can work an alert; a server only sees the ones they raised.
  final bool canAct;

  bool get resolved => status == 'resolved';

  String get statusLabel => switch (status) {
        'open' => 'Waiting for someone to take it',
        'acknowledged' => acknowledgedByName == null ? 'Taken' : 'Taken by $acknowledgedByName',
        'responding' => acknowledgedByName == null ? 'Responding' : 'Responding: $acknowledgedByName',
        'resolved' => resolvedByName == null ? 'Resolved' : 'Resolved by $resolvedByName',
        'escalated' => escalatedByName == null ? 'Escalated to a manager' : 'Escalated to a manager by $escalatedByName',
        _ => status,
      };
}

SecurityAlert? parseAlert(Map<String, dynamic> r) {
  final id = opsStr(r, 'alert_id');
  if (id == null) return null;
  return SecurityAlert(
    id: id,
    kind: opsStr(r, 'kind') ?? 'other',
    urgent: opsBool(r, 'urgent'),
    location: opsStr(r, 'location') ?? '',
    details: opsStr(r, 'details'),
    status: opsStr(r, 'status') ?? 'open',
    raisedByName: opsStr(r, 'raised_by_name') ?? 'Staff member',
    raisedByMe: opsBool(r, 'raised_by_me'),
    raisedAt: opsTime(r, 'raised_at'),
    acknowledgedByName: opsStr(r, 'acknowledged_by_name'),
    acknowledgedAt: opsTime(r, 'acknowledged_at'),
    acknowledgedByMe: opsBool(r, 'acknowledged_by_me'),
    resolvedByName: opsStr(r, 'resolved_by_name'),
    resolvedAt: opsTime(r, 'resolved_at'),
    resolutionNote: opsStr(r, 'resolution_note'),
    escalatedByName: opsStr(r, 'escalated_by_name'),
    escalatedAt: opsTime(r, 'escalated_at'),
    escalationNote: opsStr(r, 'escalation_note'),
    canAct: opsBool(r, 'can_act'),
  );
}

enum AlertStep {
  acknowledge('acknowledge', 'Take it', needsNote: false),
  respond('respond', 'I\'m responding', needsNote: false),
  resolve('resolve', 'Resolve', needsNote: true),
  escalate('escalate', 'Escalate to manager', needsNote: true);

  const AlertStep(this.id, this.label, {required this.needsNote});

  final String id;
  final String label;
  final bool needsNote;

  /// What the dialog asks for, when [needsNote].
  String get noteQuestion => this == AlertStep.resolve ? 'What was done?' : 'Why does this need a manager?';
}

/// The steps to offer on an alert, in order. Only a hint: the database refuses a step that is not allowed (and a step already taken
/// changes nothing). Security who did not take an alert can only escalate it; an escalated alert is the manager's to resolve.
List<AlertStep> alertSteps(SecurityAlert a, {required bool isManager}) {
  if (!a.canAct || a.resolved) return const [];
  final mine = isManager || a.acknowledgedByMe;
  return switch (a.status) {
    'open' => const [AlertStep.acknowledge, AlertStep.escalate],
    'acknowledged' => mine ? const [AlertStep.respond, AlertStep.resolve, AlertStep.escalate] : const [AlertStep.escalate],
    'responding' => mine ? const [AlertStep.resolve, AlertStep.escalate] : const [AlertStep.escalate],
    'escalated' => isManager ? const [AlertStep.resolve] : const [],
    _ => const [],
  };
}

/// What the database said about a step: whether it changed anything, and if not, who had got there first.
class AlertOutcome {
  const AlertOutcome({required this.changed, required this.status, this.byName});

  final bool changed;
  final String status;
  final String? byName;
}

AlertOutcome parseAlertOutcome(Object? data) {
  final m = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  return AlertOutcome(changed: opsBool(m, 'changed'), status: opsStr(m, 'status') ?? '', byName: opsStr(m, 'by_name'));
}

/// The sentence shown after a step.
String alertOutcomeMessage(AlertStep step, AlertOutcome o) {
  if (!o.changed) {
    if (step == AlertStep.acknowledge && o.byName != null) return '${o.byName} already has this alert.';
    return 'Nothing changed: this alert is already ${o.status == 'acknowledged' ? 'taken' : o.status}.';
  }
  return switch (step) {
    AlertStep.acknowledge => 'You have taken this alert.',
    AlertStep.respond => 'Marked as responding.',
    AlertStep.resolve => 'Resolved.',
    AlertStep.escalate => 'Escalated to a manager.',
  };
}

String? checkAlertForm({required String? kind, required String location, required String details}) {
  if (kind == null) return 'Choose what kind of alert this is.';
  final where = location.trim();
  if (where.length < 2) return 'Say where it is.';
  if (where.length > 200) return 'Keep the location to 200 characters or fewer.';
  if (details.trim().length > 1000) return 'Keep the details to 1000 characters or fewer.';
  return null;
}

/// A note for a step that needs one: at least three characters, at most 500.
String? checkStepNote(AlertStep step, String note) {
  final text = note.trim();
  if (!step.needsNote) return text.length > 500 ? 'Keep the note to 500 characters or fewer.' : null;
  if (text.length < 3) return step == AlertStep.resolve ? 'Say what was done.' : 'Say why this needs a manager.';
  if (text.length > 500) return 'Keep the note to 500 characters or fewer.';
  return null;
}

// -------------------------------------------------------------------------------------------------------------------------------------
// Tasks
// -------------------------------------------------------------------------------------------------------------------------------------

class SecurityTask {
  const SecurityTask({
    required this.id,
    required this.title,
    required this.status,
    required this.unassigned,
    required this.assignedToMe,
    required this.canManage,
    this.details,
    this.assignedToName,
    this.createdByName,
    this.closedByName,
    this.closedAt,
    this.closingNote,
  });

  final String id;
  final String title;
  final String? details;

  /// 'open', 'done' or 'cancelled'.
  final String status;
  final String? assignedToName;
  final bool unassigned;
  final bool assignedToMe;
  final String? createdByName;
  final String? closedByName;
  final DateTime? closedAt;
  final String? closingNote;
  final bool canManage;

  bool get open => status == 'open';

  String get assigneeLabel => unassigned ? 'Anyone on security' : (assignedToMe ? 'You' : assignedToName ?? 'Someone');
}

SecurityTask? parseTask(Map<String, dynamic> r) {
  final id = opsStr(r, 'task_id');
  if (id == null) return null;
  return SecurityTask(
    id: id,
    title: opsStr(r, 'title') ?? 'Task',
    details: opsStr(r, 'details'),
    status: opsStr(r, 'status') ?? 'open',
    assignedToName: opsStr(r, 'assigned_to_name'),
    unassigned: opsBool(r, 'unassigned'),
    assignedToMe: opsBool(r, 'assigned_to_me'),
    createdByName: opsStr(r, 'created_by_name'),
    closedByName: opsStr(r, 'closed_by_name'),
    closedAt: opsTime(r, 'closed_at'),
    closingNote: opsStr(r, 'closing_note'),
    canManage: opsBool(r, 'can_manage'),
  );
}

enum TaskStep {
  claim('claim', 'Take it'),
  done('done', 'Done'),
  cancel('cancel', 'Cancel');

  const TaskStep(this.id, this.label);

  final String id;
  final String label;
}

/// The buttons on a task, as a hint (the database decides): security takes an unassigned one and finishes theirs; a manager cancels.
List<TaskStep> taskSteps(SecurityTask t) {
  if (!t.open) return const [];
  if (t.canManage) return const [TaskStep.done, TaskStep.cancel];
  if (t.unassigned) return const [TaskStep.claim, TaskStep.done];
  return t.assignedToMe ? const [TaskStep.done] : const [];
}

String? checkTaskForm({required String title, required String details}) {
  final t = title.trim();
  if (t.length < 3) return 'Say what the task is.';
  if (t.length > 120) return 'Keep the title to 120 characters or fewer.';
  if (details.trim().length > 500) return 'Keep the details to 500 characters or fewer.';
  return null;
}

// -------------------------------------------------------------------------------------------------------------------------------------
// Incidents
// -------------------------------------------------------------------------------------------------------------------------------------

class IncidentRow {
  const IncidentRow({
    required this.id,
    required this.kind,
    required this.location,
    required this.status,
    required this.reportedByName,
    required this.reportedByMe,
    required this.noteCount,
    required this.canReview,
    this.occurredAt,
    this.createdAt,
    this.reviewedByName,
  });

  final String id;
  final String kind;
  final String location;
  final DateTime? occurredAt;
  final DateTime? createdAt;

  /// 'submitted' or 'reviewed'.
  final String status;
  final String reportedByName;
  final bool reportedByMe;
  final int noteCount;
  final String? reviewedByName;
  final bool canReview;

  bool get reviewed => status == 'reviewed';
}

IncidentRow? parseIncidentRow(Map<String, dynamic> r) {
  final id = opsStr(r, 'incident_id');
  if (id == null) return null;
  return IncidentRow(
    id: id,
    kind: opsStr(r, 'kind') ?? 'other',
    location: opsStr(r, 'location') ?? '',
    occurredAt: opsTime(r, 'occurred_at'),
    createdAt: opsTime(r, 'created_at'),
    status: opsStr(r, 'status') ?? 'submitted',
    reportedByName: opsStr(r, 'reported_by_name') ?? 'Staff member',
    reportedByMe: opsBool(r, 'reported_by_me'),
    noteCount: opsInt(r, 'note_count'),
    reviewedByName: opsStr(r, 'reviewed_by_name'),
    canReview: opsBool(r, 'can_review'),
  );
}

class IncidentNote {
  const IncidentNote({required this.authorName, required this.isMine, required this.body, this.createdAt});

  final String authorName;
  final bool isMine;
  final String body;
  final DateTime? createdAt;
}

class IncidentDetail {
  const IncidentDetail({
    required this.id,
    required this.kind,
    required this.location,
    required this.details,
    required this.status,
    required this.reportedByName,
    required this.canReview,
    required this.notes,
    this.occurredAt,
    this.actionsTaken,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNote,
  });

  final String id;
  final String kind;
  final String location;
  final DateTime? occurredAt;
  final String details;
  final String? actionsTaken;
  final String status;
  final String reportedByName;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final bool canReview;
  final List<IncidentNote> notes;

  bool get reviewed => status == 'reviewed';
}

IncidentDetail? parseIncidentDetail(Map<String, dynamic> r) {
  final id = opsStr(r, 'incident_id');
  if (id == null) return null;
  final notes = r['notes'];
  return IncidentDetail(
    id: id,
    kind: opsStr(r, 'kind') ?? 'other',
    location: opsStr(r, 'location') ?? '',
    occurredAt: opsTime(r, 'occurred_at'),
    details: r['details']?.toString() ?? '',
    actionsTaken: opsStr(r, 'actions_taken'),
    status: opsStr(r, 'status') ?? 'submitted',
    reportedByName: opsStr(r, 'reported_by_name') ?? 'Staff member',
    reviewedByName: opsStr(r, 'reviewed_by_name'),
    reviewedAt: opsTime(r, 'reviewed_at'),
    reviewNote: opsStr(r, 'review_note'),
    canReview: opsBool(r, 'can_review'),
    notes: [
      if (notes is List)
        for (final n in notes)
          if (n is Map)
            IncidentNote(
              authorName: opsStr(Map<String, dynamic>.from(n), 'author_name') ?? 'Staff member',
              isMine: n['is_mine'] == true,
              body: n['body']?.toString() ?? '',
              createdAt: opsTime(Map<String, dynamic>.from(n), 'created_at'),
            ),
    ],
  );
}

/// How long ago an incident happened, chosen from a short list: the database accepts any time within three days, but at the end of a
/// shift people mean "a little while ago".
class WhenOption {
  const WhenOption(this.id, this.label, this.minutesAgo);

  final String id;
  final String label;
  final int minutesAgo;
}

const List<WhenOption> whenOptions = [
  WhenOption('now', 'Just now', 0),
  WhenOption('15', '15 minutes ago', 15),
  WhenOption('30', '30 minutes ago', 30),
  WhenOption('60', 'An hour ago', 60),
  WhenOption('120', 'Two hours ago', 120),
  WhenOption('240', 'Four hours ago', 240),
];

String? checkIncidentForm({required String? kind, required String location, required String details, required String actions}) {
  if (kind == null) return 'Choose what kind of incident this is.';
  final where = location.trim();
  if (where.length < 2) return 'Say where it happened.';
  if (where.length > 200) return 'Keep the location to 200 characters or fewer.';
  final what = details.trim();
  if (what.length < 10) return 'Describe what happened (at least 10 characters).';
  if (what.length > 2000) return 'Keep the details to 2000 characters or fewer.';
  if (actions.trim().length > 1000) return 'Keep what was done to 1000 characters or fewer.';
  return null;
}

String? checkIncidentNote(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'Write the note first.';
  if (t.length > 1000) return 'Keep a note to 1000 characters or fewer.';
  return null;
}

// -------------------------------------------------------------------------------------------------------------------------------------
// The night at a glance
// -------------------------------------------------------------------------------------------------------------------------------------

class SecuritySummary {
  const SecuritySummary({this.alertsUnresolved = 0, this.alertsWaiting = 0, this.alertsUrgent = 0, this.alertsEscalated = 0, this.tasksOpen = 0, this.incidentsToReview = 0});

  final int alertsUnresolved;
  final int alertsWaiting;
  final int alertsUrgent;
  final int alertsEscalated;
  final int tasksOpen;
  final int incidentsToReview;

  bool get needsAttention => alertsUnresolved > 0 || incidentsToReview > 0;
}

SecuritySummary? parseSecuritySummary(Map<String, dynamic> r) => SecuritySummary(
      alertsUnresolved: opsInt(r, 'alerts_unresolved'),
      alertsWaiting: opsInt(r, 'alerts_waiting'),
      alertsUrgent: opsInt(r, 'alerts_urgent'),
      alertsEscalated: opsInt(r, 'alerts_escalated'),
      tasksOpen: opsInt(r, 'tasks_open'),
      incidentsToReview: opsInt(r, 'incidents_to_review'),
    );

/// "2 alerts to deal with (1 urgent) · 1 report to review", or that all is quiet.
String securitySummaryLine(SecuritySummary s) {
  final parts = <String>[
    if (s.alertsUnresolved > 0) '${s.alertsUnresolved} ${s.alertsUnresolved == 1 ? 'alert' : 'alerts'} to deal with${s.alertsUrgent > 0 ? ' (${s.alertsUrgent} urgent)' : ''}',
    if (s.alertsEscalated > 0) '${s.alertsEscalated} escalated',
    if (s.tasksOpen > 0) '${s.tasksOpen} ${s.tasksOpen == 1 ? 'task' : 'tasks'} open',
    if (s.incidentsToReview > 0) '${s.incidentsToReview} ${s.incidentsToReview == 1 ? 'report' : 'reports'} to review',
  ];
  return parts.isEmpty ? 'All quiet.' : parts.join(' · ');
}

String securityTime(DateTime? at) => at == null ? '' : DateFormat('HH:mm').format(at.toLocal());
