import 'dart:async';
import 'dart:typed_data';

import 'package:bottles_up_vendor/features/floor/providers/floor_providers.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/owner_home_screen.dart';
import 'package:bottles_up_vendor/features/owner/screens/owner_venues_screen.dart';
import 'package:bottles_up_vendor/features/owner/widgets/booking_link_card.dart';
import 'package:bottles_up_vendor/features/owner/widgets/photo_field.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/workspace_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../floor/fake_floor_backend.dart';
import 'fake_owner_backend.dart';
import 'fake_setup_backend.dart';

late FakeOwnerBackend owner;
late FakeFloorBackend floor;

const ownerWs = Workspace(membershipId: 'm-o', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
const managerWs = Workspace(membershipId: 'm-m', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

late FakeSetupBackend setupDb;
late FakeMedia mediaDb;
late List<Uint8List?> photoPicks;

List<Override> overrides() => [
      ownerServiceProvider.overrideWithValue(owner.service),
      floorServiceProvider.overrideWithValue(floor.service),
      venueSetupServiceProvider.overrideWithValue(setupDb.service),
      mediaServiceProvider.overrideWithValue(mediaDb.service),
      photoPickerProvider.overrideWithValue((_) async => photoPicks.isEmpty ? null : photoPicks.removeAt(0)),
    ];

Widget host(Widget screen) => ProviderScope(
      key: UniqueKey(),
      overrides: overrides(),
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: screen)),
    );

/// The real workspace routes, with a signed-in person holding [workspaces].
Widget app(List<Workspace> workspaces, {required String start}) {
  final router = GoRouter(initialLocation: start, routes: [
    GoRoute(path: '/workspaces', builder: (_, __) => const Scaffold(body: Text('workspace list'))),
    workspaceShellRoute(),
  ]);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [...overrides(), workspaceSnapshotProvider.overrideWith((ref) async => WorkspaceSnapshot.ready(workspaces))],
    child: MaterialApp.router(routerConfig: router, theme: ThemeData.dark()),
  );
}

