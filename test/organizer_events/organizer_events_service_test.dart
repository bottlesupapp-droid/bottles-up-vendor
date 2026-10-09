import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:bottles_up_vendor/features/organizer_events/providers/organizer_events_providers.dart';
import 'package:bottles_up_vendor/features/organizer_events/services/organizer_events_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_organizer_events_backend.dart';

Matcher refusal(String message) => throwsA(isA<OrganizerEventsActionException>().having((e) => e.message, 'message', message));

EventForm good({DateTime? starts, DateTime? ends}) =>
    EventForm(title: 'Party', description: 'Fun', venueName: 'The Roof', starts: starts ?? DateTime(2031, 10, 24, 22), ends: ends);

void main() {
  late FakeOrganizerEventsBackend db;
  setUp(() => db = FakeOrganizerEventsBackend());

  group('reading', () {
    test('the events of one business, dropping rows it cannot read', () async {
      db.events.addAll([eventRow('e1', 'Party'), {'title': 'no id', 'start_date': '2031-10-24T22:00:00Z'}, eventRow('e3', 'Live', status: 'published')]);
      final list = await db.service.events('o1');
      expect(list.map((e) => [e.eventId, e.isDraft]), [['e1', true], ['e3', false]]);
      expect(db.paramsOf('list_org_events'), [
        {'p_org': 'o1'},
      ]);
    });

    test('an answer that is not a list is nothing, never a crash', () async {
      final odd = OrganizerEventsService(rpc: (f, {params}) async => 'nonsense');
      expect(await odd.events('o1'), isEmpty);
    });

    test('a failure says what is wrong', () async {
      Matcher failure({bool unavailable = false, bool accessEnded = false}) => throwsA(isA<OrganizerEventsLoadException>()
          .having((e) => e.unavailable, 'unavailable', unavailable)
          .having((e) => e.accessEnded, 'accessEnded', accessEnded));
      db.failAll = const PostgrestException(message: 'no function', code: '42883');
      await expectLater(db.service.events('o1'), failure(unavailable: true));
      db.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
      await expectLater(db.service.events('o1'), failure(accessEnded: true));
      db.failAll = Exception('socket closed');
      await expectLater(db.service.events('o1'), failure());
    });

    test('the load messages', () {
      expect(const OrganizerEventsLoadException(unavailable: true, accessEnded: false).message, 'Events are not set up on this server yet.');
      expect(const OrganizerEventsLoadException(unavailable: false, accessEnded: true).message, 'Your access has ended, or you are signed out.');
      expect(const OrganizerEventsLoadException(unavailable: false, accessEnded: false).message, startsWith('Your events could not be loaded'));
    });
  });

  group('saving', () {
    test('adding sends no event id and exactly the form\'s payload, and returns the new id', () async {
      final id = await db.service.save('o1', null, eventPayload(good()));
      final call = db.paramsOf('save_org_event').single!;
      expect([call['p_org'], call['p_event']], ['o1', null]);
      expect((call['p_details'] as Map).keys.toSet(), eventPayload(good()).keys.toSet());
      expect(db.events.single['event_id'], id);
      expect(db.events.single['status'], 'draft');
    });

    test('changing a draft names it, and leaves its cover photo alone because the photo is never sent', () async {
      db.events.add(eventRow('e1', 'Party', cover: 'https://img.example/a.jpg'));
      final form = eventFormFrom((await db.service.events('o1')).single);
      await db.service.save('o1', 'e1', eventPayload(EventForm(title: 'Renamed', description: form.description, venueName: form.venueName, starts: form.starts)));
      expect(db.events.single['title'], 'Renamed');
      expect(db.events.single['cover_image_url'], 'https://img.example/a.jpg');
      expect((db.paramsOf('save_org_event').single!['p_details'] as Map).containsKey('cover_image_url'), isFalse);
    });

    test('a field the database does not know is refused (this is what the drift guard protects)', () async {
      await expectLater(db.service.save('o1', null, {'title': 'x', 'status': 'published'}), refusal('Unknown field: status.'));
      expect(db.events, isEmpty);
    });

    test('a published event cannot be changed, and the sentence says who can', () async {
      db.events.add(eventRow('e1', 'Live', status: 'published'));
      await expectLater(db.service.save('o1', 'e1', {'title': 'x'}), refusal('This event is published, so only BottlesUp can change it.'));
      expect(db.events.single['title'], 'Live');
    });

    test('an event that is not this business\'s is not found', () async {
      await expectLater(db.service.save('o1', 'nope', {'title': 'x'}), refusal('Event not found.'));
    });

    test('the 200 event limit is the database\'s sentence', () async {
      db.events.addAll([for (var i = 0; i < 200; i++) eventRow('e$i', 'Filler $i')]);
      await expectLater(db.service.save('o1', null, eventPayload(good())), refusal('A business can have 200 events at most.'));
    });

    test('an answer that is not an id is a failure, not a success', () async {
      for (final answer in [null, '', 7]) {
        final odd = OrganizerEventsService(rpc: (f, {params}) async => answer);
        await expectLater(odd.save('o1', null, {}), refusal('The event could not be saved. Try again.'), reason: '$answer');
      }
    });

    test('losing access is said in the person\'s words; a dropped connection is a generic sentence', () async {
      db.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
      await expectLater(db.service.save('o1', null, {}), refusal("You don't have access to do that."));
      db.failAll = Exception('socket closed');
      await expectLater(db.service.save('o1', null, {}), refusal('This could not be saved. Check your connection and try again.'));
    });
  });

  group('removing', () {
    test('a draft goes; the call names the business and the event', () async {
      db.events.add(eventRow('e1', 'Party'));
      await db.service.remove('o1', 'e1');
      expect(db.events, isEmpty);
      expect(db.paramsOf('remove_org_event'), [
        {'p_org': 'o1', 'p_event': 'e1'},
      ]);
    });

    test('a published event, or a draft that already has an order, stays, with the database\'s sentence', () async {
      db.events.addAll([eventRow('e1', 'Live', status: 'published'), {...eventRow('e2', 'Sold'), 'has_orders': true}]);
      await expectLater(db.service.remove('o1', 'e1'), refusal('This event is published, so only BottlesUp can remove it.'));
      await expectLater(db.service.remove('o1', 'e2'), refusal('This event already has orders, so it cannot be removed.'));
      expect(db.events, hasLength(2));
    });

    test('a dropped connection says so plainly', () async {
      db.failAll = Exception('socket closed');
      await expectLater(db.service.remove('o1', 'e1'), refusal('This could not be removed. Try again.'));
    });
  });

  group('the form\'s Save', () {
    test('a form with problems sends nothing and says what is wrong', () async {
      final out = await submitEventForm(const EventForm(), 'o1', null, db.service);
      expect(out.ok, isFalse);
      expect(out.problems, contains('Give the event a title.'));
      expect(db.calls, isEmpty);
    });

    test('a new event is sent for this business with no event id; a change names the event', () async {
      expect((await submitEventForm(good(), 'o1', null, db.service)).ok, isTrue);
      expect(db.paramsOf('save_org_event').single!['p_event'], isNull);
      final id = db.events.single['event_id'] as String;
      await submitEventForm(good(), 'o1', id, db.service);
      expect(db.paramsOf('save_org_event').last!['p_event'], id);
    });

    test('a refusal is a sentence for the form, so nothing typed is lost', () async {
      db.events.add(eventRow('e1', 'Live', status: 'published'));
      final out = await submitEventForm(good(), 'o1', 'e1', db.service);
      expect([out.ok, out.problems], [false, ['This event is published, so only BottlesUp can change it.']]);
    });

    test('what is sent can never publish', () async {
      await submitEventForm(good(), 'o1', null, db.service);
      final keys = (db.paramsOf('save_org_event').single!['p_details'] as Map).keys;
      for (final k in ['status', 'org_id', 'slug', 'cover_image_url']) {
        expect(keys, isNot(contains(k)));
      }
    });
  });

  // A stale list of events is worse than a slow one: nothing is kept once the screen that asked for it is gone.
  test('the list is read again, never kept', () async {
    final container = ProviderContainer(overrides: [organizerEventsServiceProvider.overrideWithValue(db.service)]);
    addTearDown(container.dispose);
    final sub = container.listen(organizerEventsProvider('o1'), (_, __) {});
    await container.read(organizerEventsProvider('o1').future);
    sub.close();
    await Future<void>.delayed(Duration.zero);
    db.events.add(eventRow('e1', 'Party'));
    expect((await container.read(organizerEventsProvider('o1').future)).length, 1);
  });
}
