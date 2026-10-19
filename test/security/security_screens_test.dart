import 'package:bottles_up_vendor/features/chat/logic/chat_rules.dart';
import 'package:bottles_up_vendor/features/chat/providers/chat_providers.dart';
import 'package:bottles_up_vendor/features/security/providers/security_providers.dart';
import 'package:bottles_up_vendor/features/security/screens/alerts_screen.dart';
import 'package:bottles_up_vendor/features/security/screens/incidents_screen.dart';
import 'package:bottles_up_vendor/features/security/screens/security_hub_screen.dart';
import 'package:bottles_up_vendor/features/security/screens/tasks_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/my_tables_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../server_desk/fake_desk_backend.dart';
import 'fake_security_backend.dart';

late FakeSecurityBackend db;

Workspace ws(WorkspaceRole role) => Workspace(
      membershipId: 'w1',
      orgId: 'o1',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: role,
      venueId: 'v1',
      venueName: 'Club A',
    );

/// Friday evening: the business night is Friday 9 October 2026.
DateTime fridayNight() => DateTime(2026, 10, 9, 22, 0);

final people = [
  const ChatPerson(userId: 'sec1', name: 'Sid Security', role: 'security'),
  const ChatPerson(userId: 'sec2', name: 'Sue Security', role: 'security'),
  const ChatPerson(userId: 'srv1', name: 'Sam Server', role: 'server'),
];

Widget host(Widget child, {Duration poll = const Duration(hours: 1), List<Override> extra = const []}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        securityServiceProvider.overrideWithValue(db.service),
        securityPollIntervalProvider.overrideWithValue(poll),
        chatPeopleProvider.overrideWith((ref, venue) async => people),
        ...extra,
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child, {Duration poll = const Duration(hours: 1), List<Override> extra = const [], double height = 3000}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child, poll: poll, extra: extra));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String statusOf(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('alert-status-$id'))).data!;

