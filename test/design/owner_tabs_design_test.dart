import 'dart:io';

import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/business/providers/business_providers.dart';
import 'package:bottles_up_vendor/features/business/services/business_service.dart';
import 'package:bottles_up_vendor/features/business/widgets/business_status_card.dart';
import 'package:bottles_up_vendor/features/ops/widgets/ops_async_view.dart';
import 'package:bottles_up_vendor/features/owner/widgets/venue_status_chip.dart';
import 'package:bottles_up_vendor/features/floor/providers/floor_providers.dart';
import 'package:bottles_up_vendor/features/more/screens/more_screen.dart';
import 'package:bottles_up_vendor/features/night/screens/owner_reports_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/owner_home_screen.dart';
import 'package:bottles_up_vendor/features/owner/screens/owner_tonight_screen.dart';
import 'package:bottles_up_vendor/features/owner/screens/owner_venues_screen.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/table_service/widgets/night_bar.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';

import '../floor/fake_floor_backend.dart';
import '../owner/fake_owner_backend.dart';
import '../table_service/fake_table_backend.dart';

final _bu = BuTokens.dark;

const _owner = Workspace(membershipId: 'm-o', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const _manager = Workspace(membershipId: 'm-m', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

DateTime _friday9pm() => DateTime(2026, 10, 9, 21);

/// A phone, tall enough that a whole screen is built at once.
void _phone(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Color _color(WidgetTester tester, Finder f) => tester.widget<Text>(f).style!.color!;

void main() {
  // The app's own Inter file, so text takes the room it really takes.
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(File('assets/fonts/Inter.ttf').readAsBytes().then(ByteData.sublistView));
    await font.load();
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Overview', () {
    late FakeOwnerBackend owner;
    late FakeFloorBackend floor;

    setUp(() {
      owner = FakeOwnerBackend();
      floor = FakeFloorBackend();
      owner.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A'), myVenue('v2', 'Club B', status: 'published')];
      owner.onVenueRows = (ids) => [
            {'id': 'v1', 'name': 'Club A', 'slug': 'club-a', 'status': 'draft', 'address': '1 Main St'},
            {'id': 'v2', 'name': 'Club B', 'slug': 'club-b', 'status': 'published', 'address': null},
          ];
      owner.handlers['venue_setup_status'] = (_) => partialSetup();
      // Club A: two bookings (6 guests), one arrived, one waiting for payment. Club B: one booking (6 guests).
      floor.onList = (p) => p!['p_venue'] == 'v1'
          ? [bookingRow('a1', guests: 4, checkedInAt: '2026-10-09T22:00:00Z'), bookingRow('a2', guests: 2), bookingRow('a3', status: 'pending')]
          : [bookingRow('b1', guests: 6)];
    });

    Future<void> open(WidgetTester tester) async {
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [ownerServiceProvider.overrideWithValue(owner.service), floorServiceProvider.overrideWithValue(floor.service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: OwnerHomeScreen(workspace: _owner, clock: _friday9pm, onOpenVenue: (c, m, v) {})),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Finder inHero(Finder f) => find.descendant(of: find.byKey(const Key('home-hero')), matching: f);

    testWidgets('opens with a heading and the big card: guests expected, how many bookings have arrived, and a ring of that share', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(find.byType(BuPageHeader), findsOneWidget);
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('All venues'), findsOneWidget);
      expect(inHero(find.text('TONIGHT')), findsOneWidget);
      expect(inHero(find.text('12 guests expected')), findsOneWidget);
      expect(inHero(find.text('1 of 3 bookings have arrived')), findsOneWidget);
      expect(inHero(find.text('33%')), findsOneWidget);
      // The big card is one item for a screen reader, the ring's words among the rest.
      final label = tester.getSemantics(find.byKey(const Key('home-hero'))).label;
      expect(label, 'TONIGHT\n12 guests expected\n1 of 3 bookings have arrived\n33% arrived');
      handle.dispose();
    });

    testWidgets('each figure is its own item for a screen reader: the number, then what it counts', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(tester.getSemantics(find.byKey(const Key('home-bookings'))).label, '3\nConfirmed bookings');
      expect(tester.getSemantics(find.byKey(const Key('home-guests'))).label, '12\nGuests expected');
      expect(tester.getSemantics(find.byKey(const Key('home-awaiting'))).label, '1\nAwaiting payment');
      handle.dispose();
    });

    testWidgets('the figures under it are tiles, two to a row, with the number first', (tester) async {
      await open(tester);
      expect(find.byType(BuMetricTile), findsNWidgets(4));
      final bookings = tester.getRect(find.byKey(const Key('home-bookings')));
      final guests = tester.getRect(find.byKey(const Key('home-guests')));
      final arrived = tester.getRect(find.byKey(const Key('home-arrived')));
      final awaiting = tester.getRect(find.byKey(const Key('home-awaiting')));
      expect(bookings.top, guests.top);
      expect(arrived.top, awaiting.top);
      expect(arrived.top, greaterThan(bookings.bottom), reason: 'the second row is below the first');
      expect(bookings.left, arrived.left);
      expect(bookings.width, guests.width);
    });

    testWidgets('a night that has passed says "booked", not "expected", and the card says which nights', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('home-preset-last7')));
      await tester.pumpAndSettle();
      expect(inHero(find.text('12 guests booked')), findsOneWidget);
      expect(inHero(find.text('THESE NIGHTS')), findsOneWidget);
    });

    testWidgets('with nobody booked the ring is empty and says 0%, not an error', (tester) async {
      floor.onList = (p) => <Map<String, dynamic>>[];
      await open(tester);
      expect(inHero(find.text('0 guests expected')), findsOneWidget);
      expect(inHero(find.text('0 of 0 bookings have arrived')), findsOneWidget);
      expect(inHero(find.text('0%')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one booking reads as one booking, and one guest as one guest', (tester) async {
      floor.onList = (p) => p!['p_venue'] == 'v1' ? [bookingRow('a1', guests: 1)] : <Map<String, dynamic>>[];
      await open(tester);
      expect(inHero(find.text('1 guest expected')), findsOneWidget);
      expect(inHero(find.text('0 of 1 booking has arrived')), findsOneWidget);
    });

    testWidgets('a venue that could not be read means no big card: a headline built on a short total would look more sure than it is', (tester) async {
      floor.onList = (p) => p!['p_venue'] == 'v1' ? throw Exception('offline') : [bookingRow('b1', guests: 6)];
      await open(tester);
      expect(find.byKey(const Key('home-hero')), findsNothing);
      expect(find.byKey(const Key('home-incomplete')), findsOneWidget);
      expect(find.byKey(const Key('home-guests')), findsOneWidget, reason: 'the tiles still show what could be read');
    });

    testWidgets('a venue with more bookings than can be counted also means no big card', (tester) async {
      floor.onList = (p) => p!['p_venue'] == 'v1' ? [for (var i = 0; i < 1000; i++) bookingRow('r$i')] : [bookingRow('b1', guests: 6)];
      await open(tester);
      expect(find.byKey(const Key('home-hero')), findsNothing);
      expect(find.byKey(const Key('home-cut')), findsOneWidget);
    });

    testWidgets('the warning under the tiles is the design\'s amber', (tester) async {
      floor.onList = (p) => p!['p_venue'] == 'v1' ? throw Exception('offline') : [bookingRow('b1')];
      await open(tester);
      expect(_color(tester, find.byKey(const Key('home-incomplete'))), _bu.amber);
    });

    testWidgets('"Awaiting payment" turns amber when something is waiting, and "Arrived" green when someone has; at zero they are plain', (tester) async {
      await open(tester);
      Color valueColor(String key) => _color(tester, find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first);
      expect(valueColor('home-awaiting'), _bu.amber);
      expect(valueColor('home-arrived'), _bu.green);
      expect(valueColor('home-bookings'), _bu.ink);
      expect(valueColor('home-guests'), _bu.ink);

      floor.onList = (p) => [bookingRow('x1', guests: 2)];
      await open(tester);
      await tester.tap(find.byKey(const Key('home-preset-next7')));
      await tester.pumpAndSettle();
      expect(valueColor('home-awaiting'), _bu.ink);
      expect(valueColor('home-arrived'), _bu.ink);
    });

    testWidgets('the ready-made ranges carry no tick, and the chosen one is the one that is selected', (tester) async {
      await open(tester);
      for (final id in ['tonight', 'next7', 'next30', 'last7']) {
        final chip = tester.widget<ChoiceChip>(find.byKey(Key('home-preset-$id')));
        expect(chip.showCheckmark, isFalse, reason: id);
        expect(chip.selected, id == 'tonight', reason: id);
      }
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('the two date buttons are a step under full size, so the big card is not pushed off the screen', (tester) async {
      await open(tester);
      for (final k in ['home-pick-from', 'home-pick-to']) {
        // 44 points of button inside the 48-point touch target every tap area gets.
        expect(tester.getSize(find.byKey(Key(k))).height, 48, reason: k);
        expect(tester.widget<OutlinedButton>(find.byKey(Key(k))).style!.minimumSize!.resolve({}), const Size(0, 44), reason: k);
      }
      expect(tester.getRect(find.byKey(const Key('home-hero'))).top, lessThan(400), reason: 'the big card starts in the top half of a phone');
    });

    testWidgets('each venue is a card that opens it, with a green "Live" or a grey "Draft"', (tester) async {
      final opened = <String>[];
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [ownerServiceProvider.overrideWithValue(owner.service), floorServiceProvider.overrideWithValue(floor.service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: OwnerHomeScreen(workspace: _owner, clock: _friday9pm, onOpenVenue: (c, m, v) => opened.add('$m/$v'))),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('home-venue-v1')), matching: find.byType(BuCard)), findsNothing, reason: 'the card is the keyed widget itself');
      Finder pillText(String venue, String word) =>
          find.descendant(of: find.descendant(of: find.byKey(Key('home-venue-$venue')), matching: find.byKey(const Key('venue-status'))), matching: find.text(word));
      expect(_color(tester, pillText('v2', 'Live')), _bu.green);
      expect(_color(tester, pillText('v1', 'Draft')), _bu.muted);
      await tester.tap(find.byKey(const Key('home-venue-v2')));
      expect(opened, ['m-o/v2']);
    });

    testWidgets('a failure to load is a card with the sentence and a way to try again', (tester) async {
      owner.handlers['my_venues'] = (_) => throw Exception('offline');
      await open(tester);
      expect(find.ancestor(of: find.byKey(const Key('home-error')), matching: find.byType(BuCard)), findsOneWidget);
      expect(find.byKey(const Key('home-retry')), findsOneWidget);
    });

    testWidgets('with no venues it says so in a card', (tester) async {
      owner.handlers['my_venues'] = (_) => [];
      await open(tester);
      expect(find.byKey(const Key('home-no-venues')), findsOneWidget);
      expect(find.byType(BuCard), findsOneWidget);
      expect(find.byKey(const Key('home-hero')), findsNothing);
    });

    testWidgets('keeps to the margin of the page and does not overflow a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [ownerServiceProvider.overrideWithValue(owner.service), floorServiceProvider.overrideWithValue(floor.service)],
        child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: OwnerHomeScreen(workspace: _owner, clock: _friday9pm, onOpenVenue: (c, m, v) {}))),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byKey(const Key('home-hero'))).left, BuSpace.page);
      expect(tester.getRect(find.byKey(const Key('home-hero'))).right, 320 - BuSpace.page);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Venues', () {
    late FakeOwnerBackend owner;

    setUp(() {
      owner = FakeOwnerBackend();
      owner.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A'), myVenue('v2', 'Club B', status: 'published')];
      owner.onVenueRows = (ids) => [
            {'id': 'v1', 'name': 'Club A', 'slug': 'club-a', 'status': 'draft', 'address': '1 Main St'},
            {'id': 'v2', 'name': 'Club B', 'slug': 'club-b', 'status': 'published', 'address': null},
          ];
      owner.handlers['venue_setup_status'] = (p) => p!['p_venue'] == 'v2'
          ? [for (final s in ['profile', 'floor_plan', 'tables', 'bottles', 'booking_rules']) stepRow(s, 'done')]
          : partialSetup();
    });

    Future<List<String>> open(WidgetTester tester) async {
      final opened = <String>[];
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [ownerServiceProvider.overrideWithValue(owner.service)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: OwnerVenuesScreen(workspace: _owner, onOpenVenue: (c, m, v) => opened.add('$m/$v'))),
        ),
      ));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('has a heading, the business under it, and one card per venue', (tester) async {
      await open(tester);
      expect(find.text('PORTFOLIO'), findsOneWidget);
      expect(find.text('Venues'), findsOneWidget);
      expect(find.text('Club Co'), findsOneWidget);
      expect(find.byKey(const Key('venue-v1')), findsOneWidget);
      expect(find.byKey(const Key('venue-v2')), findsOneWidget);
      expect(find.text('1 Main St'), findsOneWidget);
    });

    testWidgets('a venue card opens that venue', (tester) async {
      final opened = await open(tester);
      await tester.tap(find.byKey(const Key('venue-v1')));
      expect(opened, ['m-o/v1']);
    });

    testWidgets('Live is green, Draft is grey', (tester) async {
      await open(tester);
      expect(_color(tester, find.text('Live')), _bu.green);
      expect(_color(tester, find.text('Draft')), _bu.muted);
    });

    testWidgets('setup progress is an orange bar while steps are left, and green once every required step is done', (tester) async {
      await open(tester);
      LinearProgressIndicator bar(String venue) =>
          tester.widget<LinearProgressIndicator>(find.descendant(of: find.byKey(Key('setup-progress-$venue')), matching: find.byType(LinearProgressIndicator)));
      expect(bar('v1').color, isNull, reason: 'the theme\'s orange');
      expect(bar('v1').value, closeTo(0.6, 0.001));
      expect(bar('v2').color, _bu.green);
      expect(bar('v2').value, 1);
      expect(find.text('3 of 5 required steps'), findsOneWidget);
      expect(find.text('5 of 5 required steps'), findsOneWidget);
    });

    testWidgets('"Add a venue" is the one orange action, the width of the page, with a plus', (tester) async {
      await open(tester);
      final button = find.byKey(const Key('add-venue'));
      expect(tester.getSize(button).width, 393 - 2 * BuSpace.page);
      expect(find.descendant(of: button, matching: find.byIcon(Ionicons.add)), findsOneWidget);
      expect(find.descendant(of: button, matching: find.text('Add a venue')), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('no venues: a card says so, and the add button is still there', (tester) async {
      owner.handlers['my_venues'] = (_) => [];
      await open(tester);
      expect(find.ancestor(of: find.byKey(const Key('no-venues')), matching: find.byType(BuCard)).evaluate().isNotEmpty || find.byKey(const Key('no-venues')).evaluate().isNotEmpty, isTrue);
      expect(find.byType(BuCard), findsOneWidget);
      expect(find.byKey(const Key('add-venue')), findsOneWidget);
    });

    testWidgets('a failure to load is a card with the sentence and a way to try again', (tester) async {
      owner.handlers['my_venues'] = (_) => throw Exception('offline');
      await open(tester);
      expect(find.ancestor(of: find.byKey(const Key('venues-error')), matching: find.byType(BuCard)), findsOneWidget);
      expect(find.byKey(const Key('venues-retry')), findsOneWidget);
      expect(find.byKey(const Key('add-venue')), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Tonight', () {
    late FakeTableBackend db;

    setUp(() {
      db = FakeTableBackend()..role = 'manager';
      db.now = DateTime(2026, 10, 9, 21);
      db.addBooking('b1', name: 'Ada Lovelace', total: 10000, paid: 6000, guests: 4);
      db.addBooking('b2', name: 'Grace Hopper', total: 5000, paid: 5000, guests: 2, table: 'Corner');
      db.addBooking('b3', name: 'Nobody Nell', total: 2000, paid: 0, guests: 3, table: 'Booth 3');
      db.assignments['b1'] = 'm-me';
      db.assignments['b2'] = 'm-me';
      db.bookings['b1']!.checkedIn = true;
      db.addLine('b1', 'Patron', state: 'awaiting_prep');
      db.addLine('b3', 'Belvedere', state: 'awaiting_prep');
      db.addPayment('b1', 3000);
      db.openRequests = 3;
    });

    Future<void> open(WidgetTester tester) async {
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [tableServiceServiceProvider.overrideWithValue(db.service)],
        child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: TonightScreen(workspace: _manager, clock: _friday9pm))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('has a heading with the club under it, the night bar, then five shortcuts', (tester) async {
      await open(tester);
      expect(find.text('OPERATIONS'), findsOneWidget);
      expect(find.text('Tonight'), findsOneWidget);
      expect(find.text('Club A'), findsOneWidget);
      expect(find.byType(NightBar), findsOneWidget);
      for (final k in ['add-walkin', 'open-table-map', 'message-team', 'assign-staff', 'send-alert']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
    });

    testWidgets('the shortcuts sit two to a row, with "Send alert" on a row of its own, the width of the page', (tester) async {
      await open(tester);
      Rect r(String k) => tester.getRect(find.byKey(Key(k)));
      expect(r('add-walkin').top, r('open-table-map').top);
      expect(r('message-team').top, r('assign-staff').top);
      expect(r('message-team').top, greaterThan(r('add-walkin').bottom));
      expect(r('send-alert').top, greaterThan(r('message-team').bottom));
      expect(r('add-walkin').width, r('open-table-map').width);
      expect(r('send-alert').width, 393 - 2 * BuSpace.page);
      expect(r('add-walkin').height, 48);
    });

    testWidgets('"Add walk-in" is the filled orange button tonight, and goes quiet on any other night', (tester) async {
      await open(tester);
      Color? fill(Set<WidgetState> states) => tester.widget<OutlinedButton>(find.byKey(const Key('add-walkin'))).style!.backgroundColor!.resolve(states);
      expect(fill({}), _bu.orange);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('add-walkin'))).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('night-next')));
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('add-walkin'))).onPressed, isNull);
      expect(fill({WidgetState.disabled}), _bu.panel2);
      expect(find.byKey(const Key('walkin-tonight-only')), findsOneWidget);
    });

    testWidgets('"Send alert" is drawn in amber, because it interrupts the whole team; the others are plain', (tester) async {
      await open(tester);
      Color? ink(String k) => tester.widget<OutlinedButton>(find.byKey(Key(k))).style!.foregroundColor?.resolve({});
      expect(ink('send-alert'), _bu.amber);
      expect(ink('open-table-map'), isNull);
      expect(ink('message-team'), isNull);
    });

    testWidgets('what needs a person and the night at a glance are two grouped cards, in that order', (tester) async {
      await open(tester);
      expect(find.byType(BuListCard), findsNWidgets(2));
      final first = find.byType(BuListCard).first;
      final second = find.byType(BuListCard).last;
      for (final k in ['tile-payments', 'tile-orders-new', 'tile-requests', 'tile-without-server', 'tile-closeouts']) {
        expect(find.descendant(of: first, matching: find.byKey(Key(k))), findsOneWidget, reason: k);
      }
      for (final k in ['tile-tables', 'tile-balance', 'tile-in-progress', 'tile-delivered']) {
        expect(find.descendant(of: second, matching: find.byKey(Key(k))), findsOneWidget, reason: k);
      }
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('The night'), findsOneWidget);
      expect(tester.getRect(second).top, greaterThan(tester.getRect(first).bottom));
    });

    testWidgets('the counts line up in a column, whether or not the row opens something', (tester) async {
      await open(tester);
      double right(String k) => tester.getRect(find.descendant(of: find.byKey(Key(k)), matching: find.byType(BuCountBadge))).right;
      // Payments to check opens a list; Tables without a server does not.
      expect(right('tile-without-server'), right('tile-payments'));
      expect(right('tile-closeouts'), right('tile-orders-new'));
      expect(right('tile-tables'), right('tile-payments'));
    });

    testWidgets('a count that needs a person is amber when it is not zero; at zero, and on a plain figure of the night, it is grey', (tester) async {
      await open(tester);
      Color badge(String k) => _color(tester, find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text)).last);
      for (final k in ['tile-payments', 'tile-orders-new', 'tile-requests', 'tile-without-server']) {
        expect(badge(k), _bu.amber, reason: k);
      }
      expect(badge('tile-closeouts'), _bu.muted, reason: 'nobody asked to close: zero is not highlighted');
      expect(badge('tile-tables'), _bu.muted, reason: 'the night at a glance is never highlighted, however big');
    });

    testWidgets('a row that opens something shows a chevron; one that does not, none', (tester) async {
      await open(tester);
      expect(find.descendant(of: find.byKey(const Key('tile-payments')), matching: find.byIcon(Ionicons.chevron_forward)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tile-without-server')), matching: find.byIcon(Ionicons.chevron_forward)), findsNothing);
    });

    testWidgets('a long note is shown in full, not cut to two lines', (tester) async {
      db.addBooking('b9', name: 'Late Larry', total: 1000, paid: 0, guests: 1, table: 'Bar');
      await open(tester);
      // "Closing a table is not built yet." and the other notes are short; the longest in the app is the double-booked one, which the row allows 4 lines.
      final row = tester.widget<BuListRow>(find.byKey(const Key('tile-closeouts')));
      expect(row.maxSubtitleLines, 4);
    });

    testWidgets('"Prepare and close the night" is the highlighted card, with a moon, and opens on a tap', (tester) async {
      await open(tester);
      final card = tester.widget<BuCard>(find.byKey(const Key('tile-night')));
      expect(card.highlight, isTrue);
      expect(find.descendant(of: find.byKey(const Key('tile-night')), matching: find.byIcon(Ionicons.moon_outline)), findsOneWidget);
      await tester.tap(find.byKey(const Key('tile-night')));
      await tester.pumpAndSettle();
      expect(find.text('Prepare and close'), findsOneWidget, reason: 'the app bar of the page it opened');
    });

    testWidgets('the nightly report button uses the kit\'s document icon', (tester) async {
      await open(tester);
      expect(find.descendant(of: find.byKey(const Key('report-open')), matching: find.byIcon(Ionicons.document_text_outline)), findsOneWidget);
    });

    testWidgets('a failed load is a card with the sentence and Try again; the shortcuts are still there', (tester) async {
      db.failAll = true;
      await open(tester);
      expect(find.ancestor(of: find.byKey(const Key('tonight-error')), matching: find.byType(BuCard)), findsOneWidget);
      expect(find.byKey(const Key('tonight-retry')), findsOneWidget);
      expect(find.byKey(const Key('send-alert')), findsOneWidget);
    });

    testWidgets('does not overflow a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [tableServiceServiceProvider.overrideWithValue(db.service)],
        child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: TonightScreen(workspace: _manager, clock: _friday9pm))),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the night bar', () {
    Future<List<String>> bar(WidgetTester tester, {required String night, String tonight = '2026-10-09'}) async {
      final changes = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: NightBar(night: night, tonight: tonight, onChanged: changes.add)),
      ));
      return changes;
    }

    testWidgets('sits in a panel: a chevron each side and the night in the middle', (tester) async {
      await bar(tester, night: '2026-10-09');
      expect(find.byIcon(Ionicons.chevron_back), findsOneWidget);
      expect(find.byIcon(Ionicons.chevron_forward), findsOneWidget);
      expect(find.text('Friday Oct 9'), findsOneWidget);
      final panel = tester.widget<DecoratedBox>(find.descendant(of: find.byType(NightBar), matching: find.byType(DecoratedBox)).first);
      expect((panel.decoration as BoxDecoration).color, _bu.panel);
      expect((panel.decoration as BoxDecoration).borderRadius, BorderRadius.circular(BuRadius.control));
    });

    testWidgets('the arrows go a night back and a night forward', (tester) async {
      final changes = await bar(tester, night: '2026-10-09');
      await tester.tap(find.byKey(const Key('night-prev')));
      await tester.tap(find.byKey(const Key('night-next')));
      expect(changes, ['2026-10-08', '2026-10-10']);
    });

    testWidgets('the arrows are labelled for a screen reader and are at least 44 points', (tester) async {
      await bar(tester, night: '2026-10-09');
      expect(find.byTooltip('The night before'), findsOneWidget);
      expect(find.byTooltip('The next night'), findsOneWidget);
      for (final k in ['night-prev', 'night-next']) {
        final size = tester.getSize(find.byKey(Key(k)));
        expect(size.width, greaterThanOrEqualTo(44), reason: k);
        expect(size.height, greaterThanOrEqualTo(44), reason: k);
      }
    });

    testWidgets('"Back to tonight" appears on any other night, and only then', (tester) async {
      var changes = await bar(tester, night: '2026-10-09');
      expect(find.byKey(const Key('night-tonight')), findsNothing);
      changes = await bar(tester, night: '2026-10-12');
      await tester.pump();
      await tester.tap(find.byKey(const Key('night-tonight')));
      expect(changes, ['2026-10-09']);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Tonight (owner): the venue chips', () {
    testWidgets('are plain chips with no tick, and the chosen venue is the selected one', (tester) async {
      final db = FakeTableBackend()..role = 'owner';
      db.now = DateTime(2026, 10, 9, 21);
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          tableServiceServiceProvider.overrideWithValue(db.service),
          ownerVenuesProvider('o1').overrideWith((ref) async => const [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')]),
        ],
        child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: OwnerTonightScreen(workspace: _owner, clock: _friday9pm))),
      ));
      await tester.pumpAndSettle();
      final a = tester.widget<ChoiceChip>(find.byKey(const Key('owner-tonight-venue-v1')));
      final b = tester.widget<ChoiceChip>(find.byKey(const Key('owner-tonight-venue-v2')));
      expect([a.showCheckmark, b.showCheckmark], [false, false]);
      expect([a.selected, b.selected], [true, false]);
      final row = tester.getRect(find.byKey(const Key('owner-tonight-venue-v1')));
      expect(row.left, BuSpace.page, reason: 'the chips start at the page margin');
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('Reports', () {
    Future<void> open(WidgetTester tester, List<OrgVenue> venues) async {
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [ownerVenuesProvider('o1').overrideWith((ref) async => venues)],
        child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: OwnerReportsScreen(workspace: _owner, clock: _friday9pm))),
      ));
      await tester.pumpAndSettle();
    }

    const two = [OrgVenue(id: 'v1', name: 'Club A', status: 'published'), OrgVenue(id: 'v2', name: 'Club B', status: 'draft')];

    testWidgets('has a heading, the business, the combined card first and then a card per venue', (tester) async {
      await open(tester, two);
      expect(find.text('NIGHTLY'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Club Co'), findsOneWidget);
      final all = tester.getRect(find.byKey(const Key('owner-report-all')));
      final a = tester.getRect(find.byKey(const Key('owner-report-v1')));
      final b = tester.getRect(find.byKey(const Key('owner-report-v2')));
      expect(all.bottom, lessThanOrEqualTo(a.top));
      expect(a.bottom, lessThanOrEqualTo(b.top));
    });

    testWidgets('every card is the width of the page, not the width of what is in it', (tester) async {
      await open(tester, two);
      for (final k in ['owner-report-all', 'owner-report-v1', 'owner-report-v2']) {
        final r = tester.getRect(find.byKey(Key(k)));
        expect([r.left, r.right], [BuSpace.page, 393 - BuSpace.page], reason: k);
      }
    });

    testWidgets('the combined card is the highlighted one and its button is the orange one', (tester) async {
      await open(tester, two);
      expect(tester.widget<BuCard>(find.byKey(const Key('owner-report-all'))).highlight, isTrue);
      expect(tester.widget<BuCard>(find.byKey(const Key('owner-report-v1'))).highlight, isFalse);
      expect(find.descendant(of: find.byKey(const Key('consolidated-open')), matching: find.byIcon(Ionicons.stats_chart_outline)), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('consolidated-open'))).onPressed, isNotNull);
    });

    testWidgets('a venue\'s two buttons are stacked, each the width of the card\'s inside', (tester) async {
      await open(tester, two);
      final report = tester.getRect(find.descendant(of: find.byKey(const Key('owner-report-v1')), matching: find.byKey(const Key('report-open'))));
      final close = tester.getRect(find.byKey(const Key('owner-night-v1')));
      expect(report.left, close.left);
      expect(report.width, close.width);
      expect(close.top, greaterThan(report.bottom));
      expect(find.descendant(of: find.byKey(const Key('owner-night-v1')), matching: find.byIcon(Ionicons.moon_outline)), findsOneWidget);
    });

    testWidgets('one venue: its own card only, no combined card', (tester) async {
      await open(tester, const [OrgVenue(id: 'v1', name: 'Club A', status: 'published')]);
      expect(find.byKey(const Key('owner-report-all')), findsNothing);
      expect(find.byKey(const Key('owner-report-v1')), findsOneWidget);
    });

    testWidgets('no venues: the sentence is in a card', (tester) async {
      await open(tester, const []);
      expect(find.ancestor(of: find.byKey(const Key('owner-reports-empty')), matching: find.byType(BuCard)), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('More', () {
    Future<void> open(WidgetTester tester, {bool showUnbuilt = false}) async {
      _phone(tester, height: 4000);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: MoreScreen(workspace: _owner, showUnbuilt: showUnbuilt))));
      await tester.pumpAndSettle();
    }

    testWidgets('has a heading with the scope under it, then every entry in one grouped card', (tester) async {
      await open(tester);
      expect(find.text('WORKSPACE'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('All venues'), findsOneWidget);
      expect(find.byType(BuListCard), findsOneWidget);
      expect(find.descendant(of: find.byType(BuListCard), matching: find.byType(ListTile)), findsWidgets);
      expect(find.byType(ListTile).evaluate().length, find.descendant(of: find.byType(BuListCard), matching: find.byType(ListTile)).evaluate().length);
    });

    testWidgets('an entry has its icon in a tile, its name, what it is for, and a chevron', (tester) async {
      await open(tester);
      final row = find.byKey(const Key('more-team'));
      expect(find.descendant(of: row, matching: find.byType(BuIconTile)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.byIcon(Ionicons.people_outline)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Team')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Staff, invitations and roles for the business.')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.byIcon(Ionicons.chevron_forward)), findsOneWidget);
      expect(tester.widget<ListTile>(row).onTap, isNotNull);
    });

    testWidgets('an entry that is not built is dimmed, says so, has no chevron and does nothing', (tester) async {
      await open(tester, showUnbuilt: true);
      final row = find.byKey(const Key('more-complimentary'));
      expect(tester.widget<ListTile>(row).onTap, isNull);
      expect(tester.widget<ListTile>(row).enabled, isFalse);
      expect(find.descendant(of: row, matching: find.textContaining('Not available yet.')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.byIcon(Ionicons.chevron_forward)), findsNothing);
      expect(_color(tester, find.descendant(of: row, matching: find.text('Complimentary bottles'))), _bu.muted);
      final tile = tester.widget<Container>(find.descendant(of: find.descendant(of: row, matching: find.byType(BuIconTile)), matching: find.byType(Container)).first);
      expect((tile.decoration! as BoxDecoration).color, _bu.panel2);
    });

    testWidgets('a built entry keeps its own colours', (tester) async {
      await open(tester);
      final row = find.byKey(const Key('more-team'));
      expect(_color(tester, find.descendant(of: row, matching: find.text('Staff, invitations and roles for the business.'))), _bu.muted);
      final tile = tester.widget<Container>(find.descendant(of: find.descendant(of: row, matching: find.byType(BuIconTile)), matching: find.byType(Container)).first);
      expect((tile.decoration! as BoxDecoration).color, _bu.orangeWash);
    });

    testWidgets('a tap on an entry opens its page with the entry\'s name in the app bar', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('more-settings')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Settings')), findsOneWidget);
    });

    testWidgets('keeps to the page margin and fits a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: MoreScreen(workspace: _owner))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(BuListCard));
      expect([card.left, card.right], [BuSpace.page, 320 - BuSpace.page]);
    });
  });

  // ---------------------------------------------------------------------------------------------------------------------------------------------------------
  group('the venue pill, the shared load states and the business status card', () {
    testWidgets('a venue pill is the kit\'s pill: green "Live" for a published venue, grey "Draft" otherwise, and it keeps its key', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: Column(children: [VenueStatusChip(status: 'published'), VenueStatusChip(status: 'draft'), VenueStatusChip(status: 'pending_review')])),
      ));
      expect(find.byKey(const Key('venue-status')), findsNWidgets(3));
      expect(find.byType(BuStatusPill), findsNWidgets(3));
      expect(tester.widgetList<BuStatusPill>(find.byType(BuStatusPill)).map((p) => (p.label, p.tone)).toList(), [
        ('Live', BuTone.good),
        ('Draft', BuTone.neutral),
        ('Draft', BuTone.neutral),
      ]);
    });

    Future<void> opsView(WidgetTester tester, AsyncValue<List<String>> value, {VoidCallback? onRetry}) => tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: OpsAsyncView<List<String>>(value: value, what: 'things', isEmpty: (d) => d.isEmpty, emptyText: 'No things yet.', onRetry: onRetry, builder: (d) => Text(d.join(','), key: const Key('data'))),
          ),
        ));

    testWidgets('a failure is a card with the sentence and Try again', (tester) async {
      var retried = 0;
      await opsView(tester, AsyncValue.error(Exception('offline'), StackTrace.empty), onRetry: () => retried++);
      expect(find.ancestor(of: find.byKey(const Key('ops-error')), matching: find.byType(BuCard)), findsOneWidget);
      await tester.tap(find.byKey(const Key('ops-retry')));
      expect(retried, 1);
    });

    testWidgets('an empty list says so in a card', (tester) async {
      await opsView(tester, const AsyncValue.data([]));
      expect(find.ancestor(of: find.text('No things yet.'), matching: find.byType(BuCard)), findsOneWidget);
      expect(find.byKey(const Key('ops-empty')), findsOneWidget);
    });

    testWidgets('data is shown as it is, and loading is a spinner and nothing else', (tester) async {
      await opsView(tester, const AsyncValue.data(['a', 'b']));
      expect(find.text('a,b'), findsOneWidget);
      expect(find.byType(BuCard), findsNothing);
      await opsView(tester, const AsyncValue.loading());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(BuCard), findsNothing);
    });

    Future<void> statusCard(WidgetTester tester, String state, {String? message}) async {
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          businessServiceProvider.overrideWithValue(BusinessService(caller: (fn, {params}) async => [
                {
                  'org_id': 'o1', 'org_name': 'Club Co', 'org_kind': 'venue_owner', 'role': 'owner', 'verification_state': state,
                  'request_message': message, 'missing': <String>[], 'venue_count': 1, 'pending_claims': 0,
                },
              ])),
        ],
        child: MaterialApp(theme: AppTheme.darkTheme, home: const Scaffold(body: SingleChildScrollView(child: BusinessStatusCard(orgId: 'o1', site: 'https://site.example/')))),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('while under review the card is plain, with an orange state pill', (tester) async {
      await statusCard(tester, 'under_review');
      expect(tester.widget<BuCard>(find.byKey(const Key('business-status-card'))).highlight, isFalse);
      final pill = tester.widget<BuStatusPill>(find.byKey(const Key('business-status-label')));
      expect([pill.label, pill.tone], ['Under review', BuTone.brand]);
    });

    testWidgets('when more information is needed the card is highlighted and the pill is amber', (tester) async {
      await statusCard(tester, 'more_information_needed', message: 'Please upload your licence.');
      expect(tester.widget<BuCard>(find.byKey(const Key('business-status-card'))).highlight, isTrue);
      final pill = tester.widget<BuStatusPill>(find.byKey(const Key('business-status-label')));
      expect([pill.label, pill.tone], ['More information needed', BuTone.attention]);
      expect(find.text('From the reviewer: Please upload your licence.'), findsOneWidget);
    });

    testWidgets('a verified business has no card at all', (tester) async {
      await statusCard(tester, 'verified');
      expect(find.byKey(const Key('business-status-card')), findsNothing);
    });
  });
}
