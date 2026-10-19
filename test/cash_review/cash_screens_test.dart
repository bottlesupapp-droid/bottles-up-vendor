import 'package:bottles_up_vendor/features/cash_review/providers/cash_providers.dart';
import 'package:bottles_up_vendor/features/cash_review/screens/cash_screen.dart';
import 'package:bottles_up_vendor/features/cash_review/screens/exceptions_screen.dart';
import 'package:bottles_up_vendor/features/cash_review/screens/summary_screen.dart';
import 'package:bottles_up_vendor/features/cash_review/widgets/cash_held_card.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cash_backend.dart';

late FakeCashBackend db;

Workspace ws(WorkspaceRole role, {String? venueId = 'v1'}) => Workspace(
      membershipId: 'w1',
      orgId: 'o1',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: role,
      venueId: venueId,
      venueName: venueId == null ? null : 'Club A',
    );

DateTime fridayNight() => DateTime(2026, 10, 9, 23, 30);

Widget host(Widget child) => ProviderScope(
      key: UniqueKey(),
      overrides: [cashServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child));
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

void main() {
  setUp(() {
    db = FakeCashBackend();
    db.collected['u-sam'] = 7800;
    db.collected['u-me'] = 2000;
  });

  group('Cash (verifier)', () {
    testWidgets('shows who holds what and the handovers; Count is offered on other people\'s only', (tester) async {
      db.handovers
        ..add(FakeHandover('h1', 'u-sam', 3000, DateTime(2026, 10, 9, 23, 10), note: 'first part'))
        ..add(FakeHandover('h2', 'u-me', 500, DateTime(2026, 10, 9, 23, 20)))
        ..add(FakeHandover('h3', 'u-sam', 1000, DateTime(2026, 10, 9, 22, 50), status: 'acknowledged', counted: 900, receivedBy: 'u-me', receiveNote: 'torn note'));
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));

      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(find.text('Me Myself (you)'), findsOneWidget);
      expect(find.text('Sam Server'), findsOneWidget);
      expect(find.textContaining(r'Collected $78.00 · handed in $40.00'), findsOneWidget);
      expect(find.byKey(const Key('count-h1')), findsOneWidget);
      expect(find.byKey(const Key('count-h2')), findsNothing, reason: 'your own handover is counted by someone else');
      expect(find.text('Someone else must count it'), findsOneWidget);
      expect(find.byKey(const Key('count-h3')), findsNothing, reason: 'already counted');
      expect(find.byKey(const Key('difference-h3')), findsOneWidget);
      expect(find.text(r'Short $1.00'), findsOneWidget);
      expect(find.textContaining('Note: first part'), findsOneWidget);
      expect(find.textContaining('Counted \$9.00 by Me Myself (torn note)'), findsOneWidget);
    });

    testWidgets('a difference without a reason is stopped in the dialog and nothing is sent; with a reason it is saved', (tester) async {
      db.handovers.add(FakeHandover('h1', 'u-sam', 3000, DateTime(2026, 10, 9, 23, 10)));
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));

      await tapKey(tester, 'count-h1');
      expect(find.textContaining(r'Sam Server handed in $30.00'), findsOneWidget);
      expect((tester.widget<TextField>(find.byKey(const Key('amount-field'))).controller!.text), '30.00', reason: 'the count starts at what was handed in');

      await typeIn(tester, 'amount-field', '29.00');
      await tapKey(tester, 'dialog-confirm');
      expect(find.byKey(const Key('dialog-error')), findsOneWidget);
      expect(find.textContaining('say why'), findsOneWidget);
      expect(db.calledWith('desk_receive_handover'), isEmpty, reason: 'nothing leaves the phone while the form is wrong');

      await typeIn(tester, 'note-field', 'a note was torn');
      expect(find.byKey(const Key('dialog-error')), findsNothing, reason: 'typing clears the message');
      await tapKey(tester, 'dialog-confirm');

      expect(db.calledWith('desk_receive_handover').single, {'p_handover': 'h1', 'p_counted_cents': 2900, 'p_note': 'a note was torn'});
      expect(find.text(r'Counted: Short $1.00.'), findsOneWidget);
      expect(find.byKey(const Key('count-h1')), findsNothing);
      expect(find.byKey(const Key('difference-h1')), findsOneWidget, reason: 'the list was read again');
    });

    testWidgets('an exact count needs no note', (tester) async {
      db.handovers.add(FakeHandover('h1', 'u-sam', 3000, DateTime(2026, 10, 9, 23, 10)));
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.manager), clock: fridayNight));

      await tapKey(tester, 'count-h1');
      await tapKey(tester, 'dialog-confirm');

      expect(db.calledWith('desk_receive_handover').single, {'p_handover': 'h1', 'p_counted_cents': 3000, 'p_note': null});
      expect(find.text('Counted: Matches.'), findsOneWidget);
    });

    testWidgets('backing out of the count sends nothing', (tester) async {
      db.handovers.add(FakeHandover('h1', 'u-sam', 3000, DateTime(2026, 10, 9, 23, 10)));
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));

      await tapKey(tester, 'count-h1');
      await tapKey(tester, 'dialog-back');

      expect(db.calledWith('desk_receive_handover'), isEmpty);
      expect(find.byKey(const Key('count-h1')), findsOneWidget);
    });

    testWidgets('when somebody else counted it first the database\'s sentence is shown and the list is read again', (tester) async {
      db.handovers.add(FakeHandover('h1', 'u-sam', 3000, DateTime(2026, 10, 9, 23, 10)));
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));
      db.handovers.first
        ..status = 'acknowledged'
        ..counted = 3000
        ..receivedBy = 'u-bea';

      await tapKey(tester, 'count-h1');
      await tapKey(tester, 'dialog-confirm');

      expect(find.text('This handover was already acknowledged.'), findsOneWidget);
      expect(find.byKey(const Key('count-h1')), findsNothing, reason: 'the refreshed list shows it counted');
      expect(find.byKey(const Key('difference-h1')), findsOneWidget);
    });

    testWidgets('a night with nothing says so in words', (tester) async {
      db.collected.clear();
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));
      expect(find.byKey(const Key('cash-empty')), findsOneWidget);
      expect(find.text('No cash was recorded for this night.'), findsOneWidget);
      expect(find.text('Nothing has been handed in for this night.'), findsOneWidget);
    });

    testWidgets('a dropped connection says so, and Try again reads it again', (tester) async {
      db.offline = true;
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));
      expect(find.byKey(const Key('cash-error')), findsOneWidget);
      expect(find.byKey(const Key('handovers-error')), findsOneWidget);
      expect(find.textContaining('could not be loaded'), findsWidgets);

      db.offline = false;
      await tester.tap(find.byKey(const Key('ops-retry')).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cash-error')), findsNothing);
      expect(find.text('Sam Server'), findsOneWidget);
    });

    testWidgets('a server without the migration is told it is not set up, with nothing to retry', (tester) async {
      db.missing = true;
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));
      expect(find.text('Cash figures are not set up on this server yet.'), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
    });

    testWidgets('another night asks for that night', (tester) async {
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));
      expect(db.calledWith('desk_cash_position').last['p_night'], '2026-10-09');
      await tapKey(tester, 'night-prev');
      expect(db.calledWith('desk_cash_position').last['p_night'], '2026-10-08');
      expect(db.calledWith('desk_list_handovers').last['p_night'], '2026-10-08');
    });

    testWidgets('after midnight it is still the night before', (tester) async {
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier), clock: () => DateTime(2026, 10, 10, 1, 30)));
      expect(db.calledWith('desk_cash_position').last['p_night'], '2026-10-09');
    });

    testWidgets('a workspace with no club shows nothing and asks for nothing', (tester) async {
      await open(tester, CashScreen(workspace: ws(WorkspaceRole.verifier, venueId: null), clock: fridayNight));
      expect(find.byKey(const Key('cash-no-venue')), findsOneWidget);
      expect(db.calls, isEmpty);
    });
  });

  group('Exceptions', () {
    FakeFlag flag(String id, {String status = 'open', String reason = 'the till says 38.00'}) =>
        FakeFlag(id, 'p-$id', 'Ada Lovelace', 'VIP booth', 'debit', 4000, reason, 'u-sam', DateTime(2026, 10, 9, 22, 15), status: status);

    testWidgets('the verifier sees the open flags and is told a manager resolves them', (tester) async {
      db.flags.add(flag('f1'));
      await open(tester, ExceptionsScreen(workspace: ws(WorkspaceRole.verifier)));
      expect(find.text('Ada Lovelace · VIP booth'), findsOneWidget);
      expect(find.textContaining(r'$40.00 by debit'), findsOneWidget);
      expect(find.textContaining('Flagged by Sam Server'), findsOneWidget);
      expect(find.text('“the till says 38.00”'), findsOneWidget);
      expect(find.byKey(const Key('exceptions-manager-note')), findsOneWidget);
      expect(find.byKey(const Key('resolve-f1')), findsNothing);
    });

    testWidgets('a manager resolves: an outcome and what was done are required, then it moves to Resolved', (tester) async {
      db.role = 'manager';
      db.flags.add(flag('f1'));
      await open(tester, ExceptionsScreen(workspace: ws(WorkspaceRole.manager)));
      expect(find.byKey(const Key('exceptions-manager-note')), findsNothing);

      await tapKey(tester, 'resolve-f1');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Choose how it was resolved.'), findsOneWidget);
      await tapKey(tester, 'resolution-corrected');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say what was done.'), findsOneWidget);
      expect(db.calledWith('desk_resolve_flag'), isEmpty);

      await typeIn(tester, 'note-field', 'amount fixed to 38.00');
      await tapKey(tester, 'dialog-confirm');

      expect(db.calledWith('desk_resolve_flag').single, {'p_flag': 'f1', 'p_resolution': 'corrected', 'p_note': 'amount fixed to 38.00'});
      expect(find.text('Flag resolved.'), findsOneWidget);
      expect(find.byKey(const Key('exceptions-empty')), findsOneWidget);
      expect(find.text('No payments are flagged.'), findsOneWidget);

      await tester.tap(find.text('Resolved'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('flag-outcome-f1')), findsOneWidget);
      expect(find.textContaining('The payment was corrected · Me Myself'), findsOneWidget);
      expect(find.text('amount fixed to 38.00'), findsOneWidget);
      expect(find.byKey(const Key('resolve-f1')), findsNothing);
    });

    testWidgets('"the payment is fine" needs no note', (tester) async {
      db.role = 'owner';
      db.flags.add(flag('f1'));
      await open(tester, ExceptionsScreen(workspace: ws(WorkspaceRole.owner)));
      await tapKey(tester, 'resolve-f1');
      await tapKey(tester, 'resolution-confirmed_ok');
      await tapKey(tester, 'dialog-confirm');
      expect(db.calledWith('desk_resolve_flag').single['p_resolution'], 'confirmed_ok');
      expect(db.calledWith('desk_resolve_flag').single['p_note'], isNull);
    });

    testWidgets('backing out of resolving sends nothing', (tester) async {
      db.role = 'manager';
      db.flags.add(flag('f1'));
      await open(tester, ExceptionsScreen(workspace: ws(WorkspaceRole.manager)));
      await tapKey(tester, 'resolve-f1');
      await tapKey(tester, 'dialog-back');
      expect(db.calledWith('desk_resolve_flag'), isEmpty);
      expect(find.byKey(const Key('resolve-f1')), findsOneWidget);
    });

    testWidgets('a flag somebody else resolved first shows the database\'s sentence and the refreshed list', (tester) async {
      db.role = 'manager';
      db.flags.add(flag('f1'));
      await open(tester, ExceptionsScreen(workspace: ws(WorkspaceRole.manager)));
      db.flags.first
        ..status = 'resolved'
        ..resolution = 'confirmed_ok'
        ..resolvedBy = 'u-bea';
      await tapKey(tester, 'resolve-f1');
      await tapKey(tester, 'resolution-confirmed_ok');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('This flag was already resolved.'), findsOneWidget);
      expect(find.byKey(const Key('resolve-f1')), findsNothing);
    });

    testWidgets('nothing flagged, nothing resolved, a dropped connection, and a missing migration are each said in words', (tester) async {
      await open(tester, ExceptionsScreen(workspace: ws(WorkspaceRole.verifier)));
      expect(find.text('No payments are flagged.'), findsOneWidget);
      await tester.tap(find.text('Resolved'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing has been resolved yet.'), findsOneWidget);

      db.offline = true;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exceptions-error')), findsOneWidget);
      expect(find.text('Flagged payments could not be loaded. Check your connection and try again.'), findsOneWidget);

      db.offline = false;
      db.missing = true;
      await tester.tap(find.byKey(const Key('ops-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Flagged payments are not set up on this server yet.'), findsOneWidget);
    });

    testWidgets('a workspace with no club shows nothing', (tester) async {
      await open(tester, ExceptionsScreen(workspace: ws(WorkspaceRole.verifier, venueId: null)));
      expect(find.byKey(const Key('exceptions-no-venue')), findsOneWidget);
      expect(db.calls, isEmpty);
    });
  });

  group('Summary', () {
    testWidgets('shows the night\'s numbers and says a cash difference in words', (tester) async {
      db.flags.add(FakeFlag('f1', 'p1', 'Ada', 'VIP', 'debit', 100, 'off', 'u-sam', DateTime(2026, 10, 9)));
      db.handovers
        ..add(FakeHandover('h1', 'u-sam', 3000, DateTime(2026, 10, 9), status: 'acknowledged', counted: 2900, receivedBy: 'u-me', receiveNote: 'x y z'))
        ..add(FakeHandover('h2', 'u-sam', 500, DateTime(2026, 10, 9)));
      await open(tester, VerifierSummaryScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));
      String value(String key) => (tester.widget<ListTile>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(ListTile))).trailing as Text).data!;
      expect(value('summary-recorded'), '6');
      expect(value('summary-checked'), '2');
      expect(value('summary-to-check'), '4');
      expect(value('summary-disputed'), '1');
      expect(value('summary-flags-open'), '1');
      expect(value('summary-handovers-waiting'), '1');
      expect(value('summary-handovers-counted'), '1');
      expect(value('summary-difference'), r'Short $1.00');
      expect(find.text('1 by you'), findsOneWidget);
    });

    testWidgets('no difference reads "None"', (tester) async {
      await open(tester, VerifierSummaryScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));
      expect((tester.widget<ListTile>(find.descendant(of: find.byKey(const Key('summary-difference')), matching: find.byType(ListTile))).trailing as Text).data, 'None');
    });

    testWidgets('a failure is said, and a workspace with no club shows nothing', (tester) async {
      db.offline = true;
      await open(tester, VerifierSummaryScreen(workspace: ws(WorkspaceRole.verifier), clock: fridayNight));
      expect(find.byKey(const Key('summary-error')), findsOneWidget);
      await open(tester, VerifierSummaryScreen(workspace: ws(WorkspaceRole.verifier, venueId: null), clock: fridayNight));
      expect(find.byKey(const Key('summary-no-venue')), findsOneWidget);
    });
  });

  group('Cash I hold (a server\'s My Tables)', () {
    Widget card() => CashHeldCard(workspace: ws(WorkspaceRole.server), night: '2026-10-09');

    setUp(() {
      db.role = 'server';
    });

    testWidgets('says what is held and hands it over', (tester) async {
      await open(tester, card());
      expect(find.text(r'You are holding $20.00 in cash'), findsOneWidget);
      expect(find.textContaining(r'Collected $20.00 · handed in $0.00'), findsOneWidget);

      await tapKey(tester, 'hand-over-cash');
      expect((tester.widget<TextField>(find.byKey(const Key('amount-field'))).controller!.text), '20.00', reason: 'starts with everything held');
      await typeIn(tester, 'amount-field', '12.50');
      await typeIn(tester, 'note-field', 'first part');
      await tapKey(tester, 'dialog-confirm');

      expect(db.calledWith('desk_submit_handover').single, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_amount_cents': 1250, 'p_note': 'first part'});
      expect(find.text('Handover sent. Someone else will count it.'), findsOneWidget);
      expect(find.text(r'You are holding $7.50 in cash'), findsOneWidget, reason: 'the position was read again');
    });

    testWidgets('more than is held is stopped in the dialog', (tester) async {
      await open(tester, card());
      await tapKey(tester, 'hand-over-cash');
      await typeIn(tester, 'amount-field', '20.01');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text(r'You only hold $20.00.'), findsOneWidget);
      expect(db.calledWith('desk_submit_handover'), isEmpty);
    });

    testWidgets('everything handed in: the card says so and offers nothing more', (tester) async {
      db.handovers.add(FakeHandover('h1', 'u-me', 2000, DateTime(2026, 10, 9)));
      await open(tester, card());
      expect(find.text('All your cash is handed in'), findsOneWidget);
      expect(find.byKey(const Key('hand-over-cash')), findsNothing);
    });

    testWidgets('the database\'s refusal is shown and the position read again', (tester) async {
      await open(tester, card());
      // The cash was handed in from another phone after this card loaded.
      db.handovers.add(FakeHandover('h1', 'u-me', 2000, DateTime(2026, 10, 9)));
      await tapKey(tester, 'hand-over-cash');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('You are not holding any cash for this night.'), findsOneWidget);
      expect(find.text('All your cash is handed in'), findsOneWidget);
    });

    testWidgets('a person who collected no cash sees no card, and a server without the migration sees none either', (tester) async {
      db.collected.clear();
      await open(tester, card());
      expect(find.byKey(const Key('cash-held-card')), findsNothing);

      db.missing = true;
      await open(tester, card());
      expect(find.byKey(const Key('cash-held-card')), findsNothing);
      expect(find.byKey(const Key('cash-card-error')), findsNothing);
    });

    testWidgets('any other failure is said, not hidden', (tester) async {
      db.offline = true;
      await open(tester, card());
      expect(find.byKey(const Key('cash-card-error')), findsOneWidget);
    });

    testWidgets('a server only ever sees their own line', (tester) async {
      await open(tester, card());
      expect(find.textContaining('Sam Server'), findsNothing);
    });
  });
}
