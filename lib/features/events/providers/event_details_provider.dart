import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';

/// Provider for fetching a single event's details
final eventDetailsProvider = FutureProvider.family<Event, String>((ref, eventId) async {
  final eventService = EventService();
  return await eventService.getEventById(eventId);
});

/// Provider for event statistics
final eventStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, eventId) async {
  final eventService = EventService();
  return await eventService.getEventStats(eventId);
});

/// Provider for deleting an event
final deleteEventProvider = Provider((ref) => EventService().deleteEvent);
