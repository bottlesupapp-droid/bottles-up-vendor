import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_filter.dart';

class EventFilterNotifier extends StateNotifier<EventFilter> {
  EventFilterNotifier() : super(EventFilter.initial());

  void updateFilter(EventFilter filter) {
    state = filter;
  }

  void clearFilters() {
    state = EventFilter.initial();
  }

  void updateCity(String? city) {
    state = state.copyWith(city: city);
  }

  void updateDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDate: start, endDate: end);
  }

  void updateStatuses(List<String> statuses) {
    state = state.copyWith(statuses: statuses);
  }

  void updateSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }
}

final eventFilterProvider = StateNotifierProvider<EventFilterNotifier, EventFilter>((ref) {
  return EventFilterNotifier();
});
