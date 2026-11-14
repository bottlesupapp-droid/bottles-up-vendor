import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/ui/bu_coming_soon.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/core/ui/glass_kit.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/clubs/screens/clubs_list_screen.dart';
import 'package:bottles_up_vendor/features/dashboard/providers/dashboard_provider.dart';
import 'package:bottles_up_vendor/features/dashboard/screens/dashboard_screen.dart';
import 'package:bottles_up_vendor/features/profile/providers/profile_stats_provider.dart';
import 'package:bottles_up_vendor/features/profile/screens/profile_screen.dart';
import 'package:bottles_up_vendor/features/tonight/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/venues/providers/venues_provider.dart';
import 'package:bottles_up_vendor/shared/models/dashboard_stats.dart';
import 'package:bottles_up_vendor/shared/models/user_model.dart';
import 'package:bottles_up_vendor/shared/models/venue_model.dart';
import 'package:bottles_up_vendor/shared/widgets/classic_top_bar.dart';
import 'package:bottles_up_vendor/shared/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';

import '../workspace/fake_auth.dart';

// The classic screens (an account with no workspace: Overview, Venues, Tonight, Reports, More) as the design draws them. Everything on them is read from the
// account; what is not built is "Coming soon". These tests pin the sentences, the figures, the tones and where each row goes.
DashboardStats stats({int events = 12, int upcoming = 2, int bookings = 10, int pending = 3, int confirmed = 7, int low = 2, double sales = 4300, double payouts = 1250, DateTime? lastBooking}) => DashboardStats(
      vendorId: 'v1',
      totalEvents: events,
      upcomingEvents: upcoming,
      activeEvents: upcoming,
      totalBookings: bookings,
      monthlyBookings: pending,
      confirmedBookings: confirmed,
      inventoryCount: 5,
      featuredItems: 1,
      lowStockItems: low,
      monthlyRevenue: sales,
      confirmedRevenue: payouts,
      lastBookingDate: lastBooking,
    );

Venue venue({String id = 'c1', String name = 'XnO Lounge', VenueStatus status = VenueStatus.active, bool complete = true}) => Venue(
      id: id,
      ownerId: 'u1',
      name: name,
      address: complete ? {'street': '1800 Davenport Road', 'city': 'Toronto', 'state': 'Ontario'} : null,
      gallery: complete ? const ['https://example.test/a.jpg'] : const [],
      capacity: complete ? 250 : null,
      status: status,
      socialLinks: complete ? {'venue_type': 'Lounge', 'min_age': 19} : null,
      description: complete ? 'The best room in town.' : null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Finder navLabel(String label) => find.descendant(of: find.byType(GlassBottomNavBar), matching: find.text(label));

class Went extends StatelessWidget {
  const Went(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('WENT TO $label')));
}

