import 'dart:io';

import 'package:bottles_up_vendor/features/organizer_events/logic/organizer_events_rules.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2031, 10, 24, 12);

OrgEvent ev({String id = 'e1', OrgEventStatus status = OrgEventStatus.draft, String? start, String? end, String? address = '1 King St W', int? capacity = 250, String? cover}) => OrgEvent(
      eventId: id, title: 'Rooftop Party', description: 'Dancing', venueName: 'The Roof', address: address,
      startDate: DateTime.parse(start ?? '2031-10-24T22:00:00Z'), endDate: end == null ? null : DateTime.parse(end), category: 'Party', capacity: capacity,
      coverImageUrl: cover, status: status,
    );

EventForm good({String? title, String? description, String? venue, String? address, DateTime? starts, DateTime? ends, String? category, String? capacity}) => EventForm(
      title: title ?? 'Party', description: description ?? 'Fun', venueName: venue ?? 'The Roof', address: address ?? '', starts: starts ?? DateTime(2031, 10, 24, 22),
      ends: ends, category: category ?? '', capacity: capacity ?? '',
    );

List<String> problemsOf(EventForm f) => validateEventForm(f);

void main() {
  group('reading a list_org_events row', () {
    final row = {
      'event_id': 'e1', 'title': 'Rooftop Party', 'description': 'Dancing', 'venue_name': 'The Roof', 'address': '1 King St W', 'start_date': '2031-10-24T22:00:00+00:00',
      'end_date': null, 'category': 'Party', 'capacity': 250, 'cover_image_url': 'https://img.example/a.jpg', 'status': 'draft', 'ticket_tier_count': 2,
    };

    test('keeps what it needs', () {
      final e = parseOrgEvent(row)!;
      expect([e.eventId, e.title, e.description, e.venueName, e.address, e.category, e.capacity, e.coverImageUrl, e.status, e.ticketTierCount],
          ['e1', 'Rooftop Party', 'Dancing', 'The Roof', '1 King St W', 'Party', 250, 'https://img.example/a.jpg', OrgEventStatus.draft, 2]);
      expect(e.startDate, DateTime.utc(2031, 10, 24, 22));
      expect(e.endDate, isNull);
    });

    test('drops a row with no id, no title or no readable start', () {
      for (final key in ['event_id', 'title', 'start_date']) {
        expect(parseOrgEvent({...row, key: null}), isNull, reason: key);
      }
      expect(parseOrgEvent({...row, 'title': ''}), isNull);
      expect(parseOrgEvent({...row, 'start_date': 'soon'}), isNull);
    });

    test('only exactly "draft" is a draft: an unknown status must never unlock editing or removing', () {
      expect(parseOrgEvent({...row, 'status': 'draft'})!.isDraft, isTrue);
      for (final s in ['published', 'cancelled', 'DRAFT', '', null, 3]) {
        expect(parseOrgEvent({...row, 'status': s})!.isDraft, isFalse, reason: '$s');
      }
    });

    test('is forgiving about the optional parts', () {
      final e = parseOrgEvent({'event_id': 'e1', 'title': 't', 'start_date': '2031-10-24T22:00:00Z', 'capacity': 1.5, 'ticket_tier_count': 'x', 'description': null, 'venue_name': null})!;
      expect([e.capacity, e.ticketTierCount, e.description, e.venueName, e.address, e.endDate], [null, 0, '', '', null, null]);
      expect(parseOrgEvent({...row, 'capacity': 100.0})!.capacity, 100);
    });
  });

  group('the form', () {
    test('a new form needs a title, a description, a venue and a start, and says so', () {
      expect(problemsOf(const EventForm()), [
        'Give the event a title.',
        'Describe the event for your guests.',
        'Say where it is held: the venue or place name.',
        'Choose when it starts.',
      ]);
    });

    test('the smallest valid form needs nothing else', () => expect(problemsOf(good()), isEmpty));

    test('every refusal, in the website\'s words', () {
      final start = DateTime(2031, 10, 24, 22);
      for (final (form, message) in [
        (good(title: '   '), 'Give the event a title.'),
        (good(title: 'x' * 121), 'The title must be 120 characters or fewer.'),
        (good(description: ' '), 'Describe the event for your guests.'),
        (good(description: 'x' * 5001), 'The description must be 5000 characters or fewer.'),
        (good(venue: ''), 'Say where it is held: the venue or place name.'),
        (good(venue: 'x' * 121), 'The venue name must be 120 characters or fewer.'),
        (good(address: 'x' * 201), 'The address must be 200 characters or fewer.'),
        (good(category: 'x' * 41), 'The category must be 40 characters or fewer.'),
        (good(ends: start.subtract(const Duration(hours: 1))), 'The end must be after the start.'),
        (good(ends: start), 'The end must be after the start.'),
        (good(capacity: '-1'), 'Capacity must be a whole number from 0 to 100000, or left empty.'),
        (good(capacity: '1.5'), 'Capacity must be a whole number from 0 to 100000, or left empty.'),
        (good(capacity: 'lots'), 'Capacity must be a whole number from 0 to 100000, or left empty.'),
        (good(capacity: '100001'), 'Capacity must be a whole number from 0 to 100000, or left empty.'),
      ]) {
        expect(problemsOf(form), contains(message), reason: message);
      }
    });

    test('the limits are inclusive', () {
      expect(problemsOf(good(title: 'x' * 120, description: 'x' * 5000, venue: 'x' * 120, address: 'x' * 200, category: 'x' * 40)), isEmpty);
      expect(problemsOf(good(capacity: '0')), isEmpty);
      expect(problemsOf(good(capacity: '100000')), isEmpty);
      expect(problemsOf(good(capacity: ' 250 ')), isEmpty);
      expect(problemsOf(good(ends: DateTime(2031, 10, 24, 22, 1))), isEmpty);
    });

    test('an end is not checked against a start that is missing (one problem at a time)', () {
      expect(problemsOf(const EventForm(title: 't', description: 'd', venueName: 'v', ends: null)), ['Choose when it starts.']);
      expect(problemsOf(EventForm(title: 't', description: 'd', venueName: 'v', ends: DateTime(2031))), ['Choose when it starts.']);
    });
  });

  group('what is sent', () {
    test('the smallest form: required fields, everything optional empty as "none"', () {
      final start = DateTime(2031, 10, 24, 22);
      expect(eventPayload(good(starts: start)), {
        'title': 'Party', 'description': 'Fun', 'venue_name': 'The Roof', 'address': null, 'start_date': start.toUtc().toIso8601String(), 'end_date': null,
        'category': null, 'capacity': null,
      });
    });

    test('text is trimmed and a blank optional field is sent as null so it can be cleared', () {
      final p = eventPayload(good(title: '  Party ', address: '   ', category: ' Club night ', capacity: ' 120 '));
      expect([p['title'], p['address'], p['category'], p['capacity']], ['Party', null, 'Club night', 120]);
    });

    test('times go as UTC instants, which carry their time zone', () {
      final p = eventPayload(good(starts: DateTime(2031, 10, 24, 22), ends: DateTime(2031, 10, 25, 4)));
      expect(p['start_date'], endsWith('Z'));
      expect(p['end_date'], endsWith('Z'));
      expect(DateTime.parse(p['start_date'] as String).isAtSameMomentAs(DateTime(2031, 10, 24, 22)), isTrue);
    });

    test('never carries a status, a business, a slug, an organizer block, or the cover photo', () {
      final keys = eventPayload(good()).keys;
      for (final forbidden in ['status', 'org_id', 'slug', 'organizer_name', 'organizer_verified', 'venue_id', 'banner_image_url', 'gallery', 'lineup', 'cover_image_url']) {
        expect(keys, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('opening a saved event and saving it unchanged sends the same instants, text and numbers back (no drifting)', () {
      final e = ev(start: '2031-10-24T22:00:00Z', end: '2031-10-25T04:00:00Z', cover: 'https://img.example/a.jpg');
      final form = eventFormFrom(e);
      expect(problemsOf(form), isEmpty);
      final p = eventPayload(form);
      expect(DateTime.parse(p['start_date'] as String), e.startDate);
      expect(DateTime.parse(p['end_date'] as String), e.endDate);
      expect([p['title'], p['description'], p['venue_name'], p['address'], p['category'], p['capacity']], ['Rooftop Party', 'Dancing', 'The Roof', '1 King St W', 'Party', 250]);
    });

    test('an event with nothing optional opens with empty boxes', () {
      final f = eventFormFrom(ev(address: null, capacity: null));
      expect([f.address, f.ends, f.capacity], ['', null, '']);
    });
  });

  group('the list', () {
    final soon = ev(id: 'p1', status: OrgEventStatus.published, start: '2031-10-30T22:00:00Z');
    final later = ev(id: 'p2', status: OrgEventStatus.published, start: '2031-12-30T22:00:00Z');
    final old = ev(id: 'p3', status: OrgEventStatus.published, start: '2031-06-01T22:00:00Z', end: '2031-06-02T04:00:00Z');
    final older = ev(id: 'p4', status: OrgEventStatus.published, start: '2030-06-01T22:00:00Z');
    final draftLate = ev(id: 'd2', start: '2031-12-01T22:00:00Z');
    final draftSoon = ev(id: 'd1', start: '2031-11-01T22:00:00Z');
    final draftPast = ev(id: 'd0', start: '2031-01-01T22:00:00Z');

    test('drafts first (soonest first, even a past one), then upcoming soonest first, then past most recent first', () {
      final g = groupEvents([later, old, draftLate, soon, older, draftPast, draftSoon], now);
      expect(g.drafts.map((e) => e.eventId), ['d0', 'd1', 'd2']);
      expect(g.upcoming.map((e) => e.eventId), ['p1', 'p2']);
      expect(g.past.map((e) => e.eventId), ['p3', 'p4']);
    });

    test('every event is in exactly one group, and the input is not reordered', () {
      final input = [later, old, draftLate, soon];
      final g = groupEvents(input, now);
      expect(g.drafts.length + g.upcoming.length + g.past.length, 4);
      expect(input.map((e) => e.eventId), ['p2', 'p3', 'd2', 'p1']);
    });

    test('an event with no end lasts 12 hours, so an overnight party is not past at midnight; with an end, the end counts', () {
      final party = ev(status: OrgEventStatus.published, start: '2031-10-24T22:00:00Z');
      expect(hasEnded(party, DateTime.utc(2031, 10, 25, 8)), isFalse);
      expect(hasEnded(party, DateTime.utc(2031, 10, 25, 10, 1)), isTrue);
      final ends = ev(status: OrgEventStatus.published, start: '2031-10-24T22:00:00Z', end: '2031-10-25T02:00:00Z');
      expect(hasEnded(ends, DateTime.utc(2031, 10, 25, 1, 59)), isFalse);
      expect(hasEnded(ends, DateTime.utc(2031, 10, 25, 2, 1)), isTrue);
    });

    test('an empty list has empty groups', () {
      final g = groupEvents(const [], now);
      expect([g.drafts, g.upcoming, g.past], [isEmpty, isEmpty, isEmpty]);
    });

    test('says what each status means for the organizer', () {
      expect([OrgEventStatus.draft.label, OrgEventStatus.published.label], ['Draft', 'Published']);
      expect(OrgEventStatus.draft.note, 'Only you can see this. The BottlesUp team publishes it when it is ready.');
      expect(OrgEventStatus.published.note, 'Live on the website. Contact BottlesUp to change it.');
    });
  });

  group('how a time reads', () {
    test('with the day, in the person\'s own time', () {
      expect(formatEventWhen(DateTime(2031, 10, 24, 18), null), 'Fri, Oct 24, 2031, 6:00 PM');
    });

    test('a same-evening end shows only a clock time; an end on another day shows the day too', () {
      expect(formatEventWhen(DateTime(2031, 10, 24, 18), DateTime(2031, 10, 24, 22, 30)), 'Fri, Oct 24, 2031, 6:00 PM to 10:30 PM');
      expect(formatEventWhen(DateTime(2031, 10, 24, 18), DateTime(2031, 10, 25, 9)), 'Fri, Oct 24, 2031, 6:00 PM to Sat, Oct 25, 2031, 9:00 AM');
    });

    test('a database message becomes a sentence', () {
      expect(sentence('this event is published, so only BottlesUp can change it'), 'This event is published, so only BottlesUp can change it.');
      expect(sentence('Already a sentence.'), 'Already a sentence.');
      expect(sentence('  title is required  '), 'Title is required.');
      expect(sentence(''), 'Please try again.');
    });
  });

  // The form and the database must agree on which fields exist and how long they may be: the database refuses a key it does not
  // know, so a field added here and forgotten in the SQL would fail for every organizer. These read the website repo's migration and
  // rules when it is checked out next to this app (the monorepo); on their own they are skipped.
  group('agrees with the website', () {
    final sql = File('../bottles-up-website-main/supabase/migrations/20261013100000_organizer_events.sql');
    final ts = File('../bottles-up-website-main/src/lib/organizerEvents.ts');
    const why = 'the website repo (with its organizer events branch) is not checked out next to this app';
    final present = sql.existsSync() && ts.existsSync();

    List<String> allowedKeys() {
      final list = RegExp(r'org_event_only_keys\(p_details,\s*array\[([^\]]*)\]\)').firstMatch(sql.readAsStringSync())?.group(1) ?? '';
      return [for (final m in RegExp(r"'(\w+)'").allMatches(list)) m.group(1)!];
    }

    test('finds the whitelist it compares against (so this cannot pass by checking nothing)', () {
      expect(allowedKeys().length, greaterThan(5));
    }, skip: present ? false : why);

    test('every field the form sends is one the database accepts; the only one it does not send is the cover photo', () {
      final sent = eventPayload(good()).keys.toList();
      final allowed = allowedKeys();
      expect(allowed, containsAll(sent));
      expect(allowed.where((k) => !sent.contains(k)).toSet(), {'cover_image_url'});
    }, skip: present ? false : why);

    test('the limits on the form are the database limits', () {
      final text = sql.readAsStringSync();
      expect(text, contains("'title', 'title', ${EventLimits.title}, true"));
      expect(text, contains("'description', 'description', ${EventLimits.description}, true"));
      expect(text, contains("'venue_name', 'venue name', ${EventLimits.venueName}, true"));
      expect(text, contains("'address', 'address', ${EventLimits.address}, false"));
      expect(text, contains("'category', 'category', ${EventLimits.category}, false"));
      expect(text, contains("'capacity', 'capacity', 0, ${EventLimits.capacityMax}"));
      expect(text, contains('v_n >= ${EventLimits.perBusiness}'));
    }, skip: present ? false : why);

    test('what the database requires on creation is what the form requires', () {
      final required = RegExp(r"org_event_(?:text|time)\(p_details, '(\w+)', '[^']+'(?:, \d+)?, true\)").allMatches(sql.readAsStringSync()).map((m) => m.group(1)!).toSet();
      expect(required, {'title', 'description', 'venue_name', 'start_date'});
    }, skip: present ? false : why);

    test('the function and argument names the service uses are the ones the database defines', () {
      final text = sql.readAsStringSync();
      for (final signature in [
        'list_org_events(p_org uuid)',
        'save_org_event(p_org uuid, p_event uuid, p_details jsonb)',
        'remove_org_event(p_org uuid, p_event uuid)',
      ]) {
        expect(text, contains('create function public.$signature'), reason: signature);
      }
    }, skip: present ? false : why);

    test('the wording of the problems, the statuses and the limits is the website\'s, word for word', () {
      final src = ts.readAsStringSync();
      for (final text in [
        'Give the event a title.', 'Describe the event for your guests.', 'Say where it is held: the venue or place name.', 'Choose when it starts.',
        'The end must be after the start.', 'Only you can see this. The BottlesUp team publishes it when it is ready.',
        'Live on the website. Contact BottlesUp to change it.', "draft: 'Draft'", "published: 'Published'", 'OPEN_ENDED_HOURS = 12',
        "row.status === 'draft' ? 'draft' : 'published'",
      ]) {
        expect(src, contains(text), reason: text);
      }
      for (final limit in ['title: 120', 'description: 5000', 'venueName: 120', 'address: 200', 'category: 40', 'capacityMax: 100000', 'perBusiness: 200']) {
        expect(src, contains(limit), reason: limit);
      }
    }, skip: present ? false : why);

    test('an organizer cannot publish: the database field list has no status, business or slug', () {
      final list = allowedKeys();
      for (final forbidden in ['status', 'org_id', 'slug', 'organizer_name', 'organizer_verified', 'venue_id']) {
        expect(list, isNot(contains(forbidden)), reason: forbidden);
      }
    }, skip: present ? false : why);
  });
}
