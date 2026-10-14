import 'dart:io';
import 'dart:typed_data';

import 'package:bottles_up_vendor/features/owner/logic/media_rules.dart';
import 'package:bottles_up_vendor/features/owner/logic/venue_profile_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_setup_backend.dart' show gifBytes, jpegBytes, pngBytes;

Uint8List webpBytes() => Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 9, 9, 9, 9, 0x57, 0x45, 0x42, 0x50, 1, 2]);

void main() {
  group('what a file really is', () {
    test('JPEG, PNG and WebP are recognised from their first bytes, whatever the file is called', () {
      expect(sniffImageType(jpegBytes()), ImageType.jpeg);
      expect(sniffImageType(pngBytes()), ImageType.png);
      expect(sniffImageType(webpBytes()), ImageType.webp);
    });

    test('anything else is not an image the bucket takes: GIF, text, an iPhone HEIC photo, a RIFF file that is not WebP, a truncated header', () {
      final heic = Uint8List.fromList([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, 0, 0]);
      final wav = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 9, 9, 9, 9, 0x57, 0x41, 0x56, 0x45]);
      for (final bytes in [gifBytes(), Uint8List.fromList('hello world'.codeUnits), heic, wav, Uint8List.fromList([0xFF, 0xD8]), Uint8List.fromList([0x89, 0x50, 0x4E]), Uint8List(0)]) {
        expect(sniffImageType(bytes), isNull);
      }
    });

    test('each type has its mime and extension', () {
      expect([for (final t in ImageType.values) '${t.mime}|${t.extension}'], ['image/jpeg|jpg', 'image/png|png', 'image/webp|webp']);
    });
  });

  group('what is said about a file', () {
    test('an empty file, a file that is not an image, a file that is too large; a good one has no problem', () {
      expect(imageProblem(Uint8List(0)), 'That file is empty.');
      expect(imageProblem(gifBytes()), 'Use a JPEG, PNG or WebP image.');
      expect(imageProblem(jpegBytes()), isNull);
      expect(imageProblem(pngBytes()), isNull);
    });

    test('5 MB is allowed and one byte more is not', () {
      expect(maxImageBytes, 5242880);
      expect(imageProblem(jpegBytes(maxImageBytes)), isNull);
      expect(imageProblem(jpegBytes(maxImageBytes + 1)), 'The image is larger than 5 MB. Choose a smaller one.');
    });

    test('the type is checked before the size', () {
      expect(imageProblem(Uint8List(maxImageBytes + 1)), 'Use a JPEG, PNG or WebP image.');
    });
  });

  test('a file goes inside the business\'s own folder, with its type\'s extension', () {
    expect(mediaPath('org-1', ImageType.png, 'abc'), 'org-1/abc.png');
    expect(mediaPath('org-1', ImageType.jpeg, 'abc'), 'org-1/abc.jpg');
    expect(mediaPath('org-1', ImageType.webp, 'abc'), 'org-1/abc.webp');
  });

  // The bucket and the website decide these: a limit that drifts would show up as an upload the storage refuses, or a check that is
  // stricter than the bucket. Read from the website repo when it is checked out beside this app.
  group('agrees with the website', () {
    final sql = File('../bottles-up-website-main/supabase/migrations/20261007100000_accounts_onboarding.sql');
    final ts = File('../bottles-up-website-main/src/lib/uploadBusinessMedia.ts');
    const why = 'website repo is not checked out next to this app';
    final present = sql.existsSync() && ts.existsSync();

    test('the bucket takes exactly these types and this size', () {
      final text = sql.readAsStringSync();
      expect(text, contains("values ('business-media', 'business-media', true, $maxImageBytes, array['image/jpeg', 'image/png', 'image/webp'])"));
      expect({for (final t in ImageType.values) t.mime}, {'image/jpeg', 'image/png', 'image/webp'});
    }, skip: present ? false : why);

    test('the storage folder is the organization\'s id, which is what the policy checks, in a bucket named business-media', () {
      final text = sql.readAsStringSync();
      expect(text, contains('public.business_media_org(name) is not null'));
      expect(text, contains("bucket_id = 'business-media'"));
    }, skip: present ? false : why);

    test('the sentences and the file naming are the website\'s', () {
      final src = ts.readAsStringSync();
      for (final text in ['Use a JPEG, PNG or WebP image.', 'The image is larger than 5 MB. Choose a smaller one.', 'That file is empty.', 'The image could not be uploaded. You may not have access, or the file is not allowed.', 'return `\${orgId}/\${id}.\${EXTENSION']) {
        expect(src, contains(text), reason: text);
      }
      expect(src, contains('MAX_IMAGE_BYTES = 5 * 1024 * 1024'));
      expect(uploadFailedMessage, 'The image could not be uploaded. You may not have access, or the file is not allowed.');
    }, skip: present ? false : why);
  });

  group('reading a venue row', () {
    test('keeps what it needs; a row with no id or no name is not a profile', () {
      final p = parseVenueProfile({'id': 'v1', 'name': 'Club', 'description': 'd', 'address': 'a', 'cover_image_url': 'https://x/y.jpg'})!;
      expect([p.id, p.name, p.description, p.address, p.coverImageUrl], ['v1', 'Club', 'd', 'a', 'https://x/y.jpg']);
      expect(parseVenueProfile(null), isNull);
      expect(parseVenueProfile({'name': 'Club'}), isNull);
      expect(parseVenueProfile({'id': 'v1', 'name': ''}), isNull);
      expect(parseVenueProfile({'id': 'v1', 'name': 'Club', 'description': null})!.description, isNull);
    });
  });

  group('the profile form', () {
    const good = ProfileForm(name: 'Club Noir');

    test('says what is wrong in plain words', () {
      expect(validateProfileForm(good), isEmpty);
      expect(validateProfileForm(const ProfileForm()), ['Give the venue a name.']);
      expect(validateProfileForm(good.copyWith(name: 'x' * 121)), ['The name must be 120 characters or fewer.']);
      expect(validateProfileForm(good.copyWith(description: 'x' * 4001)), ['The description must be 4000 characters or fewer.']);
      expect(validateProfileForm(good.copyWith(address: 'x' * 301)), ['The address must be 300 characters or fewer.']);
    });

    test('the limits are inclusive', () {
      expect(validateProfileForm(good.copyWith(name: 'x' * 120, description: 'x' * 4000, address: 'x' * 300)), isEmpty);
    });

    test('what is sent: four fields, trimmed, blanks as "none" so they can be cleared; never a status, a slug or the gallery', () {
      final p = profilePayload(const ProfileForm(name: '  Club Noir ', description: '   ', address: ' 12 King St W ', coverImageUrl: ''));
      expect(p, {'name': 'Club Noir', 'description': null, 'address': '12 King St W', 'cover_image_url': null});
      for (final forbidden in ['status', 'slug', 'gallery', 'org_id', 'id']) {
        expect(p.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });

    test('opening a saved profile and saving it unchanged sends the same values back', () {
      const row = VenueProfile(id: 'v1', name: 'Club Noir', description: 'A dark club', address: '12 King St W', coverImageUrl: 'https://img.example/c.jpg');
      final form = profileFormFrom(row);
      expect(validateProfileForm(form), isEmpty);
      expect(profilePayload(form), {'name': 'Club Noir', 'description': 'A dark club', 'address': '12 King St W', 'cover_image_url': 'https://img.example/c.jpg'});
      expect(profilePayload(profileFormFrom(const VenueProfile(id: 'v1', name: 'Club'))), {'name': 'Club', 'description': null, 'address': null, 'cover_image_url': null});
    });
  });

  group('floors', () {
    test('a list_venue_floors row is read; one without an id or a name is dropped', () {
      final f = parseFloor({'floor_id': 'f1', 'label': 'Main room', 'image_url': 'https://x/m.jpg', 'sort_order': 2, 'table_count': 3})!;
      expect([f.floorId, f.label, f.imageUrl, f.sortOrder, f.tableCount], ['f1', 'Main room', 'https://x/m.jpg', 2, 3]);
      expect(parseFloor({'label': 'Main'}), isNull);
      expect(parseFloor({'floor_id': 'f1'}), isNull);
      expect(parseFloor({'floor_id': 'f1', 'label': 'Main'})!.tableCount, 0);
    });

    test('the floor form: a name and an image, in the website\'s words', () {
      expect(validateFloorForm('Main room', 'https://x/m.jpg'), isEmpty);
      expect(validateFloorForm('', ''), ['Give the floor a name, for example "Main room".', 'Upload the floor plan image.']);
      expect(validateFloorForm('   ', 'https://x/m.jpg'), ['Give the floor a name, for example "Main room".']);
      expect(validateFloorForm('x' * 61, 'https://x/m.jpg'), ['The name must be 60 characters or fewer.']);
      expect(validateFloorForm('x' * 60, 'https://x/m.jpg'), isEmpty);
      expect(validateFloorForm('Main', '  '), ['Upload the floor plan image.']);
    });

    test('how many tables are placed', () {
      expect([describeFloorTables(0), describeFloorTables(1), describeFloorTables(4)], ['No tables placed', '1 table placed', '4 tables placed']);
    });
  });

  group('agrees with the website: the profile and floors', () {
    final onboarding = File('../bottles-up-website-main/supabase/migrations/20261007100000_accounts_onboarding.sql');
    final setup = File('../bottles-up-website-main/supabase/migrations/20261010100000_venue_setup.sql');
    final ts = File('../bottles-up-website-main/src/lib/venueSetupForms.ts');
    const why = 'website repo is not checked out next to this app';
    final present = onboarding.existsSync() && setup.existsSync() && ts.existsSync();

    test('update_venue_profile accepts every field the form sends; the only one it does not send is the gallery', () {
      final text = onboarding.readAsStringSync();
      final body = text.substring(text.indexOf('create function public.update_venue_profile'));
      final list = RegExp(r"v_key not in \(([^)]*)\)").firstMatch(body)!.group(1)!;
      final allowed = [for (final m in RegExp(r"'(\w+)'").allMatches(list)) m.group(1)!];
      final sent = profilePayload(const ProfileForm(name: 'x')).keys.toList();
      expect(allowed, containsAll(sent));
      expect(allowed.where((k) => !sent.contains(k)).toSet(), {'gallery'});
    }, skip: present ? false : why);

    test('the limits on the profile and the floors are the database limits', () {
      final text = onboarding.readAsStringSync();
      expect(text, contains("length(coalesce(p_details ->> 'description', '')) > ${ProfileLimits.description}"));
      expect(text, contains("length(coalesce(p_details ->> 'address', '')) > ${ProfileLimits.address}"));
      expect(text, contains("length(p_details ->> 'name') > 120"));
      final floors = setup.readAsStringSync();
      expect(floors, contains('length(v_label) > ${ProfileLimits.floorLabel}'));
      expect(floors, contains('>= ${ProfileLimits.floors} then'));
    }, skip: present ? false : why);

    test('the function and argument names the service uses are the ones the database defines', () {
      expect(onboarding.readAsStringSync(), contains('create function public.update_venue_profile(p_venue uuid, p_details jsonb)'));
      final text = setup.readAsStringSync();
      for (final signature in [
        'list_venue_floors(p_venue uuid)',
        'save_venue_floor(p_venue uuid, p_floor uuid, p_label text, p_image_url text, p_sort_order int default null)',
        'remove_venue_floor(p_venue uuid, p_floor uuid)',
      ]) {
        expect(text, contains('create function public.$signature'), reason: signature);
      }
    }, skip: present ? false : why);

    test('the floor form\'s words are the website\'s', () {
      final src = ts.readAsStringSync();
      for (final text in ['Give the floor a name, for example "Main room".', 'The name must be 60 characters or fewer.', 'Upload the floor plan image.']) {
        expect(src, contains(text), reason: text);
      }
    }, skip: present ? false : why);
  });
}
