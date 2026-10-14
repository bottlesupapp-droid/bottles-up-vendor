import 'dart:async';

import 'package:bottles_up_vendor/features/floor/providers/floor_providers.dart';
import 'package:bottles_up_vendor/features/floor/screens/floor_screen.dart';
import 'package:bottles_up_vendor/features/server_desk/logic/server_desk_rules.dart';
import 'package:bottles_up_vendor/features/server_desk/providers/server_desk_providers.dart';
import 'package:bottles_up_vendor/features/server_desk/widgets/assign_server_row.dart';
import 'package:bottles_up_vendor/features/team/providers/team_providers.dart';
import 'package:bottles_up_vendor/features/team/services/team_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../floor/fake_floor_backend.dart';
import 'fake_desk_backend.dart';

late FakeFloorBackend floor;
late FakeDeskBackend desk;
late List<Map<String, dynamic>> team;
Object? teamFailure;

Map<String, dynamic> person(String id, String name, {String role = 'server', String venue = 'v1', String state = 'active'}) => {
      'membership_id': id,
      'user_id': 'u-$id',
      'email': '${name.toLowerCase().replaceAll(' ', '')}@club.example',
      'name': name,
      'role': role,
      'venue_id': venue,
      'venue_name': 'Club',
      'state': state,
    };

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Widget host({String? orgId = 'o1', ServerPicker? pick}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        floorServiceProvider.overrideWithValue(floor.service),
        serverDeskServiceProvider.overrideWithValue(desk.service),
        teamServiceProvider.overrideWithValue(TeamService(rpc: (f, {params}) async {
          if (teamFailure != null) throw teamFailure!;
          return team;
        })),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: FloorScreen(
            venueId: 'v1',
            venueName: 'Club A',
            orgId: orgId,
            clock: friday9pm,
            pickNight: (c, i) async => null,
            contact: (u) async {},
            pickServer: pick ?? (c, options, current) async => null,
          ),
        ),
      ),
    );

