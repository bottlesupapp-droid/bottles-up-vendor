import 'dart:io';

import 'package:bottles_up_vendor/features/door/logic/door_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DoorEvent event({int expected = 10, int admitted = 3, DateTime? start, String id = 'e1'}) => DoorEvent(
      eventId: id,
      title: 'Friday Night',
      venueName: 'Club A',
      startDate: start ?? DateTime(2026, 10, 9, 21),
      scope: 'venue',
      guestsExpected: expected,
      guestsAdmitted: admitted,
    );

void main() {
  group('results', () {
    test('every answer the database can give is known, by the exact stored word', () {
      for (final word in const [
        'ok', 'already_checked_in', 'not_paid', 'not_found', 'expired', 'code_required', 'code_incorrect',
        'code_expired', 'no_code_requested', 'wrong_event',
      ]) {
        expect(DoorResult.fromDb(word), isNotNull, reason: word);
        expect(DoorResult.fromDb(word)!.db, word);
      }
    });

    test('anything else is unknown, and the app\'s own two outcomes cannot be forged by the database', () {
      for (final bad in <Object?>['', 'OK', 'Ok ', 'admitted', 'access_ended', 'scan_error', null, 1, true, <String>[]]) {
        expect(DoorResult.fromDb(bad), isNull, reason: '$bad');
      }
    });

    test('every result has wording, and only "Admit" is green', () {
      for (final r in DoorResult.values) {
        final copy = resultCopy[r];
        expect(copy, isNotNull, reason: r.name);
        expect(copy!.label, isNotEmpty);
        expect(copy.hint, isNotEmpty);
        expect(copy.tone == Tone.ok, r == DoorResult.ok, reason: '${r.name} must not look like an admission');
      }
    });

    test('unpaid, wrong event, ended, unknown and the code failures are red stops; used and code-required are amber', () {
      for (final r in [DoorResult.notPaid, DoorResult.wrongEvent, DoorResult.expired, DoorResult.notFound, DoorResult.codeIncorrect, DoorResult.codeExpired, DoorResult.noCodeRequested, DoorResult.accessEnded, DoorResult.scanError]) {
        expect(resultCopy[r]!.tone, Tone.error, reason: r.name);
      }
      expect(resultCopy[DoorResult.alreadyCheckedIn]!.tone, Tone.warn);
      expect(resultCopy[DoorResult.codeRequired]!.tone, Tone.warn);
    });

    test('the entry-code step: asked for after four answers, retried after two, final after the rest', () {
      final asks = DoorResult.values.where(needsEntryCode).toSet();
      expect(asks, {DoorResult.codeRequired, DoorResult.codeIncorrect, DoorResult.codeExpired, DoorResult.noCodeRequested});
      final retry = DoorResult.values.where(canRetryCode).toSet();
      expect(retry, {DoorResult.codeRequired, DoorResult.codeIncorrect});
      expect(retry.difference(asks), isEmpty, reason: 'a code box is only ever shown for an answer that asks for a code');
    });
  });

  group('what a camera read does', () {
    final t0 = DateTime(2026, 10, 9, 22);
    bool go({String code = 'T-1', bool busy = false, bool paused = false, String? last, DateTime? at, DateTime? now}) =>
        shouldProcessScan(code: code, busy: busy, paused: paused, lastCode: last, lastAt: at, now: now ?? t0);

    test('a fresh read is acted on', () => expect(go(), isTrue));
    test('nothing is acted on while a check is running', () => expect(go(busy: true), isFalse));
    test('nothing is acted on while an answer is showing (the camera keeps reading underneath)', () => expect(go(paused: true), isFalse));
    test('an empty or blank read is nothing', () {
      expect(go(code: ''), isFalse);
      expect(go(code: '   \n'), isFalse);
    });
    test('the same code is ignored for five seconds, and acted on at exactly five', () {
      expect(go(last: 'T-1', at: t0.subtract(const Duration(seconds: 4, milliseconds: 999))), isFalse);
      expect(go(last: 'T-1', at: t0.subtract(const Duration(seconds: 5))), isTrue);
    });
    test('a different code is not held back by the last one', () {
      expect(go(code: 'T-2', last: 'T-1', at: t0.subtract(const Duration(seconds: 1))), isTrue);
    });
    test('what is scanned is trimmed and capped at 200 characters', () {
      expect(normalizeScan('  T-1 \n'), 'T-1');
      expect(normalizeScan('x' * 500).length, 200);
      expect(normalizeScan(''), '');
    });
  });

  group('reading an answer', () {
    test('an admitted row carries the guest, tier, party and event', () {
      final o = parseScanOutcome({'result': 'ok', 'customer_name': 'Ada Lovelace', 'event_title': 'Friday Night', 'tier_name': 'General', 'quantity': 2});
      expect(o.result, DoorResult.ok);
      expect(o.admitted, isTrue);
      expect([o.customerName, o.tierName, o.quantity, o.eventTitle], ['Ada Lovelace', 'General', 2, 'Friday Night']);
      expect(o.attemptsRemaining, isNull);
    });

    test('a wrong-event row (the database sends no details) shows none', () {
      final o = parseScanOutcome({'result': 'wrong_event', 'customer_name': null, 'event_title': null, 'tier_name': null, 'quantity': null});
      expect(o.result, DoorResult.wrongEvent);
      expect([o.customerName, o.eventTitle, o.tierName, o.quantity], [null, null, null, null]);
      expect(o.admitted, isFalse);
    });

    test('tries left on the entry code come through', () {
      expect(parseScanOutcome({'result': 'code_incorrect', 'attempts_remaining': 2}).attemptsRemaining, 2);
    });

    test('an answer this app does not know is a failed scan, never an admission', () {
      for (final row in <Map<String, dynamic>?>[null, {}, {'result': null}, {'result': 'welcome'}, {'result': 'access_ended'}, {'result': 7}]) {
        final o = parseScanOutcome(row);
        expect(o.result, DoorResult.scanError, reason: '$row');
        expect(o.admitted, isFalse);
      }
    });

    test('blank text and non-numbers are treated as missing', () {
      final o = parseScanOutcome({'result': 'ok', 'customer_name': '', 'quantity': '2', 'tier_name': 5});
      expect([o.customerName, o.quantity, o.tierName], [null, null, null]);
    });

    test('a failed call is "access ended" only when the database says the person is no longer allowed', () {
      for (final m in ['not authorized', 'Not Authorised', 'Your access has ended', 'You are signed out']) {
        expect(outcomeFromErrorMessage(m), DoorResult.accessEnded, reason: m);
      }
      for (final m in ['', 'connection reset', 'permission denied for function door_scan_ticket', 'timeout']) {
        expect(outcomeFromErrorMessage(m), DoorResult.scanError, reason: m);
      }
    });
  });

  group('events and guests', () {
    test('an event row is read, with its scope and counts', () {
      final e = parseDoorEvent({
        'event_id': 'e1', 'title': 'Friday Night', 'venue_name': 'Club A', 'start_date': '2026-10-09T21:00:00+00:00',
        'end_date': '2026-10-10T04:00:00+00:00', 'scope': 'event', 'guests_expected': 80, 'guests_admitted': 12,
      })!;
      expect([e.eventId, e.title, e.venueName, e.scope, e.guestsExpected, e.guestsAdmitted], ['e1', 'Friday Night', 'Club A', 'event', 80, 12]);
      expect(e.endDate, isNotNull);
      expect(e.startDate.isUtc || e.startDate.toUtc().hour == 21, isTrue);
    });

    test('an unknown scope is the whole club, and missing counts are zero', () {
      final e = parseDoorEvent({'event_id': 'e', 'title': 't', 'start_date': '2026-10-09T21:00:00Z', 'scope': 'galaxy'})!;
      expect([e.scope, e.guestsExpected, e.guestsAdmitted, e.venueName], ['venue', 0, 0, '']);
    });

    test('a row without an id, title or a real start time is dropped, not guessed', () {
      expect(parseDoorEvent({'title': 't', 'start_date': '2026-10-09T21:00:00Z'}), isNull);
      expect(parseDoorEvent({'event_id': 'e', 'start_date': '2026-10-09T21:00:00Z'}), isNull);
      expect(parseDoorEvent({'event_id': 'e', 'title': 't', 'start_date': 'tomorrow'}), isNull);
      expect(parseDoorEvent({'event_id': 'e', 'title': 't'}), isNull);
    });

    test('a guest row is read, and one without an order or ticket code is dropped', () {
      final g = parseGuest({'order_id': 'o1', 'customer_name': 'Ada', 'ticket_code': 'T-1', 'tier_name': 'VIP', 'quantity': 3, 'checked_in_at': '2026-10-09T22:00:00Z', 'needs_code': true})!;
      expect([g.name, g.ticketCode, g.tierName, g.quantity, g.isIn, g.needsCode], ['Ada', 'T-1', 'VIP', 3, true, true]);
      expect(parseGuest({'ticket_code': 'T-1'}), isNull);
      expect(parseGuest({'order_id': 'o'}), isNull);
    });

    test('a guest with no name is "Guest", one party by default, and not in until checked in', () {
      final g = parseGuest({'order_id': 'o', 'ticket_code': 'T'})!;
      expect([g.name, g.quantity, g.isIn, g.needsCode, g.tierName], ['Guest', 1, false, false, '']);
    });
  });

  group('wording and the default event', () {
    test('how many guests are in', () {
      expect(admittedSummary(event(expected: 80, admitted: 12)), '12 of 80 guests in');
      expect(admittedSummary(event(expected: 1, admitted: 0)), '0 of 1 guest in');
    });

    test('the percentage is whole, never above 100, and zero when nobody is expected', () {
      expect(admittedPercent(event(expected: 3, admitted: 1)), 33);
      expect(admittedPercent(event(expected: 10, admitted: 12)), 100);
      expect(admittedPercent(event(expected: 0, admitted: 5)), 0);
    });

    test('the default event is one already running, otherwise the next to start', () {
      final now = DateTime(2026, 10, 9, 22);
      final running = event(id: 'running', start: DateTime(2026, 10, 9, 20));
      final later = event(id: 'later', start: DateTime(2026, 10, 10, 20));
      expect(defaultEvent([later, running], now: now)!.eventId, 'running');
      expect(defaultEvent([later], now: now)!.eventId, 'later');
      expect(defaultEvent(const [], now: now), isNull);
    });

    test('a failed load says what is wrong in words', () {
      expect(doorLoadMessage(unavailable: true, accessEnded: false), contains('not set up on this server yet'));
      expect(doorLoadMessage(unavailable: false, accessEnded: true), contains('access has ended'));
      expect(doorLoadMessage(unavailable: false, accessEnded: false), contains('try again'));
      // "not set up" wins: retrying cannot fix a missing migration.
      expect(doorLoadMessage(unavailable: true, accessEnded: true), contains('not set up'));
    });
  });

  // The app and the website must answer the same guest the same way, and call the database by the names it defines. These
  // read the website repo's files when it is checked out next to this one (the monorepo); on their own they are skipped.
  group('agrees with the website', () {
    final root = Directory('../bottles-up-website-main');
    final sql = File('${root.path}/supabase/migrations/20261009100000_door_scanner.sql');
    final ts = File('${root.path}/src/lib/doorScan.ts');

    test('every function and argument the service uses is defined by the door scanner migration', () {
      final text = sql.readAsStringSync();
      for (final fn in ['door_events', 'door_scan_ticket', 'door_verify_ticket_code', 'door_guests']) {
        expect(text, contains('create function public.$fn('), reason: fn);
      }
      for (final arg in ['p_membership', 'p_ticket_code', 'p_event', 'p_code', 'p_query']) {
        expect(text, contains(arg), reason: arg);
      }
    }, skip: sql.existsSync() ? false : 'website repo is not checked out next to this app');

    // The answers only door_admit_group gives (website 20261020170000_group_admission.sql); the website's own door screen does not have them yet.
    const groupOnly = {DoorResult.refunded, DoorResult.group, DoorResult.tooMany};

    test('every stored result is one the database writes', () {
      final text = sql.readAsStringSync();
      for (final r in DoorResult.values.where((r) => r != DoorResult.accessEnded && r != DoorResult.scanError && !groupOnly.contains(r))) {
        expect(text, contains("'${r.db}'"), reason: r.db);
      }
    }, skip: sql.existsSync() ? false : 'website repo is not checked out next to this app');

    final website = Platform.environment['WEBSITE_REPO'] ?? '../bottles-up-website-main';
    final groupSql = File('$website/supabase/migrations/20261020170000_group_admission.sql');
    test('the answers of group admission are the ones door_admit_group gives', () {
      final text = groupSql.readAsStringSync();
      for (final r in groupOnly) {
        expect(text, contains("'${r.db}'"), reason: r.db);
      }
      // ...and every result the function can return is one the app knows (so none is shown as "scan failed").
      final given = RegExp(r"(?:return query select|then) '([a-z_]+)'").allMatches(text).map((m) => m.group(1)!).toSet();
      for (final g in given) {
        expect(DoorResult.values.any((r) => r.db == g), isTrue, reason: 'the database can answer "$g"');
      }
      expect(RegExp(r"admitted int, remaining int").hasMatch(text), isTrue, reason: 'the columns the app reads are named admitted and remaining');
    }, skip: groupSql.existsSync() ? false : 'the website checkout does not have the group admission migration');

    test('the labels and hints are the website\'s, word for word', () {
      final text = ts.readAsStringSync();
      // ok: { label: 'Admit', hint: 'Let them in.', tone: 'ok' },
      final row = RegExp(r"^\s{2}(\w+): \{ label: '([^']*)', hint: '([^']*)', tone: '(ok|warn|error)' \},$", multiLine: true);
      final found = {for (final m in row.allMatches(text)) m.group(1)!: (m.group(2)!, m.group(3)!, m.group(4)!)};
      final shared = DoorResult.values.where((r) => !groupOnly.contains(r)).toList();
      expect(found.length, shared.length, reason: 'found ${found.keys}');
      for (final r in shared) {
        final web = found[r.db];
        expect(web, isNotNull, reason: r.db);
        final copy = resultCopy[r]!;
        expect(copy.label, web!.$1, reason: r.db);
        expect(copy.hint, web.$2, reason: r.db);
        expect(copy.tone.name, web.$3, reason: r.db);
      }
    }, skip: ts.existsSync() ? false : 'website repo is not checked out next to this app');
  });
}
