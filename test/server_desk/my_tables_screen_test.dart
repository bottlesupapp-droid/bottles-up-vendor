import 'dart:async';

import 'package:bottles_up_vendor/features/server_desk/logic/server_desk_rules.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/screens/my_tables_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/widgets/ask_sheet.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_desk_backend.dart';

late FakeDeskBackend db;

const server = Workspace(
  membershipId: 'w1',
  orgId: 'o1',
  orgName: 'Club Co',
  orgKind: 'venue_owner',
  role: WorkspaceRole.server,
  venueId: 'v1',
  venueName: 'Club A',
);

/// A Friday evening: the business night is Friday 9 October 2026.
DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host({Workspace workspace = server, DateTime Function()? clock, AskPicker? pick}) => ProviderScope(
      key: UniqueKey(),
      overrides: [serverDeskServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: MyTablesScreen(workspace: workspace, clock: clock ?? friday9pm, pickAsk: pick ?? (c, label) async => null)),
      ),
    );

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    db = FakeDeskBackend();
    db.now = DateTime(2026, 10, 9, 21, 30);
    db.addBooking('b1', code: 'AB12CD', label: 'Evening', name: 'Ada Lovelace');
    db.addBooking('b2', time: '23:00:00', table: 'Dance floor table', guests: 2, name: 'Grace Hopper', code: 'EF34GH', checkedInAt: '2026-10-09T23:10:00Z');
    db.assignments['b1'] = 'm-me';
    db.assignments['b2'] = 'm-me';
  });

  testWidgets('opens on tonight and shows the server\'s own tables', (tester) async {
    await open(tester, host());
    expect(db.calls.first.$1, 'my_assigned_tables');
    expect(db.params.first, {'p_night': '2026-10-09'});
    expect(find.text('My tables'), findsOneWidget);
    expect(find.text('Club A'), findsOneWidget);
    expect(find.text('Friday Oct 9'), findsOneWidget);
    expect(find.text('2 tables · 6 guests expected'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('VIP booth · 4 guests'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('AB12CD'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsOneWidget);
    expect(find.text('Dance floor table · 2 guests'), findsOneWidget);
    expect(find.byKey(const Key('expected-b1')), findsOneWidget);
    expect(find.byKey(const Key('arrived-b2')), findsOneWidget, reason: 'Grace has arrived');
    expect(find.byKey(const Key('expected-b2')), findsNothing);
  });

  testWidgets('a single table and a single guest read naturally', (tester) async {
    db.assignments.remove('b2');
    db.bookings['b1']!.guests = 1;
    await open(tester, host());
    expect(find.text('1 table · 1 guest expected'), findsOneWidget);
    expect(find.text('VIP booth · 1 guest'), findsOneWidget);
  });

  testWidgets('shows no guest email or phone, and says what is not here yet', (tester) async {
    await open(tester, host());
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('+1'), findsNothing);
    expect(find.byKey(const Key('tables-footnote')), findsOneWidget);
    expect(find.text('Payments and bottle orders are not shown here yet.'), findsOneWidget);
  });

  testWidgets('another club\'s tables are not shown in this workspace', (tester) async {
    db.addBooking('b9', venue: 'v2', name: 'Elsewhere Ed', code: 'ZZ99ZZ');
    db.assignments['b9'] = 'm-me';
    await open(tester, host());
    expect(find.text('Elsewhere Ed'), findsNothing);
    expect(find.text('2 tables · 6 guests expected'), findsOneWidget);
  });

  testWidgets('a night with nothing says so', (tester) async {
    db.assignments.clear();
    await open(tester, host());
    expect(find.byKey(const Key('tables-empty')), findsOneWidget);
    expect(find.text('No tables have been given to you for this night.'), findsOneWidget);
    expect(find.byKey(const Key('tables-summary')), findsNothing);
  });

  testWidgets('after midnight it is still last night\'s party', (tester) async {
    await open(tester, host(clock: () => DateTime(2026, 10, 10, 1, 30)));
    expect(db.params.first, {'p_night': '2026-10-09'});
    expect(find.text('Friday Oct 9'), findsOneWidget);
  });

  testWidgets('steps to the next night and back, and can jump back to tonight', (tester) async {
    db.addBooking('b3', night: '2026-10-10', name: 'Next Night Nell', code: 'NN10NN');
    db.assignments['b3'] = 'm-me';
    await open(tester, host());
    expect(find.byKey(const Key('night-tonight')), findsNothing, reason: 'already on tonight');

    await tester.tap(find.byKey(const Key('night-next')));
    await tester.pumpAndSettle();
    expect(db.params.last, {'p_night': '2026-10-10'});
    expect(find.text('Saturday Oct 10'), findsOneWidget);
    expect(find.text('Next Night Nell'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
    expect(find.byKey(const Key('night-tonight')), findsOneWidget);

    await tester.tap(find.byKey(const Key('night-tonight')));
    await tester.pumpAndSettle();
    expect(find.text('Friday Oct 9'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);

    await tester.tap(find.byKey(const Key('night-prev')));
    await tester.pumpAndSettle();
    expect(db.params.last, {'p_night': '2026-10-08'});
    expect(find.byKey(const Key('tables-empty')), findsOneWidget);
  });

  testWidgets('what a table has asked for that is still open shows under it; finished requests do not', (tester) async {
    db.addRequest('b1', 'water_ice_mixers', assigned: 'm-me', createdAt: DateTime(2026, 10, 9, 21, 10), rid: 'r1');
    db.addRequest('b1', 'bill_request', status: 'in_progress', assigned: 'm-me', createdAt: DateTime(2026, 10, 9, 21, 25), rid: 'r2');
    db.addRequest('b1', 'assistance', status: 'completed', assigned: 'm-me', rid: 'r3').closedAt = db.now;
    await open(tester, host(clock: () => DateTime(2026, 10, 9, 21, 30)));
    expect(find.byKey(const Key('open-r1')), findsOneWidget);
    expect(find.text('Water, ice or mixers · waiting 20 min'), findsOneWidget);
    expect(find.text('Bill request · waiting 5 min'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.byKey(const Key('open-r3')), findsNothing);
  });

  testWidgets('asking for something sends the booking, the kind and the note, then shows the request', (tester) async {
    await open(tester, host(pick: (c, label) async {
      expect(label, 'VIP booth · Ada Lovelace');
      return const AskChoice(ServiceKind.waterIceMixers, 'two limes');
    }));
    await tester.tap(find.byKey(const Key('ask-b1')));
    await tester.pumpAndSettle();
    final ask = db.calls.where((c) => c.$1 == 'create_service_request').single;
    expect(ask.$2, {'p_booking': 'b1', 'p_kind': 'water_ice_mixers', 'p_note': 'two limes'});
    expect(find.text('Asked for: Water, ice or mixers.'), findsOneWidget);
    expect(find.textContaining('Water, ice or mixers · waiting'), findsOneWidget, reason: 'the request now shows under the table');
  });

  testWidgets('backing out of the sheet asks for nothing', (tester) async {
    await open(tester, host());
    await tester.tap(find.byKey(const Key('ask-b1')));
    await tester.pumpAndSettle();
    expect(db.calls.where((c) => c.$1 == 'create_service_request'), isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the button waits while the request is on its way, so a second tap cannot send it twice', (tester) async {
    final gate = Completer<void>();
    var pickedTimes = 0;
    await open(tester, host(pick: (c, label) async {
      pickedTimes++;
      return const AskChoice(ServiceKind.billRequest, null);
    }));
    db.hold = gate.future;
    await tester.tap(find.byKey(const Key('ask-b1')));
    await tester.pump();
    await tester.pump();
    final button = tester.widget<OutlinedButton>(find.byKey(const Key('ask-b1')));
    expect(button.onPressed, isNull, reason: 'busy');
    await tester.tap(find.byKey(const Key('ask-b1')), warnIfMissed: false);
    await tester.pump();
    expect(pickedTimes, 1);
    gate.complete();
    db.hold = null;
    await tester.pumpAndSettle();
    expect(db.calls.where((c) => c.$1 == 'create_service_request'), hasLength(1));
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('ask-b1'))).onPressed, isNotNull);
  });

  testWidgets('a refusal is shown as the database\'s own sentence', (tester) async {
    await open(tester, host(pick: (c, label) async {
      db.assignments['b1'] = 'm-colleague';   // the manager gave the table to someone else a moment ago
      return const AskChoice(ServiceKind.assistance, null);
    }));
    await tester.tap(find.byKey(const Key('ask-b1')));
    await tester.pumpAndSettle();
    expect(find.text('This table belongs to another server.'), findsOneWidget);
    expect(db.requests, isEmpty);
  });

  testWidgets('a note that is too long is refused before anything is sent', (tester) async {
    await open(tester, host(pick: (c, label) async => AskChoice(ServiceKind.assistance, 'x' * 301)));
    await tester.tap(find.byKey(const Key('ask-b1')));
    await tester.pumpAndSettle();
    expect(find.text('Keep it to 300 characters or fewer.'), findsOneWidget);
    expect(db.calls.where((c) => c.$1 == 'create_service_request'), isEmpty);
  });

  testWidgets('the real sheet: pick a kind with a note, or be told the note is too long', (tester) async {
    // No picker is given, so the screen uses the real sheet.
    await open(
      tester,
      ProviderScope(
        key: UniqueKey(),
        overrides: [serverDeskServiceProvider.overrideWithValue(db.service)],
        child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: MyTablesScreen(workspace: server, clock: friday9pm))),
      ),
    );
    await tester.tap(find.byKey(const Key('ask-b1')));
    await tester.pumpAndSettle();
    expect(find.text('What does this table need?'), findsOneWidget);
    expect(find.text('VIP booth · Ada Lovelace'), findsOneWidget);
    for (final k in ServiceKind.values) {
      expect(find.byKey(Key('kind-${k.value}')), findsOneWidget, reason: k.label);
    }
    await tester.enterText(find.byKey(const Key('ask-note')), 'x' * 301);
    await tester.tap(find.byKey(const Key('kind-bill_request')));
    await tester.pumpAndSettle();
    expect(find.text('Keep it to 300 characters or fewer.'), findsOneWidget);
    expect(db.calls.where((c) => c.$1 == 'create_service_request'), isEmpty);
    await tester.enterText(find.byKey(const Key('ask-note')), '  the check please ');
    await tester.tap(find.byKey(const Key('kind-bill_request')));
    await tester.pumpAndSettle();
    expect(db.calls.where((c) => c.$1 == 'create_service_request').single.$2, {'p_booking': 'b1', 'p_kind': 'bill_request', 'p_note': 'the check please'});
  });

  testWidgets('if the requests cannot be loaded the tables still show', (tester) async {
    db.failOn['list_service_requests'] = PostgrestException(message: 'nope', code: '42883');
    await open(tester, host());
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.byKey(const Key('tables-error')), findsNothing);
  });

  testWidgets('a database without the migration says so, with nothing to retry', (tester) async {
    db.failOn['my_assigned_tables'] = PostgrestException(message: 'nope', code: '42883');
    await open(tester, host());
    expect(find.text('Tables are not set up on this server yet.'), findsOneWidget);
    expect(find.byKey(const Key('tables-retry')), findsNothing);
  });

  testWidgets('a dropped connection can be tried again', (tester) async {
    db.failOn['my_assigned_tables'] = Exception('SocketException: connection lost');
    await open(tester, host());
    expect(find.text('Tables could not be loaded. Check your connection and try again.'), findsOneWidget);
    db.failOn.clear();
    await tester.tap(find.byKey(const Key('tables-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.byKey(const Key('tables-error')), findsNothing);
  });

  testWidgets('a person whose access ended is told so', (tester) async {
    db.failOn['my_assigned_tables'] = PostgrestException(message: 'not allowed', code: 'P0001');
    await open(tester, host());
    expect(find.text('Your access has ended, or you are signed out.'), findsOneWidget);
  });

  testWidgets('a workspace that is not tied to a club shows nothing and asks for nothing', (tester) async {
    const noClub = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.server);
    await open(tester, host(workspace: noClub));
    expect(find.byKey(const Key('tables-no-venue')), findsOneWidget);
    expect(db.calls, isEmpty);
  });
}