void main() {
  setUp(() {
    db = FakeSecurityBackend();
    db.alerts
      ..add(FakeAlert('a1', 'fight', 'Terrace, near the bar', urgent: true, details: 'two men shouting', at: DateTime.utc(2026, 10, 9, 21, 5)))
      ..add(FakeAlert('a2', 'medical', 'Dance floor', raisedBy: 'Sue Security', at: DateTime.utc(2026, 10, 9, 21, 20)));
  });

  Widget alerts([WorkspaceRole role = WorkspaceRole.security]) => AlertsScreen(workspace: ws(role), clock: fridayNight);

  group('Alerts', () {
    testWidgets('lists the night\'s alerts, the urgent one first, with where, who and its state', (tester) async {
      await open(tester, alerts());
      expect(db.calledWith('security_alerts').first, {'p_venue': 'v1', 'p_night': '2026-10-09'});
      expect(find.byKey(const Key('alert-urgent-a1')), findsOneWidget);
      expect(find.byKey(const Key('alert-urgent-a2')), findsNothing);
      expect(tester.getTopLeft(find.byKey(const Key('alert-a1'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('alert-a2'))).dy));
      expect(find.text('Fight'), findsOneWidget);
      expect(find.textContaining('Terrace, near the bar · Sam Server'), findsOneWidget);
      expect(find.text('two men shouting'), findsOneWidget);
      expect(statusOf(tester, 'a1'), 'Waiting for someone to take it');
      expect(tester.widget<Text>(find.byKey(const Key('alerts-summary'))).data, '2 alerts to deal with (1 urgent)');
    });

    testWidgets('taking an alert holds it for you and offers the next steps', (tester) async {
      await open(tester, alerts());
      expect(find.byKey(const Key('alert-acknowledge-a1')), findsOneWidget);
      expect(find.byKey(const Key('alert-resolve-a1')), findsNothing, reason: 'resolving comes after taking it');
      await tapKey(tester, 'alert-acknowledge-a1');
      expect(find.text('You have taken this alert.'), findsOneWidget);
      expect(statusOf(tester, 'a1'), 'Taken by Me');
      expect(find.byKey(const Key('alert-respond-a1')), findsOneWidget);
      expect(find.byKey(const Key('alert-resolve-a1')), findsOneWidget);
      expect(find.byKey(const Key('alert-acknowledge-a1')), findsNothing);
      expect(statusOf(tester, 'a2'), 'Waiting for someone to take it', reason: 'the other alert is untouched');
    });

    testWidgets('if someone else took it first, the person is told who, and does not hold it', (tester) async {
      await open(tester, alerts());
      db.takenByOtherOnNextAcknowledge = 'Sue Security';
      await tapKey(tester, 'alert-acknowledge-a1');
      expect(find.text('Sue Security already has this alert.'), findsOneWidget);
      expect(statusOf(tester, 'a1'), 'Taken by Sue Security');
      expect(find.byKey(const Key('alert-resolve-a1')), findsNothing, reason: 'only the person who took it, or a manager, resolves it');
      expect(find.byKey(const Key('alert-escalate-a1')), findsOneWidget);
    });

    testWidgets('responding then resolving needs to say what was done, and the answer stays on the card', (tester) async {
      await open(tester, alerts());
      await tapKey(tester, 'alert-acknowledge-a1');
      await tapKey(tester, 'alert-respond-a1');
      expect(statusOf(tester, 'a1'), 'Responding: Me');
      await tapKey(tester, 'alert-resolve-a1');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say what was done.'), findsOneWidget);
      expect(db.calledWith('security_alert_act').where((c) => c['p_action'] == 'resolve'), isEmpty, reason: 'nothing is sent without a note');
      await typeIn(tester, 'text-field', 'Separated them, one left');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Resolved.'), findsOneWidget);
      expect(statusOf(tester, 'a1'), 'Resolved by Me');
      expect(find.text('Done: Separated them, one left'), findsOneWidget);
      expect(find.byKey(const Key('alert-resolve-a1')), findsNothing);
      expect(tester.getTopLeft(find.byKey(const Key('alert-a2'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('alert-a1'))).dy), reason: 'a resolved alert sinks below the open ones');
    });

    testWidgets('backing out of the note sends nothing', (tester) async {
      await open(tester, alerts());
      await tapKey(tester, 'alert-escalate-a1');
      await tapKey(tester, 'dialog-back');
      expect(db.calledWith('security_alert_act'), isEmpty);
    });

    testWidgets('escalating needs a reason; then only a manager can resolve it', (tester) async {
      await open(tester, alerts());
      await tapKey(tester, 'alert-escalate-a1');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say why this needs a manager.'), findsOneWidget);
      await typeIn(tester, 'text-field', 'Police may be needed');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Escalated to a manager.'), findsOneWidget);
      expect(statusOf(tester, 'a1'), 'Escalated to a manager by Me');
      expect(find.text('Why: Police may be needed'), findsOneWidget);
      expect(find.byKey(const Key('alert-resolve-a1')), findsNothing, reason: 'security has nothing more to do with it');
      db.role = 'manager';
      await open(tester, alerts(WorkspaceRole.manager));
      expect(find.byKey(const Key('alert-resolve-a1')), findsOneWidget);
    });

    testWidgets('a step the database refuses is shown in its own words, and the list is read again', (tester) async {
      await open(tester, alerts());
      db.alerts.first.status = 'resolved';
      await tapKey(tester, 'alert-acknowledge-a1');
      expect(find.text('This alert is already resolved.'), findsOneWidget);
      expect(statusOf(tester, 'a1'), 'Resolved');
    });

    testWidgets('raising an alert: the kind and the place are needed; then it is sent and shows at the top', (tester) async {
      await open(tester, alerts());
      await tapKey(tester, 'alert-raise');
      await tapKey(tester, 'alert-submit');
      expect(find.text('Choose what kind of alert this is.'), findsOneWidget);
      await tapKey(tester, 'alert-kind-theft');
      await tapKey(tester, 'alert-submit');
      expect(find.text('Say where it is.'), findsOneWidget);
      await typeIn(tester, 'alert-location', 'Cloakroom');
      await typeIn(tester, 'alert-details', 'a bag is missing');
      await tapKey(tester, 'alert-urgent');
      await tapKey(tester, 'alert-submit');
      expect(find.text('Alert sent to security and the manager.'), findsOneWidget);
      final sent = db.calledWith('security_raise_alert').single;
      expect(sent, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_kind': 'theft', 'p_urgent': true, 'p_location': 'Cloakroom', 'p_details': 'a bag is missing'});
      expect(find.text('Theft'), findsOneWidget);
      expect(find.textContaining('Cloakroom · you'), findsOneWidget);
    });

    testWidgets('backing out of the alert form sends nothing', (tester) async {
      await open(tester, alerts());
      await tapKey(tester, 'alert-raise');
      await tapKey(tester, 'alert-back');
      expect(db.calledWith('security_raise_alert'), isEmpty);
    });

    testWidgets('a night with no alerts says so; a backend without security says it is not available', (tester) async {
      db.alerts.clear();
      await open(tester, alerts());
      expect(find.byKey(const Key('alerts-empty')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('alerts-summary'))).data, 'All quiet.');
      db.missing = true;
      await open(tester, alerts());
      expect(find.byKey(const Key('alerts-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
    });

    testWidgets('new alerts arrive on their own without a spinner, and a failed look keeps what is shown', (tester) async {
      await open(tester, alerts(), poll: const Duration(seconds: 10));
      db.alerts.add(FakeAlert('a3', 'crowd', 'Main door', at: DateTime.utc(2026, 10, 9, 21, 40)));
      await tester.pump(const Duration(seconds: 11));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump();
      expect(find.byKey(const Key('alert-a3')), findsOneWidget);
      db.offline = true;
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(find.byKey(const Key('alerts-stale')), findsOneWidget);
      expect(find.byKey(const Key('alert-a3')), findsOneWidget, reason: 'the alerts stay on screen');
      db.offline = false;
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(find.byKey(const Key('alerts-stale')), findsNothing);
    });

    testWidgets('a person with no club has nothing to show, and says so', (tester) async {
      await open(tester, const AlertsScreen(workspace: Workspace(membershipId: 'w', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.security)));
      expect(find.byKey(const Key('alerts-no-venue')), findsOneWidget);
    });
  });

  group('Tasks', () {
    Widget tasks([WorkspaceRole role = WorkspaceRole.security]) => TasksScreen(workspace: ws(role), clock: fridayNight);

    testWidgets('a manager gives a task to someone on security: only security staff are offered', (tester) async {
      db.role = 'manager';
      await open(tester, tasks(WorkspaceRole.manager));
      await tapKey(tester, 'task-new');
      await tapKey(tester, 'task-save');
      expect(find.text('Say what the task is.'), findsOneWidget);
      await typeIn(tester, 'task-title', 'Check the fire exits');
      await tapKey(tester, 'task-assignee');
      expect(find.text('Sid Security'), findsWidgets);
      expect(find.text('Sam Server'), findsNothing, reason: 'a server cannot be given a security task');
      await tester.tap(find.text('Sid Security').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'task-save');
      expect(find.text('Task added.'), findsOneWidget);
      expect(db.calledWith('security_create_task').single, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_title': 'Check the fire exits', 'p_details': null, 'p_assignee': 'sec1'});
      expect(find.text('Check the fire exits'), findsOneWidget);
      expect(find.text('For: Sid Security'), findsOneWidget);
    });

    testWidgets('a task can be left for anyone on security', (tester) async {
      db.role = 'manager';
      await open(tester, tasks(WorkspaceRole.manager));
      await tapKey(tester, 'task-new');
      await typeIn(tester, 'task-title', 'Walk the car park at 2am');
      await tapKey(tester, 'task-save');
      expect(db.calledWith('security_create_task').single['p_assignee'], isNull);
      expect(find.text('For: Anyone on security'), findsOneWidget);
    });

    testWidgets('security does not see a New task button; it takes an open task, then finishes it', (tester) async {
      db.tasks.add(FakeTask('t1', 'Walk the car park'));
      await open(tester, tasks());
      expect(find.byKey(const Key('task-new')), findsNothing);
      await tapKey(tester, 'task-claim-t1');
      expect(find.text('You have taken this task.'), findsOneWidget);
      expect(find.text('For: You'), findsOneWidget);
      expect(find.byKey(const Key('task-claim-t1')), findsNothing);
      await tapKey(tester, 'task-done-t1');
      expect(find.text('Marked done.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('task-status-t1'))).data, 'Done by Me');
      expect(find.byKey(const Key('task-done-t1')), findsNothing);
    });

    testWidgets('security does not see a task given to someone else', (tester) async {
      db.tasks.add(FakeTask('t1', 'Check the fire exits', assignedTo: 'Sue Security'));
      db.tasks.add(FakeTask('t2', 'Mine', assignedTo: 'Me', assignedToMe: true));
      await open(tester, tasks());
      expect(find.byKey(const Key('task-t1')), findsNothing);
      expect(find.byKey(const Key('task-t2')), findsOneWidget);
    });

    testWidgets('a manager cancels a task with an optional reason', (tester) async {
      db.role = 'manager';
      db.tasks.add(FakeTask('t1', 'Lock the cellar'));
      await open(tester, tasks(WorkspaceRole.manager));
      expect(find.byKey(const Key('task-claim-t1')), findsNothing, reason: 'a manager does not take security tasks');
      await tapKey(tester, 'task-cancel-t1');
      await typeIn(tester, 'text-field', 'Not needed tonight');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Task cancelled.'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('task-status-t1'))).data, 'Cancelled: Not needed tonight');
    });

    testWidgets('a task that was dealt with elsewhere says nothing changed', (tester) async {
      db.tasks.add(FakeTask('t1', 'Walk the car park'));
      await open(tester, tasks());
      db.tasks.first.status = 'done';
      await tapKey(tester, 'task-claim-t1');
      expect(find.text('Nothing changed: this task was already dealt with.'), findsOneWidget);
    });

    testWidgets('no tasks is said in words, differently for a manager', (tester) async {
      await open(tester, tasks());
      expect(find.text('No tasks for you tonight.'), findsOneWidget);
      db.role = 'manager';
      await open(tester, tasks(WorkspaceRole.manager));
      expect(find.textContaining('Add one for the security team'), findsOneWidget);
    });
  });

  group('Incidents', () {
    Widget incidents([WorkspaceRole role = WorkspaceRole.security]) => IncidentsScreen(workspace: ws(role), clock: fridayNight);

    testWidgets('lists the reports newest first with who wrote them and whether they were reviewed', (tester) async {
      db.incidents
        ..add(FakeIncident('i1', 'fight', 'Terrace', 'Two guests fought near the bar.', at: DateTime.utc(2026, 10, 9, 21)))
        ..add(FakeIncident('i2', 'property', 'Cloakroom', 'A coat rail was broken.', reportedBy: 'Mia Manager', status: 'reviewed', at: DateTime.utc(2026, 10, 9, 22)));
      await open(tester, incidents());
      expect(find.text('Property damage · Cloakroom'), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('incident-i2'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('incident-i1'))).dy));
      expect(tester.widget<Text>(find.byKey(const Key('incident-status-i2'))).data, 'Reviewed');
      expect(tester.widget<Text>(find.byKey(const Key('incident-status-i1'))).data, 'Submitted');
    });

    testWidgets('a manager is shown which reports are theirs to review', (tester) async {
      db.role = 'manager';
      db.incidents
        ..add(FakeIncident('i1', 'fight', 'Terrace', 'Two guests fought near the bar.'))
        ..add(FakeIncident('i2', 'property', 'Cloakroom', 'A coat rail was broken.', reportedByMe: true, reportedBy: 'Me', at: DateTime.utc(2026, 10, 9, 23)));
      await open(tester, incidents(WorkspaceRole.manager));
      expect(tester.widget<Text>(find.byKey(const Key('incident-status-i1'))).data, 'To review');
      expect(tester.widget<Text>(find.byKey(const Key('incident-status-i2'))).data, 'Submitted', reason: 'not their own');
    });

    testWidgets('an empty list and a missing backend are said in words', (tester) async {
      await open(tester, incidents());
      expect(find.byKey(const Key('incidents-empty')), findsOneWidget);
      db.missing = true;
      await open(tester, incidents());
      expect(find.byKey(const Key('incidents-error')), findsOneWidget);
    });

    testWidgets('reporting: what is missing is said, a refusal keeps everything typed, and a sent report appears in the list', (tester) async {
      await open(tester, incidents());
      await tapKey(tester, 'incident-report');
      await tapKey(tester, 'incident-send');
      expect(find.text('Choose what kind of incident this is.'), findsOneWidget);
      await tapKey(tester, 'incident-kind-fight');
      await typeIn(tester, 'incident-location', 'Terrace');
      await typeIn(tester, 'incident-details', 'short');
      await tapKey(tester, 'incident-send');
      expect(find.text('Describe what happened (at least 10 characters).'), findsOneWidget);
      await typeIn(tester, 'incident-details', 'Two guests fought near the bar; one had a cut lip.');
      await typeIn(tester, 'incident-actions', 'Separated them, first aid given');
      await tapKey(tester, 'incident-when-30');
      db.offline = true;
      await tapKey(tester, 'incident-send');
      expect(find.byKey(const Key('incident-problem')), findsOneWidget);
      expect(find.textContaining('Check your connection and try again'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('incident-details'))).controller!.text, 'Two guests fought near the bar; one had a cut lip.', reason: 'nothing typed was lost');
      db.offline = false;
      await tapKey(tester, 'incident-send');
      expect(find.text('Incident report sent and kept.'), findsOneWidget);
      final sent = db.calledWith('security_report_incident').last;
      expect(sent['p_kind'], 'fight');
      expect(sent['p_night'], '2026-10-09');
      expect(sent['p_actions_taken'], 'Separated them, first aid given');
      expect(DateTime.parse(sent['p_occurred_at'] as String), fridayNight().subtract(const Duration(minutes: 30)).toUtc());
      expect(find.text('Fight · Terrace'), findsOneWidget, reason: 'back on the list, with the new report');
    });

    testWidgets('a report opens with its notes; a note can be added and is shown; the report itself has no edit', (tester) async {
      final i = FakeIncident('i1', 'fight', 'Terrace', 'Two guests fought near the bar; one had a cut lip.');
      i.notes.add(FakeNote('Sid Security', false, 'Ambulance was not needed'));
      db.incidents.add(i);
      await open(tester, incidents());
      await tapKey(tester, 'incident-i1');
      expect(find.byKey(const Key('incident-detail-text')), findsOneWidget);
      expect(find.text('Ambulance was not needed'), findsOneWidget);
      expect(find.text('Not reviewed yet.'), findsOneWidget);
      expect(find.byKey(const Key('incident-review')), findsNothing, reason: 'security does not review');
      await tapKey(tester, 'incident-note-add');
      expect(find.text('Write the note first.'), findsOneWidget);
      await typeIn(tester, 'incident-note-field', 'Both guests left by taxi');
      await tapKey(tester, 'incident-note-add');
      expect(find.text('Both guests left by taxi'), findsOneWidget);
      expect(find.textContaining('You ·'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('a manager marks someone else\'s report reviewed; it then says by whom, and the button is gone', (tester) async {
      db.role = 'manager';
      db.incidents.add(FakeIncident('i1', 'fight', 'Terrace', 'Two guests fought near the bar; one had a cut lip.'));
      await open(tester, incidents(WorkspaceRole.manager));
      await tapKey(tester, 'incident-i1');
      await tapKey(tester, 'incident-review');
      await typeIn(tester, 'text-field', 'Followed up with both guests');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Marked as reviewed.'), findsOneWidget);
      expect(find.text('Reviewed by Me: Followed up with both guests'), findsOneWidget);
      expect(find.byKey(const Key('incident-review')), findsNothing);
    });

    testWidgets('a manager is not offered to review their own report', (tester) async {
      db.role = 'manager';
      db.incidents.add(FakeIncident('i1', 'property', 'Cloakroom', 'A coat rail was broken at closing.', reportedByMe: true, reportedBy: 'Me'));
      await open(tester, incidents(WorkspaceRole.manager));
      await tapKey(tester, 'incident-i1');
      expect(find.byKey(const Key('incident-review')), findsNothing);
    });

    testWidgets('long histories load a page at a time', (tester) async {
      for (var n = 0; n < 60; n++) {
        db.incidents.add(FakeIncident('i$n', 'other', 'Bar $n', 'Something happened, number $n.', at: DateTime.utc(2026, 9, 1).add(Duration(hours: n))));
      }
      await open(tester, incidents(), height: 12000);
      expect(find.byKey(const Key('incidents-more')), findsOneWidget);
      expect(find.byKey(const Key('incident-i0')), findsNothing, reason: 'the oldest are not loaded yet');
      await tester.ensureVisible(find.byKey(const Key('incidents-more')));
      await tapKey(tester, 'incidents-more');
      expect(find.byKey(const Key('incident-i0')), findsOneWidget);
      expect(find.byKey(const Key('incidents-more')), findsNothing);
    });
  });

  testWidgets('the manager\'s Security hub has Alerts, Tasks and Incidents', (tester) async {
    db.role = 'manager';
    await open(tester, SecurityHubScreen(workspace: ws(WorkspaceRole.manager), clock: fridayNight));
    expect(find.text('Alerts'), findsWidgets);
    expect(find.byKey(const Key('alerts-list')), findsOneWidget);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tasks-list')), findsOneWidget);
    await tester.tap(find.text('Incidents'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('incidents-list')), findsOneWidget);
  });

  testWidgets('a server can call security from My Tables: the alert goes to the club', (tester) async {
    final desk = FakeDeskBackend()..now = DateTime(2026, 10, 9, 21, 30);
    db.role = 'server';
    await open(
      tester,
      MyTablesScreen(workspace: ws(WorkspaceRole.server), clock: fridayNight),
      extra: [serverDeskServiceProvider.overrideWithValue(desk.service)],
    );
    await tapKey(tester, 'call-security');
    await tapKey(tester, 'alert-kind-intoxicated');
    await typeIn(tester, 'alert-location', 'VIP booth 3');
    await tapKey(tester, 'alert-submit');
    expect(find.text('Alert sent to security and the manager.'), findsOneWidget);
    expect(db.calledWith('security_raise_alert').single['p_location'], 'VIP booth 3');
    expect(db.calledWith('security_raise_alert').single['p_night'], '2026-10-09');
  });
}
