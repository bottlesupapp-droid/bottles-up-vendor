import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/dashboard_stats.dart';
import '../../../shared/services/dashboard_service.dart';
import '../../../core/config/supabase_config.dart';
import '../../auth/providers/supabase_auth_provider.dart';

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService();
});

final dashboardProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final dashboardService = ref.read(dashboardServiceProvider);
  return await dashboardService.getDashboardStats();
});

final recentActivityProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dashboardService = ref.read(dashboardServiceProvider);
  return await dashboardService.getRecentActivity();
});

final topPerformingEventsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dashboardService = ref.read(dashboardServiceProvider);
  return await dashboardService.getTopPerformingEvents();
});

final lowStockAlertsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dashboardService = ref.read(dashboardServiceProvider);
  return await dashboardService.getLowStockAlerts();
});

/// Returns a list of missing venue profile field labels for the current user's club.
/// Empty list means the profile is complete.
final venueProfileCompletenessProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  // Watch auth state so this re-runs on user change.
  ref.watch(supabaseAuthProvider);
  final user = SupabaseConfig.client.auth.currentUser;
  if (user == null) return [];

  final response = await SupabaseConfig.client
      .from('clubs')
      .select('gallery, social_links, description, floorplan_data')
      .eq('owner_id', user.id)
      .maybeSingle();

  if (response == null) return [];

  final missing = <String>[];

  final gallery = response['gallery'] as List?;
  if (gallery == null || gallery.isEmpty) {
    missing.add('Photos (banner, menu, interior)');
  }

  final socialLinks = response['social_links'] as Map?;
  if (socialLinks == null ||
      (socialLinks['venue_type'] == null &&
       socialLinks['music_genres'] == null &&
       socialLinks['amenities'] == null)) {
    missing.add('Venue details (type, music, amenities)');
  }

  final description = response['description'] as String?;
  final floorplanData = response['floorplan_data'] as Map?;
  if ((description == null || description.isEmpty) &&
      (floorplanData == null || (floorplanData['description'] as String?)?.isEmpty != false)) {
    missing.add('Venue description');
  }

  return missing;
});