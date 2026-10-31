import 'dart:convert';

import 'package:bottles_up_vendor/features/night/providers/night_providers.dart';
import 'package:bottles_up_vendor/features/night/screens/consolidated_report_screen.dart';
import 'package:bottles_up_vendor/features/night/screens/report_screen.dart';
import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/report_emails/logic/report_email_rules.dart';
import 'package:bottles_up_vendor/features/report_emails/providers/report_email_providers.dart';
import 'package:bottles_up_vendor/features/report_emails/screens/report_recipients_screen.dart';
import 'package:bottles_up_vendor/features/report_emails/widgets/email_report_button.dart';
import 'package:bottles_up_vendor/features/venue_access/providers/venue_access_providers.dart';
import 'package:bottles_up_vendor/features/venue_access/screens/organizer_sales_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../night/fake_night_backend.dart';
import '../venue_access/fake_access_backend.dart';
import 'fake_report_email_backend.dart';

late FakeReportEmailBackend mail;
late FakeNightBackend night;
late FakeAccessBackend access;

DateTime fridayNight() => DateTime(2026, 10, 9, 22, 0);

Workspace workspace(WorkspaceRole role, {String? venueId, String? venueName}) =>
    Workspace(membershipId: 'w', orgId: 'o1', orgName: 'Club Co', orgKind: role == WorkspaceRole.organizer ? 'organizer' : 'venue_owner', role: role, venueId: venueId, venueName: venueName);

