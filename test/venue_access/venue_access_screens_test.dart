import 'dart:async';
import 'dart:typed_data';

import 'package:bottles_up_vendor/features/agreements/providers/agreement_providers.dart';
import 'package:bottles_up_vendor/features/agreements/screens/agreement_detail_screen.dart';
import 'package:bottles_up_vendor/features/night/providers/night_providers.dart';
import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/venue_access/logic/access_rules.dart';
import 'package:bottles_up_vendor/features/venue_access/providers/venue_access_providers.dart';
import 'package:bottles_up_vendor/features/venue_access/screens/organizer_sales_screen.dart';
import 'package:bottles_up_vendor/features/venue_access/screens/venue_access_screen.dart';
import 'package:bottles_up_vendor/features/venue_access/widgets/agreement_grants_card.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../agreements/fake_agreement_backend.dart';
import 'fake_access_backend.dart';

late FakeAccessBackend db;
late List<({Uint8List bytes, String name})> shared;
bool shareFails = false;

const organizer = Workspace(membershipId: 'w3', orgId: 'o9', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);

Widget host(Widget child, {FakeAgreementBackend? agreements}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        venueAccessServiceProvider.overrideWithValue(db.service),
        if (agreements != null) agreementServiceProvider.overrideWithValue(agreements.service),
        shareReportProvider.overrideWithValue((bytes, name) async {
          if (shareFails) throw Exception('no share sheet');
          shared.add((bytes: bytes, name: name));
        }),
        organizerEventsProvider.overrideWith((ref, org) async => [
              OrgEvent(eventId: 'e1', title: 'Night One', startDate: DateTime(2026, 10, 10), status: OrgEventStatus.draft),
              OrgEvent(eventId: 'e2', title: 'Late Night', startDate: DateTime(2026, 10, 11), status: OrgEventStatus.draft),
            ]),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child, {FakeAgreementBackend? agreements}) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(child, agreements: agreements));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// The card on its own, in a scroll view (it is a small card, not a screen).
Widget grantsCard(String id, String side) => SingleChildScrollView(child: AgreementGrantsCard(agreementId: id, side: side));

bool switchOn(WidgetTester tester, String key) => tester.widget<SwitchListTile>(find.byKey(Key(key))).value;

