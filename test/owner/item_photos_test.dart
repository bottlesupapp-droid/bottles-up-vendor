import 'dart:async';
import 'dart:typed_data';

import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/bottle_menu_editor.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/table_types_editor.dart';
import 'package:bottles_up_vendor/features/owner/widgets/photo_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  tester.view.physicalSize = const Size(800, 2200);
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

Map<dynamic, dynamic> lastDetails(String fn) => setup.paramsOf(fn).last!['p_details'] as Map;

void main() {
  setUp(() {
    setup = FakeSetupBackend();
    owner = FakeOwnerBackend();
    media = FakeMedia();
    picks = [];
  });

  group('table photos', () {
    Widget editor() => host(const TableTypesEditor(venueId: 'v1', orgId: 'o1'));

    testWidgets('a table with a photo shows it on its card; one without shows none', (tester) async {
      setup.tables.addAll([tableRowJson('t1', 'VIP booth'), {...tableRowJson('t2', 'Dance floor'), 'image_url': null}]);
      await open(tester, editor());
      expect(find.byKey(const Key('thumb-t1')), findsOneWidget);
      expect(find.byKey(const Key('thumb-t2')), findsNothing);
    });

    testWidgets('a photo chosen for a new table is uploaded into the business\'s folder and saved with the table', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      await typeKey(tester, 'field-name', 'Booth');
      await typeKey(tester, 'field-max', '6');
      picks = [jpegBytes()];
      await tapKey(tester, 'photo-choose');
      expect(media.uploads.single.$1, 'o1/img1.jpg');
      await tapKey(tester, 'save-table');
      expect(lastDetails('save_venue_table_type')['image_url'], 'https://img.example/o1/img1.jpg');
      expect(find.byKey(Key('thumb-${setup.tables.single['type_id']}')), findsOneWidget);
    });

    testWidgets('no photo is sent as none', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      await typeKey(tester, 'field-name', 'Booth');
      await typeKey(tester, 'field-max', '6');
      await tapKey(tester, 'save-table');
      expect(lastDetails('save_venue_table_type')['image_url'], isNull);
    });

    testWidgets('editing opens with the photo, saves it back unchanged, replaces it, or removes it', (tester) async {
      setup.tables.add(tableRowJson('t1', 'VIP booth'));
      await open(tester, editor());
      await tapKey(tester, 'edit-t1');
      expect(find.text('Replace photo'), findsOneWidget);
      await tapKey(tester, 'save-table');
      expect(lastDetails('save_venue_table_type')['image_url'], 'https://img.example/t1.jpg');

      await tapKey(tester, 'edit-t1');
      picks = [pngBytes()];
      await tapKey(tester, 'photo-choose');
      await tapKey(tester, 'save-table');
      expect(lastDetails('save_venue_table_type')['image_url'], 'https://img.example/o1/img1.png');

      await tapKey(tester, 'edit-t1');
      await tapKey(tester, 'photo-remove');
      await tapKey(tester, 'save-table');
      expect(lastDetails('save_venue_table_type')['image_url'], isNull);
      expect(setup.tables.single['image_url'], isNull);
      expect(find.byKey(const Key('thumb-t1')), findsNothing);
    });

    testWidgets('Save waits for the photo upload', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      final gate = Completer<void>();
      media.hold = gate.future;
      picks = [jpegBytes()];
      await tester.tap(find.byKey(const Key('photo-choose')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-table'))).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-table'))).onPressed, isNotNull);
    });

    testWidgets('a file that is not allowed is said, nothing is uploaded, and the table keeps its photo', (tester) async {
      setup.tables.add(tableRowJson('t1', 'VIP booth'));
      await open(tester, editor());
      await tapKey(tester, 'edit-t1');
      picks = [gifBytes()];
      await tapKey(tester, 'photo-choose');
      expect(find.text('Use a JPEG, PNG or WebP image.'), findsOneWidget);
      expect(media.uploads, isEmpty);
      await tapKey(tester, 'save-table');
      expect(lastDetails('save_venue_table_type')['image_url'], 'https://img.example/t1.jpg');
    });

    testWidgets('the table form no longer says photos are done on the website', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-table');
      expect(find.textContaining('Photos, where a table sits'), findsNothing);
      expect(find.textContaining('Where a table sits on the floor plan'), findsOneWidget);
    });
  });

  group('bottle photos', () {
    Widget editor() => host(const BottleMenuEditor(venueId: 'v1', orgId: 'o1'));

    testWidgets('a bottle with a photo shows it on its tile; one without shows none', (tester) async {
      setup.bottles.addAll([bottleRowJson('b1', 'Grey Goose'), {...bottleRowJson('b2', 'Vodka'), 'image_url': null}]);
      await open(tester, editor());
      expect(find.byKey(const Key('thumb-b1')), findsOneWidget);
      expect(find.byKey(const Key('thumb-b2')), findsNothing);
    });

    testWidgets('a photo chosen for a new bottle is uploaded into the business\'s folder and saved with it', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-bottle');
      await typeKey(tester, 'field-name', 'Grey Goose');
      await typeKey(tester, 'field-price', '195');
      picks = [jpegBytes()];
      await tapKey(tester, 'photo-choose');
      expect(media.uploads.single.$1, 'o1/img1.jpg');
      await tapKey(tester, 'save-bottle');
      expect(lastDetails('save_venue_bottle')['image_url'], 'https://img.example/o1/img1.jpg');
    });

    testWidgets('editing keeps the photo unless it is replaced or removed', (tester) async {
      setup.bottles.add(bottleRowJson('b1', 'Grey Goose'));
      await open(tester, editor());
      await tapKey(tester, 'edit-b1');
      await tapKey(tester, 'save-bottle');
      expect(lastDetails('save_venue_bottle')['image_url'], 'https://img.example/b1.jpg');
      await tapKey(tester, 'edit-b1');
      await tapKey(tester, 'photo-remove');
      await tapKey(tester, 'save-bottle');
      expect(setup.bottles.single['image_url'], isNull);
    });

    testWidgets('the quick switches still send only their own field, never the photo', (tester) async {
      setup.bottles.add(bottleRowJson('b1', 'Grey Goose'));
      await open(tester, editor());
      await tapKey(tester, 'sold-out-b1');
      expect(setup.paramsOf('save_venue_bottle').single!['p_details'], {'is_sold_out': true});
      expect(setup.bottles.single['image_url'], 'https://img.example/b1.jpg');
    });

    testWidgets('Save waits for the photo upload', (tester) async {
      await open(tester, editor());
      await tapKey(tester, 'add-bottle');
      final gate = Completer<void>();
      media.hold = gate.future;
      picks = [jpegBytes()];
      await tester.tap(find.byKey(const Key('photo-choose')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('save-bottle'))).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a refused upload is said in plain words and nothing is changed', (tester) async {
      media.refuse = true;
      await open(tester, editor());
      await tapKey(tester, 'add-bottle');
      picks = [jpegBytes()];
      await tapKey(tester, 'photo-choose');
      expect(find.text('The image could not be uploaded. You may not have access, or the file is not allowed.'), findsOneWidget);
    });
  });
}
