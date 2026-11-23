import 'dart:async';

import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/organizer_events/screens/event_tickets_screen.dart';
import 'package:bottles_up_vendor/features/organizer_events/screens/organizer_events_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_organizer_events_backend.dart';
import 'fake_organizer_tiers_backend.dart';

late FakeOrganizerTiersBackend db;
late FakeOrganizerEventsBackend eventsDb;
late List<DateTime?> picks;
late DateTime now;

const orgWs = Workspace(membershipId: 'm-g', orgId: 'o1', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);

OrgEvent draft() => OrgEvent(eventId: 'ev1', title: 'Friday Night', startDate: DateTime(2031, 12, 10, 20), endDate: DateTime(2031, 12, 11, 2), status: OrgEventStatus.draft, rawStatus: 'draft');
OrgEvent live() => OrgEvent(eventId: 'ev1', title: 'Friday Night', startDate: DateTime(2031, 12, 10, 20), endDate: DateTime(2031, 12, 11, 2), status: OrgEventStatus.published, rawStatus: 'published');

Widget host(OrgEvent event) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        organizerTiersServiceProvider.overrideWithValue(db.service),
        organizerEventsServiceProvider.overrideWithValue(eventsDb.service),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: EventTicketsScreen(orgId: 'o1', event: event, clock: () => now, pickDateTime: (context, initial) async => picks.isEmpty ? null : picks.removeAt(0)),
      ),
    );