Future<void> open(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

String valueOf(WidgetTester t, String key) => ((t.widget(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first)) as Text).data!;

void main() {
  setUp(() {
    owner = FakeOwnerBackend();
    floor = FakeFloorBackend();
    setupDb = FakeSetupBackend();
    mediaDb = FakeMedia();
    photoPicks = [];
    owner.handlers['my_venues'] = (_) => [myVenue('v1', 'Club A'), myVenue('v2', 'Club B', status: 'published'), myVenue('vx', 'Not ours', org: 'o2')];
    owner.onVenueRows = (ids) => [
          {'id': 'v1', 'name': 'Club A', 'slug': 'club-a', 'status': 'draft', 'address': '1 Main St'},
          {'id': 'v2', 'name': 'Club B', 'slug': 'club-b', 'status': 'published', 'address': null},
        ];
    owner.handlers['venue_setup_status'] = (p) => p!['p_venue'] == 'v1' ? partialSetup() : [for (final s in partialSetup()) stepRow(s['step'] as String, s['required'] == true ? 'done' : s['status'] as String, required: s['required'] == true)];
    floor.onList = (p) => p!['p_venue'] == 'v1'
        ? [bookingRow('a1', guests: 4, checkedInAt: '2026-10-09T22:00:00Z'), bookingRow('a2', guests: 2), bookingRow('a3', status: 'pending')]
        : [bookingRow('b1', guests: 6, name: 'Grace Hopper')];
  });

  group('Home', () {
    Widget home({OpenVenue? onOpen, DateTime Function()? clock}) => host(OwnerHomeScreen(workspace: ownerWs, clock: clock ?? friday9pm, onOpenVenue: onOpen ?? (c, m, v) {}));

    testWidgets('shows tonight across the business: totals, and a line for each venue', (tester) async {
      await open(tester, home());
      expect(find.text('All venues'), findsOneWidget);
      expect(find.text('Club Co · Friday Oct 9'), findsOneWidget);
      expect(valueOf(tester, 'home-bookings'), '3', reason: 'a1, a2 and b1 are confirmed; the pending one is not');
      expect(valueOf(tester, 'home-guests'), '12');
      expect(valueOf(tester, 'home-arrived'), '1');
      expect(valueOf(tester, 'home-awaiting'), '1');
      expect(find.byKey(const Key('home-venue-v1')), findsOneWidget);
      expect(find.byKey(const Key('home-venue-vx')), findsNothing, reason: 'another business\'s venue is not listed');
      expect(find.text('2 confirmed bookings · 6 guests expected · 1 arrived · 1 awaiting payment'), findsOneWidget);
      expect(find.text('1 confirmed booking · 6 guests expected'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('asks for tonight\'s nights only, one read per venue, by the business night', (tester) async {
      await open(tester, home(clock: () => DateTime(2026, 10, 10, 1, 30)));
      expect(find.text('Club Co · Friday Oct 9'), findsOneWidget, reason: '1:30 AM is still Friday night');
      expect(floor.params, hasLength(2));
      for (final p in floor.params) {
        expect([p!['p_from'], p['p_to']], ['2026-10-09', '2026-10-09']);
      }
      expect(floor.params.map((p) => p!['p_venue']).toSet(), {'v1', 'v2'});
    });

    testWidgets('a venue that cannot be read says so, and the totals say they are incomplete', (tester) async {
      floor.onList = (p) => p!['p_venue'] == 'v1' ? throw Exception('offline') : [bookingRow('b1', guests: 6)];
      await open(tester, home());
      expect(find.text("Tonight's bookings could not be loaded."), findsOneWidget);
      expect(valueOf(tester, 'home-guests'), '6');
      expect(find.byKey(const Key('home-incomplete')), findsOneWidget);
      expect(find.text('One venue could not be loaded, so these totals are incomplete.'), findsOneWidget);
    });

    testWidgets('while venues are still loading it says so, instead of showing zeros as figures', (tester) async {
      final gate = Completer<dynamic>();
      floor.onList = (p) => p!['p_venue'] == 'v1' ? gate.future : [bookingRow('b1')];
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      expect(find.text('Still loading one venue…'), findsOneWidget);
      expect(find.text('Loading…'), findsOneWidget);
      gate.complete(<dynamic>[]);
      await tester.pumpAndSettle();
      expect(find.textContaining('Still loading'), findsNothing);
    });

    testWidgets('tapping a venue opens it', (tester) async {
      final opened = <(String, String)>[];
      await open(tester, home(onOpen: (c, m, v) => opened.add((m, v))));
      await tester.tap(find.byKey(const Key('home-venue-v2')));
      expect(opened, [('m-o', 'v2')]);
    });

    testWidgets('a business with no venues says so', (tester) async {
      owner.handlers['my_venues'] = (_) => <dynamic>[];
      await open(tester, home());
      expect(find.byKey(const Key('home-no-venues')), findsOneWidget);
      expect(floor.calls, isEmpty);
    });

    testWidgets('says plainly what is not here yet', (tester) async {
      await open(tester, home());
      await tester.scrollUntilVisible(find.byKey(const Key('home-footnote')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Sales, collections, balances, event status and unresolved issues are not available here yet'), findsOneWidget);
    });

    testWidgets('a server without the migration says so with no retry; another failure offers one that works', (tester) async {
      owner.handlers['my_venues'] = (_) => throw const PostgrestException(message: 'no function', code: '42883');
      await open(tester, home());
      expect(find.textContaining('not set up on this server yet'), findsOneWidget);
      expect(find.byKey(const Key('home-retry')), findsNothing);

      var fail = true;
      owner.handlers['my_venues'] = (_) => fail ? throw Exception('offline') : [myVenue('v1', 'Club A')];
      await open(tester, home());
      expect(find.textContaining('try again'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const Key('home-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-venue-v1')), findsOneWidget);
    });
  });

  group('Venues', () {
    Widget venues({OpenVenue? onOpen}) => host(OwnerVenuesScreen(workspace: ownerWs, onOpenVenue: onOpen ?? (c, m, v) {}));

    testWidgets('lists the business\'s venues with live or draft, address, and how far each is set up', (tester) async {
      await open(tester, venues());
      expect(find.text('Venues'), findsOneWidget);
      expect(find.text('Club Co'), findsOneWidget);
      expect(find.byKey(const Key('venue-v1')), findsOneWidget);
      expect(find.byKey(const Key('venue-v2')), findsOneWidget);
      expect(find.byKey(const Key('venue-vx')), findsNothing);
      expect(find.text('1 Main St'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('3 of 5 required steps'), findsOneWidget, reason: 'Club A: profile, floor plan and bottles are done');
      expect(find.text('5 of 5 required steps'), findsOneWidget, reason: 'Club B is fully set up');
    });

    testWidgets('a venue whose setup cannot be read says so; the others are unaffected', (tester) async {
      final base = owner.handlers['venue_setup_status']!;
      owner.handlers['venue_setup_status'] = (p) => p!['p_venue'] == 'v1' ? throw Exception('offline') : base(p);
      await open(tester, venues());
      expect(find.byKey(const Key('setup-unavailable-v1')), findsOneWidget);
      expect(find.text('5 of 5 required steps'), findsOneWidget);
    });

    testWidgets('tapping a venue opens it', (tester) async {
      final opened = <(String, String)>[];
      await open(tester, venues(onOpen: (c, m, v) => opened.add((m, v))));
      await tester.tap(find.byKey(const Key('venue-v1')));
      expect(opened, [('m-o', 'v1')]);
    });

    testWidgets('no venues says so and offers to add one', (tester) async {
      owner.handlers['my_venues'] = (_) => <dynamic>[];
      await open(tester, venues());
      expect(find.byKey(const Key('no-venues')), findsOneWidget);
      expect(find.byKey(const Key('add-venue')), findsOneWidget);
    });

    testWidgets('failures: nothing to retry when the server is not set up, a retry that works otherwise', (tester) async {
      owner.handlers['my_venues'] = (_) => throw const PostgrestException(message: 'no function', code: '42883');
      await open(tester, venues());
      expect(find.byKey(const Key('venues-error')), findsOneWidget);
      expect(find.byKey(const Key('venues-retry')), findsNothing);

      var fail = true;
      owner.handlers['my_venues'] = (_) => fail ? throw Exception('offline') : [myVenue('v1', 'Club A')];
      await open(tester, venues());
      fail = false;
      await tester.tap(find.byKey(const Key('venues-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('venue-v1')), findsOneWidget);
    });

    testWidgets('says that claiming an existing venue is done on the website', (tester) async {
      await open(tester, venues());
      await tester.scrollUntilVisible(find.byKey(const Key('venues-footnote')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('done on the website for now'), findsOneWidget);
    });

    group('adding a venue', () {
      Future<void> startAdd(WidgetTester tester) async {
        await tester.ensureVisible(find.byKey(const Key('add-venue')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('add-venue')));
        await tester.pumpAndSettle();
      }

      testWidgets('a name is asked for, checked, and sent trimmed; the list is read again', (tester) async {
        owner.handlers['create_org_venue'] = (_) => 'v-new';
        await open(tester, venues());
        await startAdd(tester);
        expect(find.text('Add a venue'), findsWidgets);

        await tester.tap(find.byKey(const Key('add-venue-confirm')));
        await tester.pumpAndSettle();
        expect(find.text('Give the venue a name.'), findsOneWidget, reason: 'said before anything is sent');
        expect(owner.count('create_org_venue'), 0);

        await tester.enterText(find.byKey(const Key('venue-name-field')), '  Club C  ');
        await tester.pump();
        expect(find.text('Give the venue a name.'), findsNothing, reason: 'typing clears the complaint');
        await tester.tap(find.byKey(const Key('add-venue-confirm')));
        await tester.pumpAndSettle();

        expect(owner.paramsOf('create_org_venue'), [
          {'p_org': 'o1', 'p_name': 'Club C'},
        ]);
        expect(owner.count('my_venues'), 2, reason: 'the list is read again, not guessed');
        expect(find.text('Club C added.'), findsOneWidget);
      });

      testWidgets('cancelling sends nothing', (tester) async {
        await open(tester, venues());
        await startAdd(tester);
        await tester.tap(find.byKey(const Key('add-venue-cancel')));
        await tester.pumpAndSettle();
        expect(owner.count('create_org_venue'), 0);
        expect(find.byKey(const Key('venue-name-field')), findsNothing);
      });

      testWidgets('being refused says so in plain words, and the list is not changed', (tester) async {
        owner.handlers['create_org_venue'] = (_) => throw const PostgrestException(message: 'not allowed', code: 'P0001');
        await open(tester, venues());
        await startAdd(tester);
        await tester.enterText(find.byKey(const Key('venue-name-field')), 'Club C');
        await tester.tap(find.byKey(const Key('add-venue-confirm')));
        await tester.pumpAndSettle();
        expect(find.text("You don't have access to do that."), findsOneWidget);
        expect(owner.count('my_venues'), 1);
      });

      testWidgets('while it is being added the button cannot be pressed again', (tester) async {
        final gate = Completer<dynamic>();
        owner.handlers['create_org_venue'] = (_) => gate.future;
        await open(tester, venues());
        await startAdd(tester);
        await tester.enterText(find.byKey(const Key('venue-name-field')), 'Club C');
        await tester.tap(find.byKey(const Key('add-venue-confirm')));
        await tester.pump();
        await tester.pump();
        expect(find.text('Adding…'), findsOneWidget);
        expect(tester.widget<FilledButton>(find.byKey(const Key('add-venue'))).onPressed, isNull);
        gate.complete('v-new');
        await tester.pumpAndSettle();
        expect(find.text('Add a venue'), findsOneWidget);
      });
    });
  });

  group("a venue's own page, through the real routes", () {
    Widget at(String path, {List<Workspace>? workspaces}) => app(workspaces ?? [ownerWs], start: path);

    testWidgets('opening a venue from the list shows its name, status and three tabs; back returns to the list', (tester) async {
      await open(tester, at('/w/m-o/venues'));
      await tester.tap(find.byKey(const Key('venue-v1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('venue-title')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('venue-title'))) as Text).data, 'Club A');
      expect(find.byKey(const Key('venue-status')), findsOneWidget);
      for (final tab in ['Bookings', 'Setup', 'Link']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget, reason: tab);
      }

      await tester.tap(find.byKey(const Key('venue-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('venue-v1')), findsOneWidget, reason: 'the list again');
      expect(find.byKey(const Key('venue-title')), findsNothing);
    });

    testWidgets('Bookings is given the business, so the owner can give a booking to a server', (tester) async {
      await open(tester, at('/w/m-o/venues/v1'));
      final screen = tester.widget<FloorScreen>(find.byType(FloorScreen));
      expect(screen.orgId, ownerWs.orgId);
      expect(screen.venueId, 'v1');
    });

    testWidgets('Bookings: this venue\'s bookings for tonight, with no second "Bookings" heading', (tester) async {
      await open(tester, at('/w/m-o/venues/v1'));
      expect(floor.params.last, {'p_venue': 'v1', 'p_from': isA<String>(), 'p_to': isA<String>()});
      expect(find.byKey(const Key('tile-confirmed')), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('Bookings'), findsOneWidget, reason: 'only the tab, not a heading under it');
    });

    testWidgets('Setup: a photo chosen on the venue\'s own page goes into the folder of the business the workspace belongs to', (tester) async {
      await open(tester, at('/w/m-o/venues/v1'));
      await tester.tap(find.widgetWithText(Tab, 'Setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('step-floor_plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-floor')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field-label')), 'Main room');
      photoPicks = [Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4])];
      await tester.tap(find.byKey(const Key('photo-choose')));
      await tester.pumpAndSettle();
      expect(mediaDb.uploads.single.$1, startsWith('o1/'), reason: 'the folder is the business\'s id (the workspace\'s org), which the storage policy checks');
      await tester.tap(find.byKey(const Key('save-floor')));
      await tester.pumpAndSettle();
      expect(setupDb.paramsOf('save_venue_floor').single!['p_venue'], 'v1');
    });

    testWidgets('Setup: progress, what is next, each step with what is missing, and what cannot be done yet', (tester) async {
      await open(tester, at('/w/m-o/venues/v1'));
      await tester.tap(find.widgetWithText(Tab, 'Setup'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('setup-summary')), findsOneWidget);
      expect((tester.widget(find.byKey(const Key('setup-summary'))) as Text).data, '3 of 5 required steps done');
      expect(find.text('Next: Tables and capacities'), findsOneWidget);
      expect(find.byKey(const Key('step-profile')), findsOneWidget);
      expect(find.text('To do: add a table type with capacity, deposit and minimum spend'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('step-profile')), matching: find.text('Done')), findsOneWidget);
      // The lower steps are off the bottom of the screen until scrolled to.
      final list = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(find.text('Team (optional)'), 200, scrollable: list);
      expect(find.text('Team (optional)'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('step-payments')), 200, scrollable: list);
      expect(find.descendant(of: find.byKey(const Key('step-payments')), matching: find.text('Coming soon')), findsOneWidget);
      expect(find.textContaining('payment configuration is not available yet'), findsNothing, reason: 'a step that cannot be done yet is never "To do"');
    });

    testWidgets('Setup: says where editing happens and who takes a venue live', (tester) async {
      await open(tester, at('/w/m-o/venues/v1'));
      await tester.tap(find.widgetWithText(Tab, 'Setup'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('setup-footnote')), 300, scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('done on the website for now'), findsOneWidget);
      expect(find.textContaining('done by the BottlesUp team'), findsOneWidget);
    });

    testWidgets('Setup: a failure offers a retry that works; a missing migration does not', (tester) async {
      var fail = true;
      final base = owner.handlers['venue_setup_status']!;
      owner.handlers['venue_setup_status'] = (p) => fail ? throw Exception('offline') : base(p);
      await open(tester, at('/w/m-o/venues/v1'));
      await tester.tap(find.widgetWithText(Tab, 'Setup'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setup-error')), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const Key('setup-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setup-summary')), findsOneWidget);

      owner.handlers['venue_setup_status'] = (p) => throw const PostgrestException(message: 'no function', code: '42883');
      await open(tester, at('/w/m-o/venues/v1'));
      await tester.tap(find.widgetWithText(Tab, 'Setup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not set up on this server yet'), findsOneWidget);
      expect(find.byKey(const Key('setup-retry')), findsNothing);
    });

    testWidgets('Link: a draft venue shows its address and a QR code, and says it is not live yet', (tester) async {
      await open(tester, at('/w/m-o/venues/v1'));
      await tester.tap(find.widgetWithText(Tab, 'Link'));
      await tester.pumpAndSettle();
      expect((tester.widget(find.byKey(const Key('booking-link'))) as SelectableText).data, 'https://www.bottlesupapp.com/venues/club-a');
      expect(find.byKey(const Key('booking-qr')), findsOneWidget);
      expect(find.textContaining('starts working when the venue goes live'), findsOneWidget);
      expect(find.byKey(const Key('open-link')), findsNothing, reason: 'there is nothing to preview yet');
    });

    testWidgets('Link: a live venue can be previewed', (tester) async {
      await open(tester, at('/w/m-o/venues/v2'));
      await tester.tap(find.widgetWithText(Tab, 'Link'));
      await tester.pumpAndSettle();
      expect(find.text('Guests can book through this link now.'), findsOneWidget);
      expect(find.byKey(const Key('open-link')), findsOneWidget);
    });

    testWidgets('opened by address with nothing under it, back still leads to the Venues list', (tester) async {
      await open(tester, at('/w/m-o/venues/v1'));
      await tester.tap(find.byKey(const Key('venue-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('venue-v1')), findsOneWidget);
      expect(find.byKey(const Key('add-venue')), findsOneWidget);
    });

    testWidgets('a venue of another business is "not part of your business", with a way back', (tester) async {
      await open(tester, at('/w/m-o/venues/vx'));
      expect(find.byKey(const Key('venue-not-found')), findsOneWidget);
      expect(floor.calls, isEmpty, reason: 'no bookings are asked for a venue that is not ours');
      await tester.tap(find.byKey(const Key('venue-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-venue')), findsOneWidget);
    });

    testWidgets('anyone but the business\'s owner gets nothing: a manager opening the address sees "not part of your role"', (tester) async {
      await open(tester, at('/w/m-m/venues/v1', workspaces: [managerWs]));
      expect(find.byKey(const Key('venue-not-yours')), findsOneWidget);
      expect(owner.calls, isEmpty);
      expect(floor.calls, isEmpty);
    });

    testWidgets('an address for a workspace the person does not hold goes back to the list of workspaces', (tester) async {
      await open(tester, at('/w/m-o/venues/v1', workspaces: [managerWs]));
      // The app's own redirect handles this (see workspace_routing_test); with these bare routes the shell says access ended.
      expect(find.byKey(const Key('venue-title')), findsNothing);
      expect(owner.calls, isEmpty);
    });
  });

  group('the booking link card on its own', () {
    Widget card(OrgVenue v, {Future<void> Function(String)? copy, Future<void> Function(Uri)? openUri, String? site}) =>
        MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: BookingLinkCard(venue: v, site: site, copy: copy ?? (t) async {}, open: openUri ?? (u) async {})));

    const live = OrgVenue(id: 'v2', name: 'Club B', status: 'published', slug: 'club-b');
    const draft = OrgVenue(id: 'v1', name: 'Club A', status: 'draft', slug: 'club-a');

    testWidgets('Copy puts exactly the link on the clipboard and confirms it', (tester) async {
      final copied = <String>[];
      await tester.pumpWidget(card(live, copy: (t) async => copied.add(t)));
      await tester.tap(find.byKey(const Key('copy-link')));
      await tester.pump();
      expect(copied, ['https://www.bottlesupapp.com/venues/club-b']);
      expect(find.text('Link copied.'), findsOneWidget);
    });

    testWidgets('when copying is refused it says how to do it by hand', (tester) async {
      await tester.pumpWidget(card(live, copy: (t) async => throw Exception('no clipboard')));
      await tester.tap(find.byKey(const Key('copy-link')));
      await tester.pump();
      expect(find.text('Could not copy. Select the link and copy it.'), findsOneWidget);
    });

    testWidgets('Preview opens the public page, and a phone that cannot says so', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(card(live, openUri: (u) async => opened.add(u)));
      await tester.tap(find.byKey(const Key('open-link')));
      await tester.pump();
      expect(opened.single.toString(), 'https://www.bottlesupapp.com/venues/club-b');

      await tester.pumpWidget(card(live, openUri: (u) async => throw Exception('no browser')));
      await tester.tap(find.byKey(const Key('open-link')));
      await tester.pump();
      expect(find.text('This could not be opened on this phone.'), findsOneWidget);
    });

    testWidgets('a draft has no Preview, and its link still works to copy and print', (tester) async {
      await tester.pumpWidget(card(draft));
      expect(find.byKey(const Key('open-link')), findsNothing);
      expect(find.byKey(const Key('copy-link')), findsOneWidget);
      expect(find.byKey(const Key('booking-qr')), findsOneWidget);
    });

    testWidgets('a venue with no clean slug links by id, and a configured site is used', (tester) async {
      await tester.pumpWidget(card(const OrgVenue(id: 'abc-123', name: 'X', status: 'draft'), site: 'https://staging.example.com'));
      expect((tester.widget(find.byKey(const Key('booking-link'))) as SelectableText).data, 'https://staging.example.com/venues/abc-123');
    });

    testWidgets('says that short addresses and per-link counts are not available', (tester) async {
      await tester.pumpWidget(card(live));
      await tester.scrollUntilVisible(find.byKey(const Key('link-footnote')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('not available yet'), findsOneWidget);
    });
  });
}
