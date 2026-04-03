import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/event_service.dart';
import 'event_filter_provider.dart';

// Provider for the event service
final eventServiceProvider = Provider<EventService>((ref) {
  return EventService();
});

// Filtered events provider for each tab
final filteredEventsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, tab) async {
  final eventService = ref.watch(eventServiceProvider);
  final filter = ref.watch(eventFilterProvider);

  return await eventService.getFilteredEvents(tab, filter);
});

// Provider for distinct cities
final distinctCitiesProvider = FutureProvider<List<String>>((ref) async {
  final eventService = ref.watch(eventServiceProvider);
  return await eventService.getDistinctCities();
});
