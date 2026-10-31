import 'dart:typed_data';

import 'package:bottles_up_vendor/features/night/providers/night_providers.dart';
import 'package:bottles_up_vendor/features/night/screens/consolidated_report_screen.dart';
import 'package:bottles_up_vendor/features/night/screens/night_screen.dart';
import 'package:bottles_up_vendor/features/night/screens/owner_reports_screen.dart';
import 'package:bottles_up_vendor/features/night/screens/report_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_night_backend.dart';

late FakeNightBackend db;
late List<({Uint8List bytes, String name})> shared;
bool shareFails = false;

/// Friday evening: the business night is Friday 9 October 2026.
DateTime fridayNight() => DateTime(2026, 10, 9, 22, 0);

List<OrgVenue> clubs = const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')];

Widget host(Widget child) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        nightServiceProvider.overrideWithValue(db.service),
        shareReportProvider.overrideWithValue((bytes, name) async {
          if (shareFails) throw Exception('no share sheet');
          shared.add((bytes: bytes, name: name));
        }),
        ownerVenuesProvider.overrideWith((ref, org) async => clubs),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeIn(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Widget night({bool canReopen = false}) => NightScreen(venueId: 'v1', venueName: 'Club A', canReopen: canReopen, clock: fridayNight);

bool ticked(WidgetTester tester, String key) => tester.widget<CheckboxListTile>(find.byKey(Key('check-$key'))).value == true;

void main() {
  setUp(() {
    db = FakeNightBackend();
    shared = [];
    shareFails = false;
    clubs = const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')];
  });

  group('Prepare and close', () {
    testWidgets('shows the night open, the preparing and closing items, and that nothing is waiting', (tester) async {
      await open(tester, night());
      expect(db.calledWith('night_close_status').first, {'p_venue': 'v1', 'p_night': '2026-10-09'});
      expect(find.text('Open'), findsOneWidget);
      expect(find.byKey(const Key('check-floor_ready')), findsOneWidget);
      expect(find.byKey(const Key('check-cash_secured')), findsOneWidget);
      expect(find.byKey(const Key('nothing-open')), findsOneWidget);
      expect(find.byKey(const Key('night-close')), findsOneWidget);
      expect(find.text('Preliminary report'), findsOneWidget);
    });

    testWidgets('ticking an item saves it, shows who ticked it, and unticking undoes it', (tester) async {
      await open(tester, night());
      await tapKey(tester, 'check-floor_ready');
      expect(db.calledWith('night_check').single, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_key': 'floor_ready', 'p_done': true});
      expect(ticked(tester, 'floor_ready'), isTrue);
      expect(find.textContaining('Mia Manager'), findsOneWidget);
      await tapKey(tester, 'check-floor_ready');
      expect(db.calledWith('night_check').last['p_done'], false);
      expect(ticked(tester, 'floor_ready'), isFalse);
    });

    testWidgets('what is still open is listed with counts', (tester) async {
      db.blockers = [
        {'key': 'payments_to_check', 'label': 'payments waiting to be checked', 'count': 3},
        {'key': 'cash_held', 'label': 'people still holding cash they have not handed in', 'count': 1},
      ];
      await open(tester, night());
      expect(find.text('• 3 payments waiting to be checked'), findsOneWidget);
      expect(find.text('• 1 people still holding cash they have not handed in'), findsOneWidget);
      expect(find.byKey(const Key('nothing-open')), findsNothing);
    });

    testWidgets('closing with things open: the dialog lists them, wants a yes and a reason, and the exceptions are kept', (tester) async {
      db.blockers = [
        {'key': 'payments_to_check', 'label': 'payments waiting to be checked', 'count': 3},
      ];
      await open(tester, night());
      await tapKey(tester, 'night-close');
      expect(find.byKey(const Key('close-exception-payments_to_check')), findsOneWidget);
      expect(find.byKey(const Key('close-exception-Floor cleared and tables released')), findsOneWidget, reason: 'unticked closing items count too');
      await tapKey(tester, 'close-confirm');
      expect(find.text('Tick the box to confirm you know these are still open.'), findsOneWidget);
      await tapKey(tester, 'close-know');
      await tapKey(tester, 'close-confirm');
      expect(find.text('Say why you are closing with these still open (at least 10 characters).'), findsOneWidget);
      expect(db.calledWith('close_night'), isEmpty, reason: 'nothing is sent until it is right');
      await typeIn(tester, 'close-note', 'Owner agreed to chase the rest');
      await tapKey(tester, 'close-confirm');
      expect(find.text('The night is closed with 4 exceptions.'), findsOneWidget);
      expect(db.calledWith('close_night').single, {'p_venue': 'v1', 'p_night': '2026-10-09', 'p_acknowledge': true, 'p_note': 'Owner agreed to chase the rest'});
      expect(find.text('Closed'), findsOneWidget);
      expect(find.byKey(const Key('exception-payments_to_check')), findsOneWidget);
      expect(find.byKey(const Key('exceptions-note')), findsOneWidget);
      expect(find.byKey(const Key('night-close')), findsNothing);
      expect(find.text('Final report'), findsOneWidget);
    });

    testWidgets('backing out of the close sends nothing', (tester) async {
      await open(tester, night());
      await tapKey(tester, 'night-close');
      await tapKey(tester, 'close-back');
      expect(db.calledWith('close_night'), isEmpty);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('a clean close is a plain confirmation: nothing to excuse', (tester) async {
      db.ticked.addAll(['floor_cleared', 'stock_counted', 'cash_secured']);
      await open(tester, night());
      await tapKey(tester, 'night-close');
      expect(find.byKey(const Key('close-clean')), findsOneWidget);
      expect(find.byKey(const Key('close-note')), findsNothing);
      await tapKey(tester, 'close-confirm');
      expect(find.text('The night is closed.'), findsOneWidget);
      expect(db.calledWith('close_night').single['p_acknowledge'], false);
      expect(find.byKey(const Key('closed-clean')), findsOneWidget);
    });

    testWidgets('a closed night locks its checklist and says only the owner reopens it', (tester) async {
      db.status = 'closed';
      await open(tester, night());
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('check-floor_ready'))).onChanged, isNull);
      expect(find.byKey(const Key('night-owner-only')), findsOneWidget);
      expect(find.byKey(const Key('night-reopen')), findsNothing);
      expect(find.textContaining('Closed 0'), findsOneWidget, reason: 'who closed it and when');
    });

    testWidgets('the owner reopens a closed night with a reason', (tester) async {
      db.status = 'closed';
      db.role = 'owner';
      await open(tester, night(canReopen: true));
      await tapKey(tester, 'night-reopen');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say why this night is being reopened (at least 10 characters).'), findsOneWidget);
      await typeIn(tester, 'text-field', 'We forgot to count the float');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('The night is open again.'), findsOneWidget);
      expect(db.calledWith('reopen_night').single['p_reason'], 'We forgot to count the float');
      expect(find.text('Reopened'), findsOneWidget);
      expect(find.byKey(const Key('night-close')), findsOneWidget, reason: 'it can be closed again');
    });

    testWidgets('the database refusing a close is shown in its own words', (tester) async {
      await open(tester, night());
      db.status = 'closed';
      await tapKey(tester, 'night-close');
      await tapKey(tester, 'close-know');
      await typeIn(tester, 'close-note', 'Owner agreed to chase the rest');
      await tapKey(tester, 'close-confirm');
      expect(find.text('This night is already closed.'), findsOneWidget);
    });

    testWidgets('a backend without the night functions says so and offers no retry; a dropped connection offers Try again', (tester) async {
      db.missing = true;
      await open(tester, night());
      expect(find.byKey(const Key('night-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.offline = true;
      await open(tester, night());
      db.offline = false;
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('night-close')), findsOneWidget);
    });

    testWidgets('another night can be looked at', (tester) async {
      await open(tester, night());
      await tapKey(tester, 'night-prev');
      expect(db.calledWith('night_close_status').last['p_night'], '2026-10-08');
    });
  });

  group('The report', () {
    Widget reportScreen() => ReportScreen(venueId: 'v1', venueName: 'Club A', clock: fridayNight);

    testWidgets('shows the manager\'s sections with the figures, and says it is preliminary', (tester) async {
      await open(tester, reportScreen());
      expect(find.byKey(const Key('report-title')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('report-title'))).data, 'Nightly report');
      expect(find.textContaining('PRELIMINARY'), findsOneWidget);
      expect(find.text('\$160.00'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Bottle orders'), findsOneWidget);
      expect(db.calledWith('night_report').first, {'p_venue': 'v1', 'p_night': '2026-10-09'});
    });

    testWidgets('the verifier sees the money and no security', (tester) async {
      db.role = 'verifier';
      await open(tester, reportScreen());
      expect(tester.widget<Text>(find.byKey(const Key('report-title'))).data, 'Finance report');
      expect(find.text('Cash'), findsWidgets);
      expect(find.text('Security'), findsNothing);
      expect(find.text('Bottle orders'), findsNothing);
    });

    testWidgets('security sees only security, no money', (tester) async {
      db.role = 'security';
      await open(tester, reportScreen());
      expect(tester.widget<Text>(find.byKey(const Key('report-title'))).data, 'Security report');
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Sales'), findsNothing);
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('a final report says who closed it and what was excused', (tester) async {
      db.blockers = [
        {'key': 'tasks_open', 'label': 'security tasks not done', 'count': 1},
      ];
      await db.service.close('v1', '2026-10-09', acknowledge: true, note: 'Owner agreed to chase the rest');
      await open(tester, reportScreen());
      expect(find.textContaining('FINAL · closed'), findsOneWidget);
      expect(find.text('Closed with exceptions'), findsOneWidget);
      expect(find.text('Reason given'), findsOneWidget);
    });

    testWidgets('sharing makes a real PDF named for the club, night and kind of report', (tester) async {
      await open(tester, reportScreen());
      await tapKey(tester, 'report-share');
      expect(shared, hasLength(1));
      expect(shared.single.name, 'club-a-2026-10-09-full-preliminary.pdf');
      expect(String.fromCharCodes(shared.single.bytes.take(5)), '%PDF-');
    });

    testWidgets('if the PDF cannot be shared the person is told, and can try again', (tester) async {
      shareFails = true;
      await open(tester, reportScreen());
      await tapKey(tester, 'report-share');
      expect(find.text('The PDF could not be made or shared. Try again.'), findsOneWidget);
      shareFails = false;
      await tapKey(tester, 'report-share');
      expect(shared, hasLength(1));
    });

    testWidgets('a person who may not see it is told, with no retry', (tester) async {
      db.role = 'server';
      await open(tester, reportScreen());
      expect(find.byKey(const Key('report-error')), findsOneWidget);
      expect(find.byKey(const Key('report-share')), findsNothing);
    });

    testWidgets('another night can be looked at', (tester) async {
      await open(tester, reportScreen());
      await tapKey(tester, 'night-prev');
      expect(db.calledWith('night_report').last['p_night'], '2026-10-08');
    });
  });

  group('Reports (owner)', () {
    final owner = const Workspace(membershipId: 'w', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

    testWidgets('lists each club with its report and night controls', (tester) async {
      db.role = 'owner';
      await open(tester, OwnerReportsScreen(workspace: owner, clock: fridayNight));
      expect(find.byKey(const Key('owner-report-v1')), findsOneWidget);
      expect(find.byKey(const Key('owner-report-v2')), findsOneWidget);
      expect(find.text('Club B'), findsOneWidget);
    });

    testWidgets('the owner opens a club\'s night controls and can reopen there', (tester) async {
      db.role = 'owner';
      db.status = 'closed';
      await open(tester, OwnerReportsScreen(workspace: owner, clock: fridayNight));
      await tapKey(tester, 'owner-night-v1');
      expect(find.byKey(const Key('night-reopen')), findsOneWidget);
      expect(db.calledWith('night_close_status').last['p_venue'], 'v1');
    });

    testWidgets('the owner opens a club\'s report', (tester) async {
      db.role = 'owner';
      await open(tester, OwnerReportsScreen(workspace: owner, clock: fridayNight));
      await tester.tap(find.descendant(of: find.byKey(const Key('owner-report-v2')), matching: find.byKey(const Key('report-open'))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('report-title')), findsOneWidget);
      expect(db.calledWith('night_report').last['p_venue'], 'v2');
    });

    testWidgets('with two or more clubs the whole business is one tap away', (tester) async {
      db.role = 'owner';
      await open(tester, OwnerReportsScreen(workspace: owner, clock: fridayNight));
      expect(find.byKey(const Key('owner-report-all')), findsOneWidget);
      await tapKey(tester, 'consolidated-open');
      expect(find.byKey(const Key('consolidated-title')), findsOneWidget);
      expect(db.calledWith('owner_night_report').single, {'p_org': 'o1', 'p_night': '2026-10-09'});
    });

    testWidgets('with one club there is no combined report (its own report is the whole business)', (tester) async {
      db.role = 'owner';
      clubs = const [OrgVenue(id: 'v1', name: 'Club A', status: 'published')];
      await open(tester, OwnerReportsScreen(workspace: owner, clock: fridayNight));
      expect(find.byKey(const Key('owner-report-all')), findsNothing);
      expect(find.byKey(const Key('consolidated-open')), findsNothing);
      expect(find.byKey(const Key('owner-report-v1')), findsOneWidget);
    });
  });

  group('The combined report', () {
    Widget combined() => ConsolidatedReportScreen(orgId: 'o1', orgName: 'Club Co', clock: fridayNight);

    testWidgets('shows how many clubs have closed, the totals with their currency, and each club', (tester) async {
      db.role = 'owner';
      await open(tester, combined());
      expect(find.text('All venues'), findsOneWidget);
      expect(find.textContaining('PRELIMINARY · 1 of 2 clubs have closed the night'), findsOneWidget);
      expect(find.text('Sales (CAD)'), findsOneWidget);
      expect(find.text(r'$210.00'), findsOneWidget);
      expect(find.text('By club'), findsOneWidget);
      expect(find.text('Club A · FINAL'), findsOneWidget);
      expect(find.text('Club B · PRELIMINARY'), findsOneWidget);
      expect(find.text('Club A · FINAL · CAD'), findsOneWidget);
    });

    testWidgets('clubs that sold in more than one currency are not added together', (tester) async {
      db.role = 'owner';
      db.consolidated['currency'] = null;
      db.consolidated['currency_mixed'] = true;
      db.consolidated['currencies'] = ['cad', 'usd'];
      db.consolidated['totals'] = null;
      await open(tester, combined());
      expect(find.text('Totals not added'), findsOneWidget);
      expect(find.text('Not shown'), findsOneWidget);
      expect(find.text('Booked total'), findsNWidgets(2), reason: 'only the two clubs\' own figures remain');
      expect(find.text(r'$210.00'), findsNothing);
    });

    testWidgets('sharing makes a real PDF named for the business, the night and whether it is final', (tester) async {
      db.role = 'owner';
      await open(tester, combined());
      await tapKey(tester, 'consolidated-share');
      expect(shared, hasLength(1));
      expect(shared.single.name, 'club-co-all-venues-2026-10-09-preliminary.pdf');
      expect(String.fromCharCodes(shared.single.bytes.take(5)), '%PDF-');
    });

    testWidgets('if the PDF cannot be shared the person is told, and can try again', (tester) async {
      db.role = 'owner';
      shareFails = true;
      await open(tester, combined());
      await tapKey(tester, 'consolidated-share');
      expect(find.text('The PDF could not be made or shared. Try again.'), findsOneWidget);
      shareFails = false;
      await tapKey(tester, 'consolidated-share');
      expect(shared, hasLength(1));
    });

    testWidgets('a person who is not the owner is told, with nothing to share', (tester) async {
      db.role = 'manager';
      await open(tester, combined());
      expect(find.byKey(const Key('consolidated-error')), findsOneWidget);
      expect(find.byKey(const Key('consolidated-share')), findsNothing);
    });

    testWidgets('a business with no club says so', (tester) async {
      db.role = 'owner';
      db.consolidated['venues'] = [];
      db.consolidated['venues_total'] = 0;
      db.consolidated['venues_final'] = 0;
      await open(tester, combined());
      expect(find.byKey(const Key('consolidated-empty')), findsOneWidget);
      expect(find.text('No venues in this business yet'), findsOneWidget);
    });

    testWidgets('another night can be looked at', (tester) async {
      db.role = 'owner';
      await open(tester, combined());
      await tapKey(tester, 'night-prev');
      expect(db.calledWith('owner_night_report').last['p_night'], '2026-10-08');
    });
  });
}