void main() {
  setUp(() {
    db = FakeAccessBackend();
    shared = [];
    shareFails = false;
  });

  group('what the club shares (on the agreement)', () {
    testWidgets('the club sees a switch for each of the six, with what is allowed now', (tester) async {
      await open(tester, grantsCard('a1', 'venue'));
      expect(find.text('What you share with the organizer'), findsOneWidget);
      expect(db.calledWith('agreement_grants').single, {'p_agreement': 'a1', 'p_side': 'venue'});
      for (final k in AccessKey.values) {
        expect(find.byKey(Key('grant-${k.value}')), findsOneWidget, reason: k.value);
      }
      expect([for (final k in AccessKey.values) switchOn(tester, 'grant-${k.value}')], [false, false, true, true, false, false]);
    });

    testWidgets('allowing and withdrawing send just that one thing, and the switch follows the database', (tester) async {
      await open(tester, grantsCard('a1', 'venue'));
      await tapKey(tester, 'grant-ticket_checkins');
      expect(db.calledWith('set_agreement_grant').single, {'p_agreement': 'a1', 'p_grant': 'ticket_checkins', 'p_allowed': true});
      expect(switchOn(tester, 'grant-ticket_checkins'), isTrue);
      await tapKey(tester, 'grant-table_sales');
      expect(db.calledWith('set_agreement_grant').last, {'p_agreement': 'a1', 'p_grant': 'table_sales', 'p_allowed': false});
      expect(switchOn(tester, 'grant-table_sales'), isFalse);
      expect(db.agreements['a1']!.grants, {'capacity', 'ticket_checkins'});
    });

    testWidgets('a thing that can be allowed but is not available yet says so', (tester) async {
      await open(tester, grantsCard('a1', 'venue'));
      expect(find.textContaining('Not available yet'), findsNothing);
      await tapKey(tester, 'grant-bar_sales');
      expect(find.textContaining('Not available yet: it will show once the app can supply it.'), findsOneWidget);
      expect(db.agreements['a1']!.grants, contains('bar_sales'));
    });

    testWidgets('while a change is on its way the switches wait, so a second tap sends nothing more', (tester) async {
      await open(tester, grantsCard('a1', 'venue'));
      db.gates['set_agreement_grant'] = Completer<void>();
      await tester.tap(find.byKey(const Key('grant-chat')));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('grant-chat'))).onChanged, isNull);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('grant-settlement'))).onChanged, isNull);
      db.gates['set_agreement_grant']!.complete();
      await tester.pumpAndSettle();
      expect(db.calledWith('set_agreement_grant'), hasLength(1));
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('grant-chat'))).onChanged, isNotNull);
    });

    testWidgets('if the agreement ended meanwhile the database\'s sentence is shown and the card goes away', (tester) async {
      await open(tester, grantsCard('a1', 'venue'));
      db.agreements['a1']!.status = 'cancelled';
      await tapKey(tester, 'grant-chat');
      expect(find.text('The agreement has to be active before you can share anything under it.'), findsOneWidget);
      expect(find.byKey(const Key('grants-card')), findsNothing, reason: 'nothing is shared under an agreement that is not active');
    });

    testWidgets('allowing what is already allowed says so', (tester) async {
      await open(tester, grantsCard('a1', 'venue'));
      db.agreements['a1']!.grants.add('chat');
      await tapKey(tester, 'grant-chat');
      expect(find.text('It was already shared.'), findsOneWidget);
    });

    testWidgets('withdrawing what is already withdrawn says so', (tester) async {
      await open(tester, grantsCard('a1', 'venue'));
      db.agreements['a1']!.grants.remove('capacity');
      await tapKey(tester, 'grant-capacity');
      expect(find.text('It was already not shared.'), findsOneWidget);
    });

    testWidgets('the organizer sees the same list as read-only states, and no switches', (tester) async {
      db.role = 'organizer';
      await open(tester, grantsCard('a1', 'organizer'));
      expect(find.text('What the club shares with you'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byKey(const Key('grant-state-table_sales')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('grant-state-table_sales')), matching: find.text('Shared')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('grant-state-chat')), matching: find.text('Not shared')), findsOneWidget);
    });

    testWidgets('an agreement not yet active shows no card at all', (tester) async {
      await open(tester, grantsCard('a2', 'venue'));
      expect(find.byKey(const Key('grants-card')), findsNothing);
      expect(find.byKey(const Key('grants-error-card')), findsNothing);
    });

    testWidgets('a server without the migration shows nothing; a dropped connection says so and Try again reads it', (tester) async {
      db.missing = true;
      await open(tester, grantsCard('a1', 'venue'));
      expect(find.byKey(const Key('grants-error-card')), findsNothing);
      db.missing = false;
      db.offline = true;
      await open(tester, grantsCard('a1', 'venue'));
      expect(find.byKey(const Key('grants-error')), findsOneWidget);
      db.offline = false;
      await tapKey(tester, 'grants-retry');
      expect(find.byKey(const Key('grants-card')), findsOneWidget);
    });

    testWidgets('someone with no access is told, with nothing to retry', (tester) async {
      db.role = 'stranger';
      await open(tester, grantsCard('a1', 'venue'));
      expect(find.byKey(const Key('grants-error')), findsOneWidget);
      expect(find.byKey(const Key('grants-retry')), findsNothing);
    });

    testWidgets('on the agreement\'s own page the card appears once the agreement is active, not before', (tester) async {
      final agreements = FakeAgreementBackend();
      agreements.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
      agreements.otherProposes('a1', const {'capacity': 400});
      await open(tester, const AgreementDetailScreen(agreementId: 'a1'), agreements: agreements);
      expect(find.byKey(const Key('grants-card')), findsNothing, reason: 'being agreed: nothing is shared');
      expect(db.calledWith('agreement_grants'), isEmpty, reason: 'it is not even asked for before the agreement is active');
      await tapKey(tester, 'agreement-accept');
      expect(agreements.agreement('a1').status, 'active');
      expect(find.byKey(const Key('grants-card')), findsOneWidget);
      expect(find.text('What you share with the organizer'), findsOneWidget);
    });

    testWidgets('and stays while a newer version waits to be accepted (the old terms are still in force)', (tester) async {
      final agreements = FakeAgreementBackend();
      agreements.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
      agreements.otherProposes('a1', const {'capacity': 400});
      await open(tester, const AgreementDetailScreen(agreementId: 'a1'), agreements: agreements);
      await tapKey(tester, 'agreement-accept');
      agreements.otherProposes('a1', const {'capacity': 500});
      expect(agreements.agreement('a1').status, 'changes_pending');
      await open(tester, const AgreementDetailScreen(agreementId: 'a1'), agreements: agreements);
      expect(find.byKey(const Key('grants-card')), findsOneWidget);
    });
  });

  group('Your venue access (organizer)', () {
    setUp(() => db.role = 'organizer');

    testWidgets('lists each event at each club, with the six where the agreement is active', (tester) async {
      await open(tester, const VenueAccessScreen(workspace: organizer));
      expect(db.calledWith('organizer_venue_access').single, {'p_org': 'o9'});
      expect(find.text('Your venue access'), findsOneWidget);
      expect(find.byKey(const Key('access-a1')), findsOneWidget);
      expect(find.byKey(const Key('access-a2')), findsOneWidget);
      expect(find.byKey(const Key('access-a3')), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      for (final k in AccessKey.values) {
        expect(find.byKey(Key('access-a1-${k.value}')), findsOneWidget, reason: k.value);
      }
      expect(find.descendant(of: find.byKey(const Key('access-a1-table_sales')), matching: find.text('Shared')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('access-a1-bar_sales')), matching: find.text('Not shared')), findsOneWidget);
    });

    testWidgets('an agreement still being agreed shows nothing shared, and why', (tester) async {
      await open(tester, const VenueAccessScreen(workspace: organizer));
      expect(find.text('Being agreed. Nothing is shared until both sides accept.'), findsOneWidget);
      expect(find.text('Asked for: the club has not answered yet. Nothing is shared.'), findsOneWidget);
      expect(find.text('Nothing shared yet'), findsNWidgets(2));
      expect(find.byKey(const Key('access-a2-chat')), findsNothing, reason: 'no list of things to allow before the agreement is active');
    });

    testWidgets('things allowed that cannot be shown yet are told apart from the ones that are shared', (tester) async {
      db.agreements['a1']!.grants.addAll(['bar_sales', 'chat']);
      await open(tester, const VenueAccessScreen(workspace: organizer));
      expect(find.descendant(of: find.byKey(const Key('access-a1-bar_sales')), matching: find.text('Allowed, not available yet')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('access-a1-chat')), matching: find.text('Allowed, not available yet')), findsOneWidget);
    });

    testWidgets('the agreement can be opened from its row', (tester) async {
      final agreements = FakeAgreementBackend(side: 'organizer');
      agreements.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
      agreements.otherProposes('a1', const {'capacity': 400});
      await open(tester, const VenueAccessScreen(workspace: organizer), agreements: agreements);
      await tapKey(tester, 'access-open-a1');
      expect(find.byType(AgreementDetailScreen), findsOneWidget);
    });

    testWidgets('no club yet says so; a server without the migration is told it is not set up; a dropped connection offers Try again', (tester) async {
      db.agreements.clear();
      await open(tester, const VenueAccessScreen(workspace: organizer));
      expect(find.byKey(const Key('venue-access-empty')), findsOneWidget);
      db.missing = true;
      await open(tester, const VenueAccessScreen(workspace: organizer));
      expect(find.byKey(const Key('venue-access-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.offline = true;
      await open(tester, const VenueAccessScreen(workspace: organizer));
      expect(find.byKey(const Key('ops-retry')), findsOneWidget);
    });

    testWidgets('a club cannot open it, and is told so in plain words', (tester) async {
      db.role = 'club';
      await open(tester, const VenueAccessScreen(workspace: organizer));
      expect(find.byKey(const Key('venue-access-error')), findsOneWidget);
      expect(find.text('Your access has ended, or you are signed out.'), findsOneWidget);
    });
  });

  group('Sales (organizer)', () {
    setUp(() => db.role = 'organizer');

    testWidgets('shows the first event: the status, your tickets with their currency, by type, and what the club shares', (tester) async {
      await open(tester, const OrganizerSalesScreen(workspace: organizer));
      expect(db.calledWith('organizer_event_sales').single, {'p_event': 'e1'});
      expect(find.textContaining('Only what each club has chosen to share is included.'), findsOneWidget);
      expect(find.text('Your tickets (CAD)'), findsOneWidget);
      expect(find.text(r'$360.00'), findsOneWidget);
      expect(find.text('By ticket type'), findsOneWidget);
      expect(find.text(r'$270.00'), findsOneWidget);
      expect(find.textContaining('Table sales at Club A (CAD)'), findsOneWidget);
      expect(find.text('Capacity at Club A'), findsOneWidget);
      expect(find.text('Not available from Club A'), findsOneWidget);
      expect(find.text('Club B · not active'), findsOneWidget);
    });

    testWidgets('choosing another event reads that one', (tester) async {
      await open(tester, const OrganizerSalesScreen(workspace: organizer));
      await tester.ensureVisible(find.byKey(const Key('sales-event')));
      await tester.tap(find.byKey(const Key('sales-event')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Late Night').last);
      await tester.pumpAndSettle();
      expect(db.calledWith('organizer_event_sales').last, {'p_event': 'e2'});
      expect(find.text('Your tickets (CAD)'), findsOneWidget);
      expect(find.text('Paid orders'), findsOneWidget);
      expect(find.text(r'$360.00'), findsNothing);
    });

    testWidgets('what the club has not shared stays out of the screen', (tester) async {
      db.agreements['a1']!.grants.clear();
      await open(tester, const OrganizerSalesScreen(workspace: organizer));
      expect(find.textContaining('Table sales at Club A'), findsNothing);
      expect(find.text('Capacity at Club A'), findsNothing);
      expect(find.text('Tables booked'), findsNothing);
      expect(find.text('Not available from Club A'), findsOneWidget);
    });

    testWidgets('sharing makes a real PDF named for the event, with the same words', (tester) async {
      await open(tester, const OrganizerSalesScreen(workspace: organizer));
      await tapKey(tester, 'sales-share');
      expect(shared, hasLength(1));
      expect(shared.single.name, matches(RegExp(r'^night-one-2026-10-\d\d-event-report\.pdf$')));
      expect(String.fromCharCodes(shared.single.bytes.take(5)), '%PDF-');
    });

    testWidgets('if the PDF cannot be shared the person is told and can try again', (tester) async {
      shareFails = true;
      await open(tester, const OrganizerSalesScreen(workspace: organizer));
      await tapKey(tester, 'sales-share');
      expect(find.text('The PDF could not be made or shared. Try again.'), findsOneWidget);
      shareFails = false;
      await tapKey(tester, 'sales-share');
      expect(shared, hasLength(1));
    });

    testWidgets('more than one currency: the money is not added, on the screen as in the PDF', (tester) async {
      db.mixedCurrency = true;
      await open(tester, const OrganizerSalesScreen(workspace: organizer));
      expect(find.text('Not added: more than one currency'), findsWidgets);
      expect(find.text(r'$360.00'), findsNothing);
    });

    testWidgets('a business with no events says so; a failure offers Try again; a club is told their access does not cover it', (tester) async {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [venueAccessServiceProvider.overrideWithValue(db.service), organizerEventsProvider.overrideWith((ref, org) async => <OrgEvent>[])],
        child: MaterialApp(home: const Scaffold(body: OrganizerSalesScreen(workspace: organizer))),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sales-no-events')), findsOneWidget);
      db.offline = true;
      await open(tester, const OrganizerSalesScreen(workspace: organizer));
      expect(find.byKey(const Key('sales-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsOneWidget);
      db.offline = false;
      db.role = 'club';
      await open(tester, const OrganizerSalesScreen(workspace: organizer));
      expect(find.byKey(const Key('sales-error')), findsOneWidget);
      expect(find.text('Your access has ended, or you are signed out.'), findsOneWidget);
    });
  });
}