Future<void> open(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    floor = FakeFloorBackend();
    floor.onList = (_) => [
          bookingRow('b1', name: 'Ada Lovelace', code: 'AB12CD'),
          bookingRow('b2', name: 'Grace Hopper', table: 'Dance floor table', guests: 2, code: 'EF34GH'),
          bookingRow('b3', name: 'Linus Torvalds', status: 'pending', email: 'linus@example.com'),
        ];
    desk = FakeDeskBackend()..level = 'manager';
    desk.addBooking('b1', name: 'Ada Lovelace');
    desk.addBooking('b2', name: 'Grace Hopper');
    desk.addBooking('b3', name: 'Linus Torvalds', status: 'pending');
    desk.staff.addAll({'m-sam': 'ok', 'm-zoe': 'ok'});
    team = [
      person('m-sam', 'Sam'),
      person('m-zoe', 'Zoe'),
      person('m-later', 'Later Lee', state: 'scheduled'),
      person('m-old', 'Old Olga', state: 'revoked'),
      person('m-door', 'Door Dan', role: 'door'),
      person('m-other', 'Other Ola', venue: 'v2'),
      person('m-boss', 'Boss Bea', role: 'manager'),
    ];
    teamFailure = null;
  });

  testWidgets('a confirmed booking shows who serves the table, or that nobody does; an unpaid one shows nothing', (tester) async {
    desk.assignments['b2'] = 'm-zoe';
    await open(tester, host());
    expect(find.byKey(const Key('server-b1')), findsOneWidget);
    expect(find.text('No server yet'), findsOneWidget);
    expect(find.text('Give to a server'), findsOneWidget);
    expect(find.text('Server: Zoe'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.byKey(const Key('server-b3')), findsNothing);
  });

  testWidgets('an unpaid booking, when the list shows everything, still has no server line: it cannot be given to a server', (tester) async {
    await open(tester, host());
    await tester.tap(find.text('Everything'));
    await tester.pumpAndSettle();
    expect(find.text('Linus Torvalds'), findsOneWidget, reason: 'the pending booking is on the list now, so the check below means something');
    expect(find.byKey(const Key('server-b3')), findsNothing);
    expect(find.byKey(const Key('assign-b3')), findsNothing);
    expect(find.byKey(const Key('assign-b1')), findsOneWidget);
  });

  testWidgets('it reads the assignments for the same nights as the bookings', (tester) async {
    await open(tester, host());
    final call = desk.calls.firstWhere((c) => c.$1 == 'list_venue_booking_servers');
    expect(call.$2, {'p_venue': 'v1', 'p_from': '2026-10-09', 'p_to': '2026-10-09'});
    expect(floor.params.first, {'p_venue': 'v1', 'p_from': '2026-10-09', 'p_to': '2026-10-09'});
  });

  testWidgets('the picker offers this club\'s servers: active or starting later, nobody else', (tester) async {
    List<ServerOption>? offered;
    String? current = 'not called';
    await open(tester, host(pick: (c, options, cur) async {
      offered = options;
      current = cur;
      return null;
    }));
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    expect(offered!.map((o) => o.label), ['Later Lee', 'Sam', 'Zoe']);
    expect(offered!.firstWhere((o) => o.label == 'Later Lee').starts, isTrue);
    expect(current, isNull, reason: 'nobody has b1 yet');
    expect(desk.calls.where((c) => c.$1 == 'assign_booking_server'), isEmpty, reason: 'backing out changes nothing');
  });

  testWidgets('giving a table to a server sends it and shows the new server', (tester) async {
    await open(tester, host(pick: (c, options, cur) async => ServerChoice(options.firstWhere((o) => o.label == 'Sam').membershipId)));
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    final call = desk.calls.lastWhere((c) => c.$1 == 'assign_booking_server');
    expect(call.$2, {'p_booking': 'b1', 'p_membership': 'm-sam'});
    expect(desk.assignments['b1'], 'm-sam');
    expect(find.text('Server: Sam'), findsOneWidget);
    expect(find.text('No server yet'), findsOneWidget, reason: 'the other confirmed booking is untouched');
  });

  testWidgets('changing the server tells the picker who has it now, and sends the new one', (tester) async {
    desk.assignments['b1'] = 'm-sam';
    String? current;
    await open(tester, host(pick: (c, options, cur) async {
      current = cur;
      return const ServerChoice('m-zoe');
    }));
    expect(find.text('Server: Sam'), findsOneWidget);
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    expect(current, 'm-sam');
    expect(desk.assignments['b1'], 'm-zoe');
    expect(find.text('Server: Zoe'), findsOneWidget);
  });

  testWidgets('choosing the server who already has it sends nothing', (tester) async {
    desk.assignments['b1'] = 'm-sam';
    await open(tester, host(pick: (c, options, cur) async => const ServerChoice('m-sam')));
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    expect(desk.calls.where((c) => c.$1 == 'assign_booking_server'), isEmpty);
  });

  testWidgets('the button waits while the table is being given out, so a second tap cannot send it twice', (tester) async {
    final gate = Completer<void>();
    var picked = 0;
    await open(tester, host(pick: (c, options, cur) async {
      picked++;
      return const ServerChoice('m-sam');
    }));
    desk.hold = gate.future;
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextButton>(find.byKey(const Key('assign-b1'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('assign-b1')), warnIfMissed: false);
    await tester.pump();
    expect(picked, 1);
    gate.complete();
    desk.hold = null;
    await tester.pumpAndSettle();
    expect(desk.calls.where((c) => c.$1 == 'assign_booking_server'), hasLength(1));
    expect(find.text('Server: Sam'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('assign-b1'))).onPressed, isNotNull, reason: 'free to change again once it is done');
  });

  testWidgets('taking the server off', (tester) async {
    desk.assignments['b1'] = 'm-sam';
    await open(tester, host(pick: (c, options, cur) async => const ServerChoice(null)));
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    expect(desk.calls.lastWhere((c) => c.$1 == 'unassign_booking_server').$2, {'p_booking': 'b1'});
    expect(desk.assignments, isEmpty);
    expect(find.text('No server yet'), findsNWidgets(2));
  });

  testWidgets('a refusal is shown in the database\'s words and the row shows what is really true', (tester) async {
    await open(tester, host(pick: (c, options, cur) async {
      desk.staff['m-sam'] = 'revoked';   // their access was taken away a moment ago
      return const ServerChoice('m-sam');
    }));
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    expect(find.text('That person no longer has access to this club.'), findsOneWidget);
    expect(desk.assignments, isEmpty);
    expect(find.text('No server yet'), findsNWidgets(2));
  });

  testWidgets('a server who can no longer serve the table is shown in words, so the table does not look covered', (tester) async {
    desk.assignments['b1'] = 'm-old';
    desk.staff['m-old'] = 'revoked';
    await open(tester, host());
    expect(find.text('Server: Old Olga (access ended)'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('server-b1'))).style?.color, const Color(0xFFFFB300), reason: 'amber, so the table does not look covered');
    // They cannot be offered again, but the table can be given to someone else.
    expect(find.byKey(const Key('assign-b1')), findsOneWidget);
  });

  testWidgets('a server who is not on the team list at all is not given a name', (tester) async {
    desk.assignments['b1'] = 'm-gone';
    desk.staff['m-gone'] = 'revoked';
    await open(tester, host());
    expect(find.text('Server: A server who no longer has access'), findsOneWidget);
  });

  testWidgets('the button waits while the team is loading or cannot be loaded, so nobody is picked from an empty list', (tester) async {
    teamFailure = Exception('SocketException: connection lost');
    desk.assignments['b2'] = 'm-zoe';
    await open(tester, host());
    expect(tester.widget<TextButton>(find.byKey(const Key('assign-b1'))).onPressed, isNull);
    expect(find.text('Server: …'), findsOneWidget, reason: 'the name is not known, and that is not shown as "no longer has access"');
    expect(find.textContaining('no longer has access'), findsNothing);
  });

  testWidgets('without the business there is no assignment at all, and the footnote is the old one', (tester) async {
    await open(tester, host(orgId: null));
    expect(find.byKey(const Key('assign-b1')), findsNothing);
    expect(desk.calls, isEmpty);
    expect(find.textContaining('table assignment'), findsOneWidget);
  });

  testWidgets('with the business the footnote no longer says assignment is missing', (tester) async {
    await open(tester, host());
    expect(find.textContaining('table assignment'), findsNothing);
    expect(find.textContaining('Walk-ins, guest allowances, check-in and bottle orders'), findsOneWidget);
  });

  testWidgets('a server without the migration simply does not offer assignment; the bookings still show', (tester) async {
    desk.failOn['list_venue_booking_servers'] = PostgrestException(message: 'nope', code: '42883');
    await open(tester, host());
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.byKey(const Key('assign-b1')), findsNothing);
    expect(find.textContaining('could not be loaded'), findsNothing);
  });

  testWidgets('any other failure to read the assignments is said, per booking, and the bookings still show', (tester) async {
    desk.failOn['list_venue_booking_servers'] = Exception('SocketException: connection lost');
    await open(tester, host());
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.byKey(const Key('servers-error-b1')), findsOneWidget);
    expect(find.byKey(const Key('servers-error-b2')), findsOneWidget);
    expect(find.byKey(const Key('servers-error-b3')), findsNothing);
    expect(find.byKey(const Key('assign-b1')), findsNothing);
  });

  testWidgets('the real picker lists the servers, marks the current one, and can take the server off', (tester) async {
    desk.assignments['b1'] = 'm-sam';
    await open(
      tester,
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          floorServiceProvider.overrideWithValue(floor.service),
          serverDeskServiceProvider.overrideWithValue(desk.service),
          teamServiceProvider.overrideWithValue(TeamService(rpc: (f, {params}) async => team)),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: FloorScreen(venueId: 'v1', venueName: 'Club A', orgId: 'o1', clock: friday9pm, pickNight: (c, i) async => null, contact: (u) async {})),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    expect(find.text('Who serves this table?'), findsOneWidget);
    expect(find.byKey(const Key('pick-m-sam')), findsOneWidget);
    expect(find.byKey(const Key('pick-m-zoe')), findsOneWidget);
    expect(find.byKey(const Key('pick-m-old')), findsNothing);
    expect(find.byKey(const Key('pick-m-door')), findsNothing);
    expect(find.text('Starts later'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('pick-m-sam')), matching: find.byIcon(Icons.check)), findsOneWidget, reason: 'the current server is ticked');
    expect(find.descendant(of: find.byKey(const Key('pick-m-zoe')), matching: find.byIcon(Icons.check)), findsNothing);
    await tester.tap(find.byKey(const Key('pick-m-zoe')));
    await tester.pumpAndSettle();
    expect(desk.assignments['b1'], 'm-zoe', reason: 'the person tapped, not the first in the list');
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-none')));
    await tester.pumpAndSettle();
    expect(desk.assignments, isEmpty);
  });

  testWidgets('the real picker with nobody to pick says how to get a server', (tester) async {
    team = [person('m-boss', 'Boss Bea', role: 'manager')];
    await open(
      tester,
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          floorServiceProvider.overrideWithValue(floor.service),
          serverDeskServiceProvider.overrideWithValue(desk.service),
          teamServiceProvider.overrideWithValue(TeamService(rpc: (f, {params}) async => team)),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: FloorScreen(venueId: 'v1', venueName: 'Club A', orgId: 'o1', clock: friday9pm, pickNight: (c, i) async => null, contact: (u) async {})),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('assign-b1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker-empty')), findsOneWidget);
    expect(find.byKey(const Key('pick-none')), findsNothing, reason: 'nobody has the table, so there is no one to take off');
  });
}
