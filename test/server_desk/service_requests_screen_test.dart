import 'dart:async';

import 'package:bottles_up_vendor/features/server_desk/logic/server_desk_rules.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/service_requests_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_desk_backend.dart';

late FakeDeskBackend db;

Workspace workspace(WorkspaceRole role, {String? venueId = 'v1'}) => Workspace(
      membershipId: 'w1',
      orgId: 'o1',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: role,
      venueId: venueId,
      venueName: 'Club A',
    );

DateTime nineThirty() => DateTime(2026, 10, 9, 21, 30);

Widget host({WorkspaceRole role = WorkspaceRole.server, String? venueId = 'v1', ReasonPicker? reason}) => ProviderScope(
      key: UniqueKey(),
      overrides: [serverDeskServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ServiceRequestsScreen(workspace: workspace(role, venueId: venueId), clock: nineThirty, pickReason: reason ?? (c, a) async => null),
        ),
      ),
    );

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// The arguments of the last move sent to the database (the list is read again after every move, so "the last call" is not it).
Map<String, dynamic>? lastMove() => db.calls.lastWhere((c) => c.$1 == 'update_service_request').$2;

void main() {
  setUp(() {
    db = FakeDeskBackend();
    db.now = DateTime(2026, 10, 9, 21, 30);
    db.addBooking('b1', code: 'AB12CD', name: 'Ada Lovelace');
    db.addBooking('b2', table: 'Dance floor table', name: 'Grace Hopper', code: 'EF34GH');
    db.assignments['b1'] = 'm-me';
    db.assignments['b2'] = 'm-colleague';
    db.staff['m-colleague'] = 'ok';
  });

  testWidgets('lists the server\'s requests, the longest wait first, with what each needs to be understood', (tester) async {
    db.addRequest('b1', 'bill_request', assigned: 'm-me', createdAt: DateTime(2026, 10, 9, 21, 25), rid: 'late');
    db.addRequest('b1', 'water_ice_mixers', assigned: 'm-me', note: 'two limes', createdAt: DateTime(2026, 10, 9, 20, 10), rid: 'early');
    await open(tester, host());
    expect(db.calls.first.$1, 'list_service_requests');
    expect(db.params.first, {'p_venue': 'v1', 'p_include_closed': false});
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Club A'), findsOneWidget);
    final order = tester.getTopLeft(find.byKey(const Key('request-early'))).dy < tester.getTopLeft(find.byKey(const Key('request-late'))).dy;
    expect(order, isTrue, reason: 'the request that has waited longest is on top');
    expect(find.text('Water, ice or mixers'), findsOneWidget);
    expect(find.text('VIP booth · Ada Lovelace · AB12CD'), findsNWidgets(2));
    expect(find.byKey(const Key('note-early')), findsOneWidget);
    expect(find.text('“two limes”'), findsOneWidget);
    expect(find.text('Waiting 1 h 20 min · You'), findsOneWidget);
    expect(find.text('Waiting 5 min · You'), findsOneWidget);
    expect(find.text('New'), findsNWidgets(2));
  });

  testWidgets('a server is not shown a colleague\'s table', (tester) async {
    db.addRequest('b2', 'assistance', assigned: 'm-colleague', rid: 'theirs');
    db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'mine');
    await open(tester, host());
    expect(find.byKey(const Key('request-mine')), findsOneWidget);
    expect(find.byKey(const Key('request-theirs')), findsNothing);
  });

  testWidgets('a request for a table nobody has is shown, as "Nobody yet"', (tester) async {
    db.assignments.remove('b2');
    db.addRequest('b2', 'assistance', rid: 'free');
    await open(tester, host());
    expect(find.text('Waiting just now · Nobody yet'), findsOneWidget);
  });

  testWidgets('nothing to do says so', (tester) async {
    await open(tester, host());
    expect(find.byKey(const Key('requests-empty')), findsOneWidget);
    expect(find.text('Nothing needs your attention.'), findsOneWidget);
  });

  testWidgets('taking a request: Acknowledged, with the next buttons', (tester) async {
    db.addRequest('b1', 'water_ice_mixers', assigned: 'm-me', rid: 'r1');
    await open(tester, host());
    expect([for (final a in ['acknowledge', 'complete', 'escalate', 'cancel']) find.byKey(Key('act-r1-$a')).evaluate().isNotEmpty], [true, true, true, true]);
    expect(find.byKey(const Key('act-r1-start')), findsNothing);
    expect(find.text('Take it'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tapKey(tester, 'act-r1-acknowledge');
    expect(lastMove(), {'p_request': 'r1', 'p_action': 'acknowledge', 'p_note': null});
    expect(find.text('Acknowledged'), findsOneWidget);
    expect(find.byKey(const Key('act-r1-start')), findsOneWidget);
    expect(find.byKey(const Key('act-r1-acknowledge')), findsNothing);

    await tapKey(tester, 'act-r1-start');
    expect(find.text('In progress'), findsOneWidget);
    await tapKey(tester, 'act-r1-complete');
    expect(db.requests.single.status, 'completed');
    expect(find.byKey(const Key('request-r1')), findsNothing, reason: 'finished requests are hidden unless asked for');
    expect(find.byKey(const Key('requests-empty')), findsOneWidget);
  });

  testWidgets('passing a request to a manager asks for a reason first, then it is read only', (tester) async {
    db.addRequest('b1', 'order_question', assigned: 'm-me', rid: 'r1');
    RequestAction? asked;
    await open(tester, host(reason: (c, a) async {
      asked = a;
      return 'guest wants the owner';
    }));
    await tapKey(tester, 'act-r1-escalate');
    expect(asked, RequestAction.escalate);
    expect(lastMove(), {'p_request': 'r1', 'p_action': 'escalate', 'p_note': 'guest wants the owner'});
    expect(find.text('Escalated'), findsOneWidget);
    expect(find.byKey(const Key('passed-r1')), findsOneWidget);
    expect(find.text('Passed to a manager.'), findsOneWidget);
    expect(find.text('Reason: guest wants the owner'), findsOneWidget);
    for (final a in RequestAction.values) {
      expect(find.byKey(Key('act-r1-${a.value}')), findsNothing, reason: a.value);
    }
  });

  testWidgets('backing out of the reason sends nothing', (tester) async {
    db.addRequest('b1', 'order_question', assigned: 'm-me', rid: 'r1');
    await open(tester, host());
    await tapKey(tester, 'act-r1-cancel');
    expect(db.calls.where((c) => c.$1 == 'update_service_request'), isEmpty);
    expect(db.requests.single.status, 'new');
    expect(find.byType(SnackBar), findsNothing, reason: 'backing out is not an error');
  });

  testWidgets('cancelling asks for a reason and records it', (tester) async {
    db.addRequest('b1', 'table_issue', assigned: 'm-me', rid: 'r1');
    RequestAction? asked;
    await open(tester, host(reason: (c, a) async {
      asked = a;
      return 'guest left';
    }));
    await tapKey(tester, 'act-r1-cancel');
    expect(asked, RequestAction.cancel);
    expect(db.requests.single.status, 'cancelled');
    expect(db.requests.single.statusNote, 'guest left');
  });

  testWidgets('the real reason dialog: it insists on a reason and on a sensible length', (tester) async {
    db.addRequest('b1', 'table_issue', assigned: 'm-me', rid: 'r1');
    await open(
      tester,
      ProviderScope(
        key: UniqueKey(),
        overrides: [serverDeskServiceProvider.overrideWithValue(db.service)],
        child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: ServiceRequestsScreen(workspace: workspace(WorkspaceRole.server), clock: nineThirty))),
      ),
    );
    await tapKey(tester, 'act-r1-escalate');
    expect(find.text('Pass this to a manager'), findsOneWidget);
    await tapKey(tester, 'reason-confirm');
    expect(find.text('Say why.'), findsOneWidget);
    expect(db.calls.where((c) => c.$1 == 'update_service_request'), isEmpty);
    await tester.enterText(find.byKey(const Key('reason-field')), 'x' * 301);
    await tapKey(tester, 'reason-confirm');
    expect(find.text('Keep it to 300 characters or fewer.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reason-field')), '  needs the owner ');
    await tester.pump();
    expect(find.text('Keep it to 300 characters or fewer.'), findsNothing, reason: 'typing clears the complaint');
    await tapKey(tester, 'reason-confirm');
    expect(lastMove(), {'p_request': 'r1', 'p_action': 'escalate', 'p_note': 'needs the owner'});
    expect(find.text('Escalated'), findsOneWidget);
  });

  testWidgets('the real reason dialog can be backed out of', (tester) async {
    db.addRequest('b1', 'table_issue', assigned: 'm-me', rid: 'r1');
    await open(
      tester,
      ProviderScope(
        key: UniqueKey(),
        overrides: [serverDeskServiceProvider.overrideWithValue(db.service)],
        child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: ServiceRequestsScreen(workspace: workspace(WorkspaceRole.server), clock: nineThirty))),
      ),
    );
    await tapKey(tester, 'act-r1-cancel');
    expect(find.text('Cancel this request'), findsOneWidget);
    await tapKey(tester, 'reason-back');
    expect(find.text('Cancel this request'), findsNothing);
    expect(db.calls.where((c) => c.$1 == 'update_service_request'), isEmpty);
  });

  testWidgets('the buttons wait while a move is on its way, so a second tap cannot send it twice', (tester) async {
    db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
    await open(tester, host());
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.tap(find.byKey(const Key('act-r1-acknowledge')));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('act-r1-acknowledge'))).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('act-r1-complete'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('act-r1-acknowledge')), warnIfMissed: false);
    await tester.pump();
    gate.complete();
    db.hold = null;
    await tester.pumpAndSettle();
    expect(db.calls.where((c) => c.$1 == 'update_service_request'), hasLength(1));
  });

  testWidgets('a colleague took it first: the server is told, and the list shows the truth', (tester) async {
    db.assignments.remove('b1');
    db.addRequest('b1', 'assistance', rid: 'r1');   // nobody has it, so the server sees it and may take it
    await open(tester, host());
    expect(find.byKey(const Key('request-r1')), findsOneWidget);
    // Between the list and the tap, a colleague takes it.
    db.beforeCall = (f) {
      if (f == 'update_service_request') {
        db.requests.single
          ..status = 'acknowledged'
          ..assigned = 'm-colleague';
      }
    };
    await tapKey(tester, 'act-r1-acknowledge');
    expect(find.text('Someone else has already taken this request.'), findsOneWidget);
    expect(find.byKey(const Key('request-r1')), findsNothing, reason: 'it is the colleague\'s now, so it is no longer in this server\'s list');
    expect(db.requests.single.assigned, 'm-colleague');
  });

  testWidgets('a refusal is shown in the database\'s words', (tester) async {
    db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
    await open(tester, host());
    db.beforeCall = (f) {
      if (f == 'update_service_request') db.requests.single.status = 'escalated';   // a manager just took it over
    };
    await tapKey(tester, 'act-r1-complete');
    expect(find.text('This request was passed to a manager.'), findsOneWidget);
    expect(find.text('Escalated'), findsOneWidget, reason: 'and the card now shows the state it is really in');
  });

  testWidgets('finished requests of the last 24 hours can be shown, read only', (tester) async {
    db.addRequest('b1', 'assistance', status: 'completed', assigned: 'm-me', rid: 'done')
      ..closedAt = DateTime(2026, 10, 9, 19, 30)
      ..statusNote = 'sorted';
    db.addRequest('b1', 'bill_request', status: 'cancelled', assigned: 'm-me', rid: 'gone')
      ..closedAt = DateTime(2026, 10, 9, 21, 25)
      ..statusNote = 'guest left';
    db.addRequest('b1', 'table_issue', assigned: 'm-me', rid: 'open');
    await open(tester, host());
    expect(find.byKey(const Key('request-open')), findsOneWidget);
    expect(find.byKey(const Key('request-done')), findsNothing);

    await tapKey(tester, 'show-closed');
    expect(db.params.last, {'p_venue': 'v1', 'p_include_closed': true});
    expect(find.text('Completed 2 h ago'), findsOneWidget);
    expect(find.text('Cancelled 5 min ago'), findsOneWidget);
    expect(find.text('Reason: sorted'), findsOneWidget);
    expect(find.text('Reason: guest left'), findsOneWidget);
    for (final a in RequestAction.values) {
      expect(find.byKey(Key('act-done-${a.value}')), findsNothing, reason: 'a finished request has no buttons');
    }
    final openTop = tester.getTopLeft(find.byKey(const Key('request-open'))).dy;
    expect(openTop < tester.getTopLeft(find.byKey(const Key('request-done'))).dy, isTrue, reason: 'open ones stay on top');
    await tapKey(tester, 'show-closed');
    expect(find.byKey(const Key('request-done')), findsNothing);
  });

  testWidgets('a manager sees every request of the club, and can take over one that was passed up', (tester) async {
    db.level = 'manager';
    db.addRequest('b2', 'assistance', assigned: 'm-colleague', rid: 'theirs');
    db.addRequest('b1', 'order_question', status: 'escalated', assigned: 'm-me', rid: 'up').statusNote = 'guest wants the owner';
    await open(tester, host(role: WorkspaceRole.manager));
    expect(find.byKey(const Key('request-theirs')), findsOneWidget);
    expect(find.text('Waiting just now · A colleague'), findsOneWidget);
    expect(find.byKey(const Key('act-up-acknowledge')), findsOneWidget);
    expect(find.byKey(const Key('act-up-complete')), findsOneWidget);
    expect(find.byKey(const Key('act-up-escalate')), findsNothing, reason: 'a manager has no one to pass it to');
    await tapKey(tester, 'act-up-acknowledge');
    expect(db.requests.firstWhere((r) => r.id == 'up').status, 'acknowledged');
  });

  testWidgets('an owner is treated as a manager', (tester) async {
    db.level = 'manager';
    db.addRequest('b2', 'assistance', assigned: 'm-colleague', rid: 'theirs');
    await open(tester, host(role: WorkspaceRole.owner));
    expect(find.byKey(const Key('act-theirs-acknowledge')), findsOneWidget);
  });

  testWidgets('a database without the migration says so, with nothing to retry', (tester) async {
    db.failAll = PostgrestException(message: 'nope', code: 'PGRST202');
    await open(tester, host());
    expect(find.text('Requests are not set up on this server yet.'), findsOneWidget);
    expect(find.byKey(const Key('requests-retry')), findsNothing);
  });

  testWidgets('a dropped connection can be tried again', (tester) async {
    db.addRequest('b1', 'assistance', assigned: 'm-me', rid: 'r1');
    db.failAll = Exception('SocketException: connection lost');
    await open(tester, host());
    expect(find.text('Requests could not be loaded. Check your connection and try again.'), findsOneWidget);
    db.failAll = null;
    await tapKey(tester, 'requests-retry');
    expect(find.byKey(const Key('request-r1')), findsOneWidget);
  });

  testWidgets('a person whose access ended is told so', (tester) async {
    db.level = 'none';
    await open(tester, host());
    expect(find.text('Your access has ended, or you are signed out.'), findsOneWidget);
  });

  testWidgets('a workspace that is not tied to a club shows nothing and asks for nothing', (tester) async {
    await open(tester, host(venueId: null));
    expect(find.byKey(const Key('requests-no-venue')), findsOneWidget);
    expect(db.calls, isEmpty);
  });
}
