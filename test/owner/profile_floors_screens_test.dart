import 'dart:async';
import 'dart:typed_data';

import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/floors_editor.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/venue_profile_editor.dart';
import 'package:bottles_up_vendor/features/owner/widgets/photo_field.dart';
import 'package:bottles_up_vendor/features/owner/widgets/venue_setup_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_owner_backend.dart';
import 'fake_setup_backend.dart';

late FakeSetupBackend setup;
late FakeOwnerBackend owner;
late FakeMedia media;
late List<Uint8List?> picks;

Widget host(Widget screen) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        venueSetupServiceProvider.overrideWithValue(setup.service),
        ownerServiceProvider.overrideWithValue(owner.service),
        mediaServiceProvider.overrideWithValue(media.service),
        photoPickerProvider.overrideWithValue((_) async => picks.isEmpty ? null : picks.removeAt(0)),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: screen),
    );

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
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

/// A home screen that watches the venues list (as the Venues tab does) and opens the editor, so a change of name is seen to reach it.
class _VenuesHome extends ConsumerWidget {
  const _VenuesHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ownerVenuesProvider('o1'));
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('open-profile'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VenueProfileEditor(venueId: 'v1', orgId: 'o1'))),
          child: const Text('Open'),
        ),
      ),
    );
  }
}

