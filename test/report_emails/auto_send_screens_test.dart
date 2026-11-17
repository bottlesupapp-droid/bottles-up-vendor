import 'dart:async';

import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/report_emails/logic/report_email_rules.dart';
import 'package:bottles_up_vendor/features/report_emails/providers/report_email_providers.dart';
import 'package:bottles_up_vendor/features/report_emails/screens/report_recipients_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_report_email_backend.dart';

// The switch under each list on Report e-mails (website 20261126100000_auto_report_jobs.sql): off until someone switches it on, says what it will do first, says who it is sent as, shows what the
// latest automatic send did, and shows the database's own sentence when it refuses.

late FakeReportEmailBackend mail;
late WidgetTester t0;

Workspace workspace(WorkspaceRole role, {String? venueId, String? venueName}) =>
    Workspace(membershipId: 'w', orgId: 'o1', orgName: 'Club Co', orgKind: role == WorkspaceRole.organizer ? 'organizer' : 'venue_owner', role: role, venueId: venueId, venueName: venueName);

const clubs = [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')];

Widget host(Widget child) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    reportEmailServiceProvider.overrideWithValue(mail.service),
    ownerVenuesProvider.overrideWith((ref, org) async => clubs),
    organizerEventsProvider.overrideWith((ref, org) async => [OrgEvent(eventId: 'e1', title: 'Night One', startDate: DateTime(2026, 10, 10), status: OrgEventStatus.draft)]),
  ],
  child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
);

Future<void> open(WidgetTester tester, Workspace w) async {
  t0 = tester;
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(ReportRecipientsScreen(workspace: w)));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

