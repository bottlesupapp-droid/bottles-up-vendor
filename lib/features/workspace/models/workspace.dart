import 'workspace_role.dart';

/// One workspace the signed-in user may open: a role inside an organization,
/// limited to a venue, an event, and optionally a shift or a time window.
/// Comes from the `my_workspaces()` database function, which only returns
/// memberships that are valid right now.
class Workspace {
  const Workspace({
    required this.membershipId,
    required this.orgId,
    required this.orgName,
    required this.orgKind,
    required this.role,
    this.venueId,
    this.venueName,
    this.eventId,
    this.eventTitle,
    this.shiftId,
    this.shiftName,
    this.accessStartAt,
    this.accessEndAt,
  });

  final String membershipId;
  final String orgId;
  final String orgName;
  final String orgKind;
  final WorkspaceRole role;
  final String? venueId;
  final String? venueName;
  final String? eventId;
  final String? eventTitle;
  final String? shiftId;
  final String? shiftName;
  final DateTime? accessStartAt;
  final DateTime? accessEndAt;

  /// Returns null when the row is unusable (missing id or an unknown role).
  static Workspace? tryParse(Map<String, dynamic> row) {
    final membershipId = row['membership_id']?.toString();
    final role = WorkspaceRole.fromDb(row['role']?.toString());
    if (membershipId == null || membershipId.isEmpty || role == null) return null;

    DateTime? time(String key) {
      final raw = row[key]?.toString();
      return raw == null ? null : DateTime.tryParse(raw);
    }

    return Workspace(
      membershipId: membershipId,
      orgId: row['org_id']?.toString() ?? '',
      orgName: row['org_name']?.toString() ?? '',
      orgKind: row['org_kind']?.toString() ?? '',
      role: role,
      venueId: row['venue_id']?.toString(),
      venueName: row['venue_name']?.toString(),
      eventId: row['event_id']?.toString(),
      eventTitle: row['event_title']?.toString(),
      shiftId: row['shift_id']?.toString(),
      shiftName: row['shift_name']?.toString(),
      accessStartAt: time('access_start_at'),
      accessEndAt: time('access_end_at'),
    );
  }

  /// What this workspace is limited to, in words: the brief asks that the active
  /// venue and event stay visible on every operational screen.
  String get scopeLabel {
    final String base;
    if (eventId != null) {
      base = eventTitle ?? 'Event';
    } else if (venueId != null) {
      base = venueName ?? 'Venue';
    } else if (role == WorkspaceRole.organizer) {
      base = 'All my events';
    } else {
      base = 'All venues';
    }
    return shiftName == null ? base : '$base · $shiftName';
  }

  /// Temporary staff: limited by a window or a shift.
  bool get isTemporary => accessEndAt != null || shiftId != null;
}
