import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, on this phone, which workspace a person opened last. Kept per signed-in person, so two people sharing a phone never see each
/// other's choice. It only decides the order of the list: access itself is always re-checked from the database, so a stale or tampered value
/// can never open anything. If the phone's storage is unavailable the app simply does not remember.
class LastWorkspaceStore {
  const LastWorkspaceStore();

  static String _key(String userId) => 'last_workspace_$userId';

  Future<String?> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key(userId));
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, String membershipId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId), membershipId);
    } catch (_) {
      // Not remembering is fine.
    }
  }
}
