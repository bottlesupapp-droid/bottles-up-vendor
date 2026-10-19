import 'package:bottles_up_vendor/features/agreements/providers/agreement_providers.dart';
import 'package:bottles_up_vendor/features/agreements/screens/agreement_detail_screen.dart';
import 'package:bottles_up_vendor/features/agreements/screens/agreements_screen.dart';
import 'package:bottles_up_vendor/features/agreements/screens/ask_club_screen.dart';
import 'package:bottles_up_vendor/features/agreements/screens/terms_form_screen.dart';
import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_agreement_backend.dart';

late FakeAgreementBackend db;

const manager = Workspace(membershipId: 'w1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const owner = Workspace(membershipId: 'w2', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const organizer = Workspace(membershipId: 'w3', orgId: 'o9', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);

Widget host(Widget child) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        agreementServiceProvider.overrideWithValue(db.service),
        organizerEventsProvider.overrideWith((ref, org) async => [OrgEvent(eventId: 'e1', title: 'Night One', startDate: DateTime(2026, 11, 1), status: OrgEventStatus.draft)]),
        ownerVenuesProvider.overrideWith((ref, org) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')]),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: child)),
    );

Future<void> open(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 5000);
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
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

const fullTerms = {
  'capacity': 400,
  'rooms': 'Main room',
  'ticket_ownership': 'organizer',
  'bar_percent': 10,
  'threshold_cents': 500000,
  'formula': 'above_threshold',
  'eligible_revenue': 'bar sales net of tax',
  'refunds': 'deducted',
  'taxes_tips_fees': 'excluded',
};

String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() {
    db = FakeAgreementBackend();
  });

  group('The list', () {
    testWidgets('a club sees the requests from organizers, which wait on it, and the state of each', (tester) async {
      db.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
      final b = FakeAgreement('a2', 'Night Two', 'Club A');
      db.agreements.add(b);
      db.otherProposes('a2', fullTerms);
      await open(tester, const AgreementsScreen(workspace: manager));
      expect(db.calledWith('agreement_list').first, {'p_venue': 'v1', 'p_org': null});
      expect(text(tester, 'agreement-line-a1'), 'Night Events · Requested\nWaiting for you to review the request');
      expect(text(tester, 'agreement-line-a2'), 'Night Events · Being agreed\nWaiting for you to review version 1');
      expect(find.byKey(const Key('agreements-ask')), findsNothing, reason: 'a club does not ask');
    });

    testWidgets('an organizer sees each request with the club and who must act', (tester) async {
      db.side = 'organizer';
      db.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
      await open(tester, const AgreementsScreen(workspace: organizer));
      expect(db.calledWith('agreement_list').first, {'p_venue': null, 'p_org': 'o9'});
      expect(text(tester, 'agreement-line-a1'), 'Club A · Requested\nWaiting for the club to respond');
      expect(find.byKey(const Key('agreements-ask')), findsOneWidget);
    });

    testWidgets('the owner picks a club first', (tester) async {
      await open(tester, const AgreementsScreen(workspace: owner));
      expect(find.byKey(const Key('agreements-pick-club')), findsOneWidget);
      await tapKey(tester, 'agreements-club-v2');
      expect(db.calledWith('agreement_list').first['p_venue'], 'v2');
    });

    testWidgets('nothing yet, a missing backend and a dropped connection are said in words', (tester) async {
      await open(tester, const AgreementsScreen(workspace: manager));
      expect(find.byKey(const Key('agreements-empty')), findsOneWidget);
      db.missing = true;
      await open(tester, const AgreementsScreen(workspace: manager));
      expect(find.byKey(const Key('agreements-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.offline = true;
      await open(tester, const AgreementsScreen(workspace: manager));
      db.offline = false;
      await tapKey(tester, 'ops-retry');
      expect(find.byKey(const Key('agreements-empty')), findsOneWidget);
    });
  });

  group('Asking a club', () {
    testWidgets('choose the event and a club that belongs to a business, add a message, send', (tester) async {
      db.side = 'organizer';
      await open(tester, const AskClubScreen(orgId: 'o9'));
      await tapKey(tester, 'ask-send');
      expect(find.text('Choose the event.'), findsOneWidget);
      await tapKey(tester, 'ask-event');
      await tester.tap(find.text('Night One').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'ask-send');
      expect(find.text('Choose the club.'), findsOneWidget);
      await typeIn(tester, 'ask-search', 'c');
      await tapKey(tester, 'ask-search-go');
      expect(find.text('Type at least 2 letters of the club\'s name.'), findsOneWidget);
      await typeIn(tester, 'ask-search', 'club al');
      await tapKey(tester, 'ask-search-go');
      expect(find.byKey(const Key('ask-club-v2')), findsOneWidget);
      expect(find.byKey(const Key('ask-club-v3')), findsNothing, reason: 'a club nobody runs on BottlesUp cannot be asked');
      await tapKey(tester, 'ask-club-v2');
      expect(find.text('Asking: Club Alpha'), findsOneWidget);
      await typeIn(tester, 'ask-message', 'Friday 24th, 400 guests');
      await tapKey(tester, 'ask-send');
      expect(db.calledWith('agreement_request').single, {'p_event': 'e1', 'p_venue': 'v2', 'p_message': 'Friday 24th, 400 guests'});
    });

    testWidgets('a second request for a club that already has one is refused with the reason', (tester) async {
      db.side = 'organizer';
      db.agreements.add(FakeAgreement('a1', 'Night One', 'v1'));
      await open(tester, const AskClubScreen(orgId: 'o9'));
      await tapKey(tester, 'ask-event');
      await tester.tap(find.text('Night One').last);
      await tester.pumpAndSettle();
      await typeIn(tester, 'ask-search', 'club a');
      await tapKey(tester, 'ask-search-go');
      await tapKey(tester, 'ask-club-v1');
      await tapKey(tester, 'ask-send');
      expect(find.text('This event already has an agreement with that club.'), findsOneWidget);
    });
  });

  group('The terms form', () {
    testWidgets('checks the share of bar sales, shows the sample, and returns the terms and a note', (tester) async {
      TermsProposal? result;
      await tester.pumpWidget(host(Builder(builder: (context) => TextButton(key: const Key('open'), onPressed: () async => result = await Navigator.of(context).push<TermsProposal>(MaterialPageRoute(builder: (_) => const TermsFormScreen())), child: const Text('open')))));
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tapKey(tester, 'open');
      await tapKey(tester, 'terms-send');
      expect(find.text('Fill in at least one term.'), findsOneWidget);
      await typeIn(tester, 'term-bar_percent', '10');
      await tapKey(tester, 'terms-send');
      expect(find.text('A share of bar sales needs a threshold (0 if it applies from the first sale).'), findsOneWidget);
      await typeIn(tester, 'term-threshold_cents', '5000');
      await tapKey(tester, 'terms-send');
      expect(find.textContaining('ABOVE the threshold or of ALL sales'), findsWidgets);
      await tapKey(tester, 'term-formula-above_threshold');
      await tapKey(tester, 'terms-send');
      expect(find.text('Say which revenue counts towards the share.'), findsOneWidget);
      await typeIn(tester, 'term-eligible_revenue', 'bar sales net of tax');
      await typeIn(tester, 'term-refunds', 'deducted');
      await typeIn(tester, 'term-taxes_tips_fees', 'excluded');
      expect(text(tester, 'sample-result'), 'On \$10,000.00 of bar sales the organizer\'s share would be \$500.00.');
      await typeIn(tester, 'sample-sales', '8000');
      expect(text(tester, 'sample-result'), 'On \$8,000.00 of bar sales the organizer\'s share would be \$300.00.');
      await tapKey(tester, 'term-formula-all_once_reached');
      expect(text(tester, 'sample-result'), 'On \$8,000.00 of bar sales the organizer\'s share would be \$800.00.');
      await tapKey(tester, 'term-ownership-shared');
      await typeIn(tester, 'terms-note', 'Happy to talk about the threshold');
      await tapKey(tester, 'terms-send');
      expect(result!.terms['bar_percent'], 10);
      expect(result!.terms['threshold_cents'], 500000);
      expect(result!.terms['formula'], 'all_once_reached');
      expect(result!.terms['ticket_ownership'], 'shared');
      expect(result!.note, 'Happy to talk about the threshold');
    });

    testWidgets('changing existing terms starts from them', (tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TermsFormScreen(initial: fullTerms)));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('term-capacity'))).controller!.text, '400');
      expect(tester.widget<TextField>(find.byKey(const Key('term-threshold_cents'))).controller!.text, '5000.00');
      expect(tester.widget<TextField>(find.byKey(const Key('term-bar_percent'))).controller!.text, '10');
    });
  });

  group('An agreement', () {
    Future<FakeAgreement> negotiating(WidgetTester tester, {String side = 'venue'}) async {
      db.side = side;
      final a = FakeAgreement('a1', 'Night One', 'Club A', requestNote: 'Friday 24th, around 400 guests');
      db.agreements.add(a);
      db.otherProposes('a1', fullTerms, note: 'We would like 10 percent of bar sales above 5000');
      await open(tester, const AgreementDetailScreen(agreementId: 'a1'));
      return a;
    }

    testWidgets('shows what is proposed, in words, by whom, who has accepted, and the sample calculation', (tester) async {
      await negotiating(tester);
      expect(find.text('Being agreed'), findsOneWidget);
      expect(text(tester, 'agreement-terms-heading'), 'Proposed terms: version 1');
      expect(text(tester, 'agreement-request-note'), 'Request: Friday 24th, around 400 guests');
      expect(text(tester, 'term-value-threshold_cents'), '\$5,000.00');
      expect(text(tester, 'term-value-formula'), 'A percentage of sales ABOVE the threshold');
      expect(text(tester, 'agreement-version-note'), '"We would like 10 percent of bar sales above 5000"');
      expect(text(tester, 'agreement-acceptance'), contains('Organizer: Olive Organizer'));
      expect(text(tester, 'agreement-acceptance'), contains('Club: not yet'));
      expect(text(tester, 'detail-sample-result'), 'On \$10,000.00 of bar sales the organizer\'s share would be \$500.00.');
      await typeIn(tester, 'detail-sample-sales', '8000');
      expect(text(tester, 'detail-sample-result'), 'On \$8,000.00 of bar sales the organizer\'s share would be \$300.00.');
    });

    testWidgets('accepting the version on screen makes it active, names who accepted, and hides the button', (tester) async {
      final a = await negotiating(tester);
      expect(find.text('Accept version 1'), findsOneWidget);
      await tapKey(tester, 'agreement-accept');
      expect(find.text('You accepted version 1.'), findsOneWidget);
      expect(db.calledWith('agreement_accept').single, {'p_agreement': 'a1', 'p_version': 1});
      expect(a.status, 'active');
      expect(find.text('Active'), findsOneWidget);
      expect(text(tester, 'agreement-terms-heading'), 'Accepted terms: version 1');
      expect(text(tester, 'agreement-acceptance'), contains('Club: Me'));
      expect(find.byKey(const Key('agreement-accept')), findsNothing);
    });

    testWidgets('if the other side proposed something newer meanwhile, the old version cannot be accepted', (tester) async {
      await negotiating(tester);
      db.otherProposes('a1', {...fullTerms, 'capacity': 350});
      await tapKey(tester, 'agreement-accept');
      expect(find.text('That version was replaced: read the latest one.'), findsOneWidget);
      expect(text(tester, 'agreement-terms-heading'), 'Proposed terms: version 2');
      expect(text(tester, 'change-0'), '• Capacity: 400 → 350');
    });

    testWidgets('proposing changes opens the form with the current terms, sends a new version and says the other side has to accept it', (tester) async {
      await negotiating(tester);
      await tapKey(tester, 'agreement-propose');
      expect(tester.widget<TextField>(find.byKey(const Key('term-capacity'))).controller!.text, '400');
      await typeIn(tester, 'term-capacity', '350');
      await typeIn(tester, 'terms-note', 'Capacity is limited by the fire certificate');
      await tapKey(tester, 'terms-send');
      expect(find.text('Version 2 sent. The other side has to accept it.'), findsOneWidget);
      final sent = db.calledWith('agreement_propose').single;
      expect((sent['p_terms'] as Map)['capacity'], 350);
      expect(sent['p_note'], 'Capacity is limited by the fire certificate');
      expect(text(tester, 'agreement-terms-heading'), 'Proposed terms: version 2');
      expect(find.byKey(const Key('agreement-accept')), findsNothing, reason: 'the proposer has already accepted their own proposal');
      expect(text(tester, 'change-0'), '• Capacity: 400 → 350');
      expect(find.byKey(const Key('agreement-version-1')), findsOneWidget, reason: 'the earlier version is kept');
    });

    testWidgets('a club declines a request with a reason; the organizer sees it declined', (tester) async {
      db.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
      await open(tester, const AgreementDetailScreen(agreementId: 'a1'));
      expect(find.byKey(const Key('agreement-no-terms')), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      await tapKey(tester, 'agreement-close');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Say why.'), findsOneWidget);
      await typeIn(tester, 'text-field', 'We are closed that night');
      await tapKey(tester, 'dialog-confirm');
      expect(find.text('Request declined.'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(text(tester, 'agreement-closed-reason'), 'Reason: We are closed that night');
      expect(find.byKey(const Key('agreement-propose')), findsNothing);
      expect(find.byKey(const Key('agreement-note-field')), findsNothing);
    });

    testWidgets('an organizer withdraws instead of declining', (tester) async {
      db.side = 'organizer';
      db.agreements.add(FakeAgreement('a1', 'Night One', 'Club A'));
      await open(tester, const AgreementDetailScreen(agreementId: 'a1'));
      expect(find.text('Withdraw'), findsOneWidget);
      expect(find.text('Waiting for the club to respond.'), findsOneWidget);
    });

    testWidgets('notes go to the other side and appear in the discussion', (tester) async {
      await negotiating(tester);
      await tapKey(tester, 'agreement-note-add');
      expect(find.text('Write the note first.'), findsOneWidget);
      await typeIn(tester, 'agreement-note-field', 'Can we move the threshold to 6000?');
      await tapKey(tester, 'agreement-note-add');
      expect(db.calledWith('agreement_note').single['p_body'], 'Can we move the threshold to 6000?');
      expect(find.textContaining('Can we move the threshold to 6000?'), findsWidgets);
      expect(find.textContaining('You (club)'), findsOneWidget);
    });

    testWidgets('a change to an active agreement leaves the old version in force until the new one is accepted', (tester) async {
      final a = await negotiating(tester);
      await tapKey(tester, 'agreement-accept');
      db.otherProposes('a1', {...fullTerms, 'capacity': 350});
      expect(a.status, 'changes_pending');
      await open(tester, const AgreementDetailScreen(agreementId: 'a1'));
      expect(find.text('Active, change proposed'), findsOneWidget);
      expect(find.text('Accept version 2'), findsOneWidget);
      expect(find.byKey(const Key('agreement-version-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('agreement-version-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('(in force)'), findsOneWidget);
    });

    testWidgets('a person who may not see it, and a dropped connection, are told', (tester) async {
      db.offline = true;
      await open(tester, const AgreementDetailScreen(agreementId: 'a1'));
      expect(find.byKey(const Key('agreement-error')), findsOneWidget);
    });
  });
}