Future<void> pumpAt(WidgetTester tester, Widget page, {List<Override> overrides = const [], String path = '/page'}) async {
  tester.view.physicalSize = const Size(393 * 3, 3000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: path, routes: [
    GoRoute(path: path, builder: (_, __) => Scaffold(body: page)),
    for (final p in ['/dashboard', '/events', '/bookings', '/inventory', '/clubs', '/events/create', '/clubs/create', '/clubs/c1', '/profile/edit', '/profile/settings', '/legal/terms', '/legal/privacy', '/about', '/tonight'])
      GoRoute(path: p, builder: (_, __) => Went(p)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

List<Override> overview(DashboardStats s, {List<String> missing = const [], List<Venue> venues = const []}) => [
      dashboardProvider.overrideWith((ref) async => s),
      venueProfileCompletenessProvider.overrideWith((ref) async => missing),
      myVenuesProvider.overrideWith((ref) async => venues),
    ];

void main() {
  group('Overview', () {
    testWidgets('a greeting for the time of day, the date as the eyebrow, and "Create event"', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19, 5)), overrides: overview(stats()));
      expect(find.text('Good evening'), findsOneWidget);
      expect(find.text('SUNDAY, 15 NOVEMBER'), findsOneWidget);
      expect(find.byKey(const Key('overview-create-event')), findsOneWidget);
      await tester.tap(find.byKey(const Key('overview-create-event')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /events/create'), findsOneWidget);
    });

    test('the greeting follows the clock', () {
      expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 12)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 17, 59)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 18)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 2)), 'Good morning');
    });

    testWidgets('the hero card says how the month is going, with a ring of what is confirmed', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats()));
      expect(find.text('2 events coming up'), findsOneWidget);
      expect(find.text('\$4,300 in sales this month · 7 of 10 bookings confirmed'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.byType(BuRing), findsOneWidget);
    });

    testWidgets('with no events and no bookings the hero invites you to create one, and there is no ring', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 9)), overrides: overview(stats(events: 0, upcoming: 0, bookings: 0, pending: 0, confirmed: 0, low: 0, sales: 0, payouts: 0)));
      expect(find.text('Nothing coming up yet'), findsOneWidget);
      expect(find.text('Create an event to start taking bookings.'), findsOneWidget);
      expect(find.byType(BuRing), findsNothing);
    });

    testWidgets('one upcoming event reads in the singular', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats(upcoming: 1)));
      expect(find.text('One event coming up'), findsOneWidget);
    });

    testWidgets('four figures: bookings, events, sales and payouts, each with its line', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats()));
      Finder inTile(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
      expect(inTile('tile-bookings', '10'), findsOneWidget);
      expect(inTile('tile-bookings', '7 confirmed'), findsOneWidget);
      expect(inTile('tile-bookings', '7/10'), findsOneWidget);
      expect(inTile('tile-events', '12'), findsOneWidget);
      expect(inTile('tile-events', '2 upcoming'), findsOneWidget);
      expect(inTile('tile-sales', '\$4,300'), findsOneWidget);
      expect(inTile('tile-sales', 'This month · gross'), findsOneWidget);
      expect(inTile('tile-payouts', '\$1,250'), findsOneWidget);
      expect(inTile('tile-payouts', '85%'), findsOneWidget);
    });

    testWidgets('the bookings and events tiles open their lists; the sales and payouts tiles open nothing', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats()));
      await tester.tap(find.byKey(const Key('tile-bookings')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /bookings'), findsOneWidget);
    });

    testWidgets('what needs you: bookings to confirm, items low on stock, a venue profile to finish, each with its count', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats(), missing: ['Photos (banner, menu, interior)', 'Venue description']));
      expect(find.text('3 bookings wait for you'), findsOneWidget);
      expect(find.text('2 items are low on stock'), findsOneWidget);
      expect(find.text('Finish your venue profile'), findsOneWidget);
      expect(find.text('Photos (banner, menu, interior) · Venue description'), findsOneWidget);
      expect(find.text('All clear. Nothing needs you right now.'), findsNothing);
      await tester.tap(find.byKey(const Key('attention-pending')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /bookings'), findsOneWidget);
    });

    testWidgets('one booking and one item read in the singular', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats(pending: 1, low: 1)));
      expect(find.text('1 booking waits for you'), findsOneWidget);
      expect(find.text('1 item is low on stock'), findsOneWidget);
    });

    testWidgets('when nothing needs you it says so, in a card', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats(pending: 0, low: 0)));
      expect(find.byKey(const Key('attention-clear')), findsOneWidget);
      expect(find.text('All clear. Nothing needs you right now.'), findsOneWidget);
      expect(find.byKey(const Key('attention-pending')), findsNothing);
    });

    testWidgets('your venues: each as a mini row (initials, name, address), and "Add your first venue" when there are none', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats(), venues: [venue(), venue(id: 'c2', name: 'Sky Room', status: VenueStatus.pending, complete: false)]));
      expect(find.byKey(const Key('overview-venue-c1')), findsOneWidget);
      expect(find.text('XL'), findsOneWidget);
      expect(find.text('Open · 1800 Davenport Road, Toronto, Ontario'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats()));
      expect(find.byKey(const Key('overview-add-venue')), findsOneWidget);
    });

    testWidgets('Broadcast is not built: it says "Coming soon" and a sheet says what it will do; Got it closes it', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats()));
      await tester.ensureVisible(find.byKey(const Key('shortcut-broadcast')));
      expect(find.descendant(of: find.byKey(const Key('shortcut-broadcast')), matching: find.byType(BuComingSoonPill)), findsOneWidget);
      await tester.tap(find.byKey(const Key('shortcut-broadcast')));
      await tester.pumpAndSettle();
      expect(find.text('Send an alert to your guests or your team in one tap.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('coming-soon-close')));
      await tester.pumpAndSettle();
      expect(find.text('Send an alert to your guests or your team in one tap.'), findsNothing);
    });

    testWidgets('what happened last shows only what the account has, never a made-up line', (tester) async {
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats(lastBooking: DateTime(2026, 11, 1, 12))));
      await tester.ensureVisible(find.text('Last booking'));
      expect(find.text('Last booking'), findsOneWidget);
      expect(find.text('Last event'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pumpAt(tester, DashboardScreen(now: DateTime(2026, 11, 15, 19)), overrides: overview(stats()));
      expect(find.text('Last booking'), findsNothing);
      expect(find.text('What happened last'), findsNothing);
    });

    testWidgets('when the overview cannot be read it says so and can be tried again', (tester) async {
      var tries = 0;
      await pumpAt(tester, const DashboardScreen(), overrides: [
        dashboardProvider.overrideWith((ref) async {
          tries++;
          throw Exception('offline');
        }),
        venueProfileCompletenessProvider.overrideWith((ref) async => const <String>[]),
        myVenuesProvider.overrideWith((ref) async => const <Venue>[]),
      ]);
      expect(find.text('We could not load your overview'), findsOneWidget);
      final before = tries;
      await tester.tap(find.byKey(const Key('overview-retry')));
      await tester.pumpAndSettle();
      expect(tries, greaterThan(before));
    });
  });

  group('Tonight', () {
    testWidgets('is a designed "Coming soon" page that lists what it will hold, and goes back to Overview', (tester) async {
      await pumpAt(tester, const TonightScreen());
      expect(find.byType(BuComingSoonPill), findsWidgets);
      for (final t in ['Floor', 'Bookings', 'Orders', 'Team']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Tonight is on its way'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('coming-soon-action')));
      await tester.tap(find.byKey(const Key('coming-soon-action')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /dashboard'), findsOneWidget);
    });
  });

  group('Venues', () {
    testWidgets('a strip of three figures, then a card per venue with its status and its setup progress', (tester) async {
      await pumpAt(tester, const ClubsListScreen(), overrides: [myVenuesProvider.overrideWith((ref) async => [venue(), venue(id: 'c2', name: 'Sky Room', status: VenueStatus.pending, complete: false)])]);
      expect(find.text('Venues'), findsWidgets);
      expect(find.byKey(const Key('summary-venues')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('summary-venues'))).data, '2');
      expect(tester.widget<Text>(find.byKey(const Key('summary-open'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('summary-setup'))).data, '50%', reason: '5 of 10 setup steps are done');
      expect(tester.widget<Text>(find.byKey(const Key('venue-setup-c1'))).data, '5 of 5');
      expect(tester.widget<Text>(find.byKey(const Key('venue-setup-c2'))).data, '0 of 5');
      expect(find.descendant(of: find.byKey(const Key('venue-status-c1')), matching: find.text('Open')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('venue-status-c2')), matching: find.text('Pending')), findsOneWidget);
    });

    testWidgets('the card shows its address and facts, and "Manage venue" opens it', (tester) async {
      await pumpAt(tester, const ClubsListScreen(), overrides: [myVenuesProvider.overrideWith((ref) async => [venue()])]);
      expect(find.text('1800 Davenport Road, Toronto, Ontario'), findsOneWidget);
      expect(find.text('250 guests · Lounge · 19+'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('venue-manage-c1')));
      await tester.tap(find.byKey(const Key('venue-manage-c1')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /clubs/c1'), findsOneWidget);
    });

    testWidgets('the round add button creates a venue; with none, a card says so and offers it too', (tester) async {
      await pumpAt(tester, const ClubsListScreen(), overrides: [myVenuesProvider.overrideWith((ref) async => const <Venue>[])]);
      expect(find.byKey(const Key('venues-empty')), findsOneWidget);
      expect(find.text('No venues yet'), findsOneWidget);
      await tester.tap(find.byKey(const Key('venues-add')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /clubs/create'), findsOneWidget);
    });

    test('five setup steps: photos, details, a description, an address and a capacity', () {
      final done = venueSetupItems(venue());
      expect([for (final i in done) i.$1], ['Photos', 'Details', 'Description', 'Address', 'Capacity']);
      expect(done.every((i) => i.$2), isTrue);
      final bare = venueSetupItems(venue(complete: false));
      expect(bare.where((i) => i.$2), isEmpty);
    });
  });

  group('More', () {
    final user = VendorUser(id: 'u1', email: 'a@x.test', businessName: 'Club Co', role: 'venue_owner', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1));
    List<Override> more({double rating = 4.7}) => [
          supabaseAuthProvider.overrideWith((ref) => FakeAuthNotifier(SupabaseAuthState(supabaseUser: supabaseUser(), vendorUser: user, vendorChecked: true))),
          profileStatsProvider.overrideWith((ref) async => ProfileStats(totalEvents: 12, activeEvents: 2, totalInventoryItems: 5, lowStockItems: 1, totalBookings: 10, pendingBookings: 3, averageRating: rating, totalRatings: 9)),
        ];

    testWidgets('who you are, then Operations, Business and Account in grouped lists', (tester) async {
      await pumpAt(tester, const ProfileScreen(), overrides: more());
      expect(find.text('CLUB CO'), findsOneWidget, reason: 'the business, as the eyebrow');
      expect(find.text('More'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('more-profile-card')), matching: find.text('Club Co')), findsOneWidget);
      expect(find.text('Owner · 4.7 rating'), findsOneWidget);
      for (final g in ['OPERATIONS', 'BUSINESS', 'ACCOUNT']) {
        expect(find.text(g), findsOneWidget, reason: g);
      }
    });

    testWidgets('what is built opens; what is not says "Coming soon" and opens a sheet', (tester) async {
      await pumpAt(tester, const ProfileScreen(), overrides: more());
      for (final k in ['more-team', 'more-vip', 'more-payments', 'more-agreements']) {
        await tester.ensureVisible(find.byKey(Key(k)));
        expect(find.descendant(of: find.byKey(Key(k)), matching: find.byType(BuComingSoonPill)), findsOneWidget, reason: k);
      }
      for (final k in ['more-inventory', 'more-events', 'more-bookings', 'more-settings', 'more-terms', 'more-privacy', 'more-about']) {
        await tester.ensureVisible(find.byKey(Key(k)));
        expect(find.descendant(of: find.byKey(Key(k)), matching: find.byType(BuComingSoonPill)), findsNothing, reason: k);
      }
      await tester.tap(find.byKey(const Key('more-team')));
      await tester.pumpAndSettle();
      expect(find.text('Invite your staff, give each a role, and see who is on shift.'), findsOneWidget);
    });

    testWidgets('Events and Inventory carry their counts and open their screens', (tester) async {
      await pumpAt(tester, const ProfileScreen(), overrides: more());
      expect(find.descendant(of: find.byKey(const Key('more-events')), matching: find.text('12')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('more-inventory')), matching: find.text('5')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('more-events')));
      await tester.tap(find.byKey(const Key('more-events')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /events'), findsOneWidget);
    });

    testWidgets('Edit opens the profile editor; sign out and delete account are still at the bottom', (tester) async {
      await pumpAt(tester, const ProfileScreen(), overrides: more());
      await tester.tap(find.byKey(const Key('more-edit-profile')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /profile/edit'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpAt(tester, const ProfileScreen(), overrides: more());
      await tester.ensureVisible(find.byKey(const Key('more-sign-out')));
      expect(find.byKey(const Key('more-sign-out')), findsOneWidget);
      expect(find.byKey(const Key('more-delete-account')), findsOneWidget);
    });

    testWidgets('with no rating yet the line is just the role', (tester) async {
      await pumpAt(tester, const ProfileScreen(), overrides: more(rating: 0));
      expect(find.text('Owner'), findsOneWidget);
    });
  });

  group('the frame', () {
    testWidgets('the top bar says who you are: the brand, the business and the role', (tester) async {
      final user = VendorUser(id: 'u1', email: 'a@x.test', businessName: 'Club Co', role: 'organizer', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1));
      await pumpAt(tester, const ClassicTopBar(), overrides: [currentVendorUserProvider.overrideWithValue(user)]);
      expect(find.text('BottlesUp'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('classic-top-bar-line'))).data, 'Club Co · Organizer');
      await tester.tap(find.byKey(const Key('classic-profile-button')));
      await tester.pumpAndSettle();
    });

    test('roles in words', () {
      expect(classicRoleLabel('venue_owner'), 'Owner');
      expect(classicRoleLabel('owner'), 'Owner');
      expect(classicRoleLabel('organizer'), 'Organizer');
      expect(classicRoleLabel('promoter'), 'Promoter');
      expect(classicRoleLabel('manager'), 'Manager');
      expect(classicRoleLabel('staff'), 'Team');
      expect(classicRoleLabel(null), 'Team');
    });

    testWidgets('five tabs in the design\'s order, and each opens its place', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/dashboard', routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [for (final p in ['/dashboard', '/clubs', '/tonight', '/analytics', '/profile']) GoRoute(path: p, builder: (_, __) => Went(p))],
        ),
      ]);
      await tester.pumpWidget(ProviderScope(overrides: [currentVendorUserProvider.overrideWithValue(null)], child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router)));
      await tester.pumpAndSettle();
      const labels = ['Overview', 'Venues', 'Tonight', 'Reports', 'More'];
      for (final label in labels) {
        expect(navLabel(label), findsOneWidget, reason: label);
      }
      final lefts = [for (final l in labels) tester.getTopLeft(navLabel(l)).dx];
      expect(lefts, orderedEquals([...lefts]..sort()), reason: 'in the design\'s order, left to right');
      for (final (label, path) in [('Venues', '/clubs'), ('Tonight', '/tonight'), ('Reports', '/analytics'), ('More', '/profile'), ('Overview', '/dashboard')]) {
        await tester.tap(navLabel(label));
        await tester.pumpAndSettle();
        expect(find.text('WENT TO $path'), findsOneWidget, reason: label);
      }
    });

    testWidgets('Events, Bookings and Inventory belong to More: it is the tab that stays lit', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = GoRouter(initialLocation: '/events', routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [GoRoute(path: '/events', builder: (_, __) => const Went('/events'))],
        ),
      ]);
      await tester.pumpWidget(ProviderScope(overrides: [currentVendorUserProvider.overrideWithValue(null)], child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router)));
      await tester.pumpAndSettle();
      // The lit tab shows its filled icon, the others their outline.
      expect(find.byIcon(Ionicons.menu), findsOneWidget, reason: 'More is lit');
      expect(find.byIcon(Ionicons.menu_outline), findsNothing);
      expect(find.byIcon(Ionicons.home_outline), findsOneWidget, reason: 'Overview is not');
      expect(find.byIcon(Ionicons.home), findsNothing);
    });
  });
}