Future<void> open(WidgetTester tester, {OrgEvent? event}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(event ?? draft()));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeKey(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
String boxOf(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
Finder inProblems(String text) => find.descendant(of: find.byKey(const Key('problems')), matching: find.text(text));
bool enabled(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).enabled ?? true;

void main() {
  setUp(() {
    db = FakeOrganizerTiersBackend();
    eventsDb = FakeOrganizerEventsBackend();
    picks = [];
    now = DateTime(2031, 12, 1, 12);
  });

  group('the list', () {
    testWidgets('an event with no ticket types says so and offers to add one; on a draft it says guests see them once the event is published', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('no-tiers')), findsOneWidget);
      expect(find.text('No ticket types yet. Add one to start selling.'), findsOneWidget);
      expect(find.byKey(const Key('add-tier')), findsOneWidget);
      expect(textOf(tester, 'tickets-intro'), contains('once the BottlesUp team publishes the event'));
    });

    testWidgets('shows each type: name, price, how many have sold and are left, when sales run, and what is locked', (tester) async {
      db.seed(id: 'a', name: 'Early Bird', price: 1500, capacity: 50, sold: 10, ends: '2031-12-05T22:00:00Z');
      db.seed(id: 'b', name: 'Free list', price: 0, capacity: 20);
      db.seed(id: 'c', name: 'VIP', price: 8000, capacity: 10, code: true, starts: '2031-12-20T10:00:00Z');
      await open(tester);

      expect(textOf(tester, 'tier-name-a'), 'Early Bird');
      expect(textOf(tester, 'tier-price-a'), '\$15.00');
      expect(textOf(tester, 'tier-sold-a'), '10 of 50 sold · 40 left');
      expect(textOf(tester, 'tier-sales-a'), startsWith('On sale until '));
      expect(find.byKey(const Key('tier-locked-a')), findsOneWidget, reason: 'it has sold');
      expect(textOf(tester, 'tier-price-b'), 'Free');
      expect(textOf(tester, 'tier-sales-b'), 'On sale');
      expect(find.byKey(const Key('tier-locked-b')), findsNothing);
      expect(textOf(tester, 'tier-sales-c'), startsWith('Sales open '));
      expect(find.byKey(const Key('tier-code-c')), findsOneWidget, reason: 'BottlesUp locked it behind an access code');
      expect(find.byKey(const Key('tier-code-a')), findsNothing);
    });

    testWidgets('a type that has sold can be changed but a type somebody has an order for cannot be removed, and says how to stop selling it', (tester) async {
      db.seed(id: 'a', name: 'Sold', sold: 4);
      db.seed(id: 'b', name: 'Unsold');
      db.seed(id: 'c', name: 'Started', hasOrders: true);
      await open(tester);

      expect(find.byKey(const Key('edit-tier-a')), findsOneWidget);
      expect(find.byKey(const Key('remove-tier-a')), findsNothing);
      expect(find.byKey(const Key('tier-cannot-remove-a')), findsOneWidget);
      expect(find.byKey(const Key('edit-tier-b')), findsOneWidget);
      expect(find.byKey(const Key('remove-tier-b')), findsOneWidget);
      expect(find.byKey(const Key('tier-cannot-remove-b')), findsNothing);
      expect(find.byKey(const Key('remove-tier-c')), findsNothing);
      expect(textOf(tester, 'tier-cannot-remove-c'), contains('set when sales end'));
    });

    testWidgets('a published event says what can still be done', (tester) async {
      await open(tester, event: live());
      expect(textOf(tester, 'tickets-intro'), contains('on sale now'));
      expect(textOf(tester, 'tickets-intro'), contains('keeps its name and price'));
    });

    testWidgets('only this event\'s types are shown', (tester) async {
      db.seed(id: 'a', name: 'Mine');
      db.seed(id: 'x', event: 'other', name: 'Not mine');
      await open(tester);
      expect(find.byKey(const Key('tier-a')), findsOneWidget);
      expect(find.byKey(const Key('tier-x')), findsNothing);
    });
  });

  group('an event that has ended', () {
    testWidgets('its tickets are shown and nothing can be changed', (tester) async {
      now = DateTime(2031, 12, 12);
      db.seed(id: 'a', name: 'General');
      await open(tester);
      expect(textOf(tester, 'tickets-intro'), 'This event has ended, so its tickets can no longer be changed.');
      expect(find.byKey(const Key('tier-a')), findsOneWidget);
      expect(find.byKey(const Key('add-tier')), findsNothing);
      expect(find.byKey(const Key('edit-tier-a')), findsNothing);
      expect(find.byKey(const Key('remove-tier-a')), findsNothing);
    });

    testWidgets('with no types it says none were set up', (tester) async {
      now = DateTime(2031, 12, 12);
      await open(tester);
      expect(find.text('No ticket types were set up for this event.'), findsOneWidget);
    });
  });

  group('adding a type', () {
    testWidgets('fills in the form, sends it once, comes back to the list with the new type and says it was added', (tester) async {
      await open(tester);
      await tapKey(tester, 'add-tier');
      expect(find.byKey(const Key('save-tier')), findsOneWidget);
      expect(find.byKey(const Key('locked-note')), findsNothing);

      await typeKey(tester, 'field-tier-name', '  Early   Bird ');
      await typeKey(tester, 'field-tier-price', '15.5');
      await typeKey(tester, 'field-tier-capacity', '50');
      await tapKey(tester, 'save-tier');

      final save = db.calls.where((c) => c.$1 == 'save_org_tier').single.$2!;
      expect(save['p_org'], 'o1');
      expect(save['p_event'], 'ev1');
      expect(save['p_tier'], isNull);
      expect(save['p_details'], {'name': 'Early Bird', 'price_cents': 1550, 'capacity': 50, 'sale_starts_at': null, 'sale_ends_at': null});
      expect(find.byKey(const Key('save-tier')), findsNothing, reason: 'back on the list');
      expect(find.text('Early Bird'), findsOneWidget);
      expect(find.text('\$15.50'), findsOneWidget);
      expect(find.text('Ticket type added.'), findsOneWidget);
    });

    testWidgets('sale dates are picked, sent as UTC instants, and can be cleared', (tester) async {
      await open(tester);
      await tapKey(tester, 'add-tier');
      await typeKey(tester, 'field-tier-name', 'Early Bird');
      await typeKey(tester, 'field-tier-price', '15');
      await typeKey(tester, 'field-tier-capacity', '50');

      picks = [DateTime(2031, 12, 3, 19), DateTime(2031, 12, 9, 22)];
      await tapKey(tester, 'pick-sale-start');
      await tapKey(tester, 'pick-sale-end');
      expect(find.byKey(const Key('clear-sale-start')), findsOneWidget);
      expect(find.byKey(const Key('clear-sale-end')), findsOneWidget);
      await tapKey(tester, 'clear-sale-start');
      expect(find.byKey(const Key('clear-sale-start')), findsNothing);
      await tapKey(tester, 'clear-sale-end');
      expect(find.byKey(const Key('clear-sale-end')), findsNothing);
      picks = [DateTime(2031, 12, 9, 22)];
      await tapKey(tester, 'pick-sale-end');
      picks = [DateTime(2031, 12, 3, 20)];
      await tapKey(tester, 'pick-sale-start');
      await tapKey(tester, 'save-tier');

      final details = db.calls.where((c) => c.$1 == 'save_org_tier').single.$2!['p_details'] as Map<String, dynamic>;
      expect(details['sale_starts_at'], DateTime(2031, 12, 3, 20).toUtc().toIso8601String());
      expect(details['sale_ends_at'], DateTime(2031, 12, 9, 22).toUtc().toIso8601String());
      expect(details['sale_starts_at'], endsWith('Z'));
    });

    testWidgets('cancelling a picker changes nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'add-tier');
      picks = [null];
      await tapKey(tester, 'pick-sale-start');
      expect(find.byKey(const Key('clear-sale-start')), findsNothing);
    });

    testWidgets('an empty form says everything that is missing and sends nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'add-tier');
      await tapKey(tester, 'save-tier');
      expect(inProblems('Give the ticket type a name.'), findsOneWidget);
      expect(inProblems('Set a price. Use 0 for a free ticket.'), findsOneWidget);
      expect(inProblems('Say how many tickets there are.'), findsOneWidget);
      expect(db.calls.where((c) => c.$1 == 'save_org_tier'), isEmpty);
    });

    testWidgets('a sale end after the event ends is said in the form, with what was typed kept', (tester) async {
      await open(tester);
      await tapKey(tester, 'add-tier');
      await typeKey(tester, 'field-tier-name', 'Early Bird');
      await typeKey(tester, 'field-tier-price', '15');
      await typeKey(tester, 'field-tier-capacity', '50');
      picks = [DateTime(2031, 12, 20)];
      await tapKey(tester, 'pick-sale-end');
      await tapKey(tester, 'save-tier');
      expect(inProblems('Sales cannot end after the event ends.'), findsOneWidget);
      expect(boxOf(tester, 'field-tier-name'), 'Early Bird');
      expect(db.calls.where((c) => c.$1 == 'save_org_tier'), isEmpty);
    });

    testWidgets('the same name as another type is said before anything is sent', (tester) async {
      db.seed(id: 'a', name: 'General');
      await open(tester);
      await tapKey(tester, 'add-tier');
      await typeKey(tester, 'field-tier-name', 'general');
      await typeKey(tester, 'field-tier-price', '15');
      await typeKey(tester, 'field-tier-capacity', '50');
      await tapKey(tester, 'save-tier');
      expect(inProblems('This event already has a ticket type with that name.'), findsOneWidget);
      expect(db.calls.where((c) => c.$1 == 'save_org_tier'), isEmpty, reason: 'said before anything is sent');
    });

    testWidgets('a refusal the form could not know about is shown, and everything typed is still there', (tester) async {
      db.beforeCall = (f) {
        if (f == 'save_org_tier') throw refuseTier('this event has ended, so its tickets can no longer be changed');
      };
      await open(tester);
      await tapKey(tester, 'add-tier');
      await typeKey(tester, 'field-tier-name', 'Early Bird');
      await typeKey(tester, 'field-tier-price', '15');
      await typeKey(tester, 'field-tier-capacity', '50');
      await tapKey(tester, 'save-tier');
      expect(inProblems('This event has ended, so its tickets can no longer be changed.'), findsOneWidget);
      expect([boxOf(tester, 'field-tier-name'), boxOf(tester, 'field-tier-price'), boxOf(tester, 'field-tier-capacity')], ['Early Bird', '15', '50']);
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-tier'))).onPressed, isNotNull, reason: 'they can try again');
    });

    testWidgets('a second tap on Save while it is saving sends nothing more', (tester) async {
      final done = Completer<void>();
      await open(tester);
      await tapKey(tester, 'add-tier');
      await typeKey(tester, 'field-tier-name', 'Early Bird');
      await typeKey(tester, 'field-tier-price', '15');
      await typeKey(tester, 'field-tier-capacity', '50');
      db.hold = done.future; // the database is slow from here on
      await tester.tap(find.byKey(const Key('save-tier')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-tier'))).onPressed, isNull);
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-tier')), warnIfMissed: false);
      await tester.pump();
      expect(db.calls.where((c) => c.$1 == 'save_org_tier').length, 1);
      db.hold = null;
      done.complete();
      await tester.pumpAndSettle();
      expect(find.text('Early Bird'), findsOneWidget);
    });

    testWidgets('twenty types is the most: Add is switched off and says so', (tester) async {
      for (var i = 0; i < 20; i++) {
        db.seed(id: 'x$i', name: 'Type $i', price: 100 + i);
      }
      await open(tester);
      expect(tester.widget<FilledButton>(find.byKey(const Key('add-tier'))).onPressed, isNull);
      expect(textOf(tester, 'tiers-full'), 'An event can have at most 20 ticket types.');
    });

    testWidgets('nineteen types leave room for one more', (tester) async {
      for (var i = 0; i < 19; i++) {
        db.seed(id: 'x$i', name: 'Type $i', price: 100 + i);
      }
      await open(tester);
      expect(tester.widget<FilledButton>(find.byKey(const Key('add-tier'))).onPressed, isNotNull);
      expect(find.byKey(const Key('tiers-full')), findsNothing);
    });
  });

  group('changing a type', () {
    testWidgets('opens with what the type has, saves with its id, and shows the change', (tester) async {
      db.seed(id: 'a', name: 'General', price: 2500, capacity: 100);
      await open(tester);
      await tapKey(tester, 'edit-tier-a');
      expect([boxOf(tester, 'field-tier-name'), boxOf(tester, 'field-tier-price'), boxOf(tester, 'field-tier-capacity')], ['General', '25', '100']);
      expect(find.byKey(const Key('locked-note')), findsNothing);

      await typeKey(tester, 'field-tier-price', '30');
      await tapKey(tester, 'save-tier');
      final save = db.calls.where((c) => c.$1 == 'save_org_tier').single.$2!;
      expect(save['p_tier'], 'a');
      expect((save['p_details'] as Map)['price_cents'], 3000);
      expect(textOf(tester, 'tier-price-a'), '\$30.00');
      expect(find.text('Ticket type saved.'), findsOneWidget);
    });

    testWidgets('a type that has sold has its name and price switched off, says why, and still lets the quantity be raised', (tester) async {
      db.seed(id: 'a', name: 'General', price: 2500, capacity: 100, sold: 40);
      await open(tester);
      await tapKey(tester, 'edit-tier-a');
      expect(find.byKey(const Key('locked-note')), findsOneWidget);
      expect(enabled(tester, 'field-tier-name'), isFalse);
      expect(enabled(tester, 'field-tier-price'), isFalse);
      expect(enabled(tester, 'field-tier-capacity'), isTrue);
      expect(find.text('40 sold so far'), findsOneWidget);

      await typeKey(tester, 'field-tier-capacity', '39');
      await tapKey(tester, 'save-tier');
      expect(inProblems('The quantity cannot be lower than the 40 tickets already sold.'), findsOneWidget);
      expect(db.calls.where((c) => c.$1 == 'save_org_tier'), isEmpty);

      await typeKey(tester, 'field-tier-capacity', '250');
      await tapKey(tester, 'save-tier');
      final details = db.calls.where((c) => c.$1 == 'save_org_tier').single.$2!['p_details'] as Map;
      expect([details['name'], details['price_cents'], details['capacity']], ['General', 2500, 250], reason: 'the name and price go back unchanged');
      expect(textOf(tester, 'tier-sold-a'), '40 of 250 sold · 210 left');
    });

    testWidgets('a type may keep its own name', (tester) async {
      db.seed(id: 'a', name: 'General');
      db.seed(id: 'b', name: 'VIP', price: 9000);
      await open(tester);
      await tapKey(tester, 'edit-tier-a');
      await typeKey(tester, 'field-tier-capacity', '120');
      await tapKey(tester, 'save-tier');
      expect(inProblems('This event already has a ticket type with that name.'), findsNothing);
      expect(textOf(tester, 'tier-sold-a'), '0 of 120 sold · 120 left');
    });

    testWidgets('a type\'s sales can be stopped by giving it an end time', (tester) async {
      db.seed(id: 'a', name: 'General', hasOrders: true);
      await open(tester);
      await tapKey(tester, 'edit-tier-a');
      picks = [DateTime(2031, 12, 2, 12)];
      await tapKey(tester, 'pick-sale-end');
      await tapKey(tester, 'save-tier');
      expect(textOf(tester, 'tier-sales-a'), startsWith('On sale until '));
    });
  });

  group('removing a type', () {
    testWidgets('asks first; Keep it removes nothing', (tester) async {
      db.seed(id: 'a', name: 'General');
      await open(tester);
      await tapKey(tester, 'remove-tier-a');
      expect(find.text('Remove General?'), findsOneWidget);
      await tapKey(tester, 'keep');
      expect(db.calls.where((c) => c.$1 == 'remove_org_tier'), isEmpty);
      expect(find.byKey(const Key('tier-a')), findsOneWidget);
    });

    testWidgets('confirming removes it once, the list updates, and it says so', (tester) async {
      db.seed(id: 'a', name: 'General');
      db.seed(id: 'b', name: 'VIP', price: 9000);
      await open(tester);
      await tapKey(tester, 'remove-tier-a');
      await tapKey(tester, 'confirm-remove');
      expect(db.calls.where((c) => c.$1 == 'remove_org_tier').length, 1);
      expect(db.calls.where((c) => c.$1 == 'remove_org_tier').single.$2, {'p_org': 'o1', 'p_tier': 'a'});
      expect(find.byKey(const Key('tier-a')), findsNothing);
      expect(find.byKey(const Key('tier-b')), findsOneWidget);
      expect(find.text('Ticket type removed.'), findsOneWidget);
    });

    testWidgets('a refusal from the database is said, and the type stays', (tester) async {
      db.seed(id: 'a', name: 'General');
      db.beforeCall = (f) {
        if (f == 'remove_org_tier') throw refuseTier('people have bought or started to buy this ticket type, so it cannot be removed. Set its sales to end now instead');
      };
      await open(tester);
      await tapKey(tester, 'remove-tier-a');
      await tapKey(tester, 'confirm-remove');
      expect(find.textContaining('People have bought or started to buy this ticket type'), findsOneWidget);
      expect(find.byKey(const Key('tier-a')), findsOneWidget);
    });
  });

  group('when the list cannot be loaded', () {
    testWidgets('says so with a way to try again, and tries again', (tester) async {
      db.failAll = StateError('socket closed');
      await open(tester);
      expect(textOf(tester, 'tickets-error'), 'The ticket types could not be loaded. Check your connection and try again.');
      expect(find.textContaining('socket'), findsNothing, reason: 'never the technical text');
      db.failAll = null;
      db.seed(id: 'a', name: 'General');
      await tapKey(tester, 'tickets-retry');
      expect(find.byKey(const Key('tier-a')), findsOneWidget);
    });

    testWidgets('a server without tickets says it is not set up, with no retry', (tester) async {
      db.failAll = const PostgrestException(message: 'function public.list_org_tiers does not exist', code: '42883');
      await open(tester);
      expect(textOf(tester, 'tickets-error'), 'Tickets are not set up on this server yet.');
      expect(find.byKey(const Key('tickets-retry')), findsNothing);
    });

    testWidgets('an ended access is said as such', (tester) async {
      db.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
      await open(tester);
      expect(textOf(tester, 'tickets-error'), contains('access has ended'));
    });
  });

  group('from the events list', () {
    Widget eventsHost() => ProviderScope(
          key: UniqueKey(),
          overrides: [
            organizerTiersServiceProvider.overrideWithValue(db.service),
            organizerEventsServiceProvider.overrideWithValue(eventsDb.service),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(body: OrganizerEventsScreen(workspace: orgWs, clock: () => DateTime(2031, 10, 24, 12), pickDateTime: (c, i) async => null)),
          ),
        );

    Future<void> openEvents(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(eventsHost());
      await tester.pumpAndSettle();
    }

    testWidgets('every event card has a Tickets button and says how many types it has', (tester) async {
      eventsDb.events.addAll([
        {...eventRow('d', 'Rooftop Sessions', start: '2031-11-01T22:00:00Z'), 'ticket_tier_count': 2},
        {...eventRow('p', 'Summer Closing', status: 'published', start: '2031-12-30T22:00:00Z'), 'ticket_tier_count': 1},
        eventRow('n', 'Empty Night', start: '2031-11-05T22:00:00Z'),
      ]);
      await openEvents(tester);
      expect(find.byKey(const Key('tickets-d')), findsOneWidget);
      expect(find.byKey(const Key('tickets-p')), findsOneWidget, reason: 'a published event has tickets too');
      expect(find.byKey(const Key('edit-p')), findsNothing, reason: 'but it is still not editable');
      expect(textOf(tester, 'tiers-count-d'), '2 ticket types');
      expect(textOf(tester, 'tiers-count-p'), '1 ticket type');
      expect(textOf(tester, 'tiers-count-n'), 'No ticket types yet');
    });

    testWidgets('Tickets opens that event\'s ticket types, and coming back reads the events again', (tester) async {
      eventsDb.events.add(eventRow('d', 'Rooftop Sessions', start: '2031-11-01T22:00:00Z'));
      db.seed(id: 'a', event: 'd', name: 'General');
      await openEvents(tester);
      final before = eventsDb.calls.where((c) => c.$1 == 'list_org_events').length;
      await tester.ensureVisible(find.byKey(const Key('tickets-d')));
      await tester.tap(find.byKey(const Key('tickets-d')));
      await tester.pumpAndSettle();
      expect(find.text('Tickets: Rooftop Sessions'), findsOneWidget);
      expect(find.byKey(const Key('tier-a')), findsOneWidget);
      expect(db.calls.first.$2, {'p_org': 'o1', 'p_event': 'd'});

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(eventsDb.calls.where((c) => c.$1 == 'list_org_events').length, greaterThan(before));
    });

    testWidgets('the screen no longer promises that BottlesUp sets up the tickets', (tester) async {
      await openEvents(tester);
      expect(find.textContaining('sets up tickets'), findsNothing);
      expect(find.textContaining('Add tickets to an event from its card'), findsOneWidget);
    });
  });
}
