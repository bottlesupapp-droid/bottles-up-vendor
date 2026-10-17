import 'package:bottles_up_vendor/features/security/logic/security_rules.dart';
import 'package:flutter_test/flutter_test.dart';

SecurityAlert alert({String status = 'open', bool mine = false, bool canAct = true, bool urgent = false}) => SecurityAlert(
      id: 'a',
      kind: 'fight',
      urgent: urgent,
      location: 'Terrace',
      status: status,
      raisedByName: 'Sam',
      raisedByMe: false,
      acknowledgedByMe: mine,
      canAct: canAct,
      acknowledgedByName: status == 'open' ? null : 'Sid',
    );

SecurityTask task({String status = 'open', bool unassigned = false, bool mine = false, bool manage = false}) =>
    SecurityTask(id: 't', title: 'x', status: status, unassigned: unassigned, assignedToMe: mine, canManage: manage, assignedToName: unassigned ? null : 'Sid');

void main() {
  group('reading what the database sends', () {
    test('an alert row', () {
      final a = parseAlert({
        'alert_id': 'a1',
        'kind': 'fight',
        'urgent': true,
        'location': 'Terrace',
        'details': 'two men shouting',
        'status': 'acknowledged',
        'raised_by_name': 'Sam Server',
        'raised_by_me': false,
        'raised_at': '2026-10-09T21:00:00Z',
        'acknowledged_by_name': 'Sid Security',
        'acknowledged_by_me': true,
        'can_act': true,
      })!;
      expect(a.urgent, isTrue);
      expect(a.acknowledgedByMe, isTrue);
      expect(a.statusLabel, 'Taken by Sid Security');
      expect(kindLabel(a.kind), 'Fight');
    });

    test('rows without an id are dropped; odd values do not crash', () {
      expect(parseAlert({'kind': 'fight'}), isNull);
      expect(parseTask({'title': 'x'}), isNull);
      expect(parseIncidentRow({'kind': 'fight'}), isNull);
      expect(parseIncidentDetail({'kind': 'fight'}), isNull);
      final a = parseAlert({'alert_id': 'a'})!;
      expect(a.location, '');
      expect(a.status, 'open');
      expect(a.canAct, isFalse);
    });

    test('every status reads as a sentence', () {
      expect(alert(status: 'open').statusLabel, 'Waiting for someone to take it');
      expect(alert(status: 'responding').statusLabel, 'Responding: Sid');
      expect(alert(status: 'resolved').statusLabel, 'Resolved');
      expect(alert(status: 'escalated').statusLabel, 'Escalated to a manager');
    });

    test('an incident with its notes', () {
      final d = parseIncidentDetail({
        'incident_id': 'i',
        'kind': 'fight',
        'location': 'Terrace',
        'details': 'Two guests fought.',
        'status': 'reviewed',
        'reviewed_by_name': 'Mia',
        'can_review': false,
        'notes': [
          {'author_name': 'Sid', 'is_mine': true, 'body': 'Ambulance not needed', 'created_at': '2026-10-09T22:00:00Z'},
          {'body': 'no author'},
        ],
      })!;
      expect(d.reviewed, isTrue);
      expect(d.notes, hasLength(2));
      expect(d.notes.first.isMine, isTrue);
      expect(d.notes.last.authorName, 'Staff member');
    });
  });

  group('which steps an alert offers (the database still decides)', () {
    List<String> steps(SecurityAlert a, {bool manager = false}) => [for (final s in alertSteps(a, isManager: manager)) s.id];

    test('open: take it, or escalate', () {
      expect(steps(alert()), ['acknowledge', 'escalate']);
    });
    test('taken by me: respond, resolve, escalate; taken by someone else: only escalate (a manager can do all)', () {
      expect(steps(alert(status: 'acknowledged', mine: true)), ['respond', 'resolve', 'escalate']);
      expect(steps(alert(status: 'acknowledged')), ['escalate']);
      expect(steps(alert(status: 'acknowledged'), manager: true), ['respond', 'resolve', 'escalate']);
    });
    test('responding: resolve or escalate', () {
      expect(steps(alert(status: 'responding', mine: true)), ['resolve', 'escalate']);
      expect(steps(alert(status: 'responding')), ['escalate']);
    });
    test('escalated: only a manager resolves it', () {
      expect(steps(alert(status: 'escalated')), isEmpty);
      expect(steps(alert(status: 'escalated'), manager: true), ['resolve']);
    });
    test('resolved, or an alert that cannot be worked (a server\'s own): nothing', () {
      expect(steps(alert(status: 'resolved'), manager: true), isEmpty);
      expect(steps(alert(canAct: false)), isEmpty);
    });
    test('resolve and escalate need a note; the others do not', () {
      expect(AlertStep.values.where((s) => s.needsNote).map((s) => s.id), ['resolve', 'escalate']);
    });
  });

  group('what a person typed', () {
    test('an alert needs a kind and a place', () {
      expect(checkAlertForm(kind: null, location: 'Bar', details: ''), 'Choose what kind of alert this is.');
      expect(checkAlertForm(kind: 'fight', location: ' x', details: ''), 'Say where it is.');
      expect(checkAlertForm(kind: 'fight', location: 'x' * 201, details: ''), 'Keep the location to 200 characters or fewer.');
      expect(checkAlertForm(kind: 'fight', location: 'Bar', details: 'x' * 1001), 'Keep the details to 1000 characters or fewer.');
      expect(checkAlertForm(kind: 'fight', location: 'Bar', details: ''), isNull);
    });
    test('a step note', () {
      expect(checkStepNote(AlertStep.resolve, ' ok'), 'Say what was done.');
      expect(checkStepNote(AlertStep.escalate, ''), 'Say why this needs a manager.');
      expect(checkStepNote(AlertStep.resolve, 'Separated them'), isNull);
      expect(checkStepNote(AlertStep.resolve, 'x' * 501), 'Keep the note to 500 characters or fewer.');
      expect(checkStepNote(AlertStep.acknowledge, ''), isNull);
    });
    test('a task', () {
      expect(checkTaskForm(title: 'x', details: ''), 'Say what the task is.');
      expect(checkTaskForm(title: 'x' * 121, details: ''), 'Keep the title to 120 characters or fewer.');
      expect(checkTaskForm(title: 'Check exits', details: 'x' * 501), 'Keep the details to 500 characters or fewer.');
      expect(checkTaskForm(title: 'Check exits', details: ''), isNull);
    });
    test('an incident', () {
      expect(checkIncidentForm(kind: null, location: 'Bar', details: 'Something happened here', actions: ''), 'Choose what kind of incident this is.');
      expect(checkIncidentForm(kind: 'fight', location: '', details: 'Something happened here', actions: ''), 'Say where it happened.');
      expect(checkIncidentForm(kind: 'fight', location: 'Bar', details: 'short', actions: ''), 'Describe what happened (at least 10 characters).');
      expect(checkIncidentForm(kind: 'fight', location: 'Bar', details: 'x' * 2001, actions: ''), 'Keep the details to 2000 characters or fewer.');
      expect(checkIncidentForm(kind: 'fight', location: 'Bar', details: 'Something happened here', actions: 'x' * 1001), 'Keep what was done to 1000 characters or fewer.');
      expect(checkIncidentForm(kind: 'fight', location: 'Bar', details: 'Something happened here', actions: ''), isNull);
      expect(checkIncidentNote(' '), 'Write the note first.');
      expect(checkIncidentNote('x' * 1001), 'Keep a note to 1000 characters or fewer.');
      expect(checkIncidentNote('later fact'), isNull);
    });
    test('the times an incident can be placed at are all within what the database accepts (3 days)', () {
      expect(whenOptions.every((w) => w.minutesAgo <= 3 * 24 * 60), isTrue);
      expect(whenOptions.first.minutesAgo, 0);
    });
  });

  group('tasks', () {
    List<String> steps(SecurityTask t) => [for (final s in taskSteps(t)) s.id];
    test('security takes an unassigned task, finishes their own, and has nothing on someone else\'s', () {
      expect(steps(task(unassigned: true)), ['claim', 'done']);
      expect(steps(task(mine: true)), ['done']);
      expect(steps(task()), isEmpty);
    });
    test('a manager finishes or cancels; nothing once it is closed', () {
      expect(steps(task(manage: true)), ['done', 'cancel']);
      expect(steps(task(manage: true, status: 'done')), isEmpty);
    });
    test('who it is for', () {
      expect(task(unassigned: true).assigneeLabel, 'Anyone on security');
      expect(task(mine: true).assigneeLabel, 'You');
      expect(task().assigneeLabel, 'Sid');
    });
  });

  group('outcomes and the night at a glance', () {
    test('what the person is told after a step', () {
      expect(alertOutcomeMessage(AlertStep.acknowledge, const AlertOutcome(changed: true, status: 'acknowledged')), 'You have taken this alert.');
      expect(alertOutcomeMessage(AlertStep.acknowledge, const AlertOutcome(changed: false, status: 'acknowledged', byName: 'Sid')), 'Sid already has this alert.');
      expect(alertOutcomeMessage(AlertStep.respond, const AlertOutcome(changed: false, status: 'responding')), 'Nothing changed: this alert is already responding.');
      expect(alertOutcomeMessage(AlertStep.resolve, const AlertOutcome(changed: true, status: 'resolved')), 'Resolved.');
      expect(alertOutcomeMessage(AlertStep.escalate, const AlertOutcome(changed: true, status: 'escalated')), 'Escalated to a manager.');
    });
    test('the summary line', () {
      expect(securitySummaryLine(const SecuritySummary()), 'All quiet.');
      expect(securitySummaryLine(const SecuritySummary(alertsUnresolved: 1)), '1 alert to deal with');
      expect(
        securitySummaryLine(const SecuritySummary(alertsUnresolved: 3, alertsUrgent: 1, alertsEscalated: 1, tasksOpen: 2, incidentsToReview: 1)),
        '3 alerts to deal with (1 urgent) · 1 escalated · 2 tasks open · 1 report to review',
      );
      expect(const SecuritySummary(incidentsToReview: 1).needsAttention, isTrue);
      expect(const SecuritySummary(tasksOpen: 4).needsAttention, isFalse);
    });
    test('an outcome of nothing is read as nothing changed', () {
      expect(parseAlertOutcome(null).changed, isFalse);
      expect(parseAlertOutcome({'changed': true, 'status': 'resolved'}).status, 'resolved');
    });
  });
}
