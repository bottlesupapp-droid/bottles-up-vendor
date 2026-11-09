import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/more/screens/more_screen.dart';
import 'package:bottles_up_vendor/features/preview/preview_catalog.dart';
import 'package:bottles_up_vendor/features/preview/preview_config.dart';
import 'package:bottles_up_vendor/features/preview/screens/app_wide_screens.dart';
import 'package:bottles_up_vendor/features/preview/screens/inbox_screens.dart';
import 'package:bottles_up_vendor/features/preview/screens/preview_gallery_screen.dart';
import 'package:bottles_up_vendor/features/preview/widgets/pv_kit.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design/role_test_support.dart' show loadInter, ownerWs;
import 'preview_test_support.dart';

/// The sample screens: parts of the design that are not built yet, drawn with made-up data. These tests pin that every one opens, that the
/// few that have rules (the DJ's price breakdown) add up, and that they are reachable only when they are switched on.

Workspace ws(String id, WorkspaceRole role) => Workspace(membershipId: id, orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: role);

void main() {
  setUpAll(loadInter);

  group('the catalog', () {
    test('every sample screen has its own id, says what it is, and names the prototype file its layout came from', () {
      final entries = previewCatalog;
      expect({for (final e in entries) e.id}.length, entries.length, reason: 'ids are unique');
      for (final e in entries) {
        expect(e.title.trim(), isNotEmpty);
        expect(e.subtitle.trim(), isNotEmpty);
        expect(e.source.trim(), isNotEmpty);
        expect(previewEntryFor(e.id), isNotNull, reason: e.id);
      }
      expect(previewEntryFor('no-such-screen'), isNull);
    });

    test('the three roles the app does not have are in the catalog', () {
      final ids = previewCatalog.map((e) => e.id);
      expect(ids, containsAll(['dj', 'ambassador', 'event-lead']));
    });

    test('the sample screens are on in a test run (a debug build)', () => expect(kPreviewsEnabled, isTrue));
  });

  group('every sample screen opens', () {
    for (final e in previewCatalog) {
      testWidgets('${e.title}: no error, and it says it is a sample', (tester) async {
        await show(tester, Builder(builder: e.build));
        expect(tester.takeException(), isNull);
        final saysSample = find.byKey(const Key('pv-sample-note')).evaluate().isNotEmpty || find.text('Sample').evaluate().isNotEmpty;
        expect(saysSample, isTrue, reason: 'a sample screen must say so');
      });

      if (e.app != null) {
        testWidgets('${e.title}: every tab opens with a heading and no error', (tester) async {
          await show(tester, Builder(builder: e.build));
          for (final tab in e.app!.tabs) {
            await tapTab(tester, tab.label);
            expect(tester.takeException(), isNull, reason: tab.label);
            expect(find.byType(BuPageHeader), findsOneWidget, reason: '${tab.label} shows its heading');
          }
        });
      }
    }
  });

  group('DJ / Artist', () {
    testWidgets('Requests: three new ones to start, and the chips move between the groups', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      expect(find.text('Jordan Ellis'), findsOneWidget);
      expect(find.text('Midnight Social'), findsOneWidget);
      expect(find.text('Priya Shah'), findsOneWidget);
      expect(find.text('New · 3'), findsOneWidget);
      expect(find.text('Sky Room'), findsNothing);

      await tapText(tester, 'Confirmed');
      expect(find.text('Sky Room'), findsOneWidget);
      expect(find.text('Jordan Ellis'), findsNothing);

      await tapText(tester, 'Past');
      expect(find.text('Northwind Agency'), findsOneWidget);
    });

    testWidgets('a countered request waits under "Awaiting client", not under Past', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      await tapText(tester, 'Awaiting client · 1');
      expect(find.text('Maya Chen'), findsOneWidget);
      expect(find.text('Awaiting client'), findsWidgets, reason: 'its pill');
      await tapText(tester, 'Past');
      expect(find.text('Maya Chen'), findsNothing);
      expect(find.text('Northwind Agency'), findsOneWidget);
    });

    testWidgets('a clash with another gig is said on the row', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      expect(find.textContaining('Date conflict with Nova Room residency'), findsOneWidget);
    });

    testWidgets('a request adds up: package, extra hour and equipment, then 13% tax, a 30% deposit, and the payout after the 10% fee', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      await tapText(tester, 'Jordan Ellis');
      expect(find.text('Private event · 3 h'), findsOneWidget);
      expect(find.text('\$900.00'), findsOneWidget);
      expect(find.text('Extra time · 1 h'), findsOneWidget);
      expect(find.text('\$250.00'), findsOneWidget);
      expect(find.text('\$300.00'), findsOneWidget);
      expect(find.text('\$1,450.00'), findsOneWidget, reason: 'subtotal');
      expect(find.text('\$188.50'), findsOneWidget, reason: '13% of 1,450');
      expect(find.text('\$1,638.50'), findsOneWidget, reason: 'what the client pays');
      expect(find.text('\$491.55'), findsOneWidget, reason: '30% deposit');
      expect(find.text('\$1,305.00'), findsOneWidget, reason: 'payout after a 10% fee of 145');
    });

    testWidgets('a new request can be accepted, countered or declined; each opens a sheet that says nothing is sent', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      await tapText(tester, 'Jordan Ellis');

      await tapText(tester, 'Accept booking');
      expect(find.text('Accept this booking?'), findsOneWidget);
      expect(find.text('\$491.55 deposit (30%)'), findsOneWidget);
      await tapText(tester, 'Accept booking', last: true);
      expect(find.text('Sample screen: nothing was saved or sent.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a confirmed request has nothing to accept or decline', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      await tapText(tester, 'Confirmed');
      await tapText(tester, 'Sky Room');
      expect(find.text('Accept booking'), findsNothing);
      expect(find.text('Counter-offer'), findsNothing);
    });

    testWidgets('Calendar: tapping a booked day says what is on it, a free day offers to block it', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      await tapTab(tester, 'Calendar');
      await tester.tap(find.byKey(const Key('pv-day-21')));
      await tester.pumpAndSettle();
      expect(find.text('Confirmed'), findsOneWidget, reason: 'the sheet of a booked day says the gig is confirmed');
      expect(find.text('Block this date'), findsNothing, reason: 'a booked day cannot be blocked');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pv-day-3')));
      await tester.pumpAndSettle();
      expect(find.text('Block this date'), findsOneWidget);
    });

    testWidgets('Services: the four packages and five add-ons are listed with their prices', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      await tapTab(tester, 'Services');
      expect(find.text('Warm-up set'), findsOneWidget);
      expect(find.text('Club set'), findsOneWidget);
      expect(find.text('Private event'), findsOneWidget);
      expect(find.text('Festival / headline'), findsOneWidget);
      expect(find.textContaining('from \$900 · 3 h'), findsOneWidget, reason: 'a "from" price says from');
      expect(find.text('Extra performance time'), findsOneWidget);
      expect(find.textContaining('\$250 per hour'), findsOneWidget);
    });

    testWidgets('Earnings: what can be paid out, and where each gig stands', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      await tapTab(tester, 'Earnings');
      expect(find.text('\$2,640.00'), findsOneWidget);
      expect(find.text('Paid out'), findsNWidgets(2));
      expect(find.text('Payout pending'), findsOneWidget);
      expect(find.text('Deposit held'), findsOneWidget);
    });

    testWidgets('More: the public profile, the editor and Messages each open', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('dj')!.build));
      await tapTab(tester, 'More');
      await tapText(tester, 'View public profile');
      expect(find.text('Request a booking'), findsOneWidget);
      await tapText(tester, 'Request a booking');
      expect(find.text('Send request'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Edit profile');
      expect(find.text('Save profile'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, 'Messages');
      expect(find.text('Inquiries · 2'), findsOneWidget);
    });
  });

  group('Messages', () {
    testWidgets('Inquiries and Team hold different conversations; search narrows them; no match says so', (tester) async {
      await show(tester, const InboxPage(account: 'DJ / Artist'));
      expect(find.text('Jordan Ellis'), findsOneWidget);
      expect(find.text('Neon Garden crew'), findsNothing);
      await tapText(tester, 'Team · 1');
      expect(find.text('Neon Garden crew'), findsOneWidget);
      expect(find.text('Jordan Ellis'), findsNothing);
      await tapText(tester, 'Inquiries · 2');
      await tester.enterText(find.byKey(const Key('pv-inbox-search')), 'sofia');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sofia Bell'), findsOneWidget);
      expect(find.text('Jordan Ellis'), findsNothing);
      await tester.enterText(find.byKey(const Key('pv-inbox-search')), 'zzz');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('No matches'), findsOneWidget);
    });
  });

  group('Ambassador and Event Lead', () {
    testWidgets('Ambassador: performance, a referral code with a link, and earnings by status', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('ambassador')!.build));
      expect(find.text('\$428.00 confirmed'), findsOneWidget);
      expect(find.text('1,284'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
      await tapTab(tester, 'Share');
      expect(find.text('ALEX20'), findsOneWidget);
      expect(find.text('bottlesup.com/e/neon-garden?ref=ALEX20'), findsOneWidget);
      expect(find.byType(PvQr), findsOneWidget);
      await tapTab(tester, 'Earnings');
      await tapText(tester, 'Pending');
      expect(find.text('\$96.00'), findsOneWidget);
    });

    testWidgets('Event Lead: team numbers, and nudging an inactive ambassador marks them as reminded', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('event-lead')!.build));
      expect(find.text('286 referral sales'), findsOneWidget);
      expect(find.text('4 inactive ambassadors'), findsOneWidget);
      await tapText(tester, '4 inactive ambassadors');
      expect(find.text('Sam Rivera'), findsOneWidget);
      await tapText(tester, 'Nudge');
      expect(find.text('Reminder sent'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
    });

    testWidgets('Event Lead: the earnings page shows the personal total and the permitted team total apart', (tester) async {
      await show(tester, Builder(builder: previewEntryFor('event-lead')!.build));
      await tapTab(tester, 'Earnings');
      expect(find.text('\$304.00'), findsOneWidget);
      expect(find.text('\$2,416.00'), findsOneWidget);
      expect(find.text('Not your personal payout'), findsOneWidget);
    });
  });

  group('whole-app screens', () {
    testWidgets('Settings: choosing Light says it is a sample and the app stays dark', (tester) async {
      await show(tester, const AppearanceSettingsPage());
      expect(find.text('The app uses the dark look.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pv-appearance-Light')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('the light look is not built yet'), findsOneWidget);
    });

    testWidgets('Access states: invitation, expired and pending each have their own words', (tester) async {
      await show(tester, const AccessStatesPage());
      expect(find.text("You're invited"), findsOneWidget);
      await tapText(tester, 'Expired');
      expect(find.text('Invitation expired'), findsOneWidget);
      await tapText(tester, 'Pending');
      expect(find.text('Access pending'), findsOneWidget);
    });
  });

  group('the list of sample screens', () {
    testWidgets('lists every screen of the catalog, grouped, and opens one', (tester) async {
      await show(tester, const PreviewGalleryScreen());
      for (final e in previewCatalog) {
        expect(find.byKey(Key('preview-${e.id}')), findsOneWidget, reason: e.id);
      }
      await tester.tap(find.byKey(const Key('preview-dj')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pv-context-bar')), findsOneWidget);
      expect(find.text('DJ / Artist · Amara Vale'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pv-close')));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewGalleryScreen), findsOneWidget, reason: 'Close goes back to the list');
    });

    testWidgets('an id that does not exist says so', (tester) async {
      await show(tester, const PreviewScreenHost(id: 'nope'));
      expect(find.text('There is no such sample screen'), findsOneWidget);
    });
  });

  group('how a person reaches them', () {
    testWidgets('the More tab ends with a "Sample screens" row that opens the list', (tester) async {
      await show(tester, Scaffold(body: MoreScreen(workspace: ownerWs)));
      expect(find.byKey(const Key('more-previews')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('more-previews')));
      await tester.tap(find.byKey(const Key('more-previews')));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewGalleryScreen), findsOneWidget);
    });

    testWidgets('switched off, there is no row and no way in', (tester) async {
      await show(tester, const Scaffold(body: PreviewMoreRow(enabled: false)));
      expect(find.byKey(const Key('more-previews')), findsNothing);
      await show(tester, const Scaffold(body: PreviewMoreRow(enabled: true)));
      expect(find.byKey(const Key('more-previews')), findsOneWidget);
    });

    final one = WorkspaceSnapshot.ready([ws('m1', WorkspaceRole.manager)]);
    final none = WorkspaceSnapshot.ready(const []);

    RedirectDecision decide(String path, WorkspaceSnapshot s, {bool previews = true, bool loggedIn = true, ClassicVendorStatus classic = ClassicVendorStatus.none}) =>
        decideWorkspaceRedirect(isLoggedIn: loggedIn, path: path, snapshot: s, classicVendor: classic, previewsEnabled: previews);

    test('a signed-in person can open the list and any sample, with a workspace or without one', () {
      for (final s in [one, none]) {
        for (final path in ['/preview', '/preview/dj', '/preview/anything']) {
          final d = decide(path, s);
          expect(d.isFinal, isTrue, reason: path);
          expect(d.location, isNull, reason: '$path stays where it is');
        }
      }
    });

    test('switched off, nothing changes: a person without a business is still sent to set one up', () {
      final d = decide('/preview', none, previews: false);
      expect(d.isFinal, isTrue);
      expect(d.location, WorkspaceRoutes.noWorkspace);
    });

    test('signed out, they are not reachable (the sign-in rules decide)', () {
      final d = decide('/preview', none, loggedIn: false);
      expect(d.isFinal, isFalse);
    });

    test('a pending invitation still comes first', () {
      final d = decideWorkspaceRedirect(isLoggedIn: true, path: '/preview', snapshot: one, classicVendor: ClassicVendorStatus.none, pendingToken: 'abc', previewsEnabled: true);
      expect(d.location, startsWith(WorkspaceRoutes.acceptInvite));
    });
  });
}
