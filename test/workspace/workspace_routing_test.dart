import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace ws(String id, WorkspaceRole role) =>
    Workspace(membershipId: id, orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: role);

WorkspaceSnapshot ready(List<Workspace> w) => WorkspaceSnapshot.ready(w);

RedirectDecision decide(String path, WorkspaceSnapshot s, {bool loggedIn = true, String? pending}) =>
    decideWorkspaceRedirect(isLoggedIn: loggedIn, path: path, snapshot: s, pendingToken: pending);

void expectGo(RedirectDecision d, String location) {
  expect(d.isFinal, isTrue);
  expect(d.location, location);
}

void expectStay(RedirectDecision d) {
  expect(d.isFinal, isTrue);
  expect(d.location, isNull);
}

void expectDefer(RedirectDecision d) => expect(d.isFinal, isFalse);

void main() {
  final one = ready([ws('m1', WorkspaceRole.manager)]);
  final two = ready([ws('m1', WorkspaceRole.manager), ws('m2', WorkspaceRole.owner)]);

  group('people WITHOUT a workspace keep the existing vendor flow', () {
    test('empty list', () => expectDefer(decide('/login', ready(const []))));
    test('still loading', () => expectDefer(decide('/login', const WorkspaceSnapshot.loading())));
    test('backend has no workspaces yet', () => expectDefer(decide('/dashboard', const WorkspaceSnapshot.unavailable())));
    test('an error', () => expectDefer(decide('/dashboard', const WorkspaceSnapshot.error('boom'))));
    test('signed out', () => expectDefer(decide('/dashboard', one, loggedIn: false)));
  });

  group('people WITH a workspace', () {
    test('land on the workspace list from any sign-in or legacy landing page', () {
      for (final p in ['/login', '/register', '/forgot-password', '/phone-login', '/verify-otp', '/role-selection', '/', '/dashboard']) {
        expectGo(decide(p, one), WorkspaceRoutes.workspaces);
      }
    });

    test('may stay on the list and on a workspace of their own', () {
      expectStay(decide('/workspaces', two));
      expectStay(decide('/w/m1/tonight', two));
      expectStay(decide('/w/m2/home', two));
    });

    test('are sent back to the list when the workspace in the address is not theirs (revoked, expired, shared link)', () {
      expectGo(decide('/w/someone-elses/tonight', two), WorkspaceRoutes.workspaces);
      expectGo(decide('/w/someone-elses', two), WorkspaceRoutes.workspaces);
      expectGo(decide('/w/', two), WorkspaceRoutes.workspaces);
    });

    test('a workspace address with no tab opens that role\'s landing tab, not a 404', () {
      expectGo(decide('/w/m1', two), '/w/m1/tonight'); // manager
      expectGo(decide('/w/m2', two), '/w/m2/home'); // owner
    });

    test('skip the old forced onboarding (they were invited, they did not register)', () {
      expectStay(decide('/onboarding/staff', one));
    });

    test('a workspace that has just been revoked disappears on the next snapshot', () {
      expectStay(decide('/w/m1/tonight', two));
      expectGo(decide('/w/m1/tonight', ready([ws('m2', WorkspaceRole.owner)])), WorkspaceRoutes.workspaces);
    });
  });

  group('invitation links', () {
    test('opened signed out: go sign in (the token is kept elsewhere)', () {
      expectGo(decide('/accept-invite', one, loggedIn: false), '/login');
    });

    test('opened signed in: the accept screen handles it, even with no workspaces yet', () {
      expectStay(decide('/accept-invite', ready(const [])));
      expectStay(decide('/accept-invite', const WorkspaceSnapshot.unavailable()));
    });

    test('a remembered token brings the person back to the link right after sign-in', () {
      final d = decide('/login', ready(const []), pending: 'abc 123');
      expectGo(d, '/accept-invite?token=abc+123');
    });

    test('...from wherever they land, including the old dashboard', () {
      expect(decide('/dashboard', one, pending: 'tok').location, startsWith('/accept-invite?token='));
    });

    test('...but never loops once they are on the accept screen', () {
      expectStay(decide('/accept-invite', one, pending: 'tok'));
    });

    test('a blank remembered token is ignored', () {
      expectGo(decide('/login', one, pending: ''), WorkspaceRoutes.workspaces);
    });
  });

  group('WorkspaceSnapshot', () {
    test('soleWorkspace only when there is exactly one', () {
      expect(one.soleWorkspace!.membershipId, 'm1');
      expect(two.soleWorkspace, isNull);
      expect(ready(const []).soleWorkspace, isNull);
      expect(const WorkspaceSnapshot.unavailable().soleWorkspace, isNull);
    });

    test('byMembershipId', () {
      expect(two.byMembershipId('m2')!.role, WorkspaceRole.owner);
      expect(two.byMembershipId('nope'), isNull);
    });
  });
}
