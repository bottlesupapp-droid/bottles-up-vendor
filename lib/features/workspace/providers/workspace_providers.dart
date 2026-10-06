import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/supabase_auth_provider.dart';
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
