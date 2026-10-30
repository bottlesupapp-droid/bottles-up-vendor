import 'dart:io';

import 'package:bottles_up_vendor/features/booking_conflicts/logic/conflict_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_conflict_backend.dart';

// The database decides every name, limit and sentence here; the app must not drift from them. These read the website's migration when it is checked out beside this app (the monorepo)
// and are skipped otherwise.
void main() {
  final migration = File('../bottles-up-website-main/supabase/migrations/20261113100000_oversold_booking_queue.sql');
  const why = 'website repo is not checked out next to this app';
  final present = migration.existsSync();

  group('agrees with the website', () {
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

    test('the app calls the two functions that exist, with exactly their parameters, by name', () async {
      final db = FakeConflictBackend()..add('k1');
      db.rows.first.stillOverbooked = false;
      await db.service.list('v1');
      await db.service.resolve('k1', ConflictResolution.moved, 'Moved to table 4');
      expect(db.calls[0].$2!.keys.toList(), params('desk_booking_conflicts'));
      expect(db.calls[1].$2!.keys.toList(), params('desk_resolve_booking_conflict'));
      expect(db.calls[0].$1, 'desk_booking_conflicts');
      expect(db.calls[1].$1, 'desk_resolve_booking_conflict');
    }, skip: present ? false : why);

    test('every column the list gives is a column the app reads, and the app reads nothing else', () async {
      final text = fn('desk_booking_conflicts');
      final m = RegExp(r'returns table \(([\s\S]*?)\)\s*language').firstMatch(text)!;
      final columns = [for (final c in m.group(1)!.split(',')) c.trim().split(RegExp(r'\s+')).first]..removeWhere((c) => c.isEmpty);
      final db = FakeConflictBackend()..add('k1');
      final keys = (await db.call('desk_booking_conflicts', params: {'p_venue': 'v1', 'p_include_resolved': false}) as List).first.keys.toList();
      expect(keys, columns);
    }, skip: present ? false : why);

    test('every sentence the stand-in raises is one the database raises, word for word', () {
      final text = sql();
      for (final s in FakeConflictBackend.sentences) {
        expect(text, contains("'$s'"), reason: s);
      }
    }, skip: present ? false : why);

    test('the ways of settling, the shortest and longest note, and who may call are the database\'s', () {
      final text = sql();
      final ways = RegExp(r"p_resolution not in \(([^)]*)\)").firstMatch(text)!.group(1)!;
      expect([for (final w in ways.split(',')) w.trim().replaceAll("'", '')], [for (final c in ConflictResolution.values) c.db]);
      expect(text, contains('char_length(v_note) < $conflictNoteMin'));
      expect(text, contains('char_length(v_note) > $conflictNoteMax'));
      expect(text, contains("check (resolution in ('moved', 'refunded', 'kept'))"));
      expect(text, contains('desk_booking_conflicts(uuid, boolean) to authenticated'));
      expect(text, contains('desk_resolve_booking_conflict(uuid, text, text) to authenticated'));
    }, skip: present ? false : why);

    test('the stand-in checks in the database\'s order: the conflict, then who, then the words, then its state, then the facts', () {
      final body = fn('desk_resolve_booking_conflict');
      final order = [
        "raise exception 'not allowed'",
        "raise exception 'say how it was settled",
        "raise exception 'say what was done",
        "raise exception 'keep the note",
        "raise exception 'this has already been dealt with'",
        "raise exception 'the booking is not paid any more",
        "raise exception 'that table is still double-booked",
        "raise exception 'refund or cancel the booking first'",
      ];
      var at = 0;
      for (final marker in order) {
        final i = body.indexOf(marker, at);
        expect(i, greaterThanOrEqualTo(at), reason: marker);
        at = i;
      }
    }, skip: present ? false : why);
  });
}
