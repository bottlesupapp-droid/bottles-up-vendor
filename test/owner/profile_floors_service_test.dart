import 'dart:typed_data';

import 'package:bottles_up_vendor/features/owner/logic/venue_profile_rules.dart';
import 'package:bottles_up_vendor/features/owner/services/media_service.dart';
import 'package:bottles_up_vendor/features/owner/services/owner_service.dart';
import 'package:bottles_up_vendor/features/owner/services/venue_setup_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_setup_backend.dart';

Matcher refusal(String message) => throwsA(isA<SetupEditException>().having((e) => e.message, 'message', message));
Matcher mediaRefusal(String message) => throwsA(isA<MediaException>().having((e) => e.message, 'message', message));

void main() {
  late FakeSetupBackend db;
  late FakeMedia media;
  setUp(() {
    db = FakeSetupBackend();
    media = FakeMedia();
  });

  group('floors', () {
    test('lists the venue\'s floors, dropping rows it cannot read', () async {
      db.floors.addAll([floorRowJson('f1', 'Main room', tables: 3), {'label': 'no id'}, floorRowJson('f2', 'Terrace')]);
      final list = await db.service.floors('v1');
      expect(list.map((f) => [f.floorId, f.label, f.tableCount]), [['f1', 'Main room', 3], ['f2', 'Terrace', 0]]);
      expect(db.paramsOf('list_venue_floors'), [
        {'p_venue': 'v1'},
      ]);
    });

    test('adding sends the venue, no floor id, a trimmed name and the image; the new id comes back', () async {
      final id = await db.service.saveFloor('v1', null, '  Main room ', ' https://img.example/m.jpg ');
      expect(db.paramsOf('save_venue_floor').single, {'p_venue': 'v1', 'p_floor': null, 'p_label': 'Main room', 'p_image_url': 'https://img.example/m.jpg'});
      expect(db.floors.single['floor_id'], id);
    });

    test('changing a floor names it', () async {
      db.floors.add(floorRowJson('f1', 'Main'));
      await db.service.saveFloor('v1', 'f1', 'Main room', 'https://img.example/new.jpg');
      expect(db.floors.single['label'], 'Main room');
      expect(db.floors.single['image_url'], 'https://img.example/new.jpg');
      expect(db.paramsOf('save_venue_floor').single!['p_floor'], 'f1');
    });

    test('a refusal arrives as the database\'s sentence', () async {
      await expectLater(db.service.saveFloor('v1', null, '', 'https://x/y.jpg'), refusal('a floor name is required'));
      await expectLater(db.service.saveFloor('v1', null, 'Main', ''), refusal('a floor plan image is required'));
      await expectLater(db.service.saveFloor('v1', 'nope', 'Main', 'https://x/y.jpg'), refusal('floor not found'));
      db.floors.addAll([for (var i = 0; i < 10; i++) floorRowJson('f$i', 'Floor $i')]);
      await expectLater(db.service.saveFloor('v1', null, 'One more', 'https://x/y.jpg'), refusal('a venue can have 10 floors at most'));
    });

    test('removing names the venue and the floor; an unknown floor is refused', () async {
      db.floors.add(floorRowJson('f1', 'Main'));
      await db.service.removeFloor('v1', 'f1');
      expect(db.floors, isEmpty);
      expect(db.paramsOf('remove_venue_floor').single, {'p_venue': 'v1', 'p_floor': 'f1'});
      await expectLater(db.service.removeFloor('v1', 'f1'), refusal('floor not found'));
    });

    test('an answer that is not an id is a failure; losing access is said in the person\'s words', () async {
      final odd = VenueSetupService(rpc: (f, {params}) async => null);
      await expectLater(odd.saveFloor('v1', null, 'Main', 'https://x/y.jpg'), refusal('The floor could not be saved. Try again.'));
      db.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
      await expectLater(db.service.saveFloor('v1', null, 'Main', 'https://x/y.jpg'), refusal("You don't have access to do that."));
    });

    test('loading failures say what is wrong', () async {
      Matcher failure({bool unavailable = false, bool accessEnded = false}) =>
          throwsA(isA<OwnerLoadException>().having((e) => e.unavailable, 'unavailable', unavailable).having((e) => e.accessEnded, 'accessEnded', accessEnded));
      db.failAll = const PostgrestException(message: 'no function', code: '42883');
      await expectLater(db.service.floors('v1'), failure(unavailable: true));
      db.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
      await expectLater(db.service.floors('v1'), failure(accessEnded: true));
      db.failAll = Exception('socket closed');
      await expectLater(db.service.floors('v1'), failure());
    });
  });

  group('the venue profile', () {
    test('reads the venue\'s own row', () async {
      final p = await db.service.venueProfile('v1');
      expect([p.name, p.description, p.address, p.coverImageUrl], ['Club Noir', 'A dark club', '12 King St W', 'https://img.example/cover.jpg']);
      expect(db.paramsOf('read_profile'), [
        {'p_venue': 'v1'},
      ]);
    });

    test('a venue the person cannot reach comes back as nothing (row level security), which is "no access", not a blank form', () async {
      db.profileRow = null;
      await expectLater(db.service.venueProfile('v1'), throwsA(isA<OwnerLoadException>().having((e) => e.accessEnded, 'accessEnded', true)));
    });

    test('a failed read says what is wrong', () async {
      db.failAll = Exception('socket closed');
      await expectLater(db.service.venueProfile('v1'), throwsA(isA<OwnerLoadException>().having((e) => e.unavailable || e.accessEnded, 'a specific cause', false)));
    });

    test('saving sends the venue and exactly the details; only those fields change', () async {
      await db.service.saveProfile('v1', profilePayload(const ProfileForm(name: 'Club Noir II', description: '', address: '1 Main St')));
      final call = db.paramsOf('update_venue_profile').single!;
      expect(call['p_venue'], 'v1');
      expect((call['p_details'] as Map).keys.toSet(), {'name', 'description', 'address', 'cover_image_url'});
      expect(db.profileRow!['name'], 'Club Noir II');
      expect(db.profileRow!['description'], isNull, reason: 'a blank is "none"');
    });

    test('a refusal arrives as the database\'s sentence; a field it does not know is refused', () async {
      await expectLater(db.service.saveProfile('v1', {'name': ''}), refusal('name is required (120 characters at most)'));
      await expectLater(db.service.saveProfile('v1', {'status': 'published'}), refusal('unknown field: status'));
      await expectLater(db.service.saveProfile('v1', {'cover_image_url': 'http://x/y.jpg'}), refusal('cover image must be an https link'));
    });
  });

  group('uploading a photo', () {
    test('goes into the business\'s own folder, under a new name, with its real type, and the public address comes back', () async {
      final url = await media.service.uploadBusinessImage('org-1', jpegBytes(100));
      expect(media.uploads.single, ('org-1/img1.jpg', 100, 'image/jpeg'));
      expect(url, 'https://img.example/org-1/img1.jpg');
    });

    test('each upload gets its own name, so a new photo never overwrites an old one', () async {
      await media.service.uploadBusinessImage('org-1', jpegBytes());
      final s = media.service;
      await s.uploadBusinessImage('org-1', pngBytes());
      await s.uploadBusinessImage('org-1', pngBytes());
      expect(media.uploads.map((u) => u.$1).toSet().length, 3);
      expect(media.uploads.last.$1, endsWith('.png'));
    });

    test('a file that is not allowed is a sentence, and nothing is uploaded', () async {
      await expectLater(media.service.uploadBusinessImage('org-1', Uint8List(0)), mediaRefusal('That file is empty.'));
      await expectLater(media.service.uploadBusinessImage('org-1', gifBytes()), mediaRefusal('Use a JPEG, PNG or WebP image.'));
      await expectLater(media.service.uploadBusinessImage('org-1', jpegBytes(5 * 1024 * 1024 + 1)), mediaRefusal('The image is larger than 5 MB. Choose a smaller one.'));
      expect(media.uploads, isEmpty);
    });

    test('by default every upload gets a fresh random name, so a new photo never overwrites an old one', () async {
      final paths = <String>[];
      final plain = MediaService(uploader: (path, bytes, type) async {
        paths.add(path);
        return 'https://img.example/$path';
      });
      await plain.uploadBusinessImage('org-1', jpegBytes());
      await plain.uploadBusinessImage('org-1', jpegBytes());
      expect(paths.toSet().length, 2);
      for (final p in paths) {
        expect(p, matches(RegExp(r'^org-1/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.jpg$')));
      }
    });

    test('storage is told the real type, to cache the photo for a year, and never to overwrite a file', () {
      final o = mediaFileOptions('image/png');
      expect([o.contentType, o.cacheControl, o.upsert], ['image/png', '31536000', false]);
      expect(MediaService.bucket, 'business-media');
    });

    test('a refusal from storage is a sentence, never a raw error', () async {
      media.refuse = true;
      await expectLater(media.service.uploadBusinessImage('org-1', jpegBytes()), mediaRefusal('The image could not be uploaded. You may not have access, or the file is not allowed.'));
    });
  });

  // A stale floor list or profile is worse than a slow one: nothing is kept once the screen that asked for it is gone.
  test('the floors and the profile are read again, never kept', () async {
    final container = ProviderContainer(overrides: [venueSetupServiceProvider.overrideWithValue(db.service)]);
    addTearDown(container.dispose);
    final floorsSub = container.listen(floorsProvider('v1'), (_, __) {});
    final profileSub = container.listen(venueProfileProvider('v1'), (_, __) {});
    await container.read(floorsProvider('v1').future);
    await container.read(venueProfileProvider('v1').future);
    floorsSub.close();
    profileSub.close();
    await Future<void>.delayed(Duration.zero);
    db.floors.add(floorRowJson('f1', 'Main room'));
    db.profileRow = {...db.profileRow!, 'name': 'Renamed'};
    expect((await container.read(floorsProvider('v1').future)).length, 1);
    expect((await container.read(venueProfileProvider('v1').future)).name, 'Renamed');
  });
}
