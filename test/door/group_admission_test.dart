import 'dart:async';

import 'package:bottles_up_vendor/features/door/logic/door_rules.dart';
import 'package:bottles_up_vendor/features/door/providers/door_providers.dart';
import 'package:bottles_up_vendor/features/door/screens/door_guests_screen.dart';
import 'package:bottles_up_vendor/features/door/screens/door_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_door_backend.dart';

late FakeDoorBackend db;
ValueChanged<String>? emit;

Widget fakeCamera(BuildContext context, ValueChanged<String> onCode) {
  emit = onCode;
  return const SizedBox(key: Key('fake-camera'));
}

Widget host(Widget screen) => ProviderScope(
      key: UniqueKey(),
      overrides: [doorServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: screen)),
    );

Widget scanScreen() => host(const DoorScanScreen(membershipId: 'm1', cameraBuilder: fakeCamera));
Widget guestsScreen() => host(const DoorGuestsScreen(membershipId: 'm1', debounce: Duration(milliseconds: 10)));

String label(WidgetTester t) => (t.widget(find.byKey(const Key('scan-result-label'))) as Text).data!;
String hint(WidgetTester t) => (t.widget(find.byKey(const Key('scan-result-hint'))) as Text).data!;
String count(WidgetTester t) => (t.widget(find.byKey(const Key('group-count'))) as Text).data!;