bool has(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;
String textOf(String key) => (t0.widget(find.byKey(Key(key))) as Text).data ?? '';
bool switchOn(String key) => t0.widget<SwitchListTile>(find.byKey(Key(key))).value;
bool switchEnabled(String key) => t0.widget<SwitchListTile>(find.byKey(Key(key))).onChanged != null;

const venueSwitch = 'list-venue-v1-auto-switch';

void main() {
  setUp(() => mail = FakeReportEmailBackend(role: 'owner'));

  group('The switch under each list', () {
    testWidgets('the owner has one under the combined list and one under each club\'s, all off, each saying when it would send', (tester) async {
      await open(tester, workspace(WorkspaceRole.owner));
      for (final k in ['list-combined', 'list-venue-v1', 'list-venue-v2']) {
        expect(has('$k-auto-switch'), isTrue, reason: k);
        expect(switchOn('$k-auto-switch'), isFalse, reason: k);
        expect(textOf('$k-auto-state'), 'Off. This report is e-mailed only when someone presses E-mail this report.');
      }
      expect(find.text('Send automatically when every club has closed the night'), findsOneWidget);
      expect(find.text('Send automatically when the night is closed'), findsNWidgets(2));
      expect(mail.calledWith('report_auto_status').map((p) => '${p['p_kind']}|${p['p_venue']}'), unorderedEquals(['owner_combined|null', 'venue_night|v1', 'venue_night|v2']));
    });

    testWidgets('a manager has one for their club, an organizer one for their event reports', (tester) async {
      mail.role = 'manager';
      await open(tester, workspace(WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A'));
      expect(has(venueSwitch), isTrue);
      expect(has('list-combined-auto-switch'), isFalse);
      mail.role = 'organizer';
      await open(tester, workspace(WorkspaceRole.organizer));
      expect(has('list-events-auto-switch'), isTrue);
      expect(find.text('Send automatically when every club hosting an event of yours has closed its night'), findsOneWidget);
    });

    testWidgets('switching on first says what will happen; backing out changes nothing', (tester) async {
      mail.seed('venue_night', 'o1', 'v1', ['a@club.example', 'b@club.example']);
      await open(tester, workspace(WorkspaceRole.owner));
      await tapKey(tester, venueSwitch);
      expect(textOf('auto-confirm-message'), contains('will be e-mailed to the 2 addresses on this list when the night is closed'));
      expect(textOf('auto-confirm-message'), contains('It uses your access'));
      await tapKey(tester, 'auto-confirm-back');
      expect(mail.calledWith('report_auto_set'), isEmpty);
      expect(switchOn(venueSwitch), isFalse);
    });

    testWidgets('confirming switches it on, says it is sent as you, and reads the status again', (tester) async {
      await open(tester, workspace(WorkspaceRole.owner));
      final before = mail.calledWith('report_auto_status').length;
      await tapKey(tester, venueSwitch);
      await tapKey(tester, 'auto-confirm-yes');
      expect(mail.calledWith('report_auto_set').single, {'p_kind': 'venue_night', 'p_org': 'o1', 'p_venue': 'v1', 'p_enabled': true});
      expect(switchOn(venueSwitch), isTrue);
      expect(textOf('list-venue-v1-auto-state'), 'On. It is sent as you: if you lose access to this report, it stops and says so here.');
      expect(switchOn('list-venue-v2-auto-switch'), isFalse, reason: 'only that club');
      expect(has('list-venue-v2-auto-takeover'), isFalse);
      expect(mail.calledWith('report_auto_status').length, greaterThan(before));
      expect(has('list-venue-v1-auto-takeover'), isFalse);
    });

    testWidgets('switching off is at once, with no question', (tester) async {
      mail.autos['venue_night|o1|v1'] = (enabled: true, by: 'me', at: DateTime.utc(2026, 11, 18));
      await open(tester, workspace(WorkspaceRole.owner));
      expect(switchOn(venueSwitch), isTrue);
      await tapKey(tester, venueSwitch);
      expect(has('auto-confirm-message'), isFalse);
      expect(mail.calledWith('report_auto_set').single['p_enabled'], false);
      expect(switchOn(venueSwitch), isFalse);
    });

    testWidgets('when someone else switched it on it says who it is sent as, and offers to send as you instead (after the same question)', (tester) async {
      mail.autos['venue_night|o1|v1'] = (enabled: true, by: 'Mia Manager', at: DateTime.utc(2026, 11, 18));
      await open(tester, workspace(WorkspaceRole.owner));
      expect(textOf('list-venue-v1-auto-state'), 'On. It is sent as Mia Manager: if they lose access to this report, it stops and says so here.');
      await tapKey(tester, 'list-venue-v1-auto-takeover');
      expect(has('auto-confirm-message'), isTrue);
      await tapKey(tester, 'auto-confirm-yes');
      expect(mail.calledWith('report_auto_set').single['p_enabled'], true);
      expect(textOf('list-venue-v1-auto-state'), startsWith('On. It is sent as you'));
      expect(has('list-venue-v1-auto-takeover'), isFalse);
    });

    testWidgets('when it is on and the list is empty it says nothing will be sent', (tester) async {
      mail.autos['venue_night|o1|v1'] = (enabled: true, by: 'me', at: DateTime.utc(2026, 11, 18));
      await open(tester, workspace(WorkspaceRole.owner));
      expect(textOf('list-venue-v1-auto-no-recipients'), autoNoRecipientsText);
      mail.seed('venue_night', 'o1', 'v1', ['a@club.example']);
      await open(tester, workspace(WorkspaceRole.owner));
      expect(has('list-venue-v1-auto-no-recipients'), isFalse);
    });

    testWidgets('while it is off an empty list gives no warning, and the confirmation says the list is empty', (tester) async {
      await open(tester, workspace(WorkspaceRole.owner));
      expect(has('list-venue-v1-auto-no-recipients'), isFalse);
      await tapKey(tester, venueSwitch);
      expect(textOf('auto-confirm-message'), contains('the list (it is empty, so nothing will be sent until you add an address)'));
    });

    testWidgets('adding an address updates what the switch knows about the list', (tester) async {
      mail.autos['venue_night|o1|v1'] = (enabled: true, by: 'me', at: DateTime.utc(2026, 11, 18));
      await open(tester, workspace(WorkspaceRole.owner));
      expect(has('list-venue-v1-auto-no-recipients'), isTrue);
      await t0.enterText(find.byKey(const Key('list-venue-v1-field')), 'new@club.example');
      await t0.pump();
      await tapKey(t0, 'list-venue-v1-add');
      expect(has('list-venue-v1-auto-no-recipients'), isFalse);
      await tapKey(t0, 'list-venue-v1-remove-0');
      expect(has('list-venue-v1-auto-no-recipients'), isTrue);
    });
  });

  group('What the latest automatic send did', () {
    Future<void> withLast(WidgetTester tester, String status, {String? error, String ref = '2026-11-14'}) async {
      mail.autos['venue_night|o1|v1'] = (enabled: true, by: 'me', at: DateTime.utc(2026, 11, 18));
      mail.seed('venue_night', 'o1', 'v1', ['a@club.example']);
      mail.lastJobs['venue_night|o1|v1'] = (status: status, ref: ref, error: error, at: DateTime.utc(2026, 11, 18, 3));
      await open(tester, workspace(WorkspaceRole.owner));
    }

    testWidgets('nothing yet shows no line', (tester) async {
      await open(tester, workspace(WorkspaceRole.owner));
      expect(has('list-venue-v1-auto-last'), isFalse);
    });

    testWidgets('sent (in the ordinary colour, not the error colour)', (tester) async {
      await withLast(tester, 'sent');
      expect(textOf('list-venue-v1-auto-last'), 'Last automatic send, Saturday Nov 14: sent');
      final error = Theme.of(t0.element(find.byKey(const Key('list-venue-v1-auto-last')))).colorScheme.error;
      expect((t0.widget(find.byKey(const Key('list-venue-v1-auto-last'))) as Text).style?.color, isNot(error));
    });

    testWidgets('a failure says why, and the person is told what to do (switch it on again)', (tester) async {
      await withLast(tester, 'failed', error: 'The person who switched it on no longer has access. Switch it on again.');
      expect(textOf('list-venue-v1-auto-last'), 'Last automatic send, Saturday Nov 14: not sent: The person who switched it on no longer has access. Switch it on again.');
      final error = Theme.of(t0.element(find.byKey(const Key('list-venue-v1-auto-last')))).colorScheme.error;
      expect((t0.widget(find.byKey(const Key('list-venue-v1-auto-last'))) as Text).style?.color, error, reason: 'a failure is shown in the error colour');
    });

    testWidgets('waiting, running and skipped', (tester) async {
      await withLast(tester, 'pending', error: 'Too many reports were sent this hour.');
      expect(textOf('list-venue-v1-auto-last'), 'Last automatic send, Saturday Nov 14: waiting to be sent: Too many reports were sent this hour.');
      await withLast(tester, 'running');
      expect(textOf('list-venue-v1-auto-last'), 'Last automatic send, Saturday Nov 14: being sent now');
      await withLast(tester, 'skipped', error: 'No one is set to receive it. Add an e-mail address first.');
      expect(textOf('list-venue-v1-auto-last'), 'Last automatic send, Saturday Nov 14: skipped: No one is set to receive it. Add an e-mail address first.');
    });
  });

  group('When it cannot be done or read', () {
    testWidgets('a refusal is the database\'s own sentence under the switch, and the switch shows what the database says', (tester) async {
      await open(tester, workspace(WorkspaceRole.owner));
      mail.role = 'stranger';
      await tapKey(tester, venueSwitch);
      await tapKey(tester, 'auto-confirm-yes');
      expect(textOf('list-venue-v1-auto-message'), "You don't have access to do that.");
      expect(switchOn(venueSwitch), isFalse);
    });

    testWidgets('a lost connection says so; the switch can be pressed again', (tester) async {
      await open(tester, workspace(WorkspaceRole.owner));
      mail.offline = true;
      await tapKey(tester, venueSwitch);
      await tapKey(tester, 'auto-confirm-yes');
      expect(textOf('list-venue-v1-auto-message'), contains('Check your connection'));
    });

    testWidgets('a server without the migration says automatic sending is not set up, and the list above still works', (tester) async {
      mail.seed('venue_night', 'o1', 'v1', ['a@club.example']);
      mail.missingFor.add('report_auto_status');
      await open(tester, workspace(WorkspaceRole.owner));
      expect(textOf('list-venue-v1-auto-error'), 'The automatic sending settings are not set up on this server yet.');
      expect(has(venueSwitch), isFalse);
      expect(find.text('a@club.example'), findsOneWidget);
    });

    testWidgets('an old refusal goes as soon as the next try starts', (tester) async {
      await open(tester, workspace(WorkspaceRole.owner));
      mail.role = 'stranger';
      await tapKey(tester, venueSwitch);
      await tapKey(tester, 'auto-confirm-yes');
      expect(has('list-venue-v1-auto-message'), isTrue);
      mail.role = 'owner';
      mail.setGate = Completer<void>();
      await tapKey(tester, venueSwitch);
      await tester.tap(find.byKey(const Key('auto-confirm-yes')));
      await tester.pump();
      await tester.pump();
      expect(has('list-venue-v1-auto-message'), isFalse, reason: 'while the new try is under way');
      mail.setGate!.complete();
      await tester.pumpAndSettle();
      expect(has('list-venue-v1-auto-message'), isFalse);
    });

    testWidgets('while it is being saved the takeover cannot be pressed either', (tester) async {
      mail.autos['venue_night|o1|v1'] = (enabled: true, by: 'Mia Manager', at: DateTime.utc(2026, 11, 18));
      await open(tester, workspace(WorkspaceRole.owner));
      expect(t0.widget<TextButton>(find.byKey(const Key('list-venue-v1-auto-takeover'))).onPressed, isNotNull);
      mail.setGate = Completer<void>();
      await tapKey(tester, 'list-venue-v1-auto-takeover');
      await tester.tap(find.byKey(const Key('auto-confirm-yes')));
      await tester.pump();
      await tester.pump();
      expect(t0.widget<TextButton>(find.byKey(const Key('list-venue-v1-auto-takeover'))).onPressed, isNull);
      mail.setGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('while the switch is being saved it cannot be pressed again', (tester) async {
      await open(tester, workspace(WorkspaceRole.owner));
      expect(switchEnabled(venueSwitch), isTrue);
      mail.setGate = Completer<void>();
      await tapKey(tester, venueSwitch);
      await tester.tap(find.byKey(const Key('auto-confirm-yes')));
      await tester.pump();
      await tester.pump();
      expect(switchEnabled(venueSwitch), isFalse);
      mail.setGate!.complete();
      await tester.pumpAndSettle();
      expect(switchEnabled(venueSwitch), isTrue);
      expect(mail.calledWith('report_auto_set'), hasLength(1));
    });
  });
}
