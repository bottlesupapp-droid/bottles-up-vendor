import 'dart:async';
import 'dart:io';

import 'package:bottles_up_vendor/features/door/logic/door_rules.dart';
import 'package:bottles_up_vendor/features/door/services/door_service.dart';
import 'package:bottles_up_vendor/features/door_control/logic/door_control_rules.dart';
import 'package:bottles_up_vendor/features/door_control/providers/door_control_providers.dart';
import 'package:bottles_up_vendor/features/door_control/screens/door_control_screen.dart';
import 'package:bottles_up_vendor/features/door_control/services/door_control_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Door control (website 20261122100000): the club's nights with who is inside, the exit-tracking switch, and an override for a guest held back only by the entry code, with a reason that
// is kept. The database decides who may do each and what an override may lift; these tests check what the app sends, what it shows, and that it agrees with the migration.

// ── a stand-in for the database ────────────────────────────────────────────────────────

class Backend {
  final List<(String, Map<String, dynamic>?)> calls = [];
  final Map<String, FutureOr<dynamic> Function(Map<String, dynamic>? params)> handlers = {};

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function, params));
    final h = handlers[function];
    if (h == null) throw StateError('no handler for $function');
    return h(params);
  }

  DoorControlService get service => DoorControlService(caller: call);

  List<Map<String, dynamic>?> paramsOf(String f) => [
    for (final c in calls)
      if (c.$1 == f) c.$2,
  ];

  int count(String f) => calls.where((c) => c.$1 == f).length;
}

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

Map<String, dynamic> nightRow({String id = 'e1', String title = 'Friday Night', bool track = false, int admitted = 7, int exited = 3, int? inside}) => {
  'event_id': id,
  'title': title,
  'start_date': DateTime.utc(2026, 11, 20, 22).toIso8601String(),
  'end_date': DateTime.utc(2026, 11, 21, 6).toIso8601String(),
  'track_exits': track,
  'admitted': admitted,
  'exited': exited,
  'inside': inside ?? (admitted - exited).clamp(0, 1 << 30),
};

Map<String, dynamic> overrideRow(String result, {String? name = 'Gated Gus', int quantity = 1, int admitted = 1, int remaining = 0}) => {
  'result': result,
  'customer_name': name,
  'event_title': name == null ? null : 'Friday Night',
  'tier_name': name == null ? null : 'General',
  'quantity': quantity,
  'admitted': admitted,
  'remaining': remaining,
};

Map<String, dynamic> logRow({String name = 'Gated Gus', int guests = 1, String reason = 'Lost their phone, ID checked', bool byMe = true}) => {
  'overridden_at': DateTime.utc(2026, 11, 20, 23, 30).toIso8601String(),
  'customer_name': name,
  'guests': guests,
  'reason': reason,
  'by_me': byMe,
};

Workspace ws({WorkspaceRole role = WorkspaceRole.manager, String? venueId = 'v1'}) =>
    Workspace(membershipId: 'm1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: role, venueId: venueId);

late Backend db;

Future<void> open(WidgetTester tester, {Workspace? workspace}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [doorControlServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: DoorControlScreen(workspace: workspace ?? ws()))),
    ),
  );
  await tester.pumpAndSettle();
}

String text(WidgetTester t, String key) => (t.widget(find.byKey(Key(key))) as Text).data!;

Future<void> fill(WidgetTester tester, {String code = 'GATED-1', String reason = 'Lost their phone, ID checked'}) async {
  await tester.enterText(find.byKey(const Key('override-code')), code);
  await tester.enterText(find.byKey(const Key('override-reason')), reason);
  await tester.pump();
}

Future<void> send(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('override-send')));
  await tester.tap(find.byKey(const Key('override-send')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    db = Backend();
    db.handlers['door_club_nights'] = (_) => [nightRow(track: true), nightRow(id: 'e2', title: 'Saturday Night', track: false, admitted: 2, exited: 0)];
    db.handlers['door_override_log'] = (_) => <dynamic>[];
  });

  group('Reasons', () {
    test('a reason is 5 to 300 characters, spaces do not count', () {
      expect(validateOverrideReason(''), isNotNull);
      expect(validateOverrideReason('    '), isNotNull);
      expect(validateOverrideReason('abcd'), isNotNull);
      expect(validateOverrideReason('abcde'), isNull);
      expect(validateOverrideReason('  abcde  '), isNull);
      expect(validateOverrideReason('x' * 300), isNull);
      expect(validateOverrideReason('x' * 301), isNotNull);
    });
  });

  group('Reading what the database sends', () {
    test('a night is read; anything incomplete is dropped, never guessed', () {
      final n = parseClubNight(nightRow(track: true, admitted: 9, exited: 4))!;
      expect([n.eventId, n.title, n.trackExits, n.admitted, n.exited, n.inside], ['e1', 'Friday Night', true, 9, 4, 5]);
      expect(parseClubNight({...nightRow()}..remove('inside')), isNull);
      expect(parseClubNight({...nightRow(), 'track_exits': 'yes'}), isNull);
      expect(parseClubNight({...nightRow(), 'start_date': 'soon'}), isNull);
    });

    test('"inside now" only where exits are tracked', () {
      expect(nightFigure(parseClubNight(nightRow(track: true, admitted: 9, exited: 4))!), '5 inside now · 9 checked in · 4 left');
      expect(nightFigure(parseClubNight(nightRow(track: false, admitted: 9, exited: 0))!), '9 checked in');
    });

    test('every override answer the database gives is read; an unknown one is not a success', () {
      for (final r in OverrideResult.values) {
        expect(parseOverrideOutcome(overrideRow(r.db))!.result, r);
      }
      expect(parseOverrideOutcome(overrideRow('admitted')), isNull);
      expect(parseOverrideOutcome(null), isNull);
      expect(parseOverrideOutcome(overrideRow('ok'))!.done, isTrue);
      expect(parseOverrideOutcome(overrideRow('group'))!.needsCount, isTrue);
      expect(parseOverrideOutcome(overrideRow('refunded'))!.done, isFalse);
    });

    test('only an admitted guest is a success; every refusal says it stays refused', () {
      OverrideCopy copy(String r) => overrideCopy(parseOverrideOutcome(overrideRow(r, remaining: 2, quantity: 3))!);
      expect(copy('ok').tone, OverrideTone.ok);
      expect(copy('ok').hint, contains('Your reason is kept.'));
      expect(copy('ok').hint, contains('2 more may still come in'));
      for (final r in ['not_paid', 'refunded', 'expired', 'wrong_event', 'not_found']) {
        expect(copy(r).tone, OverrideTone.error, reason: r);
      }
      for (final r in ['group', 'too_many', 'no_override_needed', 'already_checked_in']) {
        expect(copy(r).tone, OverrideTone.warn, reason: r);
      }
      expect(copy('not_paid').hint, contains('cannot admit an unpaid'));
      expect(copy('group').hint, contains('3 guests'));
      expect(copy('too_many').hint, contains('Only 2 may still come in'));
    });

    test('a log entry is read, and one with a missing part is dropped', () {
      final e = parseOverrideLogEntry(logRow(byMe: false))!;
      expect([e.customerName, e.guests, e.reason, e.byMe], ['Gated Gus', 1, 'Lost their phone, ID checked', false]);
      expect(parseOverrideLogEntry({...logRow()}..remove('reason')), isNull);
      expect(parseOverrideLogEntry({...logRow(), 'by_me': null}), isNull);
    });
  });

  group('DoorControlService', () {
    test('nights asks about the club and drops a row it cannot read', () async {
      db.handlers['door_club_nights'] =
          (_) => [
            nightRow(),
            {'event_id': 'x'},
          ];
      final list = await db.service.nights('v1');
      expect(list.length, 1);
      expect(db.paramsOf('door_club_nights'), [
        {'p_venue': 'v1'},
      ]);
    });

    test('a night list that cannot be read says what it was, not the database\'s words', () async {
      db.handlers['door_club_nights'] = (_) => throw PostgrestException(message: 'function public.door_club_nights does not exist', code: '42883');
      await expectLater(db.service.nights('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', true)));
      db.handlers['door_club_nights'] = (_) => throw refuse('not authorized');
      await expectLater(db.service.nights('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', true)));
    });

    test('exit tracking sends the night and the choice', () async {
      db.handlers['set_event_exit_tracking'] = (_) => true;
      await db.service.setExitTracking('e1', true);
      await db.service.setExitTracking('e1', false);
      expect(db.paramsOf('set_event_exit_tracking'), [
        {'p_event': 'e1', 'p_on': true},
        {'p_event': 'e1', 'p_on': false},
      ]);
    });

    test('a refused change says the database\'s sentence', () async {
      db.handlers['set_event_exit_tracking'] = (_) => throw refuse('not authorized');
      await expectLater(db.service.setExitTracking('e1', true), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('don\'t have access'))));
    });

    test('an override sends the trimmed code and reason, the count and the night', () async {
      db.handlers['door_override_entry'] = (_) => [overrideRow('ok')];
      final o = await db.service.override('  GATED-1 ', '  Lost their phone  ', count: 2, eventId: 'e1');
      expect(o.done, isTrue);
      expect(db.paramsOf('door_override_entry'), [
        {'p_ticket_code': 'GATED-1', 'p_reason': 'Lost their phone', 'p_count': 2, 'p_event': 'e1'},
      ]);
    });

    test('nothing is sent without a code or with a short reason', () async {
      await expectLater(db.service.override('', 'Lost their phone'), throwsA(isA<OpsActionException>()));
      await expectLater(db.service.override('GATED-1', 'no'), throwsA(isA<OpsActionException>()));
      expect(db.count('door_override_entry'), 0);
    });

    test('an answer that cannot be read is an error, never an admission', () async {
      db.handlers['door_override_entry'] = (_) => <dynamic>[];
      await expectLater(db.service.override('GATED-1', 'Lost their phone'), throwsA(isA<OpsActionException>()));
      db.handlers['door_override_entry'] = (_) => [overrideRow('unknown')];
      await expectLater(db.service.override('GATED-1', 'Lost their phone'), throwsA(isA<OpsActionException>()));
    });

    test('a refusal by the database says its own sentence', () async {
      db.handlers['door_override_entry'] = (_) => throw refuse('not authorized');
      await expectLater(db.service.override('GATED-1', 'Lost their phone'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('don\'t have access'))));
    });
  });

  group('Door control screen', () {
    testWidgets('lists the club\'s nights with their figures and switches; the owner picks the club first', (tester) async {
      await open(tester);
      expect(text(tester, 'night-figure-e1'), '4 inside now · 7 checked in · 3 left');
      expect(text(tester, 'night-figure-e2'), '2 checked in');
      expect(tester.widget<Switch>(find.byKey(const Key('track-e1'))).value, isTrue);
      expect(tester.widget<Switch>(find.byKey(const Key('track-e2'))).value, isFalse);
      expect(db.paramsOf('door_club_nights'), [
        {'p_venue': 'v1'},
      ]);
    });

    testWidgets('an owner (no club of their own) is asked which club, then sees its nights', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [doorControlServiceProvider.overrideWithValue(db.service)],
          child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: DoorControlScreen(workspace: ws(role: WorkspaceRole.owner, venueId: null)))),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('venue-picker')), findsOneWidget);
      expect(db.count('door_club_nights'), 0, reason: 'no club chosen, nothing asked');
    });

    testWidgets('no night on says why', (tester) async {
      db.handlers['door_club_nights'] = (_) => <dynamic>[];
      await open(tester);
      expect(find.byKey(const Key('nights-empty')), findsOneWidget);
      expect(find.textContaining('12 hours after it ends'), findsOneWidget);
    });

    testWidgets('a night list that fails says so with Try again', (tester) async {
      db.handlers['door_club_nights'] = (_) => throw StateError('socket');
      await open(tester);
      expect(find.byKey(const Key('nights-error')), findsOneWidget);
    });

    testWidgets('the switch turns exit tracking on for that night and the list is read again', (tester) async {
      db.handlers['set_event_exit_tracking'] = (_) => true;
      await open(tester);
      final before = db.count('door_club_nights');
      await tester.tap(find.byKey(const Key('track-e2')));
      await tester.pumpAndSettle();
      expect(db.paramsOf('set_event_exit_tracking'), [
        {'p_event': 'e2', 'p_on': true},
      ]);
      expect(db.count('door_club_nights'), greaterThan(before));
    });

    testWidgets('a refused switch says why, and the list shows what the database says', (tester) async {
      db.handlers['set_event_exit_tracking'] = (_) => throw refuse('not authorized');
      await open(tester);
      await tester.tap(find.byKey(const Key('track-e2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('don\'t have access'), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const Key('track-e2'))).value, isFalse);
    });

    testWidgets('an override needs a ticket code and a reason before anything is sent', (tester) async {
      await open(tester);
      await send(tester);
      expect(text(tester, 'override-problem'), 'Write why, in at least 5 characters. It is kept with the override.');
      await fill(tester, code: '', reason: 'Lost their phone');
      await send(tester);
      expect(text(tester, 'override-problem'), 'Type or scan the ticket code first.');
      expect(db.count('door_override_entry'), 0);
    });

    testWidgets('an override admits the guest, aims at the chosen night, clears the form and reads the log again', (tester) async {
      db.handlers['door_override_entry'] = (_) => [overrideRow('ok')];
      await open(tester);
      final logBefore = db.count('door_override_log');
      await fill(tester);
      await send(tester);
      expect(db.paramsOf('door_override_entry'), [
        {'p_ticket_code': 'GATED-1', 'p_reason': 'Lost their phone, ID checked', 'p_count': null, 'p_event': 'e1'},
      ]);
      expect(text(tester, 'override-label'), 'Admitted');
      expect(tester.widget<TextField>(find.byKey(const Key('override-code'))).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.byKey(const Key('override-reason'))).controller!.text, isEmpty);
      expect(db.count('door_override_log'), greaterThan(logBefore));
    });

    testWidgets('a refusal is shown as a refusal and the form keeps what was typed', (tester) async {
      db.handlers['door_override_entry'] = (_) => [overrideRow('not_paid', admitted: 0, remaining: 1)];
      await open(tester);
      await fill(tester);
      await send(tester);
      expect(text(tester, 'override-label'), 'Not paid');
      expect(tester.widget<TextField>(find.byKey(const Key('override-code'))).controller!.text, 'GATED-1');
    });

    testWidgets('a group ticket asks how many, then admits exactly that many', (tester) async {
      final answers = [
        [overrideRow('group', quantity: 3, admitted: 0, remaining: 3)],
        [overrideRow('ok', quantity: 3, admitted: 2, remaining: 1)],
      ];
      db.handlers['door_override_entry'] = (_) => answers.removeAt(0);
      await open(tester);
      await fill(tester);
      await send(tester);
      expect(text(tester, 'override-label'), 'Group ticket');
      expect(find.byKey(const Key('override-count-3')), findsOneWidget);
      expect(find.byKey(const Key('override-count-4')), findsNothing, reason: 'only as many as may still come in');
      await tester.ensureVisible(find.byKey(const Key('override-count-2')));
      await tester.tap(find.byKey(const Key('override-count-2')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('override-admit-count')));
      await tester.tap(find.byKey(const Key('override-admit-count')));
      await tester.pumpAndSettle();
      expect(db.paramsOf('door_override_entry').last!['p_count'], 2);
      expect(text(tester, 'override-label'), 'Admitted');
    });

    testWidgets('the database refusing the override (not a manager) is shown in words', (tester) async {
      db.handlers['door_override_entry'] = (_) => throw refuse('not authorized');
      await open(tester);
      await fill(tester);
      await send(tester);
      expect(text(tester, 'override-problem'), contains('don\'t have access'));
    });

    testWidgets('the log of the chosen night: empty says so; entries show who, how many, why and when', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('log-empty')), findsOneWidget);
      db.handlers['door_override_log'] = (_) => [logRow(), logRow(name: 'Gated Group', guests: 2, reason: 'Group lead has the code', byMe: false)];
      await open(tester);
      expect(find.textContaining('Gated Gus · 1 guest'), findsOneWidget);
      expect(find.textContaining('Gated Group · 2 guests'), findsOneWidget);
      expect(find.textContaining('Group lead has the code'), findsOneWidget);
      expect(find.textContaining('by you'), findsOneWidget);
      expect(db.paramsOf('door_override_log').first, {'p_event': 'e1'});
    });

    testWidgets('choosing another night aims the log and the override at it', (tester) async {
      db.handlers['door_override_entry'] = (_) => [overrideRow('ok')];
      await open(tester);
      await tester.tap(find.byKey(const Key('night-e2')));
      await tester.pumpAndSettle();
      expect(db.paramsOf('door_override_log').last, {'p_event': 'e2'});
      await fill(tester);
      await send(tester);
      expect(db.paramsOf('door_override_entry').single!['p_event'], 'e2');
    });
  });

  // ── agreement with the website ───────────────────────────────────────────────────────────

  group('agrees with the website', () {
    final migration = File('../bottles-up-website-main/supabase/migrations/20261122100000_door_exits_and_overrides.sql');
    const why = 'website repo is not checked out next to this app';
    final present = migration.existsSync();

    String sql() => migration.readAsStringSync();

    String fn(String name) {
      final m = RegExp('create function public\\.$name\\(').firstMatch(sql());
      if (m == null) fail('function $name is in the website\'s migration');
      final bodyStart = sql().indexOf('as \$\$', m.start);
      return sql().substring(m.start, sql().indexOf('\$\$;', bodyStart + 5) + 3);
    }

    List<String> params(String name) {
      final text = fn(name);
      final open = text.indexOf('(');
      final close = text.indexOf(')', open);
      return [for (final p in text.substring(open + 1, close).split(',')) p.trim().split(RegExp(r'\s+')).first];
    }

    List<String> columns(String name) {
      final m = RegExp(r'returns table \(([\s\S]*?)\)\s*language').firstMatch(fn(name))!;
      return [for (final c in m.group(1)!.split(',')) c.trim().split(RegExp(r'\s+')).first]..removeWhere((c) => c.isEmpty);
    }

    test('every function the app calls exists, with exactly the parameters the app sends', () async {
      db.handlers['set_event_exit_tracking'] = (_) => true;
      db.handlers['door_override_entry'] = (_) => [overrideRow('ok')];
      db.handlers['door_record_exit'] =
          (_) => [
            {'result': 'ok', 'customer_name': 'x', 'quantity': 1, 'admitted': 1, 'exited': 1, 'inside': 0},
          ];
      db.handlers['door_occupancy'] =
          (_) => [
            {'tracking': true, 'admitted': 1, 'exited': 0, 'inside': 1},
          ];
      await db.service.nights('v1');
      await db.service.setExitTracking('e1', true);
      await db.service.override('C-1', 'a reason', eventId: 'e1');
      await db.service.log('e1');
      final door = DoorService(rpc: db.call);
      await door.occupancy('e1');
      await door.recordExit('C-1', 'e1');
      for (final (name, sent) in db.calls) {
        expect(params(name), db.paramsOf(name).first!.keys.toList(), reason: name);
        expect(sent!.keys.toList(), params(name), reason: name);
      }
      expect(db.calls.map((c) => c.$1).toSet(), {'door_club_nights', 'set_event_exit_tracking', 'door_override_entry', 'door_override_log', 'door_occupancy', 'door_record_exit'});
    }, skip: present ? false : why);

    test('every column the app reads is a column the database returns', () {
      expect(columns('door_occupancy'), ['tracking', 'admitted', 'exited', 'inside']);
      expect(columns('door_record_exit'), ['result', 'customer_name', 'quantity', 'admitted', 'exited', 'inside']);
      expect(columns('door_club_nights'), nightRow().keys.toList());
      expect(columns('door_override_entry'), overrideRow('ok').keys.toList());
      expect(columns('door_override_log'), logRow().keys.toList());
    }, skip: present ? false : why);

    test('every answer the app reads is one the database gives, and every answer the database gives is read', () {
      for (final r in OverrideResult.values) {
        expect(fn('door_override_entry'), contains("'${r.db}'"), reason: r.db);
      }
      for (final r in ExitResult.values) {
        if (r == ExitResult.accessEnded || r == ExitResult.error) continue;
        expect(fn('door_record_exit'), contains("'${r.db}'"), reason: r.db);
      }
      final given = RegExp(r"return query select '([a-z_]+)'").allMatches(fn('door_override_entry')).map((m) => m.group(1)!).toSet();
      expect(given.difference({for (final r in OverrideResult.values) r.db}), isEmpty);
      final exits = RegExp(r"return query select '([a-z_]+)'").allMatches(fn('door_record_exit')).map((m) => m.group(1)!).toSet();
      expect(exits.difference({for (final r in ExitResult.values) r.db}), isEmpty);
    }, skip: present ? false : why);

    test('the shortest and longest reason are the database\'s, and so is its sentence', () {
      final text = sql();
      expect(text, contains('check (char_length(reason) between $overrideReasonMin and $overrideReasonMax)'));
      expect(fn('door_override_entry'), contains('char_length(v_reason) < $overrideReasonMin or char_length(v_reason) > $overrideReasonMax'));
      expect(fn('door_override_entry'), contains("'give a reason of $overrideReasonMin to $overrideReasonMax characters'"));
    }, skip: present ? false : why);

    test('an override lifts only the entry code: the migration refuses everything else before it admits', () {
      final body = fn('door_override_entry');
      final admits = body.indexOf('insert into public.site_order_admissions');
      for (final refusal in ["'not_paid'", "'refunded'", "'already_checked_in'", "'expired'", "'no_override_needed'"]) {
        final at = body.indexOf(refusal);
        expect(at, greaterThan(-1), reason: refusal);
        expect(at, lessThan(admits), reason: '$refusal is decided before anyone is admitted');
      }
      expect(body, contains('can_manage_door(v_event)'));
    }, skip: present ? false : why);
  });
}
