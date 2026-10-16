import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/providers/supabase_auth_provider.dart';
import '../../owner/logic/owner_rules.dart' show siteUrl;
import '../logic/workspace_routing.dart';
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
        error: (error, _) => WorkspaceSnapshot.error(error.toString()),
      );
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
