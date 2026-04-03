class EventFilter {
  final String? city;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> statuses;
  final String? searchQuery;

  const EventFilter({
    this.city,
    this.startDate,
    this.endDate,
    this.statuses = const [],
    this.searchQuery,
  });

  factory EventFilter.initial() {
    return const EventFilter();
  }

  EventFilter copyWith({
    String? city,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? statuses,
    String? searchQuery,
  }) {
    return EventFilter(
      city: city ?? this.city,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      statuses: statuses ?? this.statuses,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters {
    return city != null ||
        startDate != null ||
        endDate != null ||
        statuses.isNotEmpty ||
        (searchQuery != null && searchQuery!.isNotEmpty);
  }
}
