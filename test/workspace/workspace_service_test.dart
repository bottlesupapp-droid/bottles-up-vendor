import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/services/workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> row(String id, String role) => {
      'membership_id': id,
      'org_id': 'o',
      'org_name': 'Club Co',
      'org_kind': 'venue_owner',
      'role': role,
    };

WorkspaceService serviceReturning(dynamic value) => WorkspaceService(rpc: (fn, {params}) async => value);
WorkspaceService serviceThrowing(Object error) => WorkspaceService(rpc: (fn, {params}) async => throw error);

void main() {
  group('load()', () {
    test('parses the rows and drops ones it cannot use', () async {
      final s = await serviceReturning([row('m1', 'manager'), row('m2', 'wizard'), row('m3', 'door')]).load();
      expect(s.status, WorkspaceStatus.ready);
      expect(s.workspaces.map((w) => w.membershipId), ['m1', 'm3']);
      expect(s.workspaces.first.role, WorkspaceRole.manager);
    });

    test('an empty answer is ready and empty, not an error', () async {
      final s = await serviceReturning(<dynamic>[]).load();
      expect(s.status, WorkspaceStatus.ready);
      expect(s.hasWorkspaces, isFalse);
    });

    test('a surprising answer shape does not crash', () async {
      expect((await serviceReturning('what').load()).status, WorkspaceStatus.ready);
      expect((await serviceReturning(null).load()).workspaces, isEmpty);
    });

    test('asks for my_workspaces and nothing else', () async {
      String? asked;
      await WorkspaceService(rpc: (fn, {params}) async {
        asked = fn;
        return <dynamic>[];
      }).load();
      expect(asked, 'my_workspaces');
    });
  });

  group('errors', () {
    test('"function does not exist" means the migration is not applied: unavailable, not an error', () async {
      for (final code in ['42883', 'PGRST202', '42P01']) {
        final s = await serviceThrowing(PostgrestException(message: 'x', code: code)).load();
        expect(s.status, WorkspaceStatus.unavailable, reason: code);
      }
    });

    test('any other database error is an error with its message', () async {
      final s = await serviceThrowing(PostgrestException(message: 'permission denied', code: '42501')).load();
      expect(s.status, WorkspaceStatus.error);
      expect(s.message, 'permission denied');
    });

    test('a non-database failure (offline) is an error too', () async {
      final s = await serviceThrowing(Exception('offline')).load();
      expect(s.status, WorkspaceStatus.error);
    });
  });

  group('acceptInvitation()', () {
    test('maps every outcome the database function can return', () async {
      const expected = {
        'ok': InvitationOutcome.ok,
        'already_accepted': InvitationOutcome.alreadyAccepted,
        'invalid': InvitationOutcome.invalid,
        'revoked': InvitationOutcome.revoked,
        'expired': InvitationOutcome.expired,
        'email_mismatch': InvitationOutcome.emailMismatch,
      };
      for (final e in expected.entries) {
        final result = await serviceReturning([
          {'outcome': e.key, 'joined_membership_id': null, 'joined_org_id': null}
        ]).acceptInvitation('tok');
        expect(result, e.value, reason: e.key);
      }
    });

    test('only ok and already_accepted grant access', () {
      expect(InvitationOutcome.ok.grantedAccess, isTrue);
      expect(InvitationOutcome.alreadyAccepted.grantedAccess, isTrue);
      for (final o in [InvitationOutcome.invalid, InvitationOutcome.revoked, InvitationOutcome.expired, InvitationOutcome.emailMismatch, InvitationOutcome.failed]) {
        expect(o.grantedAccess, isFalse, reason: '$o');
      }
    });

    test('sends the token, and nothing but the token', () async {
      Map<String, dynamic>? sent;
      await WorkspaceService(rpc: (fn, {params}) async {
        sent = params;
        return [
          {'outcome': 'ok'}
        ];
      }).acceptInvitation('secret-token');
      expect(sent, {'p_token': 'secret-token'});
    });

    test('network or server failure is "failed", never "ok"', () async {
      expect(await serviceThrowing(Exception('offline')).acceptInvitation('t'), InvitationOutcome.failed);
      expect(await serviceReturning(<dynamic>[]).acceptInvitation('t'), InvitationOutcome.failed);
      expect(await serviceReturning(null).acceptInvitation('t'), InvitationOutcome.failed);
    });

    test('an unknown outcome string is "failed", never "ok"', () {
      expect(InvitationOutcome.fromDb('something-new'), InvitationOutcome.failed);
      expect(InvitationOutcome.fromDb(null), InvitationOutcome.failed);
    });
  });
}
