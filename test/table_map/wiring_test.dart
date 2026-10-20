import 'package:bottles_up_vendor/features/booking_detail/logic/booking_detail_rules.dart';
import 'package:bottles_up_vendor/features/owner/providers/owner_providers.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/floors_editor.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/payment_settings_editor.dart';
import 'package:bottles_up_vendor/features/owner/screens/setup/table_types_editor.dart';
import 'package:bottles_up_vendor/features/table_map/providers/table_map_providers.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:bottles_up_vendor/features/table_service/screens/tonight_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../owner/fake_owner_backend.dart';
import '../owner/fake_setup_backend.dart';
import '../table_service/fake_table_backend.dart';
import 'fake_table_map_backend.dart';

late FakeTableMapBackend map;
late FakeSetupBackend setup;
late FakeTableBackend desk;

Widget host(Widget home) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        tableMapServiceProvider.overrideWithValue(map.service),
        venueSetupServiceProvider.overrideWithValue(setup.service),
        ownerServiceProvider.overrideWithValue(FakeOwnerBackend().service),
        tableServiceServiceProvider.overrideWithValue(desk.service),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: home),
    );

Future<void> open(WidgetTester tester, Widget w, {double height = 3200}) async {
  tester.view.physicalSize = Size(800, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(w));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    map = FakeTableMapBackend();
    setup = FakeSetupBackend();
    desk = FakeTableBackend()..role = 'manager';
    desk.now = DateTime(2026, 10, 9, 21);
  });

  group('floor plans', () {
    testWidgets('each floor has Place tables, which opens the placement editor for that floor', (tester) async {
      setup.floors.addAll([floorRowJson('f1', 'Main room', image: ''), floorRowJson('f2', 'Terrace', image: '')]);
      await open(tester, const FloorsEditor(venueId: 'v1', orgId: 'o1'));
      expect(find.byKey(const Key('place-tables-f1')), findsOneWidget);
      expect(find.byKey(const Key('place-tables-f2')), findsOneWidget);
      await tapKey(tester, 'place-tables-f2');
      expect(find.text('Place tables · Terrace'), findsOneWidget);
      expect(find.byKey(const Key('placement-table-t1')), findsOneWidget);
    });

    testWidgets('after placing tables the floor list is read again, so its count is right', (tester) async {
      setup.floors.add(floorRowJson('f1', 'Main room', image: ''));
      await open(tester, const FloorsEditor(venueId: 'v1', orgId: 'o1'));
      final before = setup.calls.where((c) => c.$1 == 'list_venue_floors').length;
      await tapKey(tester, 'place-tables-f1');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(setup.calls.where((c) => c.$1 == 'list_venue_floors').length, greaterThan(before));
    });
  });

  group('a table\'s form', () {
    Future<void> openForm(WidgetTester tester, {String table = 't1'}) async {
      setup.tables.add({'type_id': 't1', 'name': 'Booth', 'max_guests': 6, 'min_spend_cents': 0, 'deposit_cents': 10000, 'inventory_count': 1, 'is_featured': false, 'pricing_mode': 'flat', 'booking_count': 0});
      await open(tester, const TableTypesEditor(venueId: 'v1', orgId: 'o1'), height: 2400);
      await tapKey(tester, 'edit-$table');
    }

    testWidgets('an existing table shows what a booking of it includes, and the admissions can be changed on their own', (tester) async {
      map.table('t1')['included_admissions'] = 2;
      await openForm(tester);
      expect(find.text('Admissions included: 2 guests'), findsOneWidget);
      await tapKey(tester, 'included-admissions');
      await tester.enterText(find.byKey(const Key('admissions-field')), '4');
      await tapKey(tester, 'admissions-save');
      expect(map.paramsOf('set_table_included_admissions').single, {'p_venue': 'v1', 'p_type': 't1', 'p_count': 4});
      expect(find.text('Admissions included: 4 guests'), findsOneWidget);
      expect(find.textContaining('New bookings of this table carry it'), findsOneWidget);
      expect(setup.calls.where((c) => c.$1 == 'save_venue_table_type'), isEmpty, reason: 'the table itself was not saved');
    });

    testWidgets('a new table has no admissions line (it has to exist first)', (tester) async {
      await open(tester, const TableTypesEditor(venueId: 'v1', orgId: 'o1'), height: 2400);
      await tapKey(tester, 'add-table');
      expect(find.byKey(const Key('included-admissions')), findsNothing);
    });

    testWidgets('the form says where placing tables is done now', (tester) async {
      await openForm(tester);
      expect(find.textContaining('set under Rooms and floor plan'), findsOneWidget);
    });
  });

  group('payment settings', () {
    Future<void> openSettings(WidgetTester tester) async {
      setup.tables.add({'type_id': 't1', 'name': 'Booth', 'max_guests': 6, 'min_spend_cents': 0, 'deposit_cents': 10000, 'inventory_count': 1, 'is_featured': false, 'pricing_mode': 'flat', 'booking_count': 0});
      await open(tester, const PaymentSettingsEditor(venueId: 'v1', orgId: 'o1'));
    }

    testWidgets('says who receives the deposit now, and opens the editor', (tester) async {
      map.depositTerms = {'recipient': 'organizer', 'venue_pct': 0, 'purpose': 'admission'};
      await openSettings(tester);
      expect(find.text('The approved organizer receives the deposit, as admission.'), findsOneWidget);
      await tapKey(tester, 'deposit-terms-open');
      expect(find.byKey(const Key('deposit-terms')), findsOneWidget);
    });

    testWidgets('before a choice it says the venue keeps the deposit, and after saving in the editor the line is updated', (tester) async {
      await openSettings(tester);
      expect(find.text('Who receives the deposit: not chosen yet (the venue keeps it).'), findsOneWidget);
      await tapKey(tester, 'deposit-terms-open');
      await tapKey(tester, 'recipient-venue');
      await tapKey(tester, 'purpose-admission');
      await tapKey(tester, 'deposit-terms-save');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('The venue keeps the deposit, as admission.'), findsOneWidget);
    });

    testWidgets('when the terms cannot be read the rest of the settings still show', (tester) async {
      map.beforeCall = (f) => throw Exception('boom');
      await openSettings(tester);
      expect(find.byKey(const Key('deposit-terms-load-failed')), findsOneWidget);
      expect(find.byKey(const Key('payment-settings')), findsOneWidget);
    });
  });

  group('a booking\'s page', () {
    Widget detail() => const TableDetailScreen(bookingId: 'b1', title: 'VIP booth · Ada Lovelace');

    void seed({String status = 'paid', bool reconciled = false}) {
      desk.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD', status: status, total: 10000, paid: 6000, guests: 4);
      desk.bookings['b1']!.reconciled = reconciled;
      map.bookings.add({'id': 'b1', 'table': 't2', 'slot': 's1', 'guests': 3, 'status': 'paid', 'seated': false, 'name': 'Ada Lovelace'});
    }

    testWidgets('a manager sees the terms of the booking and can move it', (tester) async {
      seed();
      await open(tester, detail());
      expect(find.byKey(const Key('terms-card')), findsOneWidget);
      expect(find.text('Deposit: \$25.00'), findsOneWidget);
      expect(find.byKey(const Key('move-booking')), findsOneWidget);
    });

    testWidgets('moving it re-reads the booking, so the page shows the new table', (tester) async {
      seed();
      await open(tester, detail());
      final reads = desk.calls.where((c) => c.$1 == 'desk_booking_money').length;
      await tapKey(tester, 'move-booking');
      await tapKey(tester, 'move-option-t3');
      await tester.enterText(find.byKey(const Key('move-reason')), 'Guest asked');
      await tester.pump();
      await tapKey(tester, 'move-confirm');
      expect(map.bookings.single['table'], 't3');
      expect(desk.calls.where((c) => c.$1 == 'desk_booking_money').length, greaterThan(reads));
    });

    testWidgets('the server of the table sees the terms but cannot move the booking', (tester) async {
      seed();
      desk.role = 'server';
      desk.assignments['b1'] = desk.myMembership;
      map.role = 'server';
      await open(tester, detail());
      expect(find.byKey(const Key('terms-card')), findsOneWidget);
      expect(find.byKey(const Key('move-booking')), findsNothing);
    });

    testWidgets('a booking that is not confirmed cannot be moved', (tester) async {
      seed(status: 'pending');
      await open(tester, detail());
      expect(find.byKey(const Key('terms-card')), findsOneWidget);
      expect(find.byKey(const Key('move-booking')), findsNothing);
    });

    testWidgets('a table that has been closed out cannot be moved', (tester) async {
      seed(reconciled: true);
      await open(tester, detail());
      expect(find.byKey(const Key('move-booking')), findsNothing);
    });

    testWidgets('if the terms cannot be read the money and the payments still show', (tester) async {
      seed();
      map.beforeCall = (f) => throw Exception('boom');
      await open(tester, detail());
      expect(find.byKey(const Key('terms-error')), findsOneWidget);
      expect(find.byKey(const Key('money-card')), findsOneWidget);
    });
  });

  group('Tonight', () {
    const manager = Workspace(
      membershipId: 'w2',
      orgId: 'o1',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: WorkspaceRole.manager,
      venueId: 'v1',
      venueName: 'Club A',
    );

    testWidgets('has a Tables button that opens the floor map for the night on screen', (tester) async {
      await open(tester, Scaffold(body: TonightScreen(workspace: manager, clock: () => DateTime(2026, 10, 9, 21))));
      await tapKey(tester, 'open-table-map');
      expect(find.byKey(const Key('table-map')), findsOneWidget);
      expect(map.paramsOf('desk_table_states').single, {'p_venue': 'v1', 'p_night': '2026-10-09'});
      expect(find.text('Club A'), findsWidgets);
    });

    testWidgets('on another night it opens that night', (tester) async {
      await open(tester, Scaffold(body: TonightScreen(workspace: manager, clock: () => DateTime(2026, 10, 9, 21))));
      await tapKey(tester, 'night-next');
      await tapKey(tester, 'open-table-map');
      expect(map.paramsOf('desk_table_states').single['p_night'], '2026-10-10');
    });

    testWidgets('coming back reads Tonight again', (tester) async {
      await open(tester, Scaffold(body: TonightScreen(workspace: manager, clock: () => DateTime(2026, 10, 9, 21))));
      final before = desk.calls.where((c) => c.$1 == 'desk_tonight').length;
      await tapKey(tester, 'open-table-map');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(desk.calls.where((c) => c.$1 == 'desk_tonight').length, greaterThan(before));
    });
  });

  group('the booking\'s Activity', () {
    ActivityEntry entry(Map<String, dynamic> details) => ActivityEntry(at: DateTime(2026, 10, 9, 22), kind: 'audit', action: 'booking.moved', actor: 'Mo', details: details);

    test('a move reads as one, with the reason when the database gave it', () {
      expect(activitySentence(entry({'reason': 'Guest asked'})), 'The booking was moved to another table: Guest asked');
      expect(activitySentence(entry({})), 'The booking was moved to another table');
    });
  });
}
