import 'dart:io';
import 'dart:ui' as ui;

import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/ui/bu_coming_soon.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/clubs/screens/club_details_screen.dart';
import 'package:bottles_up_vendor/features/events/providers/bookings_provider.dart';
import 'package:bottles_up_vendor/features/events/providers/inventory_provider.dart';
import 'package:bottles_up_vendor/features/events/screens/inventory_screen.dart';
import 'package:bottles_up_vendor/features/profile/screens/settings_screen.dart';
import 'package:bottles_up_vendor/features/events/screens/bookings_screen.dart';
import 'package:bottles_up_vendor/features/venues/providers/venues_provider.dart';
import 'package:bottles_up_vendor/shared/models/venue_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The screens behind the classic tabs (a venue's page, its forms, an event's pages, bookings, inventory, settings) in the prototype's look. Each reads what the account has; what the
// design shows and the account cannot do is "Coming soon". With BU_SHOTS=<folder> the tests also write a picture of each screen there.

final _boundary = GlobalKey();

Venue venue({
  String id = 'c1',
  String name = 'XnO Lounge',
  VenueStatus status = VenueStatus.active,
  bool photos = true,
  bool details = true,
  bool description = true,
  bool address = true,
  bool capacity = true,
  bool contact = true,
}) => Venue(
  id: id,
  ownerId: 'u1',
  name: name,
  address: address ? {'street': '1800 Davenport Road', 'city': 'Toronto', 'state': 'Ontario'} : null,
  gallery: photos ? const ['https://example.test/a.jpg', 'https://example.test/b.jpg', 'https://example.test/c.jpg'] : const [],
  capacity: capacity ? 250 : null,
  status: status,
  phone: contact ? '+1 416 555 0100' : null,
  email: contact ? 'hello@xno.test' : null,
  socialLinks:
      details
          ? {
            'venue_type': 'Lounge',
            'min_age': 19,
            'dress_code': 'Smart',
            'music_genres': ['Afrobeats', 'House'],
            'amenities': ['Coat check', 'Patio'],
          }
          : null,
  description: description ? 'The best room in town.' : null,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class Went extends StatelessWidget {
  const Went(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('WENT TO $label')));
}

Future<void> pumpPage(WidgetTester tester, Widget Function() page, {String path = '/page', List<Override> overrides = const [], double height = 2200, List<String> stubs = const []}) async {
  tester.view.physicalSize = Size(393 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: path, routes: [GoRoute(path: path, builder: (_, __) => page()), for (final p in stubs) GoRoute(path: p, builder: (_, __) => Went(p))]);
  // The picture boundary is outside the provider scope: a new scope (new data) then replaces what is inside it, instead of the boundary's old contents being moved into it.
  await tester.pumpWidget(RepaintBoundary(key: _boundary, child: ProviderScope(key: UniqueKey(), overrides: overrides, child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router))));
  await tester.pumpAndSettle();
}

/// With BU_SHOTS set, writes what the screen looks like to <folder>/<name>.png.
Future<void> shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['BU_SHOTS'];
  if (dir == null || dir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(find.byKey(_boundary));
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes.buffer.asUint8List());
  });
}

/// Taps a pill tab; the row scrolls sideways, so the tab is brought into view first.
Future<void> goTab(WidgetTester tester, String label) async {
  final tab = find.byKey(Key('venue-tab-$label'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

List<Override> forVenue(Venue? v) => [venueByIdProvider('c1').overrideWith((ref) async => v)];

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(File('assets/fonts/Inter.ttf').readAsBytes().then(ByteData.sublistView));
    await font.load();
  });

  group('Venue page', () {
    Future<void> open(WidgetTester tester, Venue v, {double height = 2200}) =>
        pumpPage(tester, () => const ClubDetailsScreen(clubId: 'c1'), path: '/clubs/c1', overrides: forVenue(v), height: height, stubs: ['/clubs/c1/edit', '/clubs']);

    testWidgets('a back button, the venue name over "Manage venue", and whether it is open', (tester) async {
      await open(tester, venue());
      expect(find.text('XNO LOUNGE'), findsOneWidget);
      expect(find.text('Manage venue'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('venue-status')), matching: find.text('Open')), findsOneWidget);
      expect(find.byKey(const Key('detail-back')), findsOneWidget);
      await shot(tester, 'venue_setup');
    });

    testWidgets('the status word follows the venue: Open, Approved, Pending, Suspended', (tester) async {
      for (final (status, word) in [(VenueStatus.active, 'Open'), (VenueStatus.approved, 'Approved'), (VenueStatus.pending, 'Pending'), (VenueStatus.suspended, 'Suspended')]) {
        await open(tester, venue(status: status));
        expect(find.descendant(of: find.byKey(const Key('venue-status')), matching: find.text(word)), findsOneWidget, reason: word);
      }
    });

    testWidgets('six pill tabs in the design order; Tables, Menu and Booking link carry the Coming soon dot', (tester) async {
      await open(tester, venue());
      for (final t in ['Setup', 'Page', 'Tables', 'Menu & signs', 'Photos', 'Booking link']) {
        expect(find.byKey(Key('venue-tab-$t')), findsOneWidget, reason: t);
      }
    });

    testWidgets('Setup: how far the venue is, and each of the five steps done or to do', (tester) async {
      await open(tester, venue(photos: false, description: false));
      expect(find.text('3 of 5 complete'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('setup-Photos')), matching: find.text('Set up')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('setup-Description')), matching: find.text('Set up')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('setup-Address')), matching: find.text('Done')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('setup-Capacity')), matching: find.text('Done')), findsOneWidget);
    });

    testWidgets('Setup: a finished venue says 5 of 5', (tester) async {
      await open(tester, venue());
      expect(find.text('5 of 5 complete'), findsOneWidget);
      expect(find.text('Set up'), findsNothing);
    });

    testWidgets('Setup: a step opens the venue form', (tester) async {
      await open(tester, venue(photos: false));
      await tester.tap(find.byKey(const Key('setup-Photos')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /clubs/c1/edit'), findsOneWidget);
    });

    testWidgets('Setup: the design\'s other steps are shown with Coming soon, and open the sheet', (tester) async {
      await open(tester, venue());
      for (final t in ['Rooms and floor plans', 'Tables and capacities', 'Booking rules', 'Payment settings', 'Team invited']) {
        expect(find.byKey(Key('setup-soon-$t')), findsOneWidget, reason: t);
      }
      expect(find.byType(BuComingSoonPill), findsNWidgets(5));
      await tester.ensureVisible(find.byKey(const Key('setup-soon-Booking rules')));
      await tester.tap(find.byKey(const Key('setup-soon-Booking rules')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coming-soon-close')), findsOneWidget);
      expect(find.text('Days, times, and how far ahead guests can book'), findsWidgets);
    });

    testWidgets('Setup: Edit venue and Delete venue are still there, and delete asks first', (tester) async {
      await open(tester, venue());
      await tester.ensureVisible(find.byKey(const Key('venue-delete')));
      await tester.tap(find.byKey(const Key('venue-delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Are you sure you want to delete "XnO Lounge"'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('venue-edit')));
      await tester.tap(find.byKey(const Key('venue-edit')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /clubs/c1/edit'), findsOneWidget);
    });

    testWidgets('Page: location, about, facts, music, amenities and contact, from the venue', (tester) async {
      await open(tester, venue());
      await goTab(tester, 'Page');
      expect(find.byKey(const Key('venue-location')), findsOneWidget);
      expect(find.text('The best room in town.'), findsOneWidget);
      expect(find.text('Lounge'), findsOneWidget);
      expect(find.text('19+'), findsOneWidget);
      expect(find.text('Afrobeats'), findsOneWidget);
      expect(find.text('Coat check'), findsOneWidget);
      expect(find.text('hello@xno.test'), findsOneWidget);
      await shot(tester, 'venue_page');
    });

    testWidgets('Page: a venue with nothing yet says so and offers the form', (tester) async {
      await open(tester, venue(details: false, description: false, address: false, capacity: false, contact: false));
      await goTab(tester, 'Page');
      expect(find.byKey(const Key('venue-page-empty')), findsOneWidget);
      expect(find.byKey(const Key('venue-location')), findsNothing);
      expect(find.byKey(const Key('venue-page-edit')), findsOneWidget);
    });

    testWidgets('Photos: a grid with the first as the cover; none says how to add some', (tester) async {
      await open(tester, venue());
      await goTab(tester, 'Photos');
      expect(find.text('3 photos'), findsOneWidget);
      expect(find.byKey(const Key('venue-photos-grid')), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
      expect(find.byKey(const Key('venue-photos-video')), findsOneWidget);
      await shot(tester, 'venue_photos');

      await open(tester, venue(photos: false));
      await goTab(tester, 'Photos');
      expect(find.text('No photos yet'), findsOneWidget);
      expect(find.byKey(const Key('venue-photos-empty')), findsOneWidget);
      expect(find.text('Add photos'), findsOneWidget);
    });

    testWidgets('Tables, Menu & signs and Booking link are Coming soon cards', (tester) async {
      await open(tester, venue());
      for (final (tab, card) in [('Tables', 'Tables'), ('Menu & signs', 'Menu & signs'), ('Booking link', 'Booking link')]) {
        await goTab(tester, tab);
        expect(find.byKey(Key('venue-soon-$card')), findsOneWidget, reason: tab);
        expect(find.text('$card is on its way'), findsOneWidget, reason: tab);
      }
      await shot(tester, 'venue_soon');
    });

    testWidgets('a venue that is not found says so, with a way back', (tester) async {
      await pumpPage(tester, () => const ClubDetailsScreen(clubId: 'c1'), path: '/clubs/c1', overrides: forVenue(null));
      expect(find.text('Venue not found'), findsWidgets);
      expect(find.text('Go Back'), findsOneWidget);
    });
  });
  group('Bookings', () {
    Map<String, dynamic> booking(String id, String status, {num total = 120, int tickets = 2, String title = 'Afro Nights'}) => {
      'id': id,
      'status': status,
      'totalPrice': total,
      'numberOfTickets': tickets,
      'bookedAt': '2026-11-10T20:00:00',
      'eventDetails': {'title': title, 'venue': 'XnO Lounge', 'date': '2026-11-21T22:00:00'},
    };
    final three = [booking('aaaaaaaa-1', 'pending', total: 50), booking('bbbbbbbb-2', 'confirmed', total: 120), booking('cccccccc-3', 'cancelled', total: 80)];

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> bookings) => pumpPage(tester, () => const BookingsScreen(), overrides: [bookingsProvider.overrideWith((ref) async => bookings)]);

    testWidgets('a back button over "Bookings", three figures, the filters and one card per booking', (tester) async {
      await open(tester, three);
      expect(find.text('Bookings'), findsWidgets);
      expect(find.byKey(const Key('detail-back')), findsNothing, reason: 'nothing to go back to in this test');
      expect(tester.widget<Text>(find.byKey(const Key('bookings-total'))).data, '3');
      expect(tester.widget<Text>(find.byKey(const Key('bookings-pending'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('bookings-sales'))).data, '\$120', reason: 'only the confirmed booking counts: pending and cancelled money is not sales');
      expect(find.byKey(const Key('booking-aaaaaaaa-1')), findsOneWidget);
      expect(find.text('3 bookings'), findsOneWidget);
      await shot(tester, 'bookings');
    });

    testWidgets('the filters narrow the list by status and say how many are left', (tester) async {
      await open(tester, three);
      await tester.tap(find.byKey(const Key('booking-filter-Pending')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('booking-aaaaaaaa-1')), findsOneWidget);
      expect(find.byKey(const Key('booking-bbbbbbbb-2')), findsNothing);
      expect(find.text('1 booking'), findsOneWidget);
      await tester.tap(find.byKey(const Key('booking-filter-Completed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bookings-none')), findsOneWidget);
      expect(find.text('No completed bookings.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('booking-filter-All')));
      await tester.pumpAndSettle();
      expect(find.text('3 bookings'), findsOneWidget);
    });

    testWidgets('each status has its word, and only the right buttons: pending gets Confirm and Cancel, confirmed gets Mark Completed', (tester) async {
      await open(tester, three);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.byKey(const Key('booking-confirm')), findsOneWidget);
      expect(find.byKey(const Key('booking-cancel')), findsOneWidget);
      expect(find.byKey(const Key('booking-complete')), findsOneWidget);
    });

    testWidgets('no bookings: the page says so, with nothing to filter', (tester) async {
      await open(tester, const []);
      expect(find.text('No bookings yet'), findsOneWidget);
      expect(find.text('Bookings will appear here when customers reserve your events'), findsOneWidget);
      expect(find.byKey(const Key('booking-filter-All')), findsNothing);
    });

    testWidgets('a failed load says so and offers Retry', (tester) async {
      await pumpPage(tester, () => const BookingsScreen(), overrides: [bookingsProvider.overrideWith((ref) async => throw Exception('boom'))]);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
  group('Inventory', () {
    Map<String, dynamic> bottle(String id, String name, int quantity, {num price = 180, bool featured = false}) => {
      'id': id,
      'name': name,
      'brand': 'Grey Goose',
      'quantity': quantity,
      'price': price,
      'volume': 750,
      'featured': featured,
      'description': 'Smooth',
    };
    final stock = [bottle('b1', 'Vodka', 12), bottle('b2', 'Champagne', 3, featured: true), bottle('b3', 'Tequila', 0)];

    Future<void> open(WidgetTester tester, List<Map<String, dynamic>> items) => pumpPage(tester, () => const InventoryScreen(), overrides: [inventoryProvider.overrideWith((ref) async => items)]);

    testWidgets('three figures: items, running low, out; and one card per bottle with how many are left', (tester) async {
      await open(tester, stock);
      expect(tester.widget<Text>(find.byKey(const Key('inventory-items'))).data, '3');
      expect(tester.widget<Text>(find.byKey(const Key('inventory-low'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const Key('inventory-out'))).data, '1');
      expect(find.text('12 in stock'), findsOneWidget);
      expect(find.text('3 left'), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
      await shot(tester, 'inventory');
    });

    testWidgets('the Low and Out filters narrow the list; an empty filter says so', (tester) async {
      await open(tester, stock);
      await tester.tap(find.byKey(const Key('stock-filter-Low')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bottle-b2')), findsOneWidget);
      expect(find.byKey(const Key('bottle-b1')), findsNothing);
      await tester.tap(find.byKey(const Key('stock-filter-Out')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bottle-b3')), findsOneWidget);
      await open(tester, [bottle('b1', 'Vodka', 12)]);
      await tester.tap(find.byKey(const Key('stock-filter-Low')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inventory-none')), findsOneWidget);
      expect(find.text('Nothing is running low.'), findsOneWidget);
    });

    testWidgets('add, edit and remove say Coming soon instead of doing nothing', (tester) async {
      await open(tester, stock);
      await tester.tap(find.byKey(const Key('inventory-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coming-soon-close')), findsOneWidget);
      expect(find.text('Add a bottle'), findsOneWidget);
      await tester.tap(find.byKey(const Key('coming-soon-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bottle-edit')).first);
      await tester.pumpAndSettle();
      expect(find.text('Edit a bottle'), findsOneWidget);
    });

    testWidgets('no bottles, and a failed load', (tester) async {
      await open(tester, const []);
      expect(find.text('No inventory found'), findsOneWidget);
      await pumpPage(tester, () => const InventoryScreen(), overrides: [inventoryProvider.overrideWith((ref) async => throw Exception('boom'))]);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Settings', () {
    Future<void> open(WidgetTester tester) => pumpPage(
      tester,
      () => const SettingsScreen(),
      path: '/profile/settings',
      stubs: ['/profile/edit', '/profile/business', '/profile/security', '/profile/notifications', '/support/help', '/support/contact', '/legal/terms', '/legal/privacy', '/about'],
    );

    testWidgets('a Display card (dark chosen; Light and Auto say Coming soon) and the account, help and about rows', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('settings-appearance')), findsOneWidget);
      await tester.tap(find.byKey(const Key('appearance-light')));
      await tester.pumpAndSettle();
      expect(find.text('Light appearance'), findsOneWidget);
      await tester.tap(find.byKey(const Key('coming-soon-close')));
      await tester.pumpAndSettle();
      await shot(tester, 'settings');
    });

    testWidgets('each row opens the page that exists for it', (tester) async {
      for (final (key, path) in [
        ('settings-edit-profile', '/profile/edit'),
        ('settings-business', '/profile/business'),
        ('settings-security', '/profile/security'),
        ('settings-notifications', '/profile/notifications'),
        ('settings-help', '/support/help'),
        ('settings-support', '/support/contact'),
        ('settings-terms', '/legal/terms'),
        ('settings-privacy', '/legal/privacy'),
        ('settings-about', '/about'),
      ]) {
        await open(tester);
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.text('WENT TO $path'), findsOneWidget, reason: key);
      }
    });

    testWidgets('billing and payouts is not built: it says Coming soon', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.byKey(const Key('settings-billing')));
      await tester.tap(find.byKey(const Key('settings-billing')));
      await tester.pumpAndSettle();
      expect(find.text('Billing and payouts'), findsWidgets);
      expect(find.byKey(const Key('coming-soon-close')), findsOneWidget);
    });
  });
}
