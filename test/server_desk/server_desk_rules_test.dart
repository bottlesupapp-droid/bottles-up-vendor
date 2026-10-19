import 'dart:io';

import 'package:bottles_up_vendor/features/server_desk/logic/server_desk_rules.dart';
import 'package:bottles_up_vendor/features/server_desk/widgets/desk_chip.dart';
import 'package:flutter/material.dart' show Color;
import 'package:bottles_up_vendor/features/team/logic/team_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_desk_backend.dart';

Map<String, dynamic> requestRow({
  String id = 'r1',
  String booking = 'b1',
  String kind = 'water_ice_mixers',
  String status = 'new',
  String? assigned,
  bool mine = false,
  String? note,
  String created = '2026-10-09T21:00:00Z',
  String? closed,
  String? statusNote,
}) =>
    {
      'request_id': id,
      'booking_id': booking,
      'confirmation_code': 'AB12CD',
      'customer_name': 'Ada Lovelace',
      'table_name': 'VIP booth',
      'guest_count': 4,
      'kind': kind,
      'note': note,
      'source': 'staff',
      'status': status,
      'assigned_membership_id': assigned,
      'assigned_to_me': mine,
      'created_at': created,
      'acknowledged_at': null,
      'closed_at': closed,
      'status_note': statusNote,
    };

TeamMember member(String id, {String role = 'server', String? venue = 'v1', MemberState state = MemberState.active, String? name, String? email}) =>
    TeamMember(membershipId: id, userId: 'u-$id', role: role, state: state, name: name, email: email, venueId: venue);

void main() {
  group('the words', () {
    test('the five things a table can ask for, in the brief\'s words', () {
      expect({for (final k in ServiceKind.values) k.value: k.label}, {
        'assistance': 'Server assistance',
        'water_ice_mixers': 'Water, ice or mixers',
        'order_question': 'Question about the order',
        'bill_request': 'Bill request',
        'table_issue': 'Table issue',
      });
      expect(ServiceKind.fromDb('bill_request'), ServiceKind.billRequest);
      expect(ServiceKind.fromDb('champagne_tower'), isNull);
      expect(ServiceKind.fromDb(null), isNull);
    });

    test('where a request can stand, and which of those still need somebody', () {
      expect({for (final s in RequestStatus.values) s.value: s.label}, {
        'new': 'New',
        'acknowledged': 'Acknowledged',
        'in_progress': 'In progress',
        'completed': 'Completed',
        'escalated': 'Escalated',
        'cancelled': 'Cancelled',
      });
      expect([for (final s in RequestStatus.values) if (s.isOpen) s.value], ['new', 'acknowledged', 'in_progress', 'escalated']);
      expect(RequestStatus.fromDb('exploded'), isNull);
    });

    test('only escalating and cancelling need a reason', () {
      expect([for (final a in RequestAction.values) if (a.needsReason) a.value], ['escalate', 'cancel']);
      expect(RequestAction.values.map((a) => a.value), ['acknowledge', 'start', 'complete', 'escalate', 'cancel']);
    });

    test('a reason: something to say, and not more than the database takes', () {
      expect(validateReason(''), 'Say why.');
      expect(validateReason('   \n '), 'Say why.');
      expect(validateReason('guest wants the owner'), isNull);
      expect(validateReason('x' * 300), isNull);
      expect(validateReason('x' * 301), 'Keep it to 300 characters or fewer.');
      expect(validateReason('  ${'x' * 300}  '), isNull, reason: 'spaces around it do not count');
    });

    test('a note on a new request is optional, with the same limit', () {
      expect(validateNote(''), isNull);
      expect(validateNote('ice and two limes'), isNull);
      expect(validateNote('x' * 300), isNull);
      expect(validateNote('  ${'x' * 300}  '), isNull, reason: 'spaces around it do not count');
      expect(validateNote('x' * 301), 'Keep it to 300 characters or fewer.');
    });
  });

  group('reading a request', () {
    test('a full row', () {
      final r = parseServiceRequestRow(requestRow(note: 'two limes', assigned: 'm1', mine: true, statusNote: 'sorted', status: 'completed', closed: '2026-10-09T22:00:00Z'))!;
      expect(r.requestId, 'r1');
      expect(r.bookingId, 'b1');
      expect(r.kind, ServiceKind.waterIceMixers);
      expect(r.status, RequestStatus.completed);
      expect(r.note, 'two limes');
      expect(r.assignedMembershipId, 'm1');
      expect(r.assignedToMe, isTrue);
      expect(r.createdAt, DateTime.utc(2026, 10, 9, 21));
      expect(r.closedAt, DateTime.utc(2026, 10, 9, 22));
      expect(r.statusNote, 'sorted');
      expect(r.tableName, 'VIP booth');
      expect(r.customerName, 'Ada Lovelace');
      expect(r.confirmationCode, 'AB12CD');
      expect(r.guestCount, 4);
    });

    test('a row that cannot be trusted is dropped, not guessed at', () {
      expect(parseServiceRequestRow(requestRow(kind: 'champagne_tower')), isNull, reason: 'unknown kind');
      expect(parseServiceRequestRow(requestRow(status: 'exploded')), isNull, reason: 'an unknown status must not look like New');
      expect(parseServiceRequestRow({...requestRow(), 'request_id': null}), isNull);
      expect(parseServiceRequestRow({...requestRow(), 'request_id': ''}), isNull);
      expect(parseServiceRequestRow({...requestRow(), 'booking_id': null}), isNull);
      expect(parseServiceRequestRow({...requestRow(), 'created_at': 'yesterday'}), isNull);
      expect(parseServiceRequestRow({...requestRow(), 'created_at': null}), isNull);
    });

    test('blanks and odd values are tolerated', () {
      final r = parseServiceRequestRow({...requestRow(note: '   '), 'guest_count': 'four', 'assigned_to_me': 'yes', 'customer_name': null, 'confirmation_code': ''})!;
      expect(r.note, isNull);
      expect(r.guestCount, 0);
      expect(r.assignedToMe, isFalse, reason: 'only a real true counts');
      expect(r.customerName, '');
      expect(r.confirmationCode, isNull);
    });

    test('who has it, in words a server can use (never a colleague\'s name)', () {
      expect(holderLabel(parseServiceRequestRow(requestRow(assigned: 'm1', mine: true))!), 'You');
      expect(holderLabel(parseServiceRequestRow(requestRow(assigned: 'm9'))!), 'A colleague');
      expect(holderLabel(parseServiceRequestRow(requestRow())!), 'Nobody yet');
    });
  });

  group('how long it has waited', () {
    final t = DateTime.utc(2026, 10, 9, 21);
    String at(Duration d) => waitingLabel(t, t.add(d));
    test('minutes, then hours and minutes, then days', () {
      expect(at(Duration.zero), 'just now');
      expect(at(const Duration(seconds: 59)), 'just now');
      expect(at(const Duration(seconds: 60)), '1 min');
      expect(at(const Duration(minutes: 59, seconds: 59)), '59 min');
      expect(at(const Duration(minutes: 60)), '1 h');
      expect(at(const Duration(minutes: 61)), '1 h 1 min');
      expect(at(const Duration(hours: 23, minutes: 59)), '23 h 59 min');
      expect(at(const Duration(hours: 24)), '1 day');
      expect(at(const Duration(hours: 47)), '1 day');
      expect(at(const Duration(hours: 48)), '2 days');
    });
    test('a clock that is slightly behind never says a negative time', () {
      expect(at(const Duration(minutes: -3)), 'just now');
    });
  });

  group('the buttons', () {
    ServiceRequestRow row(String status, {String? assigned, bool mine = false}) =>
        parseServiceRequestRow(requestRow(status: status, assigned: assigned, mine: mine, closed: status == 'completed' || status == 'cancelled' ? '2026-10-09T22:00:00Z' : null))!;
    List<String> server(String status, {String? assigned, bool mine = false}) =>
        availableActions(row(status, assigned: assigned, mine: mine), manager: false).map((a) => a.value).toList();
    List<String> manager(String status, {String? assigned, bool mine = false}) =>
        availableActions(row(status, assigned: assigned, mine: mine), manager: true).map((a) => a.value).toList();

    test('a server\'s own request: take it, start it, finish it, pass it up or cancel it', () {
      expect(server('new', assigned: 'm1', mine: true), ['acknowledge', 'complete', 'escalate', 'cancel']);
      expect(server('acknowledged', assigned: 'm1', mine: true), ['start', 'complete', 'escalate', 'cancel']);
      expect(server('in_progress', assigned: 'm1', mine: true), ['complete', 'escalate', 'cancel']);
    });

    test('a request nobody has can be taken by any server', () {
      expect(server('new'), ['acknowledge', 'complete', 'escalate', 'cancel']);
    });

    test('a colleague\'s request, one passed to a manager, and finished ones offer a server nothing', () {
      expect(server('new', assigned: 'm9'), isEmpty);
      expect(server('acknowledged', assigned: 'm9'), isEmpty);
      expect(server('escalated', assigned: 'm1', mine: true), isEmpty);
      expect(server('escalated'), isEmpty);
      expect(server('completed'), isEmpty);
      expect(server('cancelled'), isEmpty);
    });

    test('a manager can act on any open request, and take over one that was passed up', () {
      for (final holder in <(String?, bool)>[(null, false), ('m1', true), ('m9', false)]) {
        expect(manager('new', assigned: holder.$1, mine: holder.$2), ['acknowledge', 'complete', 'cancel']);
        expect(manager('acknowledged', assigned: holder.$1, mine: holder.$2), ['start', 'complete', 'cancel']);
        expect(manager('in_progress', assigned: holder.$1, mine: holder.$2), ['complete', 'cancel']);
        expect(manager('escalated', assigned: holder.$1, mine: holder.$2), ['acknowledge', 'complete', 'cancel']);
      }
      expect(manager('completed'), isEmpty);
      expect(manager('cancelled'), isEmpty);
    });

    // The buttons are checked against the database's own rules, as the fake backend models them (and a test below proves the fake's
    // sentences are the SQL's): never offer a move that would be refused, and offer every move a server is allowed.
    test('every button offered would be accepted, and a server is offered every move the database allows', () async {
      const statuses = ['new', 'acknowledged', 'in_progress', 'escalated', 'completed', 'cancelled'];
      const holders = <(String, String?)>[('nobody', null), ('me', 'm-me'), ('colleague', 'm-other')];
      for (final level in ['server', 'manager']) {
        for (final status in statuses) {
          for (final holder in holders) {
            final reason = '$level / $status / ${holder.$1}';
            final shown = availableActions(
              parseServiceRequestRow(requestRow(status: status, assigned: holder.$2, mine: holder.$2 == 'm-me', closed: status == 'completed' || status == 'cancelled' ? '2026-10-09T22:00:00Z' : null))!,
              manager: level == 'manager',
            );
            final accepted = <RequestAction>[];
            for (final action in RequestAction.values) {
              final db = FakeDeskBackend()
                ..level = level
                ..addBooking('b1');
              final r = db.addRequest('b1', 'water_ice_mixers', status: status, assigned: holder.$2, rid: 'r1');
              if (status == 'completed' || status == 'cancelled') r.closedAt = db.now;
              try {
                await db.call('update_service_request', params: {'p_request': 'r1', 'p_action': action.value, 'p_note': 'because'});
                // Doing again what was already done is accepted but changes nothing: not a button.
                final sameAsNow = {'acknowledge': 'acknowledged', 'start': 'in_progress', 'complete': 'completed', 'escalate': 'escalated', 'cancel': 'cancelled'}[action.value] == status;
                if (!sameAsNow) accepted.add(action);
              } on Object {
                // refused
              }
            }
            for (final a in shown) {
              expect(accepted, contains(a), reason: '$reason: ${a.value} is offered but the database would refuse it');
            }
            if (level == 'server') {
              // A server sees the same moves the database allows, except that "Escalate" from the escalated state is a repeat.
              expect(shown, accepted, reason: reason);
            }
          }
        }
      }
    });
  });

  group('the colours', () {
    test('amber while it waits, blue while someone is on it, green when done, red when passed up, grey when dropped', () {
      expect(requestStatusColor(RequestStatus.fresh), const Color(0xFFFFB300));
      expect(requestStatusColor(RequestStatus.acknowledged), const Color(0xFF42A5F5));
      expect(requestStatusColor(RequestStatus.inProgress), const Color(0xFF42A5F5));
      expect(requestStatusColor(RequestStatus.completed), const Color(0xFF66BB6A));
      expect(requestStatusColor(RequestStatus.escalated), const Color(0xFFEF5350));
      expect(requestStatusColor(RequestStatus.cancelled), const Color(0xFF9E9E9E));
    });
  });

  group('a request by its table', () {
    test('only open requests are shown under a table, grouped by booking', () {
      final rows = [
        parseServiceRequestRow(requestRow(id: 'a', booking: 'b1'))!,
        parseServiceRequestRow(requestRow(id: 'b', booking: 'b1', status: 'in_progress'))!,
        parseServiceRequestRow(requestRow(id: 'c', booking: 'b2', status: 'completed', closed: '2026-10-09T22:00:00Z'))!,
        parseServiceRequestRow(requestRow(id: 'd', booking: 'b2', status: 'escalated'))!,
        parseServiceRequestRow(requestRow(id: 'e', booking: 'b3', status: 'cancelled', closed: '2026-10-09T22:00:00Z'))!,
      ];
      final grouped = openByBooking(rows);
      expect(grouped.keys, ['b1', 'b2']);
      expect(grouped['b1']!.map((r) => r.requestId), ['a', 'b']);
      expect(grouped['b2']!.map((r) => r.requestId), ['d']);
    });
  });

  group('a server\'s table', () {
    Map<String, dynamic> table({String id = 'b1', String venue = 'v1', String night = '2026-10-09'}) => {
          'booking_id': id,
          'venue_id': venue,
          'venue_name': 'Club A',
          'night_date': night,
          'start_time': '21:00:00',
          'slot_label': 'Evening',
          'table_name': 'VIP booth',
          'guest_count': 4,
          'customer_name': 'Ada Lovelace',
          'confirmation_code': 'AB12CD',
          'checked_in_at': null,
          'assigned_at': '2026-10-09T18:00:00Z',
        };

    test('a full row', () {
      final t = parseAssignedTable(table())!;
      expect(t.bookingId, 'b1');
      expect(t.venueId, 'v1');
      expect(t.venueName, 'Club A');
      expect(t.nightDate, '2026-10-09');
      expect(t.startTime, '21:00:00');
      expect(t.slotLabel, 'Evening');
      expect(t.tableName, 'VIP booth');
      expect(t.guestCount, 4);
      expect(t.customerName, 'Ada Lovelace');
      expect(t.confirmationCode, 'AB12CD');
      expect(t.arrived, isFalse);
    });

    test('a guest who has arrived', () {
      expect(parseAssignedTable({...table(), 'checked_in_at': '2026-10-09T22:30:00Z'})!.arrived, isTrue);
      expect(parseAssignedTable({...table(), 'checked_in_at': 'later'})!.arrived, isFalse);
    });

    test('a row without an id, a club or a night is dropped', () {
      expect(parseAssignedTable({...table(), 'booking_id': null}), isNull);
      expect(parseAssignedTable({...table(), 'venue_id': ''}), isNull);
      expect(parseAssignedTable({...table(), 'night_date': null}), isNull);
    });
  });

  group('who has which booking', () {
    test('a row from the manager\'s list', () {
      final a = parseBookingServer({'booking_id': 'b1', 'membership_id': 'm1', 'user_id': 'u1', 'server_available': true})!;
      expect((a.bookingId, a.membershipId, a.userId, a.available), ('b1', 'm1', 'u1', true));
      expect(parseBookingServer({'booking_id': 'b1', 'membership_id': 'm1', 'server_available': null})!.available, isFalse, reason: 'unknown is not available');
      expect(parseBookingServer({'booking_id': null, 'membership_id': 'm1'}), isNull);
      expect(parseBookingServer({'booking_id': 'b1', 'membership_id': ''}), isNull);
    });

    test('the servers a booking can be given to: this club\'s, active now or starting later', () {
      final team = [
        member('m1', name: 'Zoe'),
        member('m2', name: 'amy'),
        member('m3', email: 'sam@club.example'),
        member('m4', state: MemberState.scheduled, name: 'Later Lee'),
        member('m5', state: MemberState.revoked, name: 'Gone Gus'),
        member('m6', state: MemberState.expired, name: 'Over Olga'),
        member('m7', role: 'door', name: 'Door Dan'),
        member('m8', role: 'manager', name: 'Boss Bea'),
        member('m9', venue: 'v2', name: 'Other Club Ola'),
        member('m10', venue: null, name: 'Event Eve'),
        member('m11'),
      ];
      final options = serverOptions(team, 'v1');
      expect(options.map((o) => o.label), ['A server', 'amy', 'Later Lee', 'sam@club.example', 'Zoe'], reason: 'sorted without regard to case; a name, else the email, else a plain word');
      expect(options.firstWhere((o) => o.membershipId == 'm4').starts, isTrue);
      expect(options.firstWhere((o) => o.membershipId == 'm1').starts, isFalse);
    });

    test('who has a booking, with a note when they can no longer serve it', () {
      final team = [member('m1', name: 'Zoe'), member('m2', email: 'sam@club.example', state: MemberState.revoked)];
      expect(assignedServerLabel(const BookingServer(bookingId: 'b', membershipId: 'm1', userId: 'u', available: true), team), 'Zoe');
      expect(assignedServerLabel(const BookingServer(bookingId: 'b', membershipId: 'm1', userId: 'u', available: false), team), 'Zoe (access ended)');
      expect(assignedServerLabel(const BookingServer(bookingId: 'b', membershipId: 'm2', userId: 'u', available: false), team), 'sam@club.example (access ended)');
      expect(assignedServerLabel(const BookingServer(bookingId: 'b', membershipId: 'mX', userId: 'u', available: true), team), 'A server who no longer has access');
    });
  });

  group('what is sent', () {
    test('asking: the argument names the database defines, a blank note as none, a note trimmed', () {
      expect(askParams('b1', ServiceKind.billRequest, null), {'p_booking': 'b1', 'p_kind': 'bill_request', 'p_note': null});
      expect(askParams('b1', ServiceKind.billRequest, '   '), {'p_booking': 'b1', 'p_kind': 'bill_request', 'p_note': null});
      expect(askParams('b1', ServiceKind.waterIceMixers, '  two limes '), {'p_booking': 'b1', 'p_kind': 'water_ice_mixers', 'p_note': 'two limes'});
    });

    test('moving a request along', () {
      expect(actParams('r1', RequestAction.acknowledge, null), {'p_request': 'r1', 'p_action': 'acknowledge', 'p_note': null});
      expect(actParams('r1', RequestAction.escalate, ' guest wants the owner '), {'p_request': 'r1', 'p_action': 'escalate', 'p_note': 'guest wants the owner'});
    });

    test('wording for a failed load', () {
      expect(deskLoadMessage(unavailable: true, accessEnded: false, what: 'requests'), 'Requests are not set up on this server yet.');
      expect(deskLoadMessage(unavailable: false, accessEnded: true, what: 'requests'), 'Your access has ended, or you are signed out.');
      expect(deskLoadMessage(unavailable: false, accessEnded: false, what: 'tables'), 'Tables could not be loaded. Check your connection and try again.');
      expect(deskLoadMessage(unavailable: true, accessEnded: true, what: 'tables'), 'Tables are not set up on this server yet.', reason: 'a missing migration comes first');
    });
  });

  // The database decides every one of these words and rules; the app must not drift from them. These read the website's source when
  // it is checked out beside this app (the monorepo) and are skipped otherwise.
  group('agrees with the website', () {
    final requestsSql = File('../bottles-up-website-main/supabase/migrations/20261014110000_service_requests.sql');
    final serversSql = File('../bottles-up-website-main/supabase/migrations/20261014100000_table_servers.sql');
    const why = 'website repo is not checked out next to this app';
    final present = requestsSql.existsSync() && serversSql.existsSync();

    String sql() => requestsSql.readAsStringSync() + serversSql.readAsStringSync();

    List<String> quotedList(String source, RegExp pattern) =>
        RegExp(r"'([a-z_]+)'").allMatches(pattern.firstMatch(source)!.group(1)!).map((m) => m.group(1)!).toList();

    test('the kinds of request are the database\'s, in the same order', () {
      final fromSql = quotedList(requestsSql.readAsStringSync(), RegExp(r'kind text not null check \(kind in \(([^)]*)\)\)'));
      expect(ServiceKind.values.map((k) => k.value).toList(), fromSql);
    }, skip: present ? false : why);

    test('the statuses are the database\'s, and "open" is what its unique index treats as open', () {
      final source = requestsSql.readAsStringSync();
      final fromSql = quotedList(source, RegExp(r"status text not null default 'new' check \(status in \(([^)]*)\)\)"));
      expect(RequestStatus.values.map((s) => s.value).toList()..sort(), fromSql.toList()..sort());
      final open = quotedList(source, RegExp(r'where status in \(([^)]*)\);'));
      expect([for (final s in RequestStatus.values) if (s.isOpen) s.value]..sort(), open..sort());
    }, skip: present ? false : why);

    test('the moves are the database\'s (plus the one no screen offers yet: handing a request on)', () {
      final source = requestsSql.readAsStringSync();
      final fromSql = quotedList(source, RegExp(r'p_action not in \(([^)]*)\) then'));
      expect(fromSql, [...RequestAction.values.map((a) => a.value), 'reassign']);
    }, skip: present ? false : why);

    test('the longest note is the database\'s', () {
      final source = requestsSql.readAsStringSync();
      expect(source, contains('char_length(note) <= $noteLimit'));
      expect(source, contains('char_length(v_note) > $noteLimit'));
      expect(source, contains('keep the note to $noteLimit characters or fewer'));
    }, skip: present ? false : why);

    test('the functions and their argument names are the ones the app sends', () {
      final all = sql();
      for (final signature in [
        'create_service_request(p_booking uuid, p_kind text, p_note text default null)',
        'list_service_requests(p_venue uuid, p_include_closed boolean default false)',
        'update_service_request(p_request uuid, p_action text, p_note text default null, p_assignee uuid default null)',
        'my_assigned_tables(p_night date)',
        'list_venue_booking_servers(p_venue uuid, p_from date, p_to date)',
        'assign_booking_server(p_booking uuid, p_membership uuid)',
        'unassign_booking_server(p_booking uuid)',
      ]) {
        expect(all, contains('create function public.$signature'), reason: signature);
      }
      expect(askParams('b', ServiceKind.assistance, null).keys, ['p_booking', 'p_kind', 'p_note']);
      expect(actParams('r', RequestAction.start, null).keys, ['p_request', 'p_action', 'p_note']);
    }, skip: present ? false : why);

    test('every column the app reads is one the database returns', () {
      String table(String fn) {
        final m = RegExp('create function public\\.$fn\\([^)]*\\)\\s*returns table \\(([\\s\\S]*?)\\)\\s*language').firstMatch(sql());
        expect(m, isNotNull, reason: fn);
        return m!.group(1)!;
      }

      final requests = table('list_service_requests');
      for (final c in ['request_id', 'booking_id', 'confirmation_code', 'customer_name', 'table_name', 'guest_count', 'kind', 'note', 'status', 'assigned_membership_id', 'assigned_to_me', 'created_at', 'acknowledged_at', 'closed_at', 'status_note']) {
        expect(requests, contains(c), reason: 'list_service_requests.$c');
      }
      final tables = table('my_assigned_tables');
      for (final c in ['booking_id', 'venue_id', 'venue_name', 'night_date', 'start_time', 'slot_label', 'table_name', 'guest_count', 'customer_name', 'confirmation_code', 'checked_in_at']) {
        expect(tables, contains(c), reason: 'my_assigned_tables.$c');
      }
      expect(tables, isNot(contains('email')), reason: 'a server is not given a guest\'s email');
      expect(tables, isNot(contains('phone')));
      final servers = table('list_venue_booking_servers');
      for (final c in ['booking_id', 'membership_id', 'user_id', 'server_available']) {
        expect(servers, contains(c), reason: 'list_venue_booking_servers.$c');
      }
    }, skip: present ? false : why);

    test('the fake database the screens are tested against raises only sentences the real one raises', () {
      final fake = File('test/server_desk/fake_desk_backend.dart').readAsStringSync();
      final sentences = RegExp(r"refuse\('([^']+)'\)|refuse\(\s*([a-z]+) \? '([^']+)' : '([^']+)'\)", multiLine: true)
          .allMatches(fake)
          .expand((m) => [m.group(1), m.group(3), m.group(4)])
          .whereType<String>()
          .toSet();
      // The two sentences chosen by a condition inside refuse(...) are matched by the second alternative; the plain ones by the first.
      final more = RegExp(r"\? '([^']+)' : '([^']+)'").allMatches(fake).expand((m) => [m.group(1)!, m.group(2)!]);
      final all = {...sentences, ...more}..removeWhere((s) => s == 'P0001');
      final real = sql();
      expect(all, isNotEmpty);
      for (final s in all) {
        expect(real, contains(s), reason: 'the fake raises "$s" but the database does not');
      }
    }, skip: present ? false : why);
  });
}