void main() {
  setUp(() {
    setup = FakeSetupBackend();
    owner = FakeOwnerBackend();
    media = FakeMedia();
    picks = [];
    owner.handlers['my_venues'] = (_) => [myVenue('v1', 'Club Noir')];
  });

  group('the venue profile', () {
    Widget editor() => host(const VenueProfileEditor(venueId: 'v1', orgId: 'o1'));

    testWidgets('opens with what is saved', (tester) async {
      await open(tester, editor());
      expect([textOf(tester, 'field-name'), textOf(tester, 'field-description'), textOf(tester, 'field-address')], ['Club Noir', 'A dark club', '12 King St W']);
      expect(find.text('Replace photo'), findsOneWidget);
      expect(find.byKey(const Key('photo-remove')), findsOneWidget);
    });

    testWidgets('a venue with no photo offers to choose one', (tester) async {
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir'};
      await open(tester, editor());
      expect(find.text('Choose photo'), findsOneWidget);
      expect(find.byKey(const Key('photo-remove')), findsNothing);
    });

    testWidgets('a blank name says so and sends nothing', (tester) async {
      await open(tester, editor());
      await typeKey(tester, 'field-name', '  ');
      await tapKey(tester, 'save-profile');
      expect(inProblems('Give the venue a name.'), findsOneWidget);
      expect(setup.count('update_venue_profile'), 0);
    });

    testWidgets('saving sends the four fields (trimmed; blanks as none) and nothing about status, slug or the gallery, and tells the person', (tester) async {
      await open(tester, editor());
      await typeKey(tester, 'field-name', '  Club Noir II ');
      await typeKey(tester, 'field-description', '');
      await tapKey(tester, 'save-profile');
      final d = setup.paramsOf('update_venue_profile').single!['p_details'] as Map;
      expect(d, {'name': 'Club Noir II', 'description': null, 'address': '12 King St W', 'cover_image_url': 'https://img.example/cover.jpg'});
      expect(setup.paramsOf('update_venue_profile').single!['p_venue'], 'v1');
      expect(find.byType(VenueProfileEditor), findsNothing, reason: 'the editor closes once it is saved');
    });

    testWidgets('a changed name reaches the venues list, and the setup checklist is read again', (tester) async {
      await open(tester, host(const _VenuesHome()));
      expect(owner.count('my_venues'), 1);
      await tapKey(tester, 'open-profile');
      await typeKey(tester, 'field-name', 'Club Noir II');
      await tapKey(tester, 'save-profile');
      expect(owner.count('my_venues'), 2);
      expect(find.text('Venue profile saved.'), findsOneWidget);
    });

    testWidgets('a refusal from the database is shown in the form and nothing typed is lost', (tester) async {
      await open(tester, editor());
      await typeKey(tester, 'field-address', 'new address');
      setup.beforeCall = (f) {
        if (f == 'update_venue_profile') throw const PostgrestException(message: 'not allowed', code: 'P0001');
      };
      await tapKey(tester, 'save-profile');
      expect(inProblems("You don't have access to do that."), findsOneWidget);
      expect(textOf(tester, 'field-address'), 'new address');
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-profile'))).onPressed, isNotNull);
    });

    testWidgets('a second tap on Save while the first is still going does not save twice', (tester) async {
      await open(tester, editor());
      final gate = Completer<void>();
      setup.hold = gate.future;
      await tester.tap(find.byKey(const Key('save-profile')));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-profile'))).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(setup.count('update_venue_profile'), 1);
    });

    testWidgets('a venue the person cannot reach says so; a server without the migration says so, with no retry', (tester) async {
      setup.profileRow = null;
      await open(tester, editor());
      expect(find.byKey(const Key('editor-error')), findsOneWidget);
      expect(find.text('Your access has ended, or you are signed out.'), findsOneWidget);
      setup.profileRow = {'id': 'v1', 'name': 'Club Noir'};
      setup.failAll = const PostgrestException(message: 'no function', code: '42883');
      await open(tester, editor());
      expect(find.byKey(const Key('editor-retry')), findsNothing);
    });

    group('the cover photo', () {
      testWidgets('a chosen photo is uploaded into the business\'s folder at once, and saved with the profile', (tester) async {
        await open(tester, editor());
        picks = [pngBytes()];
        await tapKey(tester, 'photo-choose');
        expect(media.uploads.single.$1, 'o1/img1.png');
        expect(media.uploads.single.$3, 'image/png');
        await tapKey(tester, 'save-profile');
        expect((setup.paramsOf('update_venue_profile').single!['p_details'] as Map)['cover_image_url'], 'https://img.example/o1/img1.png');
      });

      testWidgets('cancelling the picker changes nothing', (tester) async {
        await open(tester, editor());
        await tapKey(tester, 'photo-choose');
        expect(media.uploads, isEmpty);
        await tapKey(tester, 'save-profile');
        expect((setup.paramsOf('update_venue_profile').single!['p_details'] as Map)['cover_image_url'], 'https://img.example/cover.jpg');
      });

      testWidgets('a file that is not allowed is said, nothing is uploaded, and the old photo stays', (tester) async {
        await open(tester, editor());
        picks = [gifBytes()];
        await tapKey(tester, 'photo-choose');
        expect(find.text('Use a JPEG, PNG or WebP image.'), findsOneWidget);
        expect(media.uploads, isEmpty);
        await tapKey(tester, 'save-profile');
        expect((setup.paramsOf('update_venue_profile').single!['p_details'] as Map)['cover_image_url'], 'https://img.example/cover.jpg');
      });

      testWidgets('an old complaint goes away as soon as the next photo is chosen', (tester) async {
        await open(tester, editor());
        picks = [gifBytes(), jpegBytes()];
        await tapKey(tester, 'photo-choose');
        expect(find.byKey(const Key('photo-error')), findsOneWidget);
        await tapKey(tester, 'photo-choose');
        expect(find.byKey(const Key('photo-error')), findsNothing);
        expect(media.uploads, hasLength(1));
      });

      testWidgets('an upload the storage refuses is said in plain words', (tester) async {
        media.refuse = true;
        await open(tester, editor());
        picks = [jpegBytes()];
        await tapKey(tester, 'photo-choose');
        expect(find.text('The image could not be uploaded. You may not have access, or the file is not allowed.'), findsOneWidget);
        expect(find.byKey(const Key('photo-busy')), findsNothing);
      });

      testWidgets('Save waits for the photo: it is disabled while the upload is going, and enabled again after', (tester) async {
        await open(tester, editor());
        final gate = Completer<void>();
        media.hold = gate.future;
        picks = [jpegBytes()];
        await tester.tap(find.byKey(const Key('photo-choose')));
        await tester.pump();
        expect(find.byKey(const Key('photo-busy')), findsOneWidget);
        expect(tester.widget<FilledButton>(find.byKey(const Key('save-profile'))).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(find.byKey(const Key('photo-choose'))).onPressed, isNull);
        gate.complete();
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(find.byKey(const Key('save-profile'))).onPressed, isNotNull);
      });

      testWidgets('removing the photo clears it as "none"', (tester) async {
        await open(tester, editor());
        await tapKey(tester, 'photo-remove');
        expect(find.text('Choose photo'), findsOneWidget);
        await tapKey(tester, 'save-profile');
        expect((setup.paramsOf('update_venue_profile').single!['p_details'] as Map)['cover_image_url'], isNull);
      });
    });
  });

  group('floor plans', () {
    Widget editor() => host(const FloorsEditor(venueId: 'v1', orgId: 'o1'));

    testWidgets('says plainly when there are none', (tester) async {
      await open(tester, editor());
      expect(find.byKey(const Key('no-floors')), findsOneWidget);
    });

    testWidgets('shows each floor with how many tables are placed on it', (tester) async {
      setup.floors.addAll([floorRowJson('f1', 'Main room', tables: 3), floorRowJson('f2', 'Terrace'), floorRowJson('f3', 'VIP', tables: 1)]);
      await open(tester, editor());
      expect(find.text('Main room'), findsOneWidget);
      expect(find.byKey(const Key('tables-f1')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('tables-f1'))).data, '3 tables placed');
      expect(tester.widget<Text>(find.byKey(const Key('tables-f2'))).data, 'No tables placed');
      expect(tester.widget<Text>(find.byKey(const Key('tables-f3'))).data, '1 table placed');
    });

    testWidgets('an empty form says what is missing and sends nothing', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-floor');
      await tapKey(tester, 'save-floor');
      expect(inProblems('Give the floor a name, for example "Main room".'), findsOneWidget);
      expect(inProblems('Upload the floor plan image.'), findsOneWidget);
      expect(setup.count('save_venue_floor'), 0);
    });

    testWidgets('adding a floor uploads its image into the business\'s folder, saves the name and image, and lists it', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-floor');
      await typeKey(tester, 'field-label', '  Main room ');
      picks = [jpegBytes()];
      await tapKey(tester, 'photo-choose');
      expect(media.uploads.single.$1, 'o1/img1.jpg');
      await tapKey(tester, 'save-floor');
      expect(setup.paramsOf('save_venue_floor').single, {'p_venue': 'v1', 'p_floor': null, 'p_label': 'Main room', 'p_image_url': 'https://img.example/o1/img1.jpg'});
      expect(find.text('Main room'), findsOneWidget);
      expect(find.text('Floor added.'), findsOneWidget);
    });

    testWidgets('a floor\'s image cannot be removed, only replaced: there is nothing to remove it to', (tester) async {
      setup.floors.add(floorRowJson('f1', 'Main room'));
      await open(tester, editor());
      await tapKey(tester, 'edit-f1');
      expect(find.text('Replace photo'), findsOneWidget);
      expect(find.byKey(const Key('photo-remove')), findsNothing);
    });

    testWidgets('renaming a floor keeps its image; replacing the image keeps the name', (tester) async {
      setup.floors.add(floorRowJson('f1', 'Main room', image: 'https://img.example/old.jpg'));
      await open(tester, editor());
      await tapKey(tester, 'edit-f1');
      expect(textOf(tester, 'field-label'), 'Main room');
      await typeKey(tester, 'field-label', 'Main hall');
      await tapKey(tester, 'save-floor');
      expect(setup.paramsOf('save_venue_floor').last, {'p_venue': 'v1', 'p_floor': 'f1', 'p_label': 'Main hall', 'p_image_url': 'https://img.example/old.jpg'});
      expect(find.text('Floor saved.'), findsOneWidget);

      await tapKey(tester, 'edit-f1');
      picks = [pngBytes()];
      await tapKey(tester, 'photo-choose');
      await tapKey(tester, 'save-floor');
      expect(setup.paramsOf('save_venue_floor').last, {'p_venue': 'v1', 'p_floor': 'f1', 'p_label': 'Main hall', 'p_image_url': 'https://img.example/o1/img1.png'});
    });

    testWidgets('a refusal from the database is shown in the form and nothing typed is lost', (tester) async {
      setup.floors.addAll([for (var i = 0; i < 10; i++) floorRowJson('f$i', 'Floor $i')]);
      await open(tester, editor());
      await tapKey(tester, 'add-floor');
      await typeKey(tester, 'field-label', 'Eleventh');
      picks = [jpegBytes()];
      await tapKey(tester, 'photo-choose');
      await tapKey(tester, 'save-floor');
      expect(inProblems('a venue can have 10 floors at most'), findsOneWidget);
      expect(textOf(tester, 'field-label'), 'Eleventh');
    });

    testWidgets('Save waits for the image upload', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-floor');
      final gate = Completer<void>();
      media.hold = gate.future;
      picks = [jpegBytes()];
      await tester.tap(find.byKey(const Key('photo-choose')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-floor'))).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-floor'))).onPressed, isNotNull);
    });

    testWidgets('removing asks first and says what happens to the tables; keeping or dismissing changes nothing', (tester) async {
      setup.floors.add(floorRowJson('f1', 'Main room', tables: 2));
      await open(tester, editor());
      await tapKey(tester, 'remove-f1');
      expect(find.text('Remove Main room?'), findsOneWidget);
      expect(find.textContaining('The 2 tables placed on it stay, but are no longer placed'), findsOneWidget);
      await tapKey(tester, 'keep');
      await tapKey(tester, 'remove-f1');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(setup.count('remove_venue_floor'), 0);
      await tapKey(tester, 'remove-f1');
      await tapKey(tester, 'confirm-remove');
      expect(setup.paramsOf('remove_venue_floor').single, {'p_venue': 'v1', 'p_floor': 'f1'});
      expect(find.byKey(const Key('floor-f1')), findsNothing);
      expect(find.text('Floor removed.'), findsOneWidget);
    });

    testWidgets('a removal the database refuses is said, and the floor stays until the list is read again', (tester) async {
      setup.floors.add(floorRowJson('f1', 'Main room'));
      await open(tester, editor());
      setup.floors.clear(); // removed by someone else since the list was read
      await tapKey(tester, 'remove-f1');
      await tapKey(tester, 'confirm-remove');
      expect(find.text('floor not found'), findsOneWidget);
      expect(find.byKey(const Key('floor-f1')), findsOneWidget);
    });

    testWidgets('a floor with no tables placed is removed without a warning about tables', (tester) async {
      setup.floors.add(floorRowJson('f1', 'Terrace'));
      await open(tester, editor());
      await tapKey(tester, 'remove-f1');
      expect(find.textContaining('stay, but are no longer placed'), findsNothing);
    });

    testWidgets('a server without the migration says so, with no retry; a dropped connection offers one that works', (tester) async {
      setup.failAll = const PostgrestException(message: 'no function', code: '42883');
      await open(tester, editor());
      expect(find.byKey(const Key('editor-error')), findsOneWidget);
      expect(find.byKey(const Key('editor-retry')), findsNothing);
      setup.failAll = Exception('socket closed');
      await open(tester, editor());
      expect(find.byKey(const Key('editor-retry')), findsOneWidget);
      setup.failAll = null;
      setup.floors.add(floorRowJson('f1', 'Main room'));
      await tapKey(tester, 'editor-retry');
      expect(find.text('Main room'), findsOneWidget);
    });
  });

  group('from the venue\'s Setup list', () {
    setUp(() {
      owner.handlers['venue_setup_status'] = (_) => [
            stepRow('profile', 'done'),
            stepRow('floor_plan', setup.floors.isEmpty ? 'todo' : 'done'),
            stepRow('tables', 'todo'),
            stepRow('bottles', 'todo'),
            stepRow('booking_rules', 'todo'),
            stepRow('team', 'todo', required: false),
          ];
    });

    Widget list() => host(const Scaffold(body: VenueSetupList(venueId: 'v1', orgId: 'o1')));

    testWidgets('the profile and floor plan steps open their editors, for this venue', (tester) async {
      await open(tester, list());
      await tapKey(tester, 'step-profile');
      expect(find.byType(VenueProfileEditor), findsOneWidget);
      expect(setup.paramsOf('read_profile'), [
        {'p_venue': 'v1'},
      ]);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, 'step-floor_plan');
      expect(find.byType(FloorsEditor), findsOneWidget);
      expect(setup.paramsOf('list_venue_floors'), [
        {'p_venue': 'v1'},
      ]);
    });

    testWidgets('saving the profile from the checklist reads the checklist again, and a cover photo goes into the business\'s folder', (tester) async {
      await open(tester, list());
      final reads = owner.count('venue_setup_status');
      await tapKey(tester, 'step-profile');
      picks = [pngBytes()];
      await tapKey(tester, 'photo-choose');
      expect(media.uploads.single.$1, startsWith('o1/'));
      await tapKey(tester, 'save-profile');
      expect(owner.count('venue_setup_status'), greaterThan(reads));
    });

    testWidgets('a table photo and a bottle photo chosen from the checklist go into the business\'s folder', (tester) async {
      await open(tester, list());
      await tapKey(tester, 'step-tables');
      await tapKey(tester, 'add-table');
      picks = [jpegBytes()];
      await tapKey(tester, 'photo-choose');
      expect(media.uploads.last.$1, startsWith('o1/'));
      await tester.tap(find.byType(CloseButton)); // the form is a full-screen dialog
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapKey(tester, 'step-bottles');
      await tapKey(tester, 'add-bottle');
      picks = [pngBytes()];
      await tapKey(tester, 'photo-choose');
      expect(media.uploads, hasLength(2));
      expect(media.uploads.last.$1, startsWith('o1/'));
    });

    testWidgets('a floor image chosen from the checklist goes into the business\'s folder', (tester) async {
      await open(tester, list());
      await tapKey(tester, 'step-floor_plan');
      await tapKey(tester, 'add-floor');
      picks = [jpegBytes()];
      await tapKey(tester, 'photo-choose');
      expect(media.uploads.single.$1, startsWith('o1/'));
    });

    testWidgets('adding the first floor from the checklist marks that step done', (tester) async {
      await open(tester, list());
      expect(find.descendant(of: find.byKey(const Key('step-floor_plan')), matching: find.text('To do')), findsOneWidget);
      await tapKey(tester, 'step-floor_plan');
      await tapKey(tester, 'add-floor');
      await typeKey(tester, 'field-label', 'Main room');
      picks = [jpegBytes()];
      await tapKey(tester, 'photo-choose');
      await tapKey(tester, 'save-floor');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('step-floor_plan')), matching: find.text('Done')), findsOneWidget);
    });
  });
}
