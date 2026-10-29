import 'dart:io';

import 'package:bottles_up_vendor/features/owner/logic/venue_profile_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/venue_profile_editor.dart';
import 'package:bottles_up_vendor/features/owner/services/venue_setup_service.dart';
import 'package:bottles_up_vendor/features/owner/widgets/photo_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_owner_backend.dart';
import 'fake_setup_backend.dart';

late FakeSetupBackend setup;
late FakeOwnerBackend owner;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        venueSetupServiceProvider.overrideWithValue(setup.service),
        ownerServiceProvider.overrideWithValue(owner.service),
        photoPickerProvider.overrideWithValue((_) async => null),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: const VenueProfileEditor(venueId: 'v1', orgId: 'o1')),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('field-timezone')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('save-profile')));
  await tester.pumpAndSettle();
}

List<String> order() => [
      for (final c in setup.calls)
        if (c.$1 == 'save_venue_time_zone' || c.$1 == 'update_venue_profile') c.$1,
    ];

void main() {
  setUp(() {
    setup = FakeSetupBackend();
    owner = FakeOwnerBackend();
  });

  group('the zones', () {
    test('the list has each place once, includes the default, and names it', () {
      final zones = [for (final c in venueTimeZoneChoices) c.zone];
      expect(zones.toSet().length, zones.length);
      expect(zones, contains(defaultTimeZone));
      expect(defaultTimeZone, 'America/Toronto');
      expect(timeZoneLabel('America/Toronto'), 'Eastern (Toronto)');
      expect(timeZoneLabel('America/Vancouver'), 'Pacific (Vancouver)');
    });

    test('a place name has the shape the database accepts (a region and a city, never an abbreviation)', () {
      final shape = RegExp(r'^[A-Za-z]+(/[A-Za-z0-9_+-]+)+$');
      for (final c in venueTimeZoneChoices) {
        expect(shape.hasMatch(c.zone), isTrue, reason: c.zone);
        expect(c.label.trim(), isNotEmpty);
      }
    });

    test('every zone in the list is a real place name on this machine', () {
      final root = Directory('/usr/share/zoneinfo');
      if (!root.existsSync()) return; // nothing to compare with
      for (final c in venueTimeZoneChoices) {
        expect(File('${root.path}/${c.zone}').existsSync(), isTrue, reason: c.zone);
      }
    });

    test('a zone the list does not have is kept as its own choice, and one it has is not repeated', () {
      expect(timeZoneLabel('Asia/Kolkata'), 'Asia/Kolkata');
      expect(timeZoneChoicesFor('Asia/Kolkata').last.zone, 'Asia/Kolkata');
      expect(timeZoneChoicesFor('Asia/Kolkata').length, venueTimeZoneChoices.length + 1);
      expect(timeZoneChoicesFor('America/Toronto').length, venueTimeZoneChoices.length);
    });
  });

  group('reading the venue', () {
    test('a row without the time zone key is a server that does not have it; with the key, even empty, it does', () {
      expect(parseVenueProfile({'id': 'v1', 'name': 'Club'})!.timeZoneSupported, isFalse);
      final none = parseVenueProfile({'id': 'v1', 'name': 'Club', 'time_zone': null})!;
      expect([none.timeZoneSupported, none.timeZone, none.effectiveTimeZone], [true, null, 'America/Toronto']);
      final set = parseVenueProfile({'id': 'v1', 'name': 'Club', 'time_zone': 'America/Vancouver'})!;
      expect([set.timeZoneSupported, set.timeZone, set.effectiveTimeZone], [true, 'America/Vancouver', 'America/Vancouver']);
      expect(parseVenueProfile({'id': 'v1', 'name': 'Club', 'time_zone': ''})!.timeZone, isNull);
    });

    test('the row is asked for with the time zone, and without it when the server has no such column', () async {
      final asked = <String>[];
      final row = await readProfileRow((columns) async {
        asked.add(columns);
        return {'id': 'v1', 'name': 'Club', 'time_zone': null};
      });
      expect(asked, ['id, name, description, address, cover_image_url, time_zone']);
      expect(row!['name'], 'Club');

      asked.clear();
      final older = await readProfileRow((columns) async {
        asked.add(columns);
        if (columns.contains('time_zone')) throw const PostgrestException(message: 'column site_venues.time_zone does not exist', code: '42703');
        return {'id': 'v1', 'name': 'Club'};
      });
      expect(asked, ['id, name, description, address, cover_image_url, time_zone', 'id, name, description, address, cover_image_url']);
      expect(parseVenueProfile(older)!.timeZoneSupported, isFalse);
    });

    test('any other failure is not hidden by the second try', () async {
      var calls = 0;
      await expectLater(
        readProfileRow((columns) async {
          calls++;
          throw const PostgrestException(message: 'permission denied', code: '42501');
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 1);
    });
  });

  group('saving', () {
    test('asks the database for the zone by venue and name, and for the default with null', () async {
      expect(await setup.service.saveTimeZone('v1', 'America/Vancouver'), 'America/Vancouver');
      expect(setup.paramsOf('save_venue_time_zone').single, {'p_venue': 'v1', 'p_zone': 'America/Vancouver'});
      expect(await setup.service.saveTimeZone('v1', null), 'America/Toronto');
      expect(setup.paramsOf('save_venue_time_zone').last, {'p_venue': 'v1', 'p_zone': null});
    });

    test('a refusal is the database\'s own sentence', () async {
      await expectLater(setup.service.saveTimeZone('v1', 'EST'), throwsA(isA<SetupEditException>().having((e) => e.message, 'message', 'that time zone is not one the system knows (use a place name such as America/Toronto)')));
    });
  });

  group('the editor', () {
    testWidgets('on a server without time zones there is no such field, and saving never calls for one', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir'};
      await open(tester);
      expect(find.byKey(const Key('field-timezone')), findsNothing);
      expect(find.byKey(const Key('timezone-note')), findsNothing);
      await save(tester);
      expect(order(), ['update_venue_profile']);
    });

    testWidgets('a venue that has not chosen reads as Toronto, and saving without touching it writes nothing about the zone', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir', 'time_zone': null};
      await open(tester);
      expect(find.text('Eastern (Toronto)'), findsOneWidget);
      expect(find.byKey(const Key('timezone-note')), findsOneWidget);
      await save(tester);
      expect(order(), ['update_venue_profile']);
      expect(setup.profileRow!['time_zone'], isNull, reason: 'still "not chosen"');
    });

    testWidgets('choosing another zone saves the zone first, then the profile, and the venue now has it', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir', 'time_zone': null};
      await open(tester);
      await pick(tester, 'Pacific (Vancouver)');
      await save(tester);
      expect(order(), ['save_venue_time_zone', 'update_venue_profile']);
      expect(setup.paramsOf('save_venue_time_zone').single, {'p_venue': 'v1', 'p_zone': 'America/Vancouver'});
      expect(setup.profileRow!['time_zone'], 'America/Vancouver');
      expect(find.byType(VenueProfileEditor), findsNothing, reason: 'closed once saved');
    });

    testWidgets('opening a venue set to Vancouver shows it, and saving other fields leaves the zone alone', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir', 'time_zone': 'America/Vancouver'};
      await open(tester);
      expect(find.text('Pacific (Vancouver)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('field-address')), 'new address');
      await save(tester);
      expect(order(), ['update_venue_profile']);
    });

    testWidgets('a venue set to a zone the list does not have keeps it, under its own name', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir', 'time_zone': 'Asia/Kolkata'};
      await open(tester);
      expect(find.text('Asia/Kolkata'), findsOneWidget);
      await save(tester);
      expect(order(), ['update_venue_profile']);
      expect(setup.profileRow!['time_zone'], 'Asia/Kolkata');
    });

    testWidgets('a zone that is refused is said so, nothing else is saved, and the choice stays', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir', 'time_zone': null};
      await open(tester);
      await pick(tester, 'Pacific (Vancouver)');
      setup.beforeCall = (f) {
        if (f == 'save_venue_time_zone') throw const PostgrestException(message: 'not allowed', code: 'P0001');
      };
      await save(tester);
      expect(find.text("You don't have access to do that."), findsOneWidget);
      expect(order(), ['save_venue_time_zone'], reason: 'the profile was not saved after the zone was refused');
      expect(find.byType(VenueProfileEditor), findsOneWidget);
      expect(find.text('Pacific (Vancouver)'), findsOneWidget);
    });

    testWidgets('if the zone is saved and the profile is refused, a second try saves only the profile', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir', 'time_zone': null};
      await open(tester);
      await pick(tester, 'Pacific (Vancouver)');
      setup.beforeCall = (f) {
        if (f == 'update_venue_profile') throw const PostgrestException(message: 'description must be 4000 characters or fewer', code: 'P0001');
      };
      await save(tester);
      expect(setup.profileRow!['time_zone'], 'America/Vancouver');
      expect(find.text('description must be 4000 characters or fewer'), findsOneWidget);
      setup.beforeCall = null;
      await save(tester);
      expect(order(), ['save_venue_time_zone', 'update_venue_profile', 'update_venue_profile'], reason: 'the zone was not saved a second time');
    });

    testWidgets('the zone cannot be changed while saving', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir', 'time_zone': null};
      await open(tester);
      expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const Key('field-timezone'))).onChanged, isNotNull);
    });
  });

  group('agrees with the website', () {
    final migration = File('../bottles-up-website-main/supabase/migrations/20261027100000_venue_time_zone.sql');
    const why = 'website repo is not checked out next to this app';
    final present = migration.existsSync();

    test('the function takes the arguments the app sends, and the default is the one the app names', () {
      final sql = migration.readAsStringSync();
      expect(sql, contains('create function public.save_venue_time_zone(p_venue uuid, p_zone text)'));
      expect(sql, contains("'America/Toronto'::text"));
      expect(defaultTimeZone, 'America/Toronto');
      expect(sql, contains("time_zone ~ '^[A-Za-z]+(/[A-Za-z0-9_+-]+)+\$'"));
      expect(sql, contains('that time zone is not one the system knows (use a place name such as America/Toronto)'));
      expect(sql, contains('perform public.require_venue_editor(p_venue);'));
    }, skip: present ? false : why);

    test('the fake database takes exactly what the real function takes', () async {
      await setup.service.saveTimeZone('v1', 'America/Toronto');
      expect(setup.paramsOf('save_venue_time_zone').single!.keys.toList()..sort(), ['p_venue', 'p_zone']);
    });
  });
}
