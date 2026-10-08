import 'package:bottles_up_vendor/features/owner/services/owner_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_owner_backend.dart';

void main() {
  late FakeOwnerBackend db;
  setUp(() => db = FakeOwnerBackend());

  group('venues', () {
    test('asks the database for the person\'s venues and keeps only this business\'s', () async {
      db.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A'), myVenue('v2', 'Other Co Club', org: 'o2'), myVenue('v3', 'Club B', status: 'published')];
      final list = await db.service.venues('o1');
      expect(list.map((v) => v.id), ['v1', 'v3']);
      expect(db.count('my_venues'), 1);
      expect(db.venueRowCalls, [
        ['v1', 'v3'],
      ], reason: 'details are asked only for this business\'s venues');
    });

    test('a venue\'s name, status, slug and address come from its own row when there is one', () async {
      db.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A')];
      db.onVenueRows = (_) => [
            {'id': 'v1', 'name': 'Club A (renamed)', 'slug': 'club-a', 'status': 'published', 'address': '1 Main St'},
          ];
      final v = (await db.service.venues('o1')).single;
      expect([v.name, v.slug, v.status, v.address, v.isLive], ['Club A (renamed)', 'club-a', 'published', '1 Main St', true]);
    });

    test('a detail row with blank or odd values changes nothing it should not', () async {
      db.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A', status: 'published')];
      db.onVenueRows = (_) => [
            {'id': 'v1', 'name': '', 'slug': 7, 'status': null, 'address': null},
          ];
      final v = (await db.service.venues('o1')).single;
      expect([v.name, v.slug, v.status, v.address], ['Club A', null, 'published', null]);
    });

    test('if the details cannot be read the venues still come back, without a slug', () async {
      db.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A')];
      db.onVenueRows = (_) => throw Exception('permission denied');
      final v = (await db.service.venues('o1')).single;
      expect([v.name, v.slug], ['Club A', null]);
    });

    test('a business with no venues asks for no details', () async {
      db.handlers['my_venues'] = (_) => [myVenue('v2', 'Other Co Club', org: 'o2')];
      expect(await db.service.venues('o1'), isEmpty);
      expect(db.venueRowCalls, isEmpty);
    });

    test('rows it cannot read are dropped, and a non-list answer is no venues', () async {
      db.handlers['my_venues'] = (_) => [
            {'venue_name': 'no id', 'org_id': 'o1'},
            myVenue('v1', 'Club A'),
            'nonsense',
          ];
      expect((await db.service.venues('o1')).map((v) => v.id), ['v1']);
      db.handlers['my_venues'] = (_) => null;
      expect(await db.service.venues('o1'), isEmpty);
    });

    test('failures say what is wrong', () async {
      Matcher failure({bool unavailable = false, bool accessEnded = false}) => throwsA(isA<OwnerLoadException>()
          .having((e) => e.unavailable, 'unavailable', unavailable)
          .having((e) => e.accessEnded, 'accessEnded', accessEnded));
      for (final code in ['42883', 'PGRST202', '42P01']) {
        db.handlers['my_venues'] = (_) => throw PostgrestException(message: 'no function', code: code);
        await expectLater(db.service.venues('o1'), failure(unavailable: true), reason: code);
      }
      db.handlers['my_venues'] = (_) => throw const PostgrestException(message: 'not authorized', code: 'P0001');
      await expectLater(db.service.venues('o1'), failure(accessEnded: true));
      db.handlers['my_venues'] = (_) => throw Exception('socket closed');
      await expectLater(db.service.venues('o1'), failure());
    });
  });

  group('setup status', () {
    test('asks for one venue and returns the steps in the brief\'s order', () async {
      db.handlers['venue_setup_status'] = (_) => [stepRow('team', 'todo', required: false), stepRow('profile', 'done'), stepRow('tables', 'todo', detail: 'add a table type')];
      final steps = await db.service.setupStatus('v1');
      expect(db.paramsOf('venue_setup_status'), [
        {'p_venue': 'v1'},
      ]);
      expect(steps.map((s) => s.step), ['profile', 'tables', 'team']);
      expect(steps[1].detail, 'add a table type');
    });

    test('unreadable rows are dropped; failures are reported', () async {
      db.handlers['venue_setup_status'] = (_) => [
            {'status': 'done'},
            stepRow('profile', 'done'),
            42,
          ];
      expect((await db.service.setupStatus('v1')).map((s) => s.step), ['profile']);
      db.handlers['venue_setup_status'] = (_) => throw const PostgrestException(message: 'not allowed');
      await expectLater(db.service.setupStatus('v1'), throwsA(isA<OwnerLoadException>().having((e) => e.accessEnded, 'accessEnded', true)));
    });
  });

  group('adding a venue', () {
    test('sends the business and the trimmed name, and returns the new venue\'s id', () async {
      db.handlers['create_org_venue'] = (_) => 'v-new';
      expect(await db.service.createVenue('o1', '  Club C  '), 'v-new');
      expect(db.paramsOf('create_org_venue'), [
        {'p_org': 'o1', 'p_name': 'Club C'},
      ]);
    });

    test('a bad name is refused before anything is sent', () async {
      for (final bad in ['', '   ', 'x' * 121]) {
        await expectLater(db.service.createVenue('o1', bad), throwsA(isA<OwnerActionException>()), reason: '${bad.length}');
      }
      expect(db.calls, isEmpty);
    });

    test('being refused is said in plain words, and so is any other failure', () async {
      db.handlers['create_org_venue'] = (_) => throw const PostgrestException(message: 'not allowed', code: 'P0001');
      await expectLater(db.service.createVenue('o1', 'Club C'), throwsA(isA<OwnerActionException>().having((e) => e.message, 'message', "You don't have access to do that.")));
      db.handlers['create_org_venue'] = (_) => throw Exception('offline');
      await expectLater(db.service.createVenue('o1', 'Club C'), throwsA(isA<OwnerActionException>().having((e) => e.message, 'message', contains('could not be added'))));
    });

    test('an answer that is not an id is a failure, never a made-up success', () async {
      for (final odd in <dynamic>[null, '', 5, <String>[]]) {
        db.handlers['create_org_venue'] = (_) => odd;
        await expectLater(db.service.createVenue('o1', 'Club C'), throwsA(isA<OwnerActionException>()), reason: '$odd');
      }
    });
  });
}
