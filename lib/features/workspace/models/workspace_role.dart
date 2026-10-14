/// The seven roles in the Phase 2 brief (section 3). Values match the
/// `role` column of `site_memberships` in the database.
enum WorkspaceRole {
  owner('owner', 'Owner'),
  manager('manager', 'Manager'),
  organizer('organizer', 'Organizer'),
  server('server', 'Server'),
  door('door', 'Door staff'),
  security('security', 'Security'),
  verifier('verifier', 'Payment verifier');

  const WorkspaceRole(this.dbValue, this.label);

  final String dbValue;
  final String label;

  /// Null for a role this app version does not know, so a newer backend role
  /// never crashes an older app: that workspace is simply not shown.
  static WorkspaceRole? fromDb(String? value) {
    for (final role in values) {
      if (role.dbValue == value) return role;
    }
    return null;
  }
}
