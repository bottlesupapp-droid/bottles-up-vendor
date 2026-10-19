import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace ws(String id, WorkspaceRole role) =>
    Workspace(membershipId: id, orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: role);

WorkspaceSnapshot ready(List<Workspace> w) => WorkspaceSnapshot.ready(w);

/// [classic] defaults to a finished classic vendor, the people the older rules were written for.
RedirectDecision decide(
  String path,
  WorkspaceSnapshot s, {
  bool loggedIn = true,
  String? pending,
  ClassicVendorStatus classic = ClassicVendorStatus.classic,
}) =>
    decideWorkspaceRedirect(isLoggedIn: loggedIn, path: path, snapshot: s, pendingToken: pending, classicVendor: classic);

void expectGo(RedirectDecision d, String location, {String? reason}) {
  expect(d.isFinal, isTrue, reason: reason);
  expect(d.location, location, reason: reason);
}

void expectStay(RedirectDecision d) {
  expect(d.isFinal, isTrue);
  expect(d.location, isNull);
}

void expectDefer(RedirectDecision d) => expect(d.isFinal, isFalse);

void main() {
  final one = ready([ws('m1', WorkspaceRole.manager)]);
  final two = ready([ws('m1', WorkspaceRole.manager), ws('m2', WorkspaceRole.owner)]);

  group('finished classic vendors WITHOUT a workspace keep the existing vendor flow', () {
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

  group('people with no workspace who are not classic vendors set up a business on the website', () {
    const none = ClassicVendorStatus.none;
    final empty = ready(const []);

    test('wherever they land, once the backend has answered "no workspaces"', () {
      for (final p in ['/login', '/register', '/', '/dashboard', '/workspaces', '/onboarding/staff', '/onboarding/venue', '/clubs', '/w/x/tonight']) {
        expectGo(decide(p, empty, classic: none), WorkspaceRoutes.noWorkspace);
      }
    });

    test('but NOT when asking for the workspaces failed: that is a failure page with Retry, never "set up your business"', () {
      for (final p in ['/dashboard', '/login', '/', '/workspaces', '/clubs', '/w/x/tonight', WorkspaceRoutes.noWorkspace]) {
        expectGo(decide(p, const WorkspaceSnapshot.error('offline'), classic: none), WorkspaceRoutes.workspaceError);
      }
    });

    test('while the list is still being asked for they wait, instead of being pushed into the classic onboarding', () {
      expectStay(decide('/login', const WorkspaceSnapshot.loading(), classic: none));
      expectStay(decide('/onboarding/staff', const WorkspaceSnapshot.loading(), classic: none));
    });

    test('a backend without workspaces yet changes nothing (there is no website side to send them to)', () {
      expectDefer(decide('/dashboard', const WorkspaceSnapshot.unavailable(), classic: none));
    });

    test('the setup page is theirs while the answer is empty, being asked again, or the backend has no workspaces, so "Check again" never bounces them', () {
      for (final s in [empty, const WorkspaceSnapshot.loading(), const WorkspaceSnapshot.unavailable()]) {
        expectStay(decide(WorkspaceRoutes.noWorkspace, s, classic: none));
      }
    });

    test('a finished classic vendor who is on the setup page is not moved to the failure page by an error (the classic dashboard is theirs)', () {
      expectStay(decide(WorkspaceRoutes.noWorkspace, const WorkspaceSnapshot.error('offline')));
    });

    test('the failure page stays while it is failing or retrying, and moves on once there is an answer', () {
      expectStay(decide(WorkspaceRoutes.workspaceError, const WorkspaceSnapshot.error('offline'), classic: none));
      expectStay(decide(WorkspaceRoutes.workspaceError, const WorkspaceSnapshot.loading(), classic: none));
      expectGo(decide(WorkspaceRoutes.workspaceError, empty, classic: none), WorkspaceRoutes.noWorkspace);
      expectGo(decide(WorkspaceRoutes.workspaceError, empty), '/dashboard', reason: 'a finished classic vendor goes to their dashboard');
      expectDefer(decide(WorkspaceRoutes.workspaceError, const WorkspaceSnapshot.unavailable(), classic: none));
    });

    test('a person with a workspace is taken off the failure page once the list arrives', () {
      expectGo(decide(WorkspaceRoutes.workspaceError, one, classic: none), WorkspaceRoutes.workspaces);
    });

    test('an invitation still goes through: the accept screen is not intercepted, a remembered token wins', () {
      expectStay(decide('/accept-invite', empty, classic: none));
      expectGo(decide('/login', empty, classic: none, pending: 'abc'), '/accept-invite?token=abc');
    });

    test('signed out is untouched', () {
      expectDefer(decide('/login', empty, classic: none, loggedIn: false));
      expectDefer(decide(WorkspaceRoutes.noWorkspace, empty, classic: none, loggedIn: false));
    });
  });

  group('the vendors row has not been looked up yet', () {
    const loading = ClassicVendorStatus.loading;

    test('nothing is decided about somebody who may turn out to be a classic vendor', () {
      expectDefer(decide('/login', ready(const []), classic: loading));
      expectDefer(decide('/dashboard', ready(const []), classic: loading));
      expectDefer(decide('/dashboard', const WorkspaceSnapshot.error('x'), classic: loading));
    });

    test('the no-workspace page does not bounce them either', () {
      expectStay(decide(WorkspaceRoutes.noWorkspace, ready(const []), classic: loading));
    });

    test('a workspace still wins', () {
      expectGo(decide('/login', one, classic: loading), WorkspaceRoutes.workspaces);
    });
  });

  group('the no-workspace page and the other kinds of people', () {
    test('a finished classic vendor is sent to the classic dashboard once the list is known to be empty', () {
      expectGo(decide(WorkspaceRoutes.noWorkspace, ready(const [])), '/dashboard');
    });

    test('...but not before it is known', () {
      expectStay(decide(WorkspaceRoutes.noWorkspace, const WorkspaceSnapshot.loading()));
    });

    test('somebody who now has a workspace leaves the page for the list', () {
      for (final c in ClassicVendorStatus.values) {
        expectGo(decide(WorkspaceRoutes.noWorkspace, one, classic: c), WorkspaceRoutes.workspaces);
      }
    });

    test('having a workspace beats everything about the classic dashboard', () {
      for (final c in ClassicVendorStatus.values) {
        expectGo(decide('/dashboard', one, classic: c), WorkspaceRoutes.workspaces);
        expectStay(decide('/w/m1/tonight', one, classic: c));
      }
    });
  });

  group('classicVendorStatus', () {
    ClassicVendorStatus status({bool signedIn = true, bool checked = true, bool done = true}) => classicVendorStatus(
          isAuthenticated: signedIn,
          vendorChecked: checked,
          hasCompletedClassicOnboarding: done,
        );

    test('only a finished classic onboarding makes a classic vendor', () {
      expect(status(done: true), ClassicVendorStatus.classic);
      expect(status(done: false), ClassicVendorStatus.none); // no row, or a row that never finished
    });

    test('not decided until the row has been looked up (a failed lookup stays undecided too)', () {
      expect(status(checked: false, done: false), ClassicVendorStatus.loading);
      expect(status(checked: false, done: true), ClassicVendorStatus.loading);
    });

    test('signed out is undecided', () {
      expect(status(signedIn: false), ClassicVendorStatus.loading);
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
