import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/providers/supabase_auth_provider.dart';
import '../../owner/logic/owner_rules.dart' show siteUrl;
import '../logic/workspace_routing.dart';
import '../services/last_workspace_store.dart';
import '../services/workspace_service.dart';

final workspaceServiceProvider = Provider<WorkspaceService>((ref) => WorkspaceService());

/// The signed-in user's workspaces. Re-asked whenever the signed-in user changes,
/// and never for a signed-out visitor.
final workspaceSnapshotProvider = FutureProvider<WorkspaceSnapshot>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const WorkspaceSnapshot.ready([]);
  return ref.watch(workspaceServiceProvider).load();
});

/// Same data as a plain snapshot (loading while the request is in flight), for
/// code that cannot deal with AsyncValue, like the router.
final workspaceStateProvider = Provider<WorkspaceSnapshot>((ref) {
  return ref.watch(workspaceSnapshotProvider).when(
        data: (snapshot) => snapshot,
        loading: () => const WorkspaceSnapshot.loading(),
        error: (error, _) {
          debugPrint('workspaces: request failed: $error'); // for the log; never shown to the person
          return WorkspaceSnapshot.error(error.toString());
        },
      );
});

final lastWorkspaceStoreProvider = Provider<LastWorkspaceStore>((ref) => const LastWorkspaceStore());

/// Remembers that this person opened [membershipId]. Never fails the caller: if there is no signed-in person or the phone cannot store it,
/// the app simply does not remember.
final rememberWorkspaceProvider = Provider<Future<void> Function(String membershipId)>((ref) {
  return (membershipId) async {
    try {
      final user = ref.read(currentUserProvider);
      if (user != null) await ref.read(lastWorkspaceStoreProvider).write(user.id, membershipId);
    } catch (_) {
      // Not remembering is fine.
    }
  };
});

/// The membership this person opened last on this phone (null when none, or when storage is unavailable). Only decides the order of the list.
final lastWorkspaceIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(lastWorkspaceStoreProvider).read(user.id);
});

/// Is the signed-in person a finished classic vendor? Decides whether someone with no workspace keeps the classic
/// dashboard or is sent to set up a business on the website (see [ClassicVendorStatus]).
final classicVendorStatusProvider = Provider<ClassicVendorStatus>((ref) {
  final auth = ref.watch(supabaseAuthProvider);
  return classicVendorStatus(
    isAuthenticated: auth.isAuthenticated,
    vendorChecked: auth.vendorChecked,
    hasCompletedClassicOnboarding: auth.vendorUser?.onboardingCompleted ?? false,
  );
});

/// The website's address in this build (`--dart-define=SITE_URL=...`, else the real site). A provider so tests can point it elsewhere.
final siteUrlProvider = Provider<String>((ref) => siteUrl);

/// Opens an address outside the app (the phone's browser). A provider so tests can see what was opened.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});
