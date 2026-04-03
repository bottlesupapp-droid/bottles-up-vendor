import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all events for the current vendor
  Future<List<Event>> getVendorEvents() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('events')
          .select()
          .eq('user_id', userId)
          .order('event_date', ascending: false);

      return (response as List).map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch events: $e');
    }
  }

  // Get a single event by ID
  Future<Event> getEventById(String eventId) async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('id', eventId)
          .single();

      return Event.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch event: $e');
    }
  }

  // Create a new event
  Future<Event> createEvent(CreateEventRequest request) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final eventData = {
        ...request.toJson(),
        'user_id': userId,
      };

      final response = await _supabase
          .from('events')
          .insert(eventData)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  // Update an existing event
  Future<Event> updateEvent(String eventId, UpdateEventRequest request) async {
    try {
      final response = await _supabase
          .from('events')
          .update(request.toJson())
          .eq('id', eventId)
          .select()
          .single();

      return Event.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _supabase
          .from('events')
          .delete()
          .eq('id', eventId);
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  // Get categories for events
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select('id, name, description, icon, color')
          .eq('is_active', true)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // Get zones for events
  Future<List<Map<String, dynamic>>> getZones() async {
    try {
      final response = await _supabase
          .from('zones')
          .select('id, name, description, capacity, ticket_price, zone_type')
          .eq('is_active', true)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch zones: $e');
    }
  }

  // Get clubs for events
  Future<List<Map<String, dynamic>>> getClubs() async {
    try {
      final response = await _supabase
          .from('clubs')
          .select('id, name, location')
          .eq('is_active', true)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch clubs: $e');
    }
  }

  // Upload event images
  Future<List<String>> uploadEventImages(String eventId, List<Uint8List> imageBytes, List<String> fileNames) async {
    try {
      final List<String> imageUrls = [];
      
      for (int i = 0; i < imageBytes.length; i++) {
        final fileExt = fileNames[i].split('.').last;
        final fileName = '$eventId-${DateTime.now().millisecondsSinceEpoch}-$i.$fileExt';
        
        await _supabase.storage
            .from('event-images')
            .uploadBinary(fileName, imageBytes[i]);

        final imageUrl = _supabase.storage
            .from('event-images')
            .getPublicUrl(fileName);

        imageUrls.add(imageUrl);
      }

      return imageUrls;
    } catch (e) {
      throw Exception('Failed to upload images: $e');
    }
  }

  // Get event bookings
  Future<List<Map<String, dynamic>>> getEventBookings(String eventId) async {
    try {
      final response = await _supabase
          .from('events_bookings')
          .select('*, profiles(name, email)')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch event bookings: $e');
    }
  }

  // Get filtered events based on tab and filter criteria
  Future<List<Map<String, dynamic>>> getFilteredEvents(String tab, dynamic filter) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Handle templates tab separately
      if (tab == 'templates') {
        final templatesResponse = await _supabase
            .from('event_templates')
            .select()
            .eq('vendor_id', userId)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(templatesResponse);
      }

      var query = _supabase.from('events').select().eq('user_id', userId);

      // Apply tab filter
      final now = DateTime.now().toIso8601String();
      if (tab == 'active') {
        query = query.eq('status', 'published').gte('event_date', now);
      } else if (tab == 'draft') {
        query = query.eq('status', 'draft');
      } else if (tab == 'past') {
        query = query.inFilter('status', ['completed', 'cancelled']);
      }

      // Apply additional filters if filter object has properties
      if (filter != null) {
        // City filter
        try {
          final city = filter.city;
          if (city != null && city.toString().isNotEmpty) {
            query = query.eq('city', city);
          }
        } catch (e) {
          // Filter doesn't have city property
        }

        // Date range filter
        try {
          final startDate = filter.startDate;
          if (startDate != null) {
            query = query.gte('event_date', startDate.toIso8601String());
          }
        } catch (e) {
          // Filter doesn't have startDate property
        }

        try {
          final endDate = filter.endDate;
          if (endDate != null) {
            query = query.lte('event_date', endDate.toIso8601String());
          }
        } catch (e) {
          // Filter doesn't have endDate property
        }

        // Status filter
        try {
          final statuses = filter.statuses;
          if (statuses != null && statuses.isNotEmpty) {
            query = query.inFilter('status', statuses);
          }
        } catch (e) {
          // Filter doesn't have statuses property
        }

        // Search query
        try {
          final searchQuery = filter.searchQuery;
          if (searchQuery != null && searchQuery.toString().isNotEmpty) {
            query = query.ilike('name', '%$searchQuery%');
          }
        } catch (e) {
          // Filter doesn't have searchQuery property
        }
      }

      // Order by event date and execute query
      final response = await query.order('event_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch filtered events: $e');
    }
  }

  // Get distinct cities from events
  Future<List<String>> getDistinctCities() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('events')
          .select('city')
          .eq('user_id', userId)
          .not('city', 'is', null);

      final cities = (response as List)
          .map((e) => e['city'] as String)
          .where((city) => city.isNotEmpty)
          .toSet()
          .toList();

      cities.sort();
      return cities;
    } catch (e) {
      throw Exception('Failed to fetch distinct cities: $e');
    }
  }

  // Update event status
  Future<void> updateEventStatus(String eventId, String status) async {
    try {
      await _supabase
          .from('events')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', eventId);
    } catch (e) {
      throw Exception('Failed to update event status: $e');
    }
  }

  // Duplicate event as template
  Future<Map<String, dynamic>> duplicateAsTemplate(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final event = await getEventById(eventId);

      final templateData = {
        'vendor_id': userId,
        'name': '${event.name} Template',
        'description': event.description,
        'category_id': event.categoryId,
        'default_ticket_price': event.ticketPrice,
        'default_capacity': event.maxCapacity,
        'flyer_image_url': event.images?.isNotEmpty == true ? event.images!.first : null,
      };

      final response = await _supabase
          .from('event_templates')
          .insert(templateData)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to duplicate as template: $e');
    }
  }

  // Get event stats
  Future<Map<String, dynamic>> getEventStats(String eventId) async {
    try {
      final event = await getEventById(eventId);
      final bookings = await getEventBookings(eventId);

      final totalRevenue = bookings.fold<double>(
        0.0,
        (sum, booking) => sum + ((booking['total_amount'] as num?) ?? 0).toDouble(),
      );

      final confirmedBookings = bookings.where((b) => b['status'] == 'confirmed').length;

      return {
        'total_revenue': totalRevenue,
        'tickets_sold': event.currentBookings,
        'total_bookings': bookings.length,
        'confirmed_bookings': confirmedBookings,
        'capacity': event.maxCapacity,
        'available_tickets': event.maxCapacity - event.currentBookings,
      };
    } catch (e) {
      throw Exception('Failed to fetch event stats: $e');
    }
  }
}
