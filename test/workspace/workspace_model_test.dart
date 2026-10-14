import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row({Map<String, dynamic>? over}) => {
      'membership_id': 'm1',
      'org_id': 'o1',
      'org_name': 'Club Co',
      'org_kind': 'venue_owner',
      'role': 'manager',
      'venue_id': 'v1',
      'venue_name': 'Club A',
      'event_id': null,
      'event_title': null,
      'shift_id': null,
      'shift_name': null,
      'access_start_at': null,
      'access_end_at': null,
      ...?over,
    };

void main() {
  group('WorkspaceRole', () {
    test('maps every database value and nothing else', () {
      for (final r in WorkspaceRole.values) {
        expect(WorkspaceRole.fromDb(r.dbValue), r);
      }
      expect(WorkspaceRole.values.map((r) => r.dbValue),
          ['owner', 'manager', 'organizer', 'server', 'door', 'security', 'verifier']);
    });

    test('an unknown role (a newer backend) is null, never a crash', () {
      expect(WorkspaceRole.fromDb('wizard'), isNull);
      expect(WorkspaceRole.fromDb(null), isNull);
    });
  });

  group('Workspace.tryParse', () {
    test('reads a database row', () {
      final w = Workspace.tryParse(row())!;
      expect(w.membershipId, 'm1');
      expect(w.role, WorkspaceRole.manager);
      expect(w.orgName, 'Club Co');
      expect(w.venueName, 'Club A');
    });

    test('skips rows that cannot be used', () {
      expect(Workspace.tryParse(row(over: {'role': 'wizard'})), isNull);
      expect(Workspace.tryParse(row(over: {'membership_id': null})), isNull);
      expect(Workspace.tryParse(row(over: {'membership_id': ''})), isNull);
    });

    test('parses access window timestamps', () {
      final w = Workspace.tryParse(row(over: {
        'access_start_at': '2026-10-06T20:00:00+00:00',
        'access_end_at': '2026-10-07T04:00:00+00:00',
      }))!;
      expect(w.accessEndAt!.toUtc(), DateTime.utc(2026, 10, 7, 4));
      expect(w.isTemporary, isTrue);
    });

    test('a bad timestamp becomes null instead of throwing', () {
      expect(Workspace.tryParse(row(over: {'access_end_at': 'not a date'}))!.accessEndAt, isNull);
    });
  });

  group('scopeLabel (what the workspace is limited to)', () {
    test('an owner covers all venues', () {
      final w = Workspace.tryParse(row(over: {'role': 'owner', 'venue_id': null, 'venue_name': null}))!;
      expect(w.scopeLabel, 'All venues');
    });
    test('an organizer covers all their events', () {
      final w = Workspace.tryParse(row(over: {'role': 'organizer', 'venue_id': null, 'venue_name': null}))!;
      expect(w.scopeLabel, 'All my events');
    });
    test('a manager is one venue', () {
      expect(Workspace.tryParse(row())!.scopeLabel, 'Club A');
    });
    test('event staff are one event, and a shift is appended', () {
      final w = Workspace.tryParse(row(over: {
        'role': 'door',
        'venue_id': null,
        'venue_name': null,
        'event_id': 'e1',
        'event_title': 'Promoter Night',
        'shift_id': 's1',
        'shift_name': 'Saturday',
      }))!;
      expect(w.scopeLabel, 'Promoter Night · Saturday');
      expect(w.isTemporary, isTrue);
    });
    test('permanent staff are not temporary', () {
      expect(Workspace.tryParse(row())!.isTemporary, isFalse);
    });
  });
}
