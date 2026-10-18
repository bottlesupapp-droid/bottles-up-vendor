import '../models/workspace.dart';

/// Several workspaces: the one used last goes first and says so ("remember last authorized selection", brief 15 Oct, section 4).
///
/// "Authorized" is the point: the remembered id only counts if the person STILL has that workspace right now (it was not revoked, did not
/// expire, and is not somebody else's after another person signs in on the same phone). Otherwise nothing is remembered and the list keeps its order.
List<Workspace> withLastUsedFirst(List<Workspace> all, String? lastMembershipId) {
  if (lastMembershipId == null) return all;
  final i = all.indexWhere((w) => w.membershipId == lastMembershipId);
  if (i <= 0) return all; // not there (no longer authorized), or already first
  return [all[i], ...all.sublist(0, i), ...all.sublist(i + 1)];
}

/// Is [workspace] the remembered one and still in the list?
bool isLastUsed(Workspace workspace, List<Workspace> all, String? lastMembershipId) =>
    lastMembershipId != null && workspace.membershipId == lastMembershipId && all.any((w) => w.membershipId == lastMembershipId);
