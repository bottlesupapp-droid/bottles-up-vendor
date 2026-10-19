import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/security/logic/security_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_security_backend.dart';

void main() {
  late FakeSecurityBackend db;
  setUp(() {
    db = FakeSecurityBackend();
  });

  Future<void> expectRefusal(Future<Object?> f, String message) =>
      expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));

  test('raising an alert sends the club, the night, the kind, urgency, a trimmed place and details', () async {
    final id = await db.service.raiseAlert('v1', '2026-10-09', kind: 'fight', urgent: true, location: '  Terrace  ', details: ' two men shouting ');
    expect(db.calledWith('security_raise_alert').single, {
      'p_venue': 'v1',
      'p_night': '2026-10-09',
      'p_kind': 'fight',
      'p_urgent': true,
      'p_location': 'Terrace',
      'p_details': 'two men shouting',
    });
    expect(db.alerts.single.id, id);
    expect(db.calledWith('security_raise_alert').single['p_details'], 'two men shouting');
    await db.service.raiseAlert('v1', '2026-10-09', kind: 'other', urgent: false, location: 'Bar', details: '  ');
    expect(db.calledWith('security_raise_alert').last['p_details'], isNull);
  });

  test('the alerts of a night come back with who took them', () async {
    db.alerts.add(FakeAlert('a1', 'fight', 'Terrace', urgent: true));
    db.alerts.add(FakeAlert('a2', 'medical', 'Dance floor', status: 'resolved'));
    final list = await db.service.alerts('v1', '2026-10-09');
    expect(db.calledWith('security_alerts').single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
    expect(list.map((a) => a.id), ['a1', 'a2'], reason: 'unresolved first');
  });

  test('taking an alert once, and being told who has it when someone was first', () async {
    db.alerts.add(FakeAlert('a1', 'fight', 'Terrace'));
    final first = await db.service.alertStep('a1', AlertStep.acknowledge);
    expect(first.changed, isTrue);
    expect(db.calledWith('security_alert_act').single, {'p_alert': 'a1', 'p_action': 'acknowledge', 'p_note': null});
    final again = await db.service.alertStep('a1', AlertStep.acknowledge);
    expect(again.changed, isFalse);
    db.alerts.add(FakeAlert('a2', 'fight', 'Bar'));
    db.takenByOtherOnNextAcknowledge = 'Sue Security';
    final lost = await db.service.alertStep('a2', AlertStep.acknowledge);
    expect(lost.changed, isFalse);
    expect(lost.byName, 'Sue Security');
  });

  test('the steps in order, with the notes trimmed', () async {
    db.alerts.add(FakeAlert('a1', 'fight', 'Terrace'));
    await expectRefusal(db.service.alertStep('a1', AlertStep.respond), 'Take the alert first.');
    await db.service.alertStep('a1', AlertStep.acknowledge);
    expect((await db.service.alertStep('a1', AlertStep.respond)).status, 'responding');
    await expectRefusal(db.service.alertStep('a1', AlertStep.resolve), 'Say what was done.');
    await db.service.alertStep('a1', AlertStep.resolve, note: '  Separated them  ');
    expect(db.calledWith('security_alert_act').last['p_note'], 'Separated them');
    expect(db.alerts.single.status, 'resolved');
    await expectRefusal(db.service.alertStep('a1', AlertStep.respond), 'This alert is already resolved.');
  });

  test('escalating needs a reason and a manager resolves an escalated alert', () async {
    db.alerts.add(FakeAlert('a1', 'theft', 'Cloakroom'));
    await expectRefusal(db.service.alertStep('a1', AlertStep.escalate), 'Say why this needs a manager.');
    await db.service.alertStep('a1', AlertStep.escalate, note: 'Police may be needed');
    await expectRefusal(db.service.alertStep('a1', AlertStep.resolve, note: 'handled'), 'This alert was escalated: a manager resolves it.');
    db.role = 'manager';
    await db.service.alertStep('a1', AlertStep.resolve, note: 'Bag found');
    expect(db.alerts.single.status, 'resolved');
  });

  test('a server cannot work an alert and sees only their own', () async {
    db.role = 'server';
    db.alerts.add(FakeAlert('a1', 'fight', 'Terrace'));
    await expectRefusal(db.service.alertStep('a1', AlertStep.acknowledge), "You don't have access to do that.");
    expect(await db.service.alerts('v1', '2026-10-09'), isEmpty);
    await db.service.raiseAlert('v1', '2026-10-09', kind: 'other', urgent: false, location: 'Bar');
    expect((await db.service.alerts('v1', '2026-10-09')).single.canAct, isFalse);
  });

  test('tasks: a manager creates one for security; it cannot go to anyone else', () async {
    db.role = 'manager';
    await db.service.createTask('v1', '2026-10-09', title: ' Check the exits ', assigneeId: 'sec1');
    expect(db.calledWith('security_create_task').single, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_title': 'Check the exits', 'p_details': null, 'p_assignee': 'sec1'});
    await expectRefusal(db.service.createTask('v1', '2026-10-09', title: 'Watch the bar', assigneeId: 'a-server'), 'A task can only be given to someone on the security team of this club.');
    await expectRefusal(db.service.createTask('v1', '2026-10-09', title: 'x'), 'Say what the task is.');
    db.role = 'security';
    await expectRefusal(db.service.createTask('v1', '2026-10-09', title: 'Anything at all'), "You don't have access to do that.");
  });

  test('tasks: claim, finish and cancel report whether anything changed', () async {
    db.tasks.add(FakeTask('t1', 'Walk the car park'));
    expect(await db.service.taskStep('t1', TaskStep.claim), isTrue);
    expect(await db.service.taskStep('t1', TaskStep.claim), isFalse);
    expect(await db.service.taskStep('t1', TaskStep.done, note: ' all clear '), isTrue);
    expect(db.calledWith('security_task_act').last['p_note'], 'all clear');
    expect(await db.service.taskStep('t1', TaskStep.done), isFalse);
    db.tasks.add(FakeTask('t2', 'Lock the cellar'));
    await expectRefusal(db.service.taskStep('t2', TaskStep.cancel), 'Only a manager or the owner cancels a task.');
  });

  test('incident reports: sent with the time in UTC, trimmed; refusals in the database\'s words; the list pages by time', () async {
    final at = DateTime(2026, 10, 9, 21, 40);
    await db.service.reportIncident('v1', '2026-10-09', kind: 'fight', occurredAt: at, location: ' Terrace ', details: ' Two guests fought near the bar. ', actionsTaken: '');
    final sent = db.calledWith('security_report_incident').single;
    expect(sent['p_location'], 'Terrace');
    expect(sent['p_details'], 'Two guests fought near the bar.');
    expect(sent['p_actions_taken'], isNull);
    expect(sent['p_occurred_at'], at.toUtc().toIso8601String());
    await expectRefusal(db.service.reportIncident('v1', '2026-10-09', kind: 'fight', occurredAt: at, location: 'Bar', details: 'short'), 'Describe what happened (at least 10 characters).');
    for (var i = 0; i < 3; i++) {
      db.incidents.add(FakeIncident('x$i', 'other', 'Bar', 'Something happened $i', at: DateTime.utc(2026, 10, 9, 10 + i)));
    }
    final page = await db.service.incidents('v1', limit: 2);
    expect(page.length, 2, reason: 'a page of two');
    expect(page.last.id, 'x2', reason: 'newest first: the report just sent, then the latest of the others');
    final older = await db.service.incidents('v1', before: page.last.createdAt);
    expect(older.map((r) => r.id), ['x1', 'x0']);
    expect(db.calledWith('security_incidents').last['p_before'], page.last.createdAt!.toUtc().toIso8601String());
  });

  test('notes and review: a note is added, a report is reviewed once and never by its author', () async {
    db.role = 'manager';
    db.incidents.add(FakeIncident('i1', 'fight', 'Terrace', 'Two guests fought near the bar.'));
    db.incidents.add(FakeIncident('i2', 'property', 'Cloakroom', 'A coat rail was broken.', reportedByMe: true, reportedBy: 'Me'));
    await db.service.addNote('i1', '  Ambulance not needed ');
    expect(db.calledWith('security_incident_note').single, {'p_incident': 'i1', 'p_body': 'Ambulance not needed'});
    expect((await db.service.incident('i1')).notes.single.body, 'Ambulance not needed');
    await expectRefusal(db.service.addNote('i1', ' '), 'Write the note first.');
    await db.service.review('i1', note: 'Followed up');
    await expectRefusal(db.service.review('i1'), 'This report was already reviewed.');
    await expectRefusal(db.service.review('i2'), 'You wrote this report, so someone else has to review it.');
  });

  test('a backend without security says it is not available yet; a dropped connection says to try again', () async {
    db.missing = true;
    await expectLater(db.service.alerts('v1', '2026-10-09'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    db.missing = false;
    db.offline = true;
    await expectLater(db.service.incidents('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
    await expectRefusal(
      db.service.raiseAlert('v1', '2026-10-09', kind: 'fight', urgent: false, location: 'Bar'),
      'The alert could not be sent. Check your connection and try again.',
    );
  });

  test('the summary reads the counts', () async {
    db.alerts.add(FakeAlert('a1', 'fight', 'Terrace', urgent: true));
    db.alerts.add(FakeAlert('a2', 'other', 'Bar', status: 'escalated'));
    db.tasks.add(FakeTask('t1', 'Check'));
    db.incidents.add(FakeIncident('i1', 'fight', 'Bar', 'Something happened here'));
    final s = await db.service.summary('v1', '2026-10-09');
    expect((s.alertsUnresolved, s.alertsWaiting, s.alertsUrgent, s.alertsEscalated, s.tasksOpen, s.incidentsToReview), (2, 1, 1, 1, 1, 1));
  });
}