/// A tall screen, so the whole list is built and nothing needs scrolling to be found.
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> read(WidgetTester tester, String code) async {
  emit!(code);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// The database as door_admit_group behaves for one group ticket of [quantity] guests: no count answers "group" (nobody admitted); a count admits that many, never
/// more than are left.
class GroupTicket {
  GroupTicket({this.quantity = 4, this.inside = 0});

  final int quantity;
  int inside;

  List<Map<String, dynamic>> answer(Map<String, dynamic>? p) {
    final count = p?['p_count'] as int?;
    final left = quantity - inside;
    if (left == 0) return [groupRow('already_checked_in', quantity: quantity, admitted: inside)];
    if (count == null) return [groupRow('group', quantity: quantity, admitted: inside)];
    if (count > left) return [groupRow('too_many', quantity: quantity, admitted: inside)];
    inside += count;
    return [groupRow('ok', quantity: quantity, admitted: inside)];
  }
}

void main() {
  setUp(() {
    db = FakeDoorBackend();
    emit = null;
    db.handlers['door_events'] = (_) => [eventRow()];
  });

  group('the rules', () {
    test('the three new answers are known, and have wording', () {
      for (final r in ['refunded', 'group', 'too_many']) {
        expect(DoorResult.fromDb(r), isNotNull, reason: r);
      }
      expect(resultCopy[DoorResult.refunded]!.label, 'Refunded');
      expect(resultCopy[DoorResult.refunded]!.tone, Tone.error, reason: 'a refunded order is a red stop, not a hint');
      expect(resultCopy[DoorResult.group]!.tone, Tone.warn);
      expect(resultCopy[DoorResult.tooMany]!.tone, Tone.warn);
    });

    test('a group answer is read with how many are in and how many are left', () {
      final o = parseScanOutcome(groupRow('group', quantity: 4, admitted: 1));
      expect((o.result, o.quantity, o.guestsIn, o.guestsLeft), (DoorResult.group, 4, 1, 3));
      expect(o.chooseCount, isTrue);
      expect(o.isGroup, isTrue);
      expect(o.moreMayCome, isTrue);
      expect(o.admitted, isFalse, reason: 'nobody has been admitted by this answer');
    });

    test('an answer from the older scan has no counts', () {
      final o = parseScanOutcome(scanRow('ok', name: 'Ada', quantity: 2));
      expect((o.guestsIn, o.guestsLeft, o.moreMayCome, o.chooseCount), (null, null, false, false));
    });

    test('only "group" and "too many" ask how many; admitted and already-in answers do not', () {
      for (final r in DoorResult.values) {
        expect(ScanOutcome(r).chooseCount, r == DoorResult.group || r == DoorResult.tooMany, reason: r.db);
      }
    });

    test('the hint says how many to let in when a number of a group was chosen, and "Let them in." otherwise', () {
      expect(admitHint(const ScanOutcome(DoorResult.ok, quantity: 4, admittedNow: 2)), 'Let 2 guests in.');
      expect(admitHint(const ScanOutcome(DoorResult.ok, quantity: 4, admittedNow: 1)), 'Let 1 guest in.');
      expect(admitHint(const ScanOutcome(DoorResult.ok, quantity: 1)), 'Let them in.');
      expect(admitHint(const ScanOutcome(DoorResult.ok, quantity: 1, admittedNow: 1)), 'Let them in.');
      expect(admitHint(const ScanOutcome(DoorResult.ok, quantity: 4)), 'Let them in.');
    });

    test('the progress says how many of the group are in and how many may still come, and is silent for one guest or no counts', () {
      expect(groupProgress(const ScanOutcome(DoorResult.ok, quantity: 4, guestsIn: 2, guestsLeft: 2)), '2 of 4 are in. 2 may still come in with this ticket.');
      expect(groupProgress(const ScanOutcome(DoorResult.ok, quantity: 4, guestsIn: 1, guestsLeft: 3)), '1 of 4 is in. 3 may still come in with this ticket.');
      expect(groupProgress(const ScanOutcome(DoorResult.alreadyCheckedIn, quantity: 4, guestsIn: 4, guestsLeft: 0)), 'All 4 are in.');
      expect(groupProgress(const ScanOutcome(DoorResult.ok, quantity: 1, guestsIn: 1, guestsLeft: 0)), isNull);
      expect(groupProgress(const ScanOutcome(DoorResult.ok, quantity: 4)), isNull);
    });

    test('an event given the exact count shows it, never below zero', () {
      final e = parseDoorEvent(eventRow(expected: 10, admitted: 6))!;
      expect(e.withAdmitted(4).guestsAdmitted, 4);
      expect(e.withAdmitted(-3).guestsAdmitted, 0);
      expect(e.withAdmitted(4).guestsExpected, 10);
      expect(e.withAdmitted(4).title, e.title);
    });

    test('a guest is fully in by the exact count when there is one, otherwise by the older checked-in time', () {
      final fresh = parseGuest(guestRow('Gina', 'G1', quantity: 4))!;
      expect((fresh.isIn, fresh.partlyIn), (false, false));
      final older = parseGuest(guestRow('Gina', 'G1', quantity: 4, checkedInAt: '2026-10-09T21:00:00Z'))!;
      expect((older.isIn, older.partlyIn), (true, false), reason: 'admitted whole by an older scanner');
      final partly = older.withAdmittedKeepingTime(2);
      expect((partly.isIn, partly.partlyIn, partly.admittedCount), (false, true, 2), reason: 'the exact count wins over the checked-in time');
      expect(partly.checkedInAt, older.checkedInAt);
      expect(older.withAdmittedKeepingTime(4).isIn, isTrue);
      expect(fresh.withAdmitted(4).isIn, isTrue);
      expect(fresh.withAdmitted(1).partlyIn, isTrue);
    });
  });

  group('the service', () {
    test('a scan asks door_admit_group with no count, and a one-guest ticket is admitted', () async {
      db.handlers['door_admit_group'] = (_) => [groupRow('ok', name: 'Solo Sam', quantity: 1, admitted: 1)];
      final o = await db.service.scan('  T-1 ', 'e1');
      expect(db.paramsOf('door_admit_group').single, {'p_ticket_code': 'T-1', 'p_count': null, 'p_event': 'e1'});
      expect((o.result, o.guestsIn, o.guestsLeft), (DoorResult.ok, 1, 0));
      expect(db.count('door_scan_ticket'), 0);
    });

    test('a group ticket answers "group" and admits nobody', () async {
      db.handlers['door_admit_group'] = (_) => [groupRow('group')];
      final o = await db.service.scan('T-G', 'e1');
      expect(o.chooseCount, isTrue);
      expect(db.paramsOf('door_admit_group').single!['p_count'], isNull);
    });

    test('without group admission on the server the older whole-order scan is used, and remembered', () async {
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada', quantity: 2)];
      final service = db.service;
      expect((await service.scan('T-1', 'e1')).result, DoorResult.ok);
      expect((await service.scan('T-2', 'e1')).result, DoorResult.ok);
      expect(db.count('door_admit_group'), 1, reason: 'asked once, then known to be missing');
      expect(db.count('door_scan_ticket'), 2);
    });

    test('a failed group scan is a failed scan, not a fall back (the server has the function)', () async {
      db.handlers['door_admit_group'] = (_) => throw PostgrestException(message: 'not authorized', code: 'P0001');
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada')];
      expect((await db.service.scan('T-1', 'e1')).result, DoorResult.accessEnded);
      expect(db.count('door_scan_ticket'), 0, reason: 'nobody is admitted by the other scan when this person has lost access');
    });

    test('admitting a count sends it, and an admission says how many were admitted now', () async {
      final ticket = GroupTicket();
      db.handlers['door_admit_group'] = (p) => ticket.answer(p);
      final o = await db.service.admit('T-G', 2, 'e1');
      expect(db.paramsOf('door_admit_group').single, {'p_ticket_code': 'T-G', 'p_count': 2, 'p_event': 'e1'});
      expect((o.result, o.guestsIn, o.guestsLeft, o.admittedNow), (DoorResult.ok, 2, 2, 2));
    });

    test('more than are left is refused by the database and nobody is admitted', () async {
      final ticket = GroupTicket(inside: 3);
      db.handlers['door_admit_group'] = (p) => ticket.answer(p);
      final o = await db.service.admit('T-G', 2, 'e1');
      expect((o.result, o.admittedNow), (DoorResult.tooMany, null));
      expect(ticket.inside, 3);
    });

    test('a count below one, or no code, never leaves the phone', () async {
      db.handlers['door_admit_group'] = (_) => throw StateError('should not be called');
      expect((await db.service.admit('T-G', 0, 'e1')).result, DoorResult.scanError);
      expect((await db.service.admit('T-G', -1, 'e1')).result, DoorResult.scanError);
      expect((await db.service.admit('   ', 1, 'e1')).result, DoorResult.scanError);
      expect(db.count('door_admit_group'), 0);
    });

    test('a failed admission never throws: it is "access ended" or "scan failed"', () async {
      db.handlers['door_admit_group'] = (_) => throw PostgrestException(message: 'not authorized');
      expect((await db.service.admit('T-G', 1, 'e1')).result, DoorResult.accessEnded);
      db.handlers['door_admit_group'] = (_) => throw Exception('socket closed');
      expect((await db.service.admit('T-G', 1, 'e1')).result, DoorResult.scanError);
    });

    test('the event list takes the exact count of guests in from the server', () async {
      db.handlers['door_events'] = (_) => [eventRow(id: 'e1', expected: 10, admitted: 6), eventRow(id: 'e2', title: 'Second', expected: 5, admitted: 2)];
      db.handlers['door_admission_counts'] = (_) => [
            {'event_id': 'e1', 'guests_admitted': 4},
          ];
      final events = await db.service.events('m1');
      expect(db.paramsOf('door_admission_counts').single, {'p_events': ['e1', 'e2']});
      expect(events[0].guestsAdmitted, 4, reason: 'the exact figure replaces the older one');
      expect(events[1].guestsAdmitted, 2, reason: 'an event the server has no figure for keeps the older one');
    });

    test('without the exact counts the older figure stands, and the events still load', () async {
      db.handlers['door_events'] = (_) => [eventRow(admitted: 6)];
      final service = db.service;
      final events = await service.events('m1');
      expect(events.single.guestsAdmitted, 6);
      await service.events('m1');
      expect(db.count('door_admission_counts'), 1, reason: 'asked once, then known to be missing');
    });

    test('a failed count read leaves the events as they were', () async {
      db.handlers['door_events'] = (_) => [eventRow(admitted: 6)];
      db.handlers['door_admission_counts'] = (_) => throw Exception('offline');
      expect((await db.service.events('m1')).single.guestsAdmitted, 6);
    });

    test('no events means no count read', () async {
      db.handlers['door_events'] = (_) => <Map<String, dynamic>>[];
      expect(await db.service.events('m1'), isEmpty);
      expect(db.count('door_admission_counts'), 0);
    });

    test('a guest search takes how many of each ticket are in, and keeps the older time for the rest', () async {
      db.handlers['door_guests'] = (_) => [guestRow('Gina', 'G1', quantity: 4, checkedInAt: '2026-10-09T21:00:00Z'), guestRow('Old Ollie', 'G2', quantity: 3, checkedInAt: '2026-10-09T21:00:00Z'), guestRow('New Nia', 'G3', quantity: 2)];
      db.handlers['door_guest_admissions'] = (_) => [
            {'order_id': 'o-G1', 'admitted': 2},
          ];
      final guests = await db.service.guests('e1', 'gi');
      expect(db.paramsOf('door_guest_admissions').single, {'p_event': 'e1'});
      expect([for (final g in guests) (g.ticketCode, g.isIn, g.partlyIn)], [('G1', false, true), ('G2', true, false), ('G3', false, false)]);
    });

    test('a failed read of the counts leaves the search as it was', () async {
      db.handlers['door_guests'] = (_) => [guestRow('Gina', 'G1', quantity: 4, checkedInAt: '2026-10-09T21:00:00Z')];
      db.handlers['door_guest_admissions'] = (_) => throw Exception('offline');
      expect((await db.service.guests('e1', 'gi')).single.isIn, isTrue);
    });
  });

  group('Scan: a group ticket', () {
    late GroupTicket ticket;
    setUp(() {
      ticket = GroupTicket();
      db.handlers['door_admit_group'] = (p) => ticket.answer(p);
    });

    testWidgets('a group is not admitted by the scan: the screen asks how many, starting with everyone who is left', (tester) async {
      tall(tester);
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      expect(label(tester), 'Group ticket');
      expect(find.text('Group Gina'), findsOneWidget);
      expect(find.text('General × 4'), findsOneWidget);
      expect(count(tester), '4');
      expect(find.text('Admit 4 guests'), findsOneWidget);
      expect(ticket.inside, 0, reason: 'nobody was admitted by the scan');
      expect(find.byKey(const Key('group-progress')), findsNothing, reason: 'nobody is in yet: nothing to say about progress');
    });

    testWidgets('the number can be changed between one and what is left', (tester) async {
      tall(tester);
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      await tapKey(tester, 'group-less');
      await tapKey(tester, 'group-less');
      expect(count(tester), '2');
      expect(find.text('Admit 2 guests'), findsOneWidget);
      await tapKey(tester, 'group-less');
      expect(find.text('Admit 1 guest'), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const Key('group-less'))).onPressed, isNull, reason: 'not below one');
      for (var i = 0; i < 6; i++) {
        final more = tester.widget<IconButton>(find.byKey(const Key('group-more')));
        if (more.onPressed == null) break;
        await tapKey(tester, 'group-more');
      }
      expect(count(tester), '4');
      expect(tester.widget<IconButton>(find.byKey(const Key('group-more'))).onPressed, isNull, reason: 'not above what is left');
    });

    testWidgets('admitting two of four: green, "Let 2 guests in.", how many are in and left, and the count of guests in is read again', (tester) async {
      tall(tester);
      db.handlers['door_admission_counts'] = (_) => [
            {'event_id': 'e1', 'guests_admitted': 2},
          ];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      await tapKey(tester, 'group-less');
      await tapKey(tester, 'group-less');
      final eventReads = db.count('door_events');
      await tapKey(tester, 'admit-group');
      expect(label(tester), 'Admit');
      expect(hint(tester), 'Let 2 guests in.');
      expect(find.text('2 of 4 are in. 2 may still come in with this ticket.'), findsOneWidget);
      expect(db.paramsOf('door_admit_group').last, {'p_ticket_code': 'GA-1', 'p_count': 2, 'p_event': 'e1'});
      expect(ticket.inside, 2);
      expect(db.count('door_events'), greaterThan(eventReads));
      expect(find.text('2 of 10 guests in'), findsOneWidget, reason: 'the exact count');
    });

    testWidgets('"Admit more of this group" asks again, and the rest can come in', (tester) async {
      tall(tester);
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      await tapKey(tester, 'group-less');
      await tapKey(tester, 'group-less');
      await tapKey(tester, 'admit-group');
      await tapKey(tester, 'admit-more');
      expect(label(tester), 'Group ticket');
      expect(find.text('2 of 4 are in. 2 may still come in with this ticket.'), findsOneWidget);
      expect(count(tester), '2', reason: 'starts at everyone who is left');
      await tapKey(tester, 'admit-group');
      expect(hint(tester), 'Let 2 guests in.');
      expect(find.text('All 4 are in.'), findsOneWidget);
      expect(find.byKey(const Key('admit-more')), findsNothing, reason: 'nobody is left');
      expect(ticket.inside, 4);
    });

    testWidgets('the same group scanned again once everybody is in is "already checked in", with all four in', (tester) async {
      tall(tester);
      ticket.inside = 4;
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      expect(label(tester), 'Already checked in');
      expect(find.text('All 4 are in.'), findsOneWidget);
      expect(find.byKey(const Key('admit-group')), findsNothing);
    });

    testWidgets('more than are left (another door got there first): the screen says how many are left and offers fewer', (tester) async {
      tall(tester);
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      ticket.inside = 3;
      await tapKey(tester, 'admit-group');
      expect(label(tester), 'More than this ticket allows');
      expect(hint(tester), 'Only 1 is left on this ticket. Choose fewer.');
      expect(count(tester), '1');
      expect(ticket.inside, 3, reason: 'nobody was admitted');
      await tapKey(tester, 'admit-group');
      expect(label(tester), 'Admit');
      expect(ticket.inside, 4);
    });

    testWidgets('while the admission is on its way the buttons wait, and a second tap changes nothing', (tester) async {
      tall(tester);
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      final gate = Completer<void>();
      db.handlers['door_admit_group'] = (p) async {
        if (p?['p_count'] != null) await gate.future;
        return ticket.answer(p);
      };
      await tester.tap(find.byKey(const Key('admit-group')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('admit-group'))).onPressed, isNull);
      expect(find.text('Admitting…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('admit-group')), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(ticket.inside, 4);
      expect(db.paramsOf('door_admit_group').where((p) => p?['p_count'] != null).length, 1);
    });

    testWidgets('two taps in the same instant, before any redraw, still admit once', (tester) async {
      tall(tester);
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      final gate = Completer<void>();
      db.handlers['door_admit_group'] = (p) async {
        if (p?['p_count'] != null) await gate.future;
        return ticket.answer(p);
      };
      await tester.ensureVisible(find.byKey(const Key('admit-group')));
      await tester.tap(find.byKey(const Key('admit-group')));
      await tester.tap(find.byKey(const Key('admit-group')));
      gate.complete();
      await tester.pumpAndSettle();
      expect(db.paramsOf('door_admit_group').where((p) => p?['p_count'] != null).length, 1);
    });

    testWidgets('a lost connection while admitting is "scan failed", and the person can ask again (the database never admits twice)', (tester) async {
      tall(tester);
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-1');
      db.handlers['door_admit_group'] = (p) => p?['p_count'] != null ? throw Exception('offline') : ticket.answer(p);
      await tapKey(tester, 'admit-group');
      expect(label(tester), 'Scan failed');
      expect(ticket.inside, 0);
    });

    testWidgets('a refunded order is a red stop, told apart from an unpaid one', (tester) async {
      tall(tester);
      db.handlers['door_admit_group'] = (_) => [groupRow('refunded', quantity: 2)];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-R');
      expect(label(tester), 'Refunded');
      expect(hint(tester), 'This order was refunded. Do not admit.');
      expect(find.byKey(const Key('admit-group')), findsNothing);
    });

    testWidgets('a ticket for one guest is admitted by the scan alone, as before', (tester) async {
      tall(tester);
      db.handlers['door_admit_group'] = (_) => [groupRow('ok', name: 'Solo Sam', quantity: 1, admitted: 1)];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'GA-S');
      expect(label(tester), 'Admit');
      expect(hint(tester), 'Let them in.');
      expect(find.byKey(const Key('group-progress')), findsNothing);
      expect(find.byKey(const Key('admit-group')), findsNothing);
      expect(find.byKey(const Key('admit-more')), findsNothing);
    });
  });

  group('Scan: a server without group admission', () {
    testWidgets('behaves exactly as before: a whole order is admitted by the scan', (tester) async {
      tall(tester);
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada', tier: 'General', quantity: 2)];
      await tester.pumpWidget(scanScreen());
      await tester.pumpAndSettle();
      await read(tester, 'T-1');
      expect(label(tester), 'Admit');
      expect(hint(tester), 'Let them in.');
      expect(find.byKey(const Key('admit-group')), findsNothing);
    });
  });

  group('Guests: a group ticket', () {
    late GroupTicket ticket;
    setUp(() {
      ticket = GroupTicket(inside: 1);
      db.handlers['door_admit_group'] = (p) => ticket.answer(p);
      db.handlers['door_guests'] = (_) => [guestRow('Group Gina', 'GA-1', quantity: 4, checkedInAt: '2026-10-09T21:00:00Z'), guestRow('Fully Fran', 'GA-2', quantity: 2, checkedInAt: '2026-10-09T21:00:00Z'), guestRow('New Nia', 'GA-3', quantity: 1)];
      db.handlers['door_guest_admissions'] = (_) => [
            {'order_id': 'o-GA-1', 'admitted': 1},
            {'order_id': 'o-GA-2', 'admitted': 2},
          ];
    });

    Future<void> search(WidgetTester tester) async {
      await tester.pumpWidget(guestsScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('guest-search-field')), 'gi');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    }

    testWidgets('the list says how many of a group are in: all (In), some (n of m, Admit more) or none (Admit)', (tester) async {
      tall(tester);
      await search(tester);
      expect(find.byKey(const Key('guest-partly-GA-1')), findsOneWidget);
      expect(find.text('1 of 4 in'), findsOneWidget);
      expect(find.text('Admit more'), findsOneWidget);
      expect(find.byKey(const Key('guest-in')), findsOneWidget, reason: 'the fully admitted one');
      expect(find.byKey(const Key('admit-GA-3')), findsOneWidget);
      expect(find.byKey(const Key('guest-partly-GA-3')), findsNothing);
      expect(find.byKey(const Key('admit-GA-2')), findsNothing);
    });

    testWidgets('Admit more asks how many, admits that many, and the list shows the new count', (tester) async {
      tall(tester);
      await search(tester);
      await tapKey(tester, 'admit-GA-1');
      expect(label(tester), 'Group ticket');
      expect(find.text('1 of 4 is in. 3 may still come in with this ticket.'), findsOneWidget);
      expect(count(tester), '3');
      await tapKey(tester, 'group-less');
      await tapKey(tester, 'admit-group');
      expect(hint(tester), 'Let 2 guests in.');
      expect(ticket.inside, 3);
      await tapKey(tester, 'scan-next');
      expect(find.text('3 of 4 in'), findsOneWidget);
    });

    testWidgets('admitting everyone who is left marks the guest In', (tester) async {
      tall(tester);
      await search(tester);
      await tapKey(tester, 'admit-GA-1');
      await tapKey(tester, 'admit-group');
      expect(find.text('All 4 are in.'), findsOneWidget);
      await tapKey(tester, 'scan-next');
      expect(find.byKey(const Key('admit-GA-1')), findsNothing);
      expect(find.byKey(const Key('guest-in')), findsNWidgets(2));
    });

    testWidgets('a guest of one ticket seat is admitted straight from the list', (tester) async {
      tall(tester);
      db.handlers['door_admit_group'] = (p) => p?['p_ticket_code'] == 'GA-3' ? [groupRow('ok', name: 'New Nia', quantity: 1, admitted: 1)] : ticket.answer(p);
      await search(tester);
      await tapKey(tester, 'admit-GA-3');
      expect(label(tester), 'Admit');
      expect(find.byKey(const Key('admit-group')), findsNothing);
    });
  });
}
