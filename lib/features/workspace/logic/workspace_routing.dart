import 'package:flutter/foundation.dart';

import '../models/role_navigation.dart';
import '../models/workspace.dart';

/// Route paths owned by the workspace layer.
class WorkspaceRoutes {
  static const String workspaces = '/workspaces';
  static const String acceptInvite = '/accept-invite';

  /// Signed in, no workspace and not a classic vendor: set up a business on the website, or use an invitation.
  static const String noWorkspace = '/no-workspace';
  static const String workspacePrefix = '/w/';
}

/// Is the signed-in person a vendor of the older, classic dashboard (legacy tables)?
///
/// Only someone who finished that dashboard's own onboarding is. A `vendors` row that exists but never finished it
/// (the app used to create one for every account that signed in, including website and customer accounts) is not.
enum ClassicVendorStatus {
  /// The `vendors` row has not been looked up yet (or the lookup failed): do not decide anything.
  loading,

  /// Finished the classic onboarding: keep the classic dashboard exactly as it was.
  classic,

  /// No such row, or never finished: business accounts are created on the website, not here.
  none,
}

ClassicVendorStatus classicVendorStatus({
  required bool isAuthenticated,
  required bool vendorChecked,
  required bool hasCompletedClassicOnboarding,
}) {
  if (!isAuthenticated || !vendorChecked) return ClassicVendorStatus.loading;
  return hasCompletedClassicOnboarding ? ClassicVendorStatus.classic : ClassicVendorStatus.none;
}

enum WorkspaceStatus {
  /// Still asking the backend.
  loading,

  /// The backend answered (the list may be empty).
  ready,

  /// The backend does not have workspaces yet (migration not applied).
  /// Treated like "no workspaces": the existing vendor flow carries on.
  unavailable,

  /// Something else went wrong.
  error,
}

class WorkspaceSnapshot {
  const WorkspaceSnapshot._(this.status, this.workspaces, this.message);

  const WorkspaceSnapshot.loading() : this._(WorkspaceStatus.loading, const [], null);
  const WorkspaceSnapshot.ready(List<Workspace> workspaces) : this._(WorkspaceStatus.ready, workspaces, null);
  const WorkspaceSnapshot.unavailable([String? message]) : this._(WorkspaceStatus.unavailable, const [], message);
  const WorkspaceSnapshot.error(String message) : this._(WorkspaceStatus.error, const [], message);

  final WorkspaceStatus status;
  final List<Workspace> workspaces;
  final String? message;

  bool get hasWorkspaces => status == WorkspaceStatus.ready && workspaces.isNotEmpty;

  Workspace? byMembershipId(String id) {
    for (final w in workspaces) {
      if (w.membershipId == id) return w;
    }
    return null;
  }

  /// "If one workspace exists, open it directly." (brief, section 2)
  Workspace? get soleWorkspace => hasWorkspaces && workspaces.length == 1 ? workspaces.first : null;
}

/// An invitation link opened while signed out. The token is remembered across the
/// sign-in so the person lands back on it instead of losing it.
final ValueNotifier<String?> pendingInviteToken = ValueNotifier<String?>(null);

/// What the router should do. `defer` means "the workspace layer has no opinion:
/// let the existing vendor rules decide".
class RedirectDecision {
  const RedirectDecision._(this.location, this.isFinal);

  /// Leave the current location alone and skip the older rules.
  const RedirectDecision.stay() : this._(null, true);

  /// Send the user to [location].
  const RedirectDecision.go(String location) : this._(location, true);

  /// No decision: fall through to the existing vendor rules.
  const RedirectDecision.defer() : this._(null, false);

  final String? location;
  final bool isFinal;
}

const Set<String> _signedOutPaths = {
  '/login',
  '/register',
  '/forgot-password',
  '/phone-login',
  '/verify-otp',
  '/role-selection',
};

/// The workspace layer of the router. Pure: no providers, no widgets, so it can
/// be tested exhaustively.
///
/// It takes over for people who have a workspace, and for people who have neither a workspace nor the
/// classic vendor dashboard (they are sent to [WorkspaceRoutes.noWorkspace]: business accounts are created
/// on the website). Everyone else (a finished classic vendor, or a backend that does not have workspaces)
/// gets the existing vendor flow unchanged.
RedirectDecision decideWorkspaceRedirect({
  required bool isLoggedIn,
  required String path,
  required WorkspaceSnapshot snapshot,
  required ClassicVendorStatus classicVendor,
  String? pendingToken,
}) {
  if (!isLoggedIn) {
    // An invitation opened signed out: go sign in; the token is kept (see above).
    if (path == WorkspaceRoutes.acceptInvite) return const RedirectDecision.go('/login');
    return const RedirectDecision.defer();
  }

  if (path == WorkspaceRoutes.acceptInvite) return const RedirectDecision.stay();

  if (pendingToken != null && pendingToken.isNotEmpty) {
    return RedirectDecision.go('${WorkspaceRoutes.acceptInvite}?token=${Uri.encodeQueryComponent(pendingToken)}');
  }

  if (!snapshot.hasWorkspaces) return _withoutWorkspace(path, snapshot, classicVendor);

  // From here the person has at least one workspace.
  if (_signedOutPaths.contains(path) || path == '/' || path == '/dashboard' || path == WorkspaceRoutes.noWorkspace) {
    return const RedirectDecision.go(WorkspaceRoutes.workspaces);
  }

  if (path.startsWith(WorkspaceRoutes.workspacePrefix)) {
    final segments = Uri.parse(path).pathSegments; // ['w', membershipId, section]
    final membershipId = segments.length > 1 ? segments[1] : '';
    // Revoked, expired or somebody else's: back to the list. Access is re-checked on every change.
    final workspace = snapshot.byMembershipId(membershipId);
    if (workspace == null) return const RedirectDecision.go(WorkspaceRoutes.workspaces);
    // A workspace address with no tab (/w/<id>) opens that role's first tab instead of a 404.
    if (segments.length < 3) return RedirectDecision.go(workspaceLandingPath(workspace));
  }

  return const RedirectDecision.stay();
}

/// A signed-in person with no workspace.
RedirectDecision _withoutWorkspace(String path, WorkspaceSnapshot snapshot, ClassicVendorStatus classicVendor) {
  // Asked and answered, whether with an empty list or with an error. Loading and "not set up on this server yet"
  // are not answers.
  final answered = snapshot.status == WorkspaceStatus.ready || snapshot.status == WorkspaceStatus.error;

  if (path == WorkspaceRoutes.noWorkspace) {
    // A finished classic vendor does not belong here (a link, a back button): the classic dashboard is theirs.
    if (classicVendor == ClassicVendorStatus.classic && snapshot.status == WorkspaceStatus.ready) {
      return const RedirectDecision.go('/dashboard');
    }
    // Everyone else stays, including while the list is being asked for again ("Check again").
    return const RedirectDecision.stay();
  }

  if (classicVendor == ClassicVendorStatus.none) {
    if (answered) return const RedirectDecision.go(WorkspaceRoutes.noWorkspace);
    // Still asking: do not let the old rules push this person into the classic onboarding in the meantime.
    if (snapshot.status == WorkspaceStatus.loading) return const RedirectDecision.stay();
  }

  return const RedirectDecision.defer();
}
