import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/dashboard_stats.dart';
import '../../../shared/services/dashboard_service.dart';

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService();
});

final dashboardProvider = FutureProvider<DashboardStats>((ref) async {
  final dashboardService = ref.read(dashboardServiceProvider);
  return await dashboardService.getDashboardStats();
});

final recentActivityProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dashboardService = ref.read(dashboardServiceProvider);
  return await dashboardService.getRecentActivity();
});

final topPerformingEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dashboardService = ref.read(dashboardServiceProvider);
  return await dashboardService.getTopPerformingEvents();
});

final lowStockAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dashboardService = ref.read(dashboardServiceProvider);
  return await dashboardService.getLowStockAlerts();
}); 