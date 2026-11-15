import 'package:bottles_up_vendor/features/door/logic/door_rules.dart';
import 'package:bottles_up_vendor/features/door/providers/door_providers.dart';
import 'package:bottles_up_vendor/features/door/screens/door_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_door_backend.dart';

// Exits and live occupancy at the door (website 20261122100000). The bar says "Inside now" only where exits are tracked and "Total checked in" otherwise; in Exit mode a scan records one
// guest leaving; the count is read again from the database after every change, never guessed.

Map<String, dynamic> occupancyRow({bool tracking = true, int admitted = 5, int exited = 1, int? inside}) => {
  'tracking': tracking,
  'admitted': admitted,
  'exited': exited,
  'inside': inside ?? (admitted - exited),
};

Map<String, dynamic> exitRow(String result, {String? name = 'Group Gina', int quantity = 4, int admitted = 2, int exited = 1, int inside = 1}) => {
  'result': result,
  'customer_name': name,
  'quantity': quantity,
  'admitted': admitted,
  'exited': exited,
  'inside': inside,
};

late FakeDoorBackend db;
ValueChanged<String>? emit;

Widget fakeCamera(BuildContext context, ValueChanged<String> onCode) {
  emit = onCode;
  return const SizedBox(key: Key('fake-camera'));
}

Widget scanScreen() => ProviderScope(
  key: UniqueKey(),
  overrides: [doorServiceProvider.overrideWithValue(db.service)],
  child: MaterialApp(theme: ThemeData.dark(), home: const Scaffold(body: DoorScanScreen(membershipId: 'm1', cameraBuilder: fakeCamera))),
);

Future<void> read(WidgetTester tester, String code) async {
  emit!(code);
  await tester.pumpAndSettle();
}

Future<void> openScan(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(scanScreen());
  await tester.pumpAndSettle();
}

String text(WidgetTester t, String key) => (t.widget(find.byKey(Key(key))) as Text).data!;

void main() {
  group('Reading occupancy', () {
    test('a complete answer is read as it is', () {
      final o = parseOccupancy(occupancyRow(admitted: 7, exited: 3))!;
      expect([o.tracking, o.admitted, o.exited, o.inside], [true, 7, 3, 4]);
    });

    test('anything incomplete or of the wrong kind is not guessed at', () {
      expect(parseOccupancy(null), isNull);
      expect(parseOccupancy({'tracking': true, 'admitted': 5, 'exited': 1}), isNull, reason: 'no inside');
      expect(parseOccupancy({'tracking': 'yes', 'admitted': 5, 'exited': 1, 'inside': 4}), isNull);
      expect(parseOccupancy({'tracking': true, 'admitted': '5', 'exited': 1, 'inside': 4}), isNull);
    });

    test('"Inside now" only where exits are tracked, otherwise "Total checked in"', () {
      expect(occupancyHeadline(parseOccupancy(occupancyRow(tracking: true, admitted: 7, exited: 3))!), 'Inside now: 4');
      expect(occupancyHeadline(parseOccupancy(occupancyRow(tracking: false, admitted: 7, exited: 0))!), 'Total checked in: 7');
    });

    test('the line under it breaks the figure down, or says how many of those expected are in', () {
      expect(occupancySummary(parseOccupancy(occupancyRow(admitted: 7, exited: 3)), expected: 50), '4 inside now · 7 checked in · 3 left');
      expect(occupancySummary(parseOccupancy(occupancyRow(tracking: false, admitted: 7, exited: 0)), expected: 50), '7 of 50 guests checked in');
      expect(occupancySummary(parseOccupancy(occupancyRow(tracking: false, admitted: 1, exited: 0)), expected: 1), '1 of 1 guest checked in');
      expect(occupancySummary(null, expected: 50), '');
    });
  });

  group('Reading an exit answer', () {
    test('each answer the database gives is read', () {
      for (final r in ['ok', 'not_tracking', 'nothing_inside', 'too_many', 'not_found', 'wrong_event']) {
        expect(parseExitOutcome(exitRow(r)).result.db, r);
      }
      final ok = parseExitOutcome(exitRow('ok', inside: 2, exited: 2));
      expect([ok.recorded, ok.customerName, ok.inside, ok.exited], [true, 'Group Gina', 2, 2]);
    });

    test('an answer the app does not know is an error, never a success', () {
      expect(parseExitOutcome(exitRow('admitted')).result, ExitResult.error);
      // The app's own two answers are never taken from the server: it cannot say the door person's access has ended.
      expect(parseExitOutcome(exitRow('access_ended')).result, ExitResult.error);
      expect(parseExitOutcome(exitRow('error')).result, ExitResult.error);
      expect(parseExitOutcome(null).result, ExitResult.error);
      expect(parseExitOutcome({'result': 5}).result, ExitResult.error);
      expect(parseExitOutcome(exitRow('ok')).recorded, isTrue);
      expect(parseExitOutcome(exitRow('too_many')).recorded, isFalse);
    });

    test('what each answer tells the person, and its tone', () {
      expect(exitCopy(parseExitOutcome(exitRow('ok', inside: 0))).hint, 'Everyone on this ticket has left.');
      expect(exitCopy(parseExitOutcome(exitRow('ok', inside: 1))).hint, '1 more from this ticket is still inside.');
      expect(exitCopy(parseExitOutcome(exitRow('ok', inside: 3))).hint, '3 more from this ticket are still inside.');
      expect(exitCopy(parseExitOutcome(exitRow('ok'))).tone, Tone.ok);
      for (final r in ['not_tracking', 'nothing_inside', 'too_many']) {
        expect(exitCopy(parseExitOutcome(exitRow(r))).tone, Tone.warn, reason: r);
      }
      for (final r in ['not_found', 'wrong_event']) {
        expect(exitCopy(parseExitOutcome(exitRow(r))).tone, Tone.error, reason: r);
      }
      expect(exitCopy(const ExitOutcome(ExitResult.accessEnded)).label, 'Your access has ended');
    });

    test('a failed call ends the door person\'s access, or is a plain error', () {
      expect(exitOutcomeFromError('not authorized').result, ExitResult.accessEnded);
      expect(exitOutcomeFromError('connection reset').result, ExitResult.error);
    });
  });

  group('DoorService', () {
    setUp(() => db = FakeDoorBackend());

    test('occupancy asks about the event and reads the answer', () async {
      db.handlers['door_occupancy'] = (_) => [occupancyRow(admitted: 9, exited: 4)];
      final o = await db.service.occupancy('e1');
      expect(o!.inside, 5);
      expect(db.paramsOf('door_occupancy'), [
        {'p_event': 'e1'},
      ]);
    });

    test('a server without exits answers nothing, and is not asked again', () async {
      db.handlers['door_occupancy'] = (_) => throw PostgrestException(message: 'function public.door_occupancy does not exist', code: '42883');
      final service = db.service;
      expect(await service.occupancy('e1'), isNull);
      expect(await service.occupancy('e1'), isNull);
      expect(db.count('door_occupancy'), 1);
    });

    test('any other failure is no figure, and the next ask tries again', () async {
      var asked = 0;
      db.handlers['door_occupancy'] = (_) {
        asked++;
        if (asked == 1) throw PostgrestException(message: 'timeout', code: '57014');
        return [occupancyRow()];
      };
      final service = db.service;
      expect(await service.occupancy('e1'), isNull);
      expect((await service.occupancy('e1'))!.tracking, isTrue);
    });

    test('recordExit sends the code, one guest and the event; and reads the answer', () async {
      db.handlers['door_record_exit'] = (_) => [exitRow('ok', inside: 1)];
      final o = await db.service.recordExit('  T-100  ', 'e1');
      expect(o.recorded, isTrue);
      expect(db.paramsOf('door_record_exit'), [
        {'p_ticket_code': 'T-100', 'p_count': 1, 'p_event': 'e1'},
      ]);
    });

    test('recordExit sends the number of guests that are leaving', () async {
      db.handlers['door_record_exit'] = (_) => [exitRow('ok', inside: 1)];
      await db.service.recordExit('T-100', 'e1', count: 3);
      expect(db.paramsOf('door_record_exit').single!['p_count'], 3);
    });

    test('nothing is sent for an empty code or a count below one', () async {
      expect((await db.service.recordExit('   ', 'e1')).result, ExitResult.error);
      expect((await db.service.recordExit('T-1', 'e1', count: 0)).result, ExitResult.error);
      expect(db.count('door_record_exit'), 0);
    });

    test('a refusal or a broken connection becomes an answer, never an exception', () async {
      db.handlers['door_record_exit'] = (_) => throw PostgrestException(message: 'not authorized', code: 'P0001');
      expect((await db.service.recordExit('T-1', 'e1')).result, ExitResult.accessEnded);
      db.handlers['door_record_exit'] = (_) => throw StateError('socket closed');
      expect((await db.service.recordExit('T-1', 'e1')).result, ExitResult.error);
      db.handlers['door_record_exit'] = (_) => <dynamic>[];
      expect((await db.service.recordExit('T-1', 'e1')).result, ExitResult.error, reason: 'an empty answer is not a success');
    });
  });

  group('Scan screen', () {
    setUp(() {
      db = FakeDoorBackend();
      emit = null;
      db.handlers['door_events'] = (_) => [eventRow()];
    });

    testWidgets('where exits are not tracked it says "checked in" and offers no Exit mode', (tester) async {
      db.handlers['door_occupancy'] = (_) => [occupancyRow(tracking: false, admitted: 3, exited: 0)];
      await openScan(tester);
      expect(text(tester, 'occupancy-headline'), 'Total checked in: 3');
      expect(text(tester, 'admitted-summary'), '3 of 10 guests checked in');
      expect(find.byKey(const Key('door-mode')), findsNothing);
    });

    testWidgets('a server without exits keeps the old line and no Exit mode', (tester) async {
      db.handlers['door_occupancy'] = (_) => throw PostgrestException(message: 'does not exist', code: '42883');
      await openScan(tester);
      expect(find.byKey(const Key('occupancy-headline')), findsNothing);
      expect(text(tester, 'admitted-summary'), '3 of 10 guests in');
      expect(find.byKey(const Key('door-mode')), findsNothing);
    });

    testWidgets('where exits are tracked it says "Inside now" and offers Entry and Exit', (tester) async {
      db.handlers['door_occupancy'] = (_) => [occupancyRow(admitted: 5, exited: 1)];
      await openScan(tester);
      expect(text(tester, 'occupancy-headline'), 'Inside now: 4');
      expect(text(tester, 'admitted-summary'), '4 inside now · 5 checked in · 1 left');
      expect(find.byKey(const Key('door-mode')), findsOneWidget);
    });

    testWidgets('in Exit mode a scan records one guest leaving, and the count is read again', (tester) async {
      var inside = 4;
      db.handlers['door_occupancy'] = (_) => [occupancyRow(admitted: 5, exited: 5 - inside, inside: inside)];
      db.handlers['door_record_exit'] = (_) {
        inside = 3;
        return [exitRow('ok', inside: 0)];
      };
      await openScan(tester);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      await read(tester, 'T-100');

      expect(db.paramsOf('door_record_exit'), [
        {'p_ticket_code': 'T-100', 'p_count': 1, 'p_event': 'e1'},
      ]);
      expect(db.count('door_scan_ticket'), 0, reason: 'an exit never admits anyone');
      expect(text(tester, 'exit-label'), 'Left');
      expect(find.text('Everyone on this ticket has left.'), findsOneWidget);
      expect(text(tester, 'occupancy-headline'), 'Inside now: 3');
      expect(db.count('door_occupancy'), greaterThanOrEqualTo(2));
    });

    testWidgets('a ticket with more guests inside offers "Another guest leaves"', (tester) async {
      db.handlers['door_occupancy'] = (_) => [occupancyRow()];
      var left = 0;
      db.handlers['door_record_exit'] = (_) {
        left++;
        return [exitRow('ok', inside: left == 1 ? 1 : 0, exited: left)];
      };
      await openScan(tester);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      await read(tester, 'T-100');
      expect(find.byKey(const Key('exit-another')), findsOneWidget);
      expect(find.text('1 more from this ticket is still inside.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('exit-another')));
      await tester.pumpAndSettle();
      expect(db.count('door_record_exit'), 2);
      expect(find.byKey(const Key('exit-another')), findsNothing, reason: 'nobody is left inside on that ticket');
      expect(find.text('Everyone on this ticket has left.'), findsOneWidget);
    });

    testWidgets('a refusal is shown as what it is, and nothing is counted as left', (tester) async {
      db.handlers['door_occupancy'] = (_) => [occupancyRow()];
      db.handlers['door_record_exit'] = (_) => [exitRow('nothing_inside', inside: 0, exited: 2)];
      await openScan(tester);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      await read(tester, 'T-100');
      expect(text(tester, 'exit-label'), 'Nobody inside');
      expect(find.byKey(const Key('exit-another')), findsNothing);
    });

    testWidgets('a camera that keeps seeing a ticket does not count a second exit while the answer shows', (tester) async {
      db.handlers['door_occupancy'] = (_) => [occupancyRow()];
      db.handlers['door_record_exit'] = (_) => [exitRow('ok', inside: 0)];
      await openScan(tester);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      await read(tester, 'T-100');
      await read(tester, 'T-200');
      expect(db.count('door_record_exit'), 1);
      await tester.tap(find.byKey(const Key('exit-next')));
      await tester.pumpAndSettle();
      await read(tester, 'T-200');
      expect(db.count('door_record_exit'), 2);
    });

    testWidgets('back in Entry mode a scan admits as before, and the occupancy is read again', (tester) async {
      db.handlers['door_occupancy'] = (_) => [occupancyRow()];
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada Lovelace', tier: 'General', quantity: 1)];
      await openScan(tester);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entry'));
      await tester.pumpAndSettle();
      final before = db.count('door_occupancy');
      await read(tester, 'T-100');
      expect(db.count('door_scan_ticket'), 1);
      expect(db.count('door_record_exit'), 0);
      expect(db.count('door_occupancy'), greaterThan(before));
    });

    testWidgets('an event that stops tracking while the door is in Exit mode scans as an entry again', (tester) async {
      var tracking = true;
      db.handlers['door_occupancy'] = (_) => [occupancyRow(tracking: tracking)];
      db.handlers['door_scan_ticket'] = (_) => [scanRow('ok', name: 'Ada Lovelace', tier: 'General', quantity: 1)];
      await openScan(tester);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      tracking = false;
      // Another look at the event (the screen reads it again after every answer).
      final container = ProviderScope.containerOf(tester.element(find.byType(DoorScanScreen)));
      container.invalidate(doorOccupancyProvider('e1'));
      await tester.pumpAndSettle();
      await read(tester, 'T-100');
      expect(db.count('door_record_exit'), 0, reason: 'with tracking off nobody is recorded as leaving');
      expect(db.count('door_scan_ticket'), 1);
    });
  });
}