const clubs = [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')];

Widget host(Widget child) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        reportEmailServiceProvider.overrideWithValue(mail.service),
        nightServiceProvider.overrideWithValue(night.service),
        venueAccessServiceProvider.overrideWithValue(access.service),
        shareReportProvider.overrideWithValue((bytes, name) async {}),
        ownerVenuesProvider.overrideWith((ref, org) async => clubs),
        organizerEventsProvider.overrideWith((ref, org) async => [OrgEvent(eventId: 'e1', title: 'Night One', startDate: DateTime(2026, 10, 10), status: OrgEventStatus.draft)]),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child) async {
  tester0 = tester;
  tester.view.physicalSize = const Size(800, 6000);
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

bool has(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;
String textOf(String key) => (tester0.widget(find.byKey(Key(key))) as Text).data ?? '';
Color? colorOf(String key) => (tester0.widget(find.byKey(Key(key))) as Text).style?.color;
late WidgetTester tester0;

void main() {
  setUp(() {
    mail = FakeReportEmailBackend(role: 'owner');
    night = FakeNightBackend();
    access = FakeAccessBackend(role: 'organizer');
  });

  group('Report e-mails (More)', () {
    testWidgets('the owner keeps the combined list and a list for each club', (tester) async {
      tester0 = tester;
      mail.seed('owner_combined', 'o1', null, ['boss@club.example']);
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      expect(find.text('Report e-mails'), findsOneWidget);
      expect(has('report-emails-note'), isTrue);
      expect(find.text('Combined report'), findsOneWidget);
      expect(find.text('Night report: Club A'), findsOneWidget);
      expect(find.text('Night report: Club B'), findsOneWidget);
      expect(find.text('boss@club.example'), findsOneWidget);
      expect(find.text('Event report'), findsNothing);
    });

    testWidgets('adds an address to one list only, and shows it', (tester) async {
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      await typeIn(tester, 'list-venue-v1-field', '  Accountant@Club.Example ');
      await tapKey(tester, 'list-venue-v1-add');
      expect(find.text('accountant@club.example'), findsOneWidget);
      expect(mail.calledWith('add_report_recipient').single, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1', 'p_email': 'Accountant@Club.Example'});
      expect(mail.lists['owner_combined|o1|'], isNull);
      expect(mail.lists['venue_night|o1|v2'], isNull);
      expect(tester.widget<TextField>(find.byKey(const Key('list-venue-v1-field'))).controller!.text, '');
    });

    testWidgets('says what is wrong without asking the database', (tester) async {
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      await typeIn(tester, 'list-combined-field', 'not an address');
      await tapKey(tester, 'list-combined-add');
      expect(find.text('Enter one e-mail address, like name@company.com.'), findsOneWidget);
      await typeIn(tester, 'list-combined-field', 'ok@club.example');
      expect(find.text('Enter one e-mail address, like name@company.com.'), findsNothing);
      expect(mail.calledWith('add_report_recipient'), isEmpty);
    });

    testWidgets('a duplicate is refused before it is sent', (tester) async {
      mail.seed('owner_combined', 'o1', null, ['boss@club.example']);
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      await typeIn(tester, 'list-combined-field', 'BOSS@club.example');
      await tapKey(tester, 'list-combined-add');
      expect(find.text('That address is already on the list.'), findsOneWidget);
      expect(mail.calledWith('add_report_recipient'), isEmpty);
    });

    testWidgets('the eleventh address is turned away', (tester) async {
      mail.seed('owner_combined', 'o1', null, [for (var i = 1; i <= 10; i++) 'p$i@club.example']);
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      await typeIn(tester, 'list-combined-field', 'eleventh@club.example');
      await tapKey(tester, 'list-combined-add');
      expect(find.text('A list can hold at most 10 addresses. Remove one first.'), findsOneWidget);
    });

    testWidgets('takes an address off', (tester) async {
      mail.seed('venue_night', 'o1', 'v1', ['a@club.example', 'b@club.example']);
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      await tapKey(tester, 'list-venue-v1-remove-0');
      expect(find.text('a@club.example'), findsNothing);
      expect(find.text('b@club.example'), findsOneWidget);
      expect(mail.lists['venue_night|o1|v1']!.map((r) => r.email), ['b@club.example']);
    });

    testWidgets('a refusal from the database is shown as its sentence', (tester) async {
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      mail.role = 'stranger';
      await typeIn(tester, 'list-combined-field', 'late@club.example');
      await tapKey(tester, 'list-combined-add');
      expect(find.text('You don\'t have access to do that.'), findsOneWidget);
    });

    testWidgets('a dropped connection is a plain sentence, and the list stays', (tester) async {
      mail.seed('owner_combined', 'o1', null, ['boss@club.example']);
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      mail.offline = true;
      await typeIn(tester, 'list-combined-field', 'late@club.example');
      await tapKey(tester, 'list-combined-add');
      expect(find.text('That could not be saved. Check your connection and try again.'), findsOneWidget);
      expect(find.text('boss@club.example'), findsOneWidget);
    });

    testWidgets('a list that cannot be read says so, with a way to try again', (tester) async {
      mail.role = 'stranger';
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.owner)));
      expect(has('list-combined-error'), isTrue);
    });

    testWidgets('the manager keeps only their own club\'s list', (tester) async {
      mail.role = 'manager';
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A')));
      expect(find.text('Night report: Club A'), findsOneWidget);
      expect(find.text('Combined report'), findsNothing);
      expect(find.text('Event report'), findsNothing);
      expect(find.text('Night report: Club B'), findsNothing);
    });

    testWidgets('a manager who is not tied to a club has no list to keep', (tester) async {
      mail.role = 'manager';
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.manager)));
      expect(find.textContaining('Night report'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(mail.calls, isEmpty);
    });

    testWidgets('the organizer keeps the event report\'s list', (tester) async {
      mail.role = 'organizer';
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.organizer)));
      expect(find.text('Event report'), findsOneWidget);
      expect(find.text('Combined report'), findsNothing);
      await typeIn(tester, 'list-events-field', 'promoter@events.example');
      await tapKey(tester, 'list-events-add');
      expect(mail.calledWith('add_report_recipient').single['p_kind'], 'organizer_sales');
      expect(find.text('promoter@events.example'), findsOneWidget);
    });

    testWidgets('a role with nothing to set up is told so', (tester) async {
      await open(tester, ReportRecipientsScreen(workspace: workspace(WorkspaceRole.door)));
      expect(has('report-emails-none'), isTrue);
    });
  });

  group('E-mail this report', () {
    Widget report({String? emailOrgId = 'o1'}) => ReportScreen(venueId: 'v1', venueName: 'Club A', emailOrgId: emailOrgId, clock: fridayNight);

    testWidgets('the night report has the button only for the people who may use it', (tester) async {
      await open(tester, report());
      expect(has('report-email'), isTrue);
      expect(has('report-share'), isTrue);
      await open(tester, report(emailOrgId: null));
      expect(has('report-email'), isFalse);
      expect(has('report-share'), isTrue);
    });

    testWidgets('the combined report and an organizer\'s Sales have it too', (tester) async {
      night.role = 'owner';
      await open(tester, ConsolidatedReportScreen(orgId: 'o1', orgName: 'Club Co', clock: fridayNight));
      expect(has('consolidated-email'), isTrue);
      await open(tester, OrganizerSalesScreen(workspace: workspace(WorkspaceRole.organizer)));
      expect(has('sales-email'), isTrue);
    });

    testWidgets('opens a sheet that says who it goes to and that nothing is sent on its own', (tester) async {
      mail.role = 'manager';
      mail.seed('venue_night', 'o1', 'v1', ['boss@club.example', 'accountant@club.example']);
      await open(tester, report());
      await tapKey(tester, 'report-email');
      expect(has('report-email-title'), isTrue);
      expect(find.text('boss@club.example'), findsOneWidget);
      expect(find.text('accountant@club.example'), findsOneWidget);
      expect(textOf('report-email-explainer'), contains('owner and the manager of the club'));
      expect(textOf('report-email-note'), reportEmailNote);
      expect(find.text('E-mail to 2 people'), findsOneWidget);
      expect(mail.sends, isEmpty);
    });

    testWidgets('sends the PDF the screen made, to the list, and shows the result and the log', (tester) async {
      mail.role = 'manager';
      mail.seed('venue_night', 'o1', 'v1', ['boss@club.example', 'accountant@club.example']);
      await open(tester, report());
      await tapKey(tester, 'report-email');
      await tapKey(tester, 'report-email-send');
      expect(mail.sends, hasLength(1));
      final body = mail.sends.single.body;
      expect(body['kind'], 'venue_night');
      expect(body['orgId'], 'o1');
      expect(body['venueId'], 'v1');
      expect(body['ref'], '2026-10-09');
      expect(base64Decode(body['pdfBase64'] as String).sublist(0, 5), utf8.encode('%PDF-'));
      expect(RegExp(r'^[A-Za-z0-9 _.()-]{1,95}\.pdf$').hasMatch(body['filename'] as String), isTrue);
      expect(textOf('report-email-result'), 'Sent to 2 people.');
      expect(colorOf('report-email-result'), isNot(Theme.of(tester.element(find.byKey(const Key('report-email-result')))).colorScheme.error));
      expect(has('report-email-again'), isFalse);
      expect(has('report-email-log-0'), isTrue);
      expect(find.textContaining('boss@club.example: sent'), findsOneWidget);
    });

    testWidgets('says which address failed and sends again to only that one', (tester) async {
      mail.role = 'manager';
      mail.seed('venue_night', 'o1', 'v1', ['boss@club.example', 'accountant@club.example']);
      mail.failFor.add('accountant@club.example');
      await open(tester, report());
      await tapKey(tester, 'report-email');
      await tapKey(tester, 'report-email-send');
      expect(textOf('report-email-result'), 'Sent to 1 of 2. 1 could not be reached: you can send again to them.');
      expect(find.textContaining('accountant@club.example: could not be sent'), findsOneWidget);
      expect(find.text('Send again to the 1 that failed'), findsOneWidget);
      mail.failFor.clear();
      await tapKey(tester, 'report-email-again');
      expect(mail.sends.last.body['again'], isTrue);
      expect(textOf('report-email-result'), 'Sent to 1 person.');
      expect(has('report-email-again'), isFalse);
      expect(mail.sends, hasLength(2));
    });

    testWidgets('with no one on the list there is nothing to send, and adding someone is possible right there', (tester) async {
      mail.role = 'manager';
      await open(tester, report());
      await tapKey(tester, 'report-email');
      expect(find.text('No one yet. Add an e-mail address below.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('report-email-send'))).onPressed, isNull);
      await typeIn(tester, 'report-email-list-field', 'boss@club.example');
      await tapKey(tester, 'report-email-list-add');
      expect(find.text('E-mail to 1 person'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('report-email-send'))).onPressed, isNotNull);
    });

    testWidgets('a refusal or a dropped connection is a sentence in the sheet, in the error colour', (tester) async {
      mail.role = 'manager';
      mail.seed('venue_night', 'o1', 'v1', ['boss@club.example']);
      await open(tester, report());
      await tapKey(tester, 'report-email');
      mail.offline = true;
      await tapKey(tester, 'report-email-send');
      expect(textOf('report-email-result'), 'The report could not be e-mailed. Check your connection and try again.');
      expect(colorOf('report-email-result'), Theme.of(tester.element(find.byKey(const Key('report-email-result')))).colorScheme.error);
      mail.offline = false;
      mail.role = 'stranger';
      await tapKey(tester, 'report-email-send');
      expect(textOf('report-email-result'), 'You cannot e-mail this report.');
    });

    testWidgets('when nothing could be sent the result is an error, in the error colour, and sending again is offered', (tester) async {
      mail.role = 'manager';
      mail.seed('venue_night', 'o1', 'v1', ['boss@club.example']);
      mail.failFor.add('boss@club.example');
      await open(tester, report());
      await tapKey(tester, 'report-email');
      await tapKey(tester, 'report-email-send');
      expect(textOf('report-email-result'), 'Nothing was sent: the e-mail was not accepted. Try again in a moment.');
      expect(colorOf('report-email-result'), Theme.of(tester.element(find.byKey(const Key('report-email-result')))).colorScheme.error);
      expect(has('report-email-again'), isTrue);
    });

    testWidgets('a report that could not be made as a PDF says so and sends nothing', (tester) async {
      mail.role = 'manager';
      mail.seed('venue_night', 'o1', 'v1', ['boss@club.example']);
      await open(
        tester,
        EmailReportButton(
          target: const ReportTarget(kind: ReportKind.venueNight, orgId: 'o1', venueId: 'v1', ref: '2026-10-09', fileName: 'n.pdf'),
          buildPdf: () async => throw Exception('no fonts'),
        ),
      );
      await tapKey(tester, 'email-report');
      await tapKey(tester, 'email-report-send');
      expect(textOf('email-report-result'), 'The PDF could not be made. Try again.');
      expect(mail.sends, isEmpty);
    });

    testWidgets('an organizer\'s Sales e-mails the event\'s report to the organizer list', (tester) async {
      mail.role = 'organizer';
      mail.seed('organizer_sales', 'o1', null, ['promoter@events.example']);
      await open(tester, OrganizerSalesScreen(workspace: workspace(WorkspaceRole.organizer)));
      await tapKey(tester, 'sales-email');
      await tapKey(tester, 'sales-email-send');
      final body = mail.sends.single.body;
      expect((body['kind'], body['orgId'], body['venueId'], body['eventId'], body['ref']), ('organizer_sales', 'o1', null, 'e1', 'e1'));
      expect(textOf('sales-email-result'), 'Sent to 1 person.');
    });

    testWidgets('the owner\'s combined report e-mails to the combined list for the night shown', (tester) async {
      night.role = 'owner';
      mail.seed('owner_combined', 'o1', null, ['boss@club.example']);
      await open(tester, ConsolidatedReportScreen(orgId: 'o1', orgName: 'Club Co', clock: fridayNight));
      await tapKey(tester, 'consolidated-email');
      await tapKey(tester, 'consolidated-email-send');
      final body = mail.sends.single.body;
      expect((body['kind'], body['orgId'], body['venueId'], body['ref']), ('owner_combined', 'o1', null, '2026-10-09'));
      expect(textOf('consolidated-email-result'), 'Sent to 1 person.');
    });
  });
}
