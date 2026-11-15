import 'dart:io';

import 'package:bottles_up_vendor/core/ui/bu_coming_soon.dart';
import 'package:bottles_up_vendor/core/ui/bu_kit.dart';
import 'package:bottles_up_vendor/features/events/providers/event_details_provider.dart';
import 'package:bottles_up_vendor/features/events/screens/event_details_screen.dart';
import 'package:bottles_up_vendor/shared/models/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'classic_detail_screens_test.dart' show pumpPage, shot;

// An event's page, rebuilt in the design's look from what the event has. Share, Duplicate and Delete are not built: they say "Coming soon".
Event event({String status = 'upcoming', String? dressCode = 'Smart', int? minAge = 19, String? description = 'The big night.', int booked = 120, int capacity = 400}) => Event(
  id: 'e1',
  name: 'Afro Nights',
  description: description,
  userId: 'u1',
  zoneId: 'z1',
  eventDate: DateTime(2026, 11, 21),
  startTime: '10:00 PM',
  endTime: '3:00 AM',
  ticketPrice: 35,
  maxCapacity: capacity,
  currentBookings: booked,
  status: status,
  dressCode: dressCode,
  minAge: minAge,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(File('assets/fonts/Inter.ttf').readAsBytes().then(ByteData.sublistView));
    await font.load();
  });

  const routes = ['/events/e1/edit', '/events/e1/scanner', '/events/e1/guests', '/events/e1/tables', '/bookings', '/events/e1/tiers', '/events/e1/releases', '/events/e1/lineup'];

  Future<void> open(WidgetTester tester, Event e, {Map<String, dynamic>? stats, bool statsFail = false}) => pumpPage(
    tester,
    () => const EventDetailsScreen(eventId: 'e1'),
    path: '/events/e1',
    height: 2600,
    stubs: routes,
    overrides: [
      eventDetailsProvider('e1').overrideWith((ref) async => e),
      eventStatsProvider('e1').overrideWith((ref) async => statsFail ? throw Exception('x') : (stats ?? {'tickets_sold': 130, 'total_revenue': 4550, 'available_tickets': 270})),
    ],
  );

  group('Event details', () {
    testWidgets('what the event is: name, status, when, price, dress code and age', (tester) async {
      await open(tester, event());
      expect(tester.widget<Text>(find.byKey(const Key('event-name'))).data, 'Afro Nights');
      expect(find.descendant(of: find.byKey(const Key('event-status')), matching: find.text('Upcoming')), findsOneWidget);
      expect(find.text('The big night.'), findsOneWidget);
      expect(find.textContaining('Sat 21 Nov 2026'), findsOneWidget);
      expect(find.textContaining('10:00 PM to 3:00 AM'), findsOneWidget);
      expect(find.text('Tickets from \$35.00'), findsOneWidget);
      expect(find.text('Dress code: Smart'), findsOneWidget);
      expect(find.text('Age: 19+'), findsOneWidget);
      await shot(tester, 'event_details');
    });

    testWidgets('the four figures come from the event\'s numbers', (tester) async {
      await open(tester, event());
      Finder tile(String k) => find.descendant(of: find.byKey(Key(k)), matching: find.byType(Text));
      expect(find.descendant(of: find.byKey(const Key('event-stat-sold')), matching: find.text('130')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-stat-revenue')), matching: find.text('\$4550')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-stat-capacity')), matching: find.text('400')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-stat-available')), matching: find.text('270')), findsOneWidget);
      expect(tile('event-stat-sold'), findsWidgets);
    });

    testWidgets('when the figures cannot be loaded the revenue says N/A and the rest falls back to the event\'s own counts', (tester) async {
      await open(tester, event(), statsFail: true);
      expect(find.descendant(of: find.byKey(const Key('event-stat-revenue')), matching: find.text('N/A')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-stat-sold')), matching: find.text('120')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-stat-available')), matching: find.text('280')), findsOneWidget);
    });

    testWidgets('the status word follows the event', (tester) async {
      for (final (status, word, tone) in [('active', 'Live', BuTone.good), ('draft', 'Draft', BuTone.attention), ('completed', 'Completed', BuTone.brand), ('cancelled', 'Cancelled', BuTone.bad)]) {
        await open(tester, event(status: status));
        expect(find.descendant(of: find.byKey(const Key('event-status')), matching: find.text(word)), findsOneWidget, reason: status);
        expect(tester.widget<BuStatusPill>(find.descendant(of: find.byKey(const Key('event-status')), matching: find.byType(BuStatusPill))).tone, tone, reason: status);
      }
    });

    testWidgets('a line the event does not have is left out', (tester) async {
      await open(tester, event(dressCode: null, minAge: null, description: null));
      expect(find.textContaining('Dress code'), findsNothing);
      expect(find.textContaining('Age:'), findsNothing);
    });

    testWidgets('each row opens its page, and the event\'s name travels to the pages that show it', (tester) async {
      for (final (key, path) in [
        ('event-scanner', '/events/e1/scanner'),
        ('event-guests', '/events/e1/guests'),
        ('event-tables', '/events/e1/tables'),
        ('event-bookings', '/bookings'),
        ('event-releases', '/events/e1/releases'),
      ]) {
        await open(tester, event());
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.text('WENT TO $path'), findsOneWidget, reason: key);
      }
      for (final (key, path) in [('event-tiers', '/events/e1/tiers'), ('event-lineup', '/events/e1/lineup')]) {
        await open(tester, event());
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.text('WENT TO $path'), findsOneWidget, reason: key);
      }
    });

    testWidgets('the pencil opens the edit page', (tester) async {
      await open(tester, event());
      await tester.tap(find.byKey(const Key('event-edit')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /events/e1/edit'), findsOneWidget);
    });

    testWidgets('Share, Duplicate and Delete say Coming soon; Delete no longer asks "are you sure" first', (tester) async {
      await open(tester, event());
      for (final (key, title) in [('event-share', 'Share Event'), ('event-duplicate', 'Duplicate Event'), ('event-delete', 'Delete Event')]) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('coming-soon-close')), findsOneWidget, reason: key);
        expect(find.textContaining('Are you sure'), findsNothing, reason: key);
        await tester.tap(find.byKey(const Key('coming-soon-close')));
        await tester.pumpAndSettle();
        expect(title, isNotEmpty);
      }
      expect(find.byType(BuComingSoonPill), findsNWidgets(3));
    });

    testWidgets('a failed load says so and offers Retry', (tester) async {
      await pumpPage(
        tester,
        () => const EventDetailsScreen(eventId: 'e1'),
        path: '/events/e1',
        overrides: [eventDetailsProvider('e1').overrideWith((ref) async => throw Exception('x')), eventStatsProvider('e1').overrideWith((ref) async => <String, dynamic>{})],
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
