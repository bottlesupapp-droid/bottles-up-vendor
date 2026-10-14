import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../shared/models/event_model.dart';
import '../../../shared/models/user_model.dart';

class EventsService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Get events based on user role
  ///
  /// Role-based access:
  /// - venue_owner: Events at their venues
  /// - organizer: Events they created
  /// - promoter: Events they have promo codes for (read-only)
  /// - staff: Events they're assigned to (read-only)
  Future<List<EventModel>> getEventsByRole({
    required VendorUser user,
    String? status,
    int? limit,
  }) async {
    try {
      var query = _client.from('events').select();

      // Apply role-based filtering
      switch (user.role) {
        case 'venue_owner':
          // Venue owners see events at their venues
          // First, get venue IDs owned by this user
          final venuesResponse = await _client
              .from('clubs')
              .select('id')
              .eq('owner_id', user.id);

          final venuesList = venuesResponse as List;
          if (venuesList.isNotEmpty) {
            final venueIds = venuesList.map((v) => v['id'] as String).toList();
            query = query.inFilter('club_id', venueIds);
          } else {
            // No venues, return empty
            return [];
          }
          break;

        case 'organizer':
          // Organizers see events they created
          query = query.eq('user_id', user.id);
          break;

        case 'promoter':
          // Promoters see events they have promo codes for
          final promoCodesResponse = await _client
              .from('promo_codes')
              .select('event_id')
              .eq('promoter_id', user.id);

          final promoCodesList = promoCodesResponse as List;
          if (promoCodesList.isNotEmpty) {
            final eventIds = promoCodesList
                .where((p) => p['event_id'] != null)
                .map((p) => p['event_id'] as String)
                .toList();

            if (eventIds.isEmpty) return [];
            query = query.inFilter('id', eventIds);
          } else {
            // No promo codes, return empty
            return [];
          }
          break;

        case 'staff':
          // Staff see events they're assigned to via shifts
          final shiftsResponse = await _client
              .from('shifts')
              .select('event_id')
              .eq('staff_id', user.id);

          final shiftsList = shiftsResponse as List;
          if (shiftsList.isNotEmpty) {
            final eventIds = shiftsList.map((s) => s['event_id'] as String).toList();
            query = query.inFilter('id', eventIds);
          } else {
            // No shifts, return empty
            return [];
          }
          break;

        default:
          // Unknown role, return empty
          return [];
      }

      // Apply status filter if provided
      if (status != null && status.isNotEmpty && status != 'all') {
        if (status == 'active') {
          query = query.inFilter('status', ['published', 'upcoming', 'live', 'ongoing']);
        } else if (status == 'draft') {
          query = query.eq('status', 'draft');
        } else if (status == 'past') {
          query = query.inFilter('status', ['completed', 'cancelled']);
        } else {
          query = query.eq('status', status);
        }
      }

      // Order by event date descending and apply limit
      var transformQuery = query.order('event_date', ascending: false);

      if (limit != null && limit > 0) {
        transformQuery = transformQuery.limit(limit);
      }

      final response = await transformQuery;

      return (response as List).map((json) => EventModel.fromJson(json)).toList();
    } catch (e) {
      print('Error getting events by role: $e');
      throw Exception('Failed to load events: $e');
    }
  }

  /// Get a single event by ID (with role-based access check)
  Future<EventModel?> getEventById(String eventId, VendorUser user) async {
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('id', eventId)
          .maybeSingle();

      if (response == null) return null;

      final event = EventModel.fromJson(response);

      // Verify user has access to this event
      final hasAccess = await _checkEventAccess(event, user);
      if (!hasAccess) {
        throw Exception('Access denied to this event');
      }

      return event;
    } catch (e) {
      print('Error getting event by ID: $e');
      throw Exception('Failed to load event: $e');
    }
  }

  /// Check if user has access to an event based on their role
  Future<bool> _checkEventAccess(EventModel event, VendorUser user) async {
    switch (user.role) {
      case 'venue_owner':
        if (event.clubId == null) return false;

        // Check if user owns the club
        final clubResponse = await _client
            .from('clubs')
            .select('owner_id')
            .eq('id', event.clubId!)
            .maybeSingle();

        return clubResponse != null && clubResponse['owner_id'] == user.id;

      case 'organizer':
        return event.userId == user.id;

      case 'promoter':
        // Check if promoter has a promo code for this event
        final promoResponse = await _client
            .from('promo_codes')
            .select('id')
            .eq('event_id', event.id)
            .eq('promoter_id', user.id)
            .maybeSingle();

        return promoResponse != null;

      case 'staff':
        // Check if staff has a shift for this event
        final shiftResponse = await _client
            .from('shifts')
            .select('id')
            .eq('event_id', event.id)
            .eq('staff_id', user.id)
            .maybeSingle();

        return shiftResponse != null;

      default:
        return false;
    }
  }

  /// Create a new event (only for venue_owner and organizer roles)
  Future<EventModel> createEvent({
    required VendorUser user,
    required String name,
    required DateTime eventDate,
    String? description,
    String? clubId,
    String? startTime,
    String? endTime,
    double ticketPrice = 0,
    int maxCapacity = 100,
    bool isDraft = true,
  }) async {
    // Only venue_owner and organizer can create events
    if (user.role != 'venue_owner' && user.role != 'organizer') {
      throw Exception('Only venue owners and organizers can create events');
    }

    try {
      final eventData = {
        'name': name,
        'description': description,
        'club_id': clubId,
        'event_date': eventDate.toIso8601String().split('T')[0],
        'start_time': startTime,
        'end_time': endTime,
        'ticket_price': ticketPrice,
        'max_capacity': maxCapacity,
        'status': isDraft ? 'draft' : 'published',
        'user_id': user.id,
        'is_active': true,
        'current_bookings': 0,
        'rsvp_count': 0,
        'table_booking_count': 0,
        'revenue': 0,
        'sales_count': 0,
      };

      final response = await _client
          .from('events')
          .insert(eventData)
          .select()
          .single();

      return EventModel.fromJson(response);
    } catch (e) {
      print('Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  /// Update an event (only by owner/organizer)
  Future<EventModel> updateEvent({
    required String eventId,
    required VendorUser user,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // First check if user has access to this event
      final event = await getEventById(eventId, user);
      if (event == null) {
        throw Exception('Event not found or access denied');
      }

      // Only venue owner and organizer can update
      if (user.role != 'venue_owner' && user.role != 'organizer') {
        throw Exception('Only venue owners and organizers can update events');
      }

      // Verify ownership
      if (user.role == 'organizer' && event.userId != user.id) {
        throw Exception('You can only update your own events');
      }

      if (user.role == 'venue_owner' && event.clubId != null) {
        final hasAccess = await _checkEventAccess(event, user);
        if (!hasAccess) {
          throw Exception('You can only update events at your venues');
        }
      }

      // Update the event
      final response = await _client
          .from('events')
          .update(updates)
          .eq('id', eventId)
          .select()
          .single();

      return EventModel.fromJson(response);
    } catch (e) {
      print('Error updating event: $e');
      throw Exception('Failed to update event: $e');
    }
  }

  /// Delete an event (only by owner/organizer)
  Future<void> deleteEvent({
    required String eventId,
    required VendorUser user,
  }) async {
    try {
      // First check if user has access to this event
      final event = await getEventById(eventId, user);
      if (event == null) {
        throw Exception('Event not found or access denied');
      }

      // Only venue owner and organizer can delete
      if (user.role != 'venue_owner' && user.role != 'organizer') {
        throw Exception('Only venue owners and organizers can delete events');
      }

      // Verify ownership
      if (user.role == 'organizer' && event.userId != user.id) {
        throw Exception('You can only delete your own events');
      }

      if (user.role == 'venue_owner' && event.clubId != null) {
        final hasAccess = await _checkEventAccess(event, user);
        if (!hasAccess) {
          throw Exception('You can only delete events at your venues');
        }
      }

      // Delete the event
      await _client.from('events').delete().eq('id', eventId);
    } catch (e) {
      print('Error deleting event: $e');
      throw Exception('Failed to delete event: $e');
    }
  }

  /// Get event statistics for dashboard
  Future<Map<String, dynamic>> getEventStats(VendorUser user) async {
    try {
      final events = await getEventsByRole(user: user);

      final activeEvents = events.where((e) => e.isActiveEvent).length;
      final draftEvents = events.where((e) => e.isDraft).length;
      final completedEvents = events.where((e) => e.isCompleted).length;
      final totalRevenue = events.fold<double>(0, (sum, e) => sum + e.revenue);
      final totalBookings = events.fold<int>(0, (sum, e) => sum + e.currentBookings);

      return {
        'total_events': events.length,
        'active_events': activeEvents,
        'draft_events': draftEvents,
        'completed_events': completedEvents,
        'total_revenue': totalRevenue,
        'total_bookings': totalBookings,
      };
    } catch (e) {
      print('Error getting event stats: $e');
      return {
        'total_events': 0,
        'active_events': 0,
        'draft_events': 0,
        'completed_events': 0,
        'total_revenue': 0.0,
        'total_bookings': 0,
      };
    }
  }
}
