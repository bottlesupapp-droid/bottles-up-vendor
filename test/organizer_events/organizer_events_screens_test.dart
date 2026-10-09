import 'dart:async';

import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/organizer_events/screens/organizer_events_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_organizer_events_backend.dart';

late FakeOrganizerEventsBackend db;
late List<DateTime?> picks;

const orgWs = Workspace(membershipId: 'm-g', orgId: 'o1', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);
final fixedNow = DateTime(2031, 10, 24, 12);

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [organizerEventsServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: OrganizerEventsScreen(workspace: orgWs, clock: () => fixedNow, pickDateTime: (context, initial) async => picks.isEmpty ? null : picks.removeAt(0)),
        ),
      ),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> typeKey(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String textOf(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
Finder inProblems(String text) => find.descendant(of: find.byKey(const Key('problems')), matching: find.text(text));

Future<void> fillRequired(WidgetTester tester, {String title = 'Midnight Social'}) async {
  await typeKey(tester, 'field-title', title);
  await typeKey(tester, 'field-description', 'An all-night social.');
  await typeKey(tester, 'field-venue', 'Eonics Lounge');
  picks = [DateTime(2031, 11, 20, 22)];
  await tapKey(tester, 'pick-start');
}

void main() {
  setUp(() {
    db = FakeOrganizerEventsBackend();
    picks = [];
  });

  group('the list', () {
    testWidgets('says plainly when there are no events, and offers to create one', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('no-events')), findsOneWidget);
      expect(find.byKey(const Key('create-event')), findsOneWidget);
      expect(find.textContaining('private draft'), findsWidgets);
    });

    testWidgets('groups drafts, upcoming and past, each only when it has something, and shows what a guest would see', (tester) async {
      db.events.addAll([
        eventRow('d', 'Rooftop Sessions', address: '1 King St W', capacity: 250, start: '2031-11-01T22:00:00Z', end: '2031-11-02T03:00:00Z'),
        eventRow('p', 'Summer Closing', status: 'published', start: '2031-12-30T22:00:00Z', venue: 'Harbour Club'),
        eventRow('x', 'Launch Night', status: 'published', start: '2031-06-01T22:00:00Z', end: '2031-06-02T04:00:00Z'),
      ]);
      await open(tester);
      expect(find.text('DRAFTS'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('PAST'), findsOneWidget);
      final y = [for (final t in ['DRAFTS', 'UPCOMING', 'PAST']) tester.getTopLeft(find.text(t)).dy];
      expect(y, [...y]..sort());
      final draft = find.byKey(const Key('event-d'));
      expect(find.descendant(of: draft, matching: find.text('The Roof, 1 King St W')), findsOneWidget);
      expect(find.descendant(of: draft, matching: find.text('Capacity 250')), findsOneWidget);
      expect(find.descendant(of: draft, matching: find.text('Draft')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-p')), matching: find.text('Published')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-p')), matching: find.text('Draft')), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('event-x')), matching: find.text('Published')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-p')), matching: find.text('Harbour Club')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-p')), matching: find.textContaining('Capacity')), findsNothing);
    });

    testWidgets('only a draft can be changed or removed; a published event says who to ask', (tester) async {
      db.events.addAll([eventRow('d', 'Draft party'), eventRow('p', 'Live night', status: 'published')]);
      await open(tester);
      expect(find.byKey(const Key('edit-d')), findsOneWidget);
      expect(find.byKey(const Key('remove-d')), findsOneWidget);
      expect(find.byKey(const Key('edit-p')), findsNothing);
      expect(find.byKey(const Key('remove-p')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('note-d'))).data, contains('Only you can see this'));
      expect(tester.widget<Text>(find.byKey(const Key('note-p'))).data, contains('Contact BottlesUp'));
    });

    testWidgets('an event with an unknown status is treated as published: no editing', (tester) async {
      db.events.add(eventRow('u', 'Odd one', status: 'cancelled'));
      await open(tester);
      expect(find.byKey(const Key('edit-u')), findsNothing);
      expect(find.byKey(const Key('remove-u')), findsNothing);
    });

    testWidgets('a server without the migration says so, with no retry; a dropped connection offers one that works', (tester) async {
      db.failAll = const PostgrestException(message: 'no function', code: '42883');
      await open(tester);
      expect(find.text('Events are not set up on this server yet.'), findsOneWidget);
      expect(find.byKey(const Key('events-retry')), findsNothing);
      db.failAll = Exception('socket closed');
      await open(tester);
      expect(find.byKey(const Key('events-retry')), findsOneWidget);
      db.failAll = null;
      db.events.add(eventRow('d', 'Back again'));
      await tapKey(tester, 'events-retry');
      expect(find.text('Back again'), findsOneWidget);
    });
  });

  group('creating an event', () {
    testWidgets('an empty form says what is missing and sends nothing', (tester) async {
      await open(tester);
      await tapKey(tester, 'create-event');
      await tapKey(tester, 'save-event');
      expect(inProblems('Give the event a title.'), findsOneWidget);
      expect(inProblems('Choose when it starts.'), findsOneWidget);
      expect(db.count('save_org_event'), 0);
    });

    testWidgets('a draft is created with the form\'s payload, the list shows it, and the person is told it stays private', (tester) async {
      await open(tester);
      await tapKey(tester, 'create-event');
      await fillRequired(tester);
      await typeKey(tester, 'field-address', ' 5 Queen St ');
      await typeKey(tester, 'field-capacity', '180');
      await tapKey(tester, 'save-event');
      final call = db.paramsOf('save_org_event').single!;
      expect([call['p_org'], call['p_event']], ['o1', null]);
      final d = call['p_details'] as Map;
      expect([d['title'], d['venue_name'], d['address'], d['capacity'], d['category']], ['Midnight Social', 'Eonics Lounge', '5 Queen St', 180, null]);
      expect(DateTime.parse(d['start_date'] as String).isAtSameMomentAs(DateTime(2031, 11, 20, 22)), isTrue);
      for (final k in ['status', 'org_id', 'slug', 'cover_image_url']) {
        expect(d.containsKey(k), isFalse, reason: k);
      }
      expect(find.text('Midnight Social'), findsOneWidget);
      expect(find.byKey(const Key('event-${'e1'}')), findsOneWidget);
      expect(find.textContaining('Draft created. It stays private until the BottlesUp team publishes it.'), findsOneWidget);
    });

    testWidgets('Create event opens an empty form even when events already exist, and saves a new one rather than changing one', (tester) async {
      db.events.add(eventRow('d', 'Existing draft'));
      await open(tester);
      await tapKey(tester, 'create-event');
      expect(find.text('Create event'), findsWidgets);
      expect(textOf(tester, 'field-title'), isEmpty);
      await fillRequired(tester, title: 'Brand new');
      await typeKey(tester, 'field-category', ' Club night ');
      await tapKey(tester, 'save-event');
      final call = db.paramsOf('save_org_event').single!;
      expect(call['p_event'], isNull);
      expect((call['p_details'] as Map)['category'], 'Club night');
      expect(db.events.map((e) => e['title']), containsAll(['Existing draft', 'Brand new']));
    });

    testWidgets('cancelling the picker changes nothing; an end before the start is refused; the end can be removed', (tester) async {
      await open(tester);
      await tapKey(tester, 'create-event');
      await fillRequired(tester);
      picks = [null];
      await tapKey(tester, 'pick-end');
      expect(find.text('Choose when it ends'), findsOneWidget);
      picks = [DateTime(2031, 11, 20, 21)];
      await tapKey(tester, 'pick-end');
      await tapKey(tester, 'save-event');
      expect(inProblems('The end must be after the start.'), findsOneWidget);
      expect(db.count('save_org_event'), 0);
      await tapKey(tester, 'clear-end');
      expect(find.text('Choose when it ends'), findsOneWidget);
      await tapKey(tester, 'save-event');
      expect((db.paramsOf('save_org_event').single!['p_details'] as Map)['end_date'], isNull);
    });

    testWidgets('an end is sent with the start', (tester) async {
      await open(tester);
      await tapKey(tester, 'create-event');
      await fillRequired(tester);
      picks = [DateTime(2031, 11, 21, 4)];
      await tapKey(tester, 'pick-end');
      await tapKey(tester, 'save-event');
      final d = db.paramsOf('save_org_event').single!['p_details'] as Map;
      expect(DateTime.parse(d['end_date'] as String).isAtSameMomentAs(DateTime(2031, 11, 21, 4)), isTrue);
    });

    testWidgets('a refusal from the database is shown in the form and nothing typed is lost', (tester) async {
      await open(tester);
      await tapKey(tester, 'create-event');
      await fillRequired(tester);
      db.beforeCall = (f) {
        if (f == 'save_org_event') throw const PostgrestException(message: 'a business can have 200 events at most', code: 'P0001');
      };
      await tapKey(tester, 'save-event');
      expect(inProblems('A business can have 200 events at most.'), findsOneWidget);
      expect(textOf(tester, 'field-title'), 'Midnight Social');
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-event'))).onPressed, isNotNull);
    });

    testWidgets('a second tap on Save while the first is still going does not save twice', (tester) async {
      await open(tester);
      await tapKey(tester, 'create-event');
      await fillRequired(tester);
      final gate = Completer<void>();
      db.hold = gate.future;
      await tester.tap(find.byKey(const Key('save-event')));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-event')), warnIfMissed: false);
      gate.complete();
      await tester.pumpAndSettle();
      expect(db.count('save_org_event'), 1);
    });

    testWidgets('the form asks for what the database takes, says which zone the times are in, and offers no status or tickets', (tester) async {
      await open(tester);
      await tapKey(tester, 'create-event');
      for (final k in ['field-title', 'field-description', 'field-venue', 'field-address', 'pick-start', 'pick-end', 'field-category', 'field-capacity']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const Key('zone-note')), findsOneWidget);
      for (final forbidden in ['Status', 'Publish', 'Ticket price', 'Slug']) {
        expect(find.text(forbidden), findsNothing, reason: forbidden);
      }
    });
  });

  group('changing a draft', () {
    testWidgets('opens with what is saved, changes it, and leaves the cover photo alone', (tester) async {
      db.events.add(eventRow('d', 'Rooftop Sessions', address: '1 King St W', capacity: 250, category: 'Club night', cover: 'https://img.example/a.jpg', end: '2031-11-02T03:00:00Z'));
      await open(tester);
      await tapKey(tester, 'edit-d');
      expect([textOf(tester, 'field-title'), textOf(tester, 'field-venue'), textOf(tester, 'field-address'), textOf(tester, 'field-capacity'), textOf(tester, 'field-category')],
          ['Rooftop Sessions', 'The Roof', '1 King St W', '250', 'Club night']);
      expect(find.text('Edit Rooftop Sessions'), findsOneWidget);
      await typeKey(tester, 'field-title', 'Rooftop Sessions II');
      await tapKey(tester, 'save-event');
      expect(db.paramsOf('save_org_event').single!['p_event'], 'd');
      expect(db.events.single['title'], 'Rooftop Sessions II');
      expect(db.events.single['cover_image_url'], 'https://img.example/a.jpg');
      expect(find.text('Draft saved.'), findsOneWidget);
      expect(find.text('Rooftop Sessions II'), findsOneWidget);
    });

    testWidgets('saving it without a change sends the same instants back', (tester) async {
      db.events.add(eventRow('d', 'Party', start: '2031-11-01T22:00:00Z', end: '2031-11-02T03:00:00Z'));
      await open(tester);
      await tapKey(tester, 'edit-d');
      await tapKey(tester, 'save-event');
      final d = db.paramsOf('save_org_event').single!['p_details'] as Map;
      expect(DateTime.parse(d['start_date'] as String), DateTime.utc(2031, 11, 1, 22));
      expect(DateTime.parse(d['end_date'] as String), DateTime.utc(2031, 11, 2, 3));
    });

    testWidgets('an event published since the list was read is refused in the database\'s words, in the form', (tester) async {
      db.events.add(eventRow('d', 'Party'));
      await open(tester);
      db.events[0] = {...db.events[0], 'status': 'published'};
      await tapKey(tester, 'edit-d');
      await tapKey(tester, 'save-event');
      expect(inProblems('This event is published, so only BottlesUp can change it.'), findsOneWidget);
    });
  });

  group('removing a draft', () {
    testWidgets('keeping at the confirmation changes nothing; confirming removes it', (tester) async {
      db.events.add(eventRow('d', 'Party'));
      await open(tester);
      await tapKey(tester, 'remove-d');
      expect(find.text('Remove Party?'), findsOneWidget);
      await tapKey(tester, 'keep');
      expect(db.count('remove_org_event'), 0);
      await tapKey(tester, 'remove-d');
      await tapKey(tester, 'confirm-remove');
      expect(db.paramsOf('remove_org_event'), [
        {'p_org': 'o1', 'p_event': 'd'},
      ]);
      expect(find.byKey(const Key('event-d')), findsNothing);
      expect(find.text('Event removed.'), findsOneWidget);
      expect(find.byKey(const Key('no-events')), findsOneWidget);
    });

    testWidgets('dismissing the confirmation by tapping outside it removes nothing', (tester) async {
      db.events.add(eventRow('d', 'Party'));
      await open(tester);
      await tapKey(tester, 'remove-d');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(db.count('remove_org_event'), 0);
      expect(find.byKey(const Key('event-d')), findsOneWidget);
    });

    testWidgets('a removal the database refuses is said in its words, and the event stays', (tester) async {
      db.events.add({...eventRow('d', 'Party'), 'has_orders': true});
      await open(tester);
      await tapKey(tester, 'remove-d');
      await tapKey(tester, 'confirm-remove');
      expect(find.text('This event already has orders, so it cannot be removed.'), findsOneWidget);
      expect(find.byKey(const Key('event-d')), findsOneWidget);
    });
  });
}
