import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class SupabaseService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Get event statistics
  Future<Map<String, dynamic>> getEventStats() async {
    try {
      final response = await _client
          .from('vendor_events')
          .select('id, date')
          .order('created_at', ascending: false);

      final events = response as List<dynamic>;
      final now = DateTime.now();
      
      final upcomingEvents = events.where((event) {
        if (event['date'] != null) {
          final eventDate = DateTime.parse(event['date']);
          return eventDate.isAfter(now);
        }
        return false;
      }).length;

      return {
        'total': events.length,
        'upcoming': upcomingEvents,
      };
    } catch (e) {
      return {'total': 0, 'upcoming': 0};
    }
  }

  // Get booking statistics
  Future<Map<String, dynamic>> getBookingStats() async {
    try {
      final response = await _client
          .from('vendor_bookings')
          .select('id, total_amount')
          .order('created_at', ascending: false);

      final bookings = response as List<dynamic>;
      
      double totalRevenue = 0.0;
      for (final booking in bookings) {
        totalRevenue += (booking['total_amount'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'total': bookings.length,
        'revenue': totalRevenue,
      };
    } catch (e) {
      return {'total': 0, 'revenue': 0.0};
    }
  }

  // Get inventory statistics
  Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      final response = await _client
          .from('vendor_inventory')
          .select('id, featured')
          .order('created_at', ascending: false);

      final inventory = response as List<dynamic>;
      
      final featuredCount = inventory.where((item) {
        return item['featured'] == true;
      }).length;

      return {
        'total': inventory.length,
        'featured': featuredCount,
      };
    } catch (e) {
      return {'total': 0, 'featured': 0};
    }
  }

  // Get recent events with booking data
  Future<List<Map<String, dynamic>>> getRecentEvents() async {
    try {
      final eventsResponse = await _client
          .from('vendor_events')
          .select('id, title, venue, date')
          .order('date', ascending: false)
          .limit(5);

      final events = eventsResponse as List<dynamic>;
      final List<Map<String, dynamic>> recentEvents = [];

      for (final event in events) {
        // Get bookings for this event
        final bookingsResponse = await _client
            .from('vendor_bookings')
            .select('id, total_amount')
            .eq('event_id', event['id']);

        final bookings = bookingsResponse as List<dynamic>;
        double eventRevenue = 0.0;
        
        for (final booking in bookings) {
          eventRevenue += (booking['total_amount'] as num?)?.toDouble() ?? 0.0;
        }

        recentEvents.add({
          'id': event['id'],
          'title': event['title'] ?? 'Unknown Event',
          'venue': event['venue'] ?? 'Unknown Venue',
          'date': event['date'] ?? DateTime.now().toIso8601String(),
          'bookings': bookings.length,
          'revenue': eventRevenue,
        });
      }

      return recentEvents;
    } catch (e) {
      return [];
    }
  }

  // Get all events
  Future<List<Map<String, dynamic>>> getAllEvents() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('events')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((event) => Map<String, dynamic>.from(event))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get all bookings
  Future<List<Map<String, dynamic>>> getAllBookings() async {
    try {
      final response = await _client
          .from('vendor_bookings')
          .select()
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((booking) => Map<String, dynamic>.from(booking))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get all inventory
  Future<List<Map<String, dynamic>>> getAllInventory() async {
    try {
      final response = await _client
          .from('vendor_inventory')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Add new event
  Future<String?> addEvent(Map<String, dynamic> eventData) async {
    try {
      final response = await _client
          .from('vendor_events')
          .insert(eventData)
          .select('id')
          .single();
      
      return response['id']?.toString();
    } catch (e) {
      return null;
    }
  }

  // Update event
  Future<bool> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      await _client
          .from('vendor_events')
          .update(eventData)
          .eq('id', eventId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete event
  Future<bool> deleteEvent(String eventId) async {
    try {
      await _client
          .from('vendor_events')
          .delete()
          .eq('id', eventId);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});