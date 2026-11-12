import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/preview/preview_catalog.dart';
import 'package:bottles_up_vendor/features/preview/screens/organizer_screens.dart';
import 'package:bottles_up_vendor/features/preview/screens/role_chooser_screen.dart';
import 'package:bottles_up_vendor/features/preview/screens/venue_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design/role_test_support.dart' show loadInter;
import 'preview_test_support.dart';

/// The sample tools of an organizer and of a venue owner or manager: each opens, and what a person can do on it (switch a range, shortlist an
/// applicant, fix the bank details) changes what is shown, so the sample behaves like the real screen will.

void main() {
  setUpAll(loadInter);

  group('organizer tools', () {
    testWidgets('Analytics: the best day this week; 30 days changes the bars; an event with no sales says "No data yet"', (tester) async {
      await show(tester, const OrganizerAnalyticsPage());
      expect(find.text('31 tickets sold on Sunday, the best day this week.'), findsOneWidget);
      expect(find.text('1.9% of viewers booked. 184 tickets and 6 tables. Referral links brought \$1,420.'), findsOneWidget);
      expect(find.text('\$6,083'), findsOneWidget, reason: 'net earnings: 6,840 - 210 - 547');
      await tapText(tester, '30 days');
      expect(find.text('87 tickets sold in the last week.'), findsOneWidget);
      await tapText(tester, 'Afterdark Sessions');
      expect(find.text('No data yet'), findsOneWidget);
      expect(find.text('Ticket sales'), findsNothing);
    });

    testWidgets('Opportunities: two new applications show as a count; shortlisting and declining change the pills and the count', (tester) async {
      await show(tester, const OpportunitiesPage());
      expect(find.byType(BuCountBadge), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tapText(tester, 'Photographer · Neon Garden');
      expect(find.text('Photographer applicants'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shortlist-Priya Shah')));
      await tester.pumpAndSettle();
      expect(find.text('Shortlisted'), findsOneWidget);
      await tester.tap(find.byKey(const Key('decline-Leo Park')));
      await tester.pumpAndSettle();
      expect(find.text('Declined'), findsOneWidget);
      expect(find.byKey(const Key('shortlist-Priya Shah')), findsNothing, reason: 'an answered application has no buttons');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(BuCountBadge), findsNothing, reason: 'nothing new is left');
    });

    testWidgets('Flyer: the template, the words and the alignment change the picture', (tester) async {
      await show(tester, const FlyerToolPage());
      BoxDecoration deco() => tester.widget<Container>(find.byKey(const Key('flyer-preview'))).decoration! as BoxDecoration;
      expect((deco().gradient! as LinearGradient).colors.first, const Color(0xFFFF5A2F));
      await tapText(tester, 'Neon');
      expect((deco().gradient! as LinearGradient).colors.first, const Color(0xFF14002B));
      await tester.enterText(find.widgetWithText(TextField, 'Event name'), 'Halloween');
      await tester.pump();
      expect(find.descendant(of: find.byKey(const Key('flyer-preview')), matching: find.text('Halloween')), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Event name'), '');
      await tester.pump();
      expect(find.descendant(of: find.byKey(const Key('flyer-preview')), matching: find.text('Event name')), findsOneWidget, reason: 'an empty name shows the placeholder');
    });

    testWidgets('Repeats and promo codes: turning the repeat off hides its settings; the codes show how many were used', (tester) async {
      await show(tester, const RepeatAndPromosPage());
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.textContaining('Next dates: Sat 31 Aug'), findsOneWidget);
      await tester.tap(find.byKey(const Key('repeat-switch')));
      await tester.pumpAndSettle();
      expect(find.text('Weekly'), findsNothing);
      expect(find.text('GARDEN10'), findsOneWidget);
      expect(find.text('10% off tickets · 24 of 100 used'), findsOneWidget);
      expect(find.text('Used up'), findsOneWidget);
    });

    testWidgets('Posts: a post opens its comments, and the spam one is marked for review', (tester) async {
      await show(tester, const ContentManagerPage());
      await tapText(tester, 'Lineup reveal: Neon Garden');
      expect(find.text('Cheap followers, DM me'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('Overview and Profile open with their sections', (tester) async {
      await show(tester, const OrganizerOverviewPage());
      expect(find.text('Neon Garden'), findsWidgets);
      expect(find.text('NEEDS ATTENTION'), findsOneWidget);
      await show(tester, const OrganizerProfilePage());
      expect(find.text('What to show'), findsOneWidget);
      expect(find.text('Messages from guests'), findsOneWidget);
    });
  });

  group('venue owner and manager tools', () {
    testWidgets('Overview numbers: expected adds up to 186; arrived is by the hour; sales go from gross to earnings', (tester) async {
      await show(tester, const OverviewNumbersPage());
      expect(find.text('186 people'), findsOneWidget);
      await tapText(tester, 'Arrived');
      expect(find.text('96 of 186'), findsOneWidget);
      expect(find.text('96 of 186 expected (52%)'), findsOneWidget);
      await tapText(tester, 'Sales');
      expect(find.text('\$4,340'), findsOneWidget);
      expect(find.text('\$4,079.78'), findsOneWidget, reason: '4,340 - 150 refunds - 92.22 card fees - 18 platform fee');
      await tapText(tester, 'Payouts');
      expect(find.text('Bank account ending 4021'), findsOneWidget);
    });

    testWidgets('A failed payout: says what happened and that the money is safe; fixing the bank details turns it into "sent"', (tester) async {
      await show(tester, const PayoutIssuePage());
      expect(find.byKey(const Key('payout-failed')), findsOneWidget);
      expect(find.text("Payout of \$9,420 didn't go through"), findsOneWidget);
      expect(find.textContaining('Your money is safe'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fix-bank')));
      await tester.pumpAndSettle();
      expect(find.text('Update bank account'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('save-bank')));
      await tester.tap(find.byKey(const Key('save-bank')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payout-failed')), findsNothing);
      expect(find.byKey(const Key('payout-sent')), findsOneWidget);
      expect(find.text('\$9,420 sent to bank ending 7733'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
    });

    testWidgets('Messages centre: customers, team and requests are separate; a conversation opens', (tester) async {
      await show(tester, const MessagesCenterPage());
      expect(find.text('Maya Chen'), findsOneWidget);
      expect(find.text('Door team'), findsNothing);
      await tapText(tester, 'Team · 3');
      expect(find.text('Door team'), findsOneWidget);
      await tapText(tester, 'Requests · 2');
      expect(find.text('Ask for a change'), findsOneWidget);
      expect(find.text('Refund request'), findsOneWidget);
      await tapText(tester, 'Customers · 3');
      await tapText(tester, 'Maya Chen');
      expect(find.text('Can we move to a bigger table for 8?'), findsOneWidget);
      expect(find.text('Write a message'), findsOneWidget);
    });

    testWidgets('Booking: passes claimed and not, the pre-order total, and a cancel sheet that says what is refunded', (tester) async {
      await show(tester, const BookingExtrasPage());
      expect(find.text('Claimed'), findsNWidgets(3));
      expect(find.text('Invited'), findsOneWidget);
      expect(find.text('\$640'), findsOneWidget, reason: '280 + 2 × 180');
      await tapText(tester, 'Cancel booking');
      expect(find.text('Cancel booking and refund'), findsOneWidget);
      expect(find.text('\$500'), findsWidgets);
    });

    testWidgets("The venue's events: a weekly series opens its dates; Past shows the finished ones", (tester) async {
      await show(tester, const VenueEventsPage());
      expect(find.text('Weekly'), findsOneWidget);
      await tapText(tester, 'Nova Saturdays');
      expect(find.text('112 of 300 sold'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tapText(tester, 'Past');
      expect(find.text('Spring Social'), findsOneWidget);
    });
  });

  group('the role chooser (a demo screen)', () {
    testWidgets('shows all eight roles and says it is demo mode', (tester) async {
      await show(tester, const RoleChooserPage());
      expect(find.text('Demo mode'), findsOneWidget);
      expect(find.text('How are you working tonight?'), findsOneWidget);
      for (final role in ['Venue Owner', 'Venue Manager', 'Event Organizer', 'DJ / Artist', 'Door Staff', 'Server', 'Ambassador', 'Event Lead']) {
        expect(find.byKey(Key('role-$role')), findsOneWidget, reason: role);
      }
    });

    testWidgets('a role the app does not have opens its sample; a role it has says where it lives', (tester) async {
      await show(tester, const RoleChooserPage());
      await tester.tap(find.byKey(const Key('role-Door Staff')));
      await tester.pumpAndSettle();
      expect(find.text('Already in the app'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('role-DJ / Artist')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pv-context-bar')), findsOneWidget);
    });
  });

  test('every group of the catalog has at least one sample, and the catalog holds the roles, the tools and the whole-app screens', () {
    final byGroup = <PreviewGroup, int>{};
    for (final e in previewCatalog) {
      byGroup[e.group] = (byGroup[e.group] ?? 0) + 1;
    }
    for (final g in PreviewGroup.values) {
      expect(byGroup[g] ?? 0, greaterThan(0), reason: g.label);
    }
    expect(previewCatalog.length, greaterThanOrEqualTo(19));
  });
}
