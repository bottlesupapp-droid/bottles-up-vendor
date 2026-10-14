import 'package:flutter/foundation.dart';

import '../models/role_navigation.dart';
import '../models/workspace.dart';

/// Route paths owned by the workspace layer.
class WorkspaceRoutes {
  static const String workspaces = '/workspaces';
  static const String acceptInvite = '/accept-invite';
  static const String workspacePrefix = '/w/';
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
/// It only takes over for people who actually have a workspace. Everyone else
/// (no memberships yet, or a backend that does not have them) gets the existing
/// vendor flow unchanged.
RedirectDecision decideWorkspaceRedirect({
  required bool isLoggedIn,
  required String path,
  required WorkspaceSnapshot snapshot,
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

  if (!snapshot.hasWorkspaces) return const RedirectDecision.defer();

  // From here the person has at least one workspace.
  if (_signedOutPaths.contains(path) || path == '/' || path == '/dashboard') {
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
