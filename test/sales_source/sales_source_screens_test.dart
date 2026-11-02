import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/sales_source/logic/sales_source_rules.dart';
import 'package:bottles_up_vendor/features/sales_source/providers/sales_source_providers.dart';
import 'package:bottles_up_vendor/features/sales_source/screens/closing_report_form_screen.dart';
import 'package:bottles_up_vendor/features/sales_source/screens/sales_tracking_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sales_backend.dart';

late FakeSalesBackend db;

Workspace ws(WorkspaceRole role, {String? venueId = 'v1'}) =>
    Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: role, venueId: venueId, venueName: 'Club A');

DateTime noon() => DateTime(2026, 11, 1, 12);

Future<void> open(WidgetTester tester, WorkspaceRole role, {String? venueId = 'v1', Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? pick}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [salesSourceServiceProvider.overrideWithValue(db.service)],
    child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: SalesTrackingScreen(workspace: ws(role, venueId: venueId), clock: noon))),
  ));
  await tester.pumpAndSettle();
}

Future<void> openForm(WidgetTester tester, {Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? pick}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [salesSourceServiceProvider.overrideWithValue(db.service)],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open-form'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClosingReportFormScreen(venueId: 'v1', venueName: 'Club A', clock: noon, pickTime: pick))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('open-form')));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void main() {
  setUp(() => db = FakeSalesBackend());

  group('the service', () {
    test('a club that never chose is on entries', () async => expect(await db.service.source('v1'), SalesSource.entries));

    test('choosing writes the wire word, and a refusal is the database\'s own sentence', () async {
      await db.service.saveSource('v1', SalesSource.upload);
      expect(db.calledWith('save_venue_sales_source').single, {'p_venue': 'v1', 'p_source': 'upload'});
      db.role = 'server';
      await expectLater(db.service.saveSource('v1', SalesSource.entries), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'You don\'t have access to do that.')));
    });

    test('a read that is refused says the access ended; an old server says it is not available', () async {
      db.role = 'server';
      await expectLater(db.service.source('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      db.role = 'owner';
      db.missing = true;
      await expectLater(db.service.reports('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    });

    test('a lost connection while sending is a plain sentence, not a stack', () async {
      db.source = 'upload';
      db.offline = true;
      await expectLater(
        db.service.send('v1', ClosingReportForm(night: '2026-10-31', grossText: '10', includesBottlesUp: false)),
        throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'The report could not be sent. Check your connection and try again.')),
      );
    });

    test('the list asks for the latest 30', () async {
      db.source = 'upload';
      await db.service.reports('v1');
      expect(db.calledWith('closing_reports').single, {'p_venue': 'v1', 'p_limit': 30});
    });

    test('a night\'s sales come back as two blocks', () async {
      db.source = 'upload';
      db.seed(night: '2026-10-31', status: 'reviewed', includes: true, gross: 90000, discount: 5000, refund: 1000);
      final s = await db.service.nightSales('v1', '2026-10-31');
      expect(db.calledWith('night_sales_sources').single, {'p_venue': 'v1', 'p_night': '2026-10-31'});
      expect((s.recorded.label, s.reported!.label, s.reported!.barAndOtherCents), ('Recorded sales', 'Venue-reported sales', 29000));
    });
  });

  group('Sales Tracking', () {
    testWidgets('a manager sees the two sources with entries chosen, and Connected POS as not available', (tester) async {
      await open(tester, WorkspaceRole.manager);
      expect(find.text('Sales Tracking'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(find.byKey(const Key('source-entries')), findsOneWidget);
      expect(find.byKey(const Key('source-upload')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('source-entries')), matching: find.byIcon(Icons.radio_button_checked)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('source-pos')), matching: find.text(posUnavailableText)), findsOneWidget);
      expect(find.byKey(const Key('send-closing-report')), findsNothing, reason: 'reports are only for a club on upload');
      expect(find.byKey(const Key('sales-read-only')), findsNothing);
    });

    testWidgets('tapping Connected POS does nothing', (tester) async {
      await open(tester, WorkspaceRole.manager);
      await tester.tap(find.byKey(const Key('source-pos')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(db.calledWith('save_venue_sales_source'), isEmpty);
    });

    testWidgets('choosing closing report upload saves it and brings the reports and the Send button', (tester) async {
      await open(tester, WorkspaceRole.manager);
      await tester.tap(find.byKey(const Key('source-upload')));
      await tester.pumpAndSettle();
      expect(db.source, 'upload');
      expect(db.calledWith('save_venue_sales_source').single['p_source'], 'upload');
      expect(find.descendant(of: find.byKey(const Key('source-upload')), matching: find.byIcon(Icons.radio_button_checked)), findsOneWidget);
      expect(find.byKey(const Key('send-closing-report')), findsOneWidget);
      expect(find.byKey(const Key('reports-empty')), findsOneWidget);
    });

    testWidgets('the chosen source is not tapped again (no call for what is already true)', (tester) async {
      await open(tester, WorkspaceRole.manager);
      await tester.tap(find.byKey(const Key('source-entries')));
      await tester.pumpAndSettle();
      expect(db.calledWith('save_venue_sales_source'), isEmpty);
    });

    testWidgets('a verifier reads the source but cannot change it, and cannot send a report', (tester) async {
      db.source = 'upload';
      db.role = 'verifier';
      await open(tester, WorkspaceRole.verifier);
      expect(find.byKey(const Key('sales-read-only')), findsOneWidget);
      await tester.tap(find.byKey(const Key('source-entries')));
      await tester.pumpAndSettle();
      expect(db.calledWith('save_venue_sales_source'), isEmpty);
      expect(find.byKey(const Key('send-closing-report')), findsNothing);
    });

    testWidgets('a refusal from the database reaches the person in its own words', (tester) async {
      await open(tester, WorkspaceRole.manager);
      db.role = 'server';
      await tester.tap(find.byKey(const Key('source-upload')));
      await tester.pumpAndSettle();
      expect(find.text('You don\'t have access to do that.'), findsOneWidget);
    });

    testWidgets('a workspace with no club says so', (tester) async {
      await open(tester, WorkspaceRole.manager, venueId: null);
      expect(find.byKey(const Key('sales-no-venue')), findsOneWidget);
      expect(db.calls, isEmpty);
    });

    testWidgets('when the server cannot be reached it says so and offers Try again', (tester) async {
      db.offline = true;
      await open(tester, WorkspaceRole.manager);
      expect(find.byKey(const Key('sales-error')), findsOneWidget);
      db.offline = false;
      await tester.tap(find.byKey(const Key('ops-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('source-entries')), findsOneWidget);
    });
  });

  group('the reports and checking them', () {
    setUp(() => db.source = 'upload');

    testWidgets('each report says the night, version, net, state, period, figures and whether it includes BottlesUp\'s', (tester) async {
      db.seed(night: '2026-10-31', version: 2, status: 'reviewed', includes: true, note: 'Bar till', reviewNote: 'Matches the till');
      db.seed(night: '2026-10-30', status: 'submitted');
      await open(tester, WorkspaceRole.manager);
      expect(find.textContaining('Sat Oct 31 · version 2 · \$750.00 net · Checked'), findsOneWidget);
      expect(find.text('Includes what BottlesUp recorded.'), findsOneWidget);
      expect(find.text('Bar and other sales only.'), findsOneWidget);
      expect(find.text('Note: Bar till'), findsOneWidget);
      expect(find.text('Checker: Matches the till'), findsOneWidget);
      expect(find.textContaining('gross \$800.00, discounts \$50.00, refunds \$0.00'), findsNWidgets(2));
    });

    testWidgets('a manager cannot check anything; the owner can check what someone else sent', (tester) async {
      final r = db.seed(by: 'someone');
      await open(tester, WorkspaceRole.manager);
      expect(find.byKey(Key('accept-${r['id']}')), findsNothing);
      db.role = 'owner';
      await open(tester, WorkspaceRole.owner);
      expect(find.byKey(Key('accept-${r['id']}')), findsOneWidget);
      expect(find.byKey(Key('refuse-${r['id']}')), findsOneWidget);
    });

    testWidgets('a report you sent says someone else has to check it, and has no Accept', (tester) async {
      db.role = 'owner';
      final r = db.seed(by: 'me');
      await open(tester, WorkspaceRole.owner);
      expect(find.byKey(Key('mine-${r['id']}')), findsOneWidget);
      expect(find.byKey(Key('accept-${r['id']}')), findsNothing);
    });

    testWidgets('a report already checked offers nothing', (tester) async {
      db.role = 'verifier';
      final r = db.seed(status: 'reviewed');
      await open(tester, WorkspaceRole.verifier);
      expect(find.byKey(Key('accept-${r['id']}')), findsNothing);
    });

    testWidgets('Accept accepts it and the list shows it checked', (tester) async {
      db.role = 'verifier';
      final r = db.seed();
      await open(tester, WorkspaceRole.verifier);
      await tester.tap(find.byKey(Key('accept-${r['id']}')));
      await tester.pumpAndSettle();
      expect(db.calledWith('review_closing_report').single, {'p_report': r['id'], 'p_approve': true, 'p_note': null});
      expect(r['status'], 'reviewed');
      expect(find.text('Report accepted.'), findsOneWidget);
      expect(find.byKey(Key('accept-${r['id']}')), findsNothing);
    });

    testWidgets('Not accepted asks why, will not take a few letters, and sends the reason', (tester) async {
      db.role = 'verifier';
      final r = db.seed();
      await open(tester, WorkspaceRole.verifier);
      await tester.tap(find.byKey(Key('refuse-${r['id']}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('refuse-reason')), 'nope');
      await tester.tap(find.byKey(const Key('refuse-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('refuse-reason')), findsOneWidget, reason: 'four letters is not a reason: the question stays');
      expect(db.calledWith('review_closing_report'), isEmpty);
      await tester.enterText(find.byKey(const Key('refuse-reason')), 'Totals do not add up');
      await tester.tap(find.byKey(const Key('refuse-confirm')));
      await tester.pumpAndSettle();
      expect(db.calledWith('review_closing_report').single, {'p_report': r['id'], 'p_approve': false, 'p_note': 'Totals do not add up'});
      expect(r['status'], 'rejected');
      expect(find.text('Report not accepted.'), findsOneWidget);
    });

    testWidgets('cancelling the question sends nothing', (tester) async {
      db.role = 'verifier';
      final r = db.seed();
      await open(tester, WorkspaceRole.verifier);
      await tester.tap(find.byKey(Key('refuse-${r['id']}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('refuse-cancel')));
      await tester.pumpAndSettle();
      expect(db.calledWith('review_closing_report'), isEmpty);
      expect(r['status'], 'submitted');
    });

    testWidgets('when the database refuses (the report was replaced meanwhile) the person reads its sentence', (tester) async {
      db.role = 'verifier';
      final r = db.seed();
      await open(tester, WorkspaceRole.verifier);
      r['status'] = 'superseded';
      await tester.tap(find.byKey(Key('accept-${r['id']}')));
      await tester.pumpAndSettle();
      expect(find.text('A newer report replaced this one.'), findsOneWidget);
    });
  });

  group('sending a report', () {
    setUp(() => db.source = 'upload');

    Future<void> goToForm(WidgetTester tester) async {
      await open(tester, WorkspaceRole.manager);
      await tester.tap(find.byKey(const Key('send-closing-report')));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on last night, 8:00 PM to 4:00 AM, with nothing chosen', (tester) async {
      await goToForm(tester);
      expect(find.text('Send a closing report'), findsWidgets);
      expect(find.text('Sat Oct 31'), findsOneWidget);
      expect(find.text('8:00 PM'), findsOneWidget);
      expect(find.text('4:00 AM'), findsOneWidget);
      expect(find.byKey(const Key('closing-problem')), findsNothing, reason: 'nothing is said about what is missing until the person presses Send');
    });

    testWidgets('pressing Send with nothing says what is missing and sends nothing', (tester) async {
      await goToForm(tester);
      await tester.ensureVisible(find.byKey(const Key('closing-send')));
      await tester.tap(find.byKey(const Key('closing-send')));
      await tester.pump();
      expect(find.text('Enter the gross sales for the period.'), findsOneWidget);
      expect(db.calledWith('submit_closing_report'), isEmpty);
    });

    testWidgets('it will not send until the person says whether the figures include BottlesUp\'s', (tester) async {
      await goToForm(tester);
      await fill(tester, 'closing-gross', '800');
      await tester.ensureVisible(find.byKey(const Key('closing-send')));
      await tester.tap(find.byKey(const Key('closing-send')));
      await tester.pump();
      expect(find.text('Say whether these figures include what BottlesUp recorded.'), findsOneWidget);
      expect(db.calledWith('submit_closing_report'), isEmpty);
    });

    testWidgets('discounts and refunds above the gross are stopped before anything is sent', (tester) async {
      await goToForm(tester);
      await fill(tester, 'closing-gross', '100');
      await fill(tester, 'closing-discount', '60');
      await fill(tester, 'closing-refund', '50');
      await tester.tap(find.byKey(const Key('closing-includes-no')));
      await tester.ensureVisible(find.byKey(const Key('closing-send')));
      await tester.tap(find.byKey(const Key('closing-send')));
      await tester.pump();
      expect(find.text('Discounts and refunds cannot be more than the gross sales.'), findsOneWidget);
      expect(db.calledWith('submit_closing_report'), isEmpty);
    });

    testWidgets('a complete report is sent as the database asks, the list shows it, and the person is told', (tester) async {
      await goToForm(tester);
      await fill(tester, 'closing-gross', '800.00');
      await fill(tester, 'closing-discount', '50');
      await fill(tester, 'closing-note', 'Bar till 1 and 2');
      await tester.ensureVisible(find.byKey(const Key('closing-includes-yes')));
      await tester.tap(find.byKey(const Key('closing-includes-yes')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('closing-send')));
      await tester.tap(find.byKey(const Key('closing-send')));
      await tester.pumpAndSettle();
      final p = db.calledWith('submit_closing_report').single;
      expect((p['p_venue'], p['p_night'], p['p_gross_cents'], p['p_discount_cents'], p['p_refund_cents'], p['p_includes_bottlesup'], p['p_note']), ('v1', '2026-10-31', 80000, 5000, 0, true, 'Bar till 1 and 2'));
      expect(find.text('Closing report sent. Someone else will check it.'), findsOneWidget);
      expect(find.byKey(const Key('closing-report-form')), findsNothing, reason: 'back on the list');
      expect(find.textContaining('Sat Oct 31 · version 1 · \$750.00 net · Waiting to be checked'), findsOneWidget);
    });

    testWidgets('sending the same night again makes version 2, and the first is replaced', (tester) async {
      db.seed(night: '2026-10-31', by: 'me');
      await goToForm(tester);
      await fill(tester, 'closing-gross', '900');
      await tester.ensureVisible(find.byKey(const Key('closing-includes-no')));
      await tester.tap(find.byKey(const Key('closing-includes-no')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('closing-send')));
      await tester.tap(find.byKey(const Key('closing-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('version 2'), findsOneWidget);
      expect(find.textContaining('version 1 · \$750.00 net · Replaced by a newer report'), findsOneWidget);
    });

    testWidgets('a refusal from the database stays on the form, in its own words', (tester) async {
      await goToForm(tester);
      await fill(tester, 'closing-gross', '800');
      await tester.ensureVisible(find.byKey(const Key('closing-includes-no')));
      await tester.tap(find.byKey(const Key('closing-includes-no')));
      await tester.pump();
      db.source = 'entries';
      await tester.ensureVisible(find.byKey(const Key('closing-send')));
      await tester.tap(find.byKey(const Key('closing-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('closing-failure')), findsOneWidget);
      expect(find.text('This club does not use closing report uploads: change Sales Tracking first.'), findsOneWidget);
      expect(find.byKey(const Key('closing-report-form')), findsOneWidget);
    });

    testWidgets('the times can be changed', (tester) async {
      await openForm(tester, pick: (context, initial) async => const TimeOfDay(hour: 22, minute: 30));
      await tester.tap(find.byKey(const Key('closing-start')));
      await tester.pump();
      expect(find.text('10:30 PM'), findsOneWidget);
      await tester.tap(find.byKey(const Key('closing-end')));
      await tester.pump();
      expect(find.text('10:30 PM'), findsNWidgets(2));
      await fill(tester, 'closing-gross', '800');
      await tester.ensureVisible(find.byKey(const Key('closing-send')));
      await tester.tap(find.byKey(const Key('closing-send')));
      await tester.pump();
      expect(find.text('The period must end after it starts.'), findsOneWidget);
    });
  });
}
