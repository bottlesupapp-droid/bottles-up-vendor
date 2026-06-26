import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class SupabaseService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Get event statistics
  Future<Map<String, dynamic>> getEventStats() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {'total': 0, 'upcoming': 0};

      final response = await _client
          .from('events')
          .select('id, event_date')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final events = response as List<dynamic>;
      final now = DateTime.now();

      final upcomingEvents = events.where((event) {
        if (event['event_date'] != null) {
          final eventDate = DateTime.parse(event['event_date']);
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
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {'total': 0, 'revenue': 0.0};

      final response = await _client
          .from('events_bookings')
          .select('id, total_amount, events!inner(user_id)')
          .eq('events.user_id', userId);

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
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final eventsResponse = await _client
          .from('events')
          .select('id, name, event_date, clubs(name)')
          .eq('user_id', userId)
          .order('event_date', ascending: false)
          .limit(5);

      final events = eventsResponse as List<dynamic>;
      final List<Map<String, dynamic>> recentEvents = [];

      for (final event in events) {
        final bookingsResponse = await _client
            .from('events_bookings')
            .select('id, total_amount')
            .eq('event_id', event['id']);

        final bookings = bookingsResponse as List<dynamic>;
        double eventRevenue = 0.0;

        for (final booking in bookings) {
          eventRevenue += (booking['total_amount'] as num?)?.toDouble() ?? 0.0;
        }

        final club = event['clubs'] as Map<String, dynamic>?;
        recentEvents.add({
          'id': event['id'],
          'title': event['name'] ?? 'Unknown Event',
          'venue': club?['name'] ?? 'Unknown Venue',
          'date': event['event_date'] ?? DateTime.now().toIso8601String(),
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

  // Get all bookings for this vendor's events
  Future<List<Map<String, dynamic>>> getAllBookings() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      // Fetch event ticket bookings for events owned by this vendor
      final eventBookingsRes = await _client
          .from('events_bookings')
          .select('''
            id,
            ticket_quantity,
            total_amount,
            status,
            created_at,
            events!inner(
              name,
              event_date,
              user_id,
              clubs(name)
            )
          ''')
          .eq('events.user_id', userId)
          .order('created_at', ascending: false);

      final eventBookings = (eventBookingsRes as List<dynamic>).map((booking) {
        final event = booking['events'] as Map<String, dynamic>? ?? {};
        final club = event['clubs'] as Map<String, dynamic>?;
        return {
          'id': booking['id'],
          'type': 'event',
          'eventDetails': {
            'title': event['name'] ?? 'Unknown Event',
            'venue': club?['name'] ?? 'Unknown Venue',
            'date': event['event_date'],
          },
          'totalPrice': booking['total_amount'],
          'numberOfTickets': booking['ticket_quantity'],
          'status': booking['status'] ?? 'pending',
          'bookedAt': booking['created_at'],
        };
      }).toList();

      // Fetch club table bookings for clubs owned by this vendor
      List<Map<String, dynamic>> tableBookings = [];
      try {
        final tableBookingsRes = await _client
            .from('table_bookings')
            .select('''
              id,
              guest_count,
              total_price,
              status,
              booking_date,
              time_slot,
              created_at,
              club_tables!inner(
                name,
                club_id,
                clubs!inner(name, owner_id)
              )
            ''')
            .eq('club_tables.clubs.owner_id', userId)
            .order('created_at', ascending: false);

        tableBookings = (tableBookingsRes as List<dynamic>).map((booking) {
          final table = booking['club_tables'] as Map<String, dynamic>? ?? {};
          final club = table['clubs'] as Map<String, dynamic>?;
          return {
            'id': booking['id'],
            'type': 'table',
            'eventDetails': {
              'title': 'Table: ${table['name'] ?? 'Unknown Table'}',
              'venue': club?['name'] ?? 'Unknown Venue',
              'date': booking['booking_date'],
              'timeSlot': booking['time_slot'],
            },
            'totalPrice': booking['total_price'],
            'numberOfTickets': booking['guest_count'],
            'status': booking['status'] ?? 'pending',
            'bookedAt': booking['created_at'],
          };
        }).toList();
      } catch (_) {
        // Table bookings unavailable — return event bookings only
      }

      final all = [...eventBookings, ...tableBookings];
      all.sort((a, b) {
        final aDate = DateTime.tryParse(a['bookedAt'] as String? ?? '') ?? DateTime(0);
        final bDate = DateTime.tryParse(b['bookedAt'] as String? ?? '') ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      return all;
    } catch (e) {
      return [];
    }
  }

  // Update booking status
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      await _client
          .from('events_bookings')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', bookingId);
      return true;
    } catch (e) {
      return false;
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