import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/events/models/ticket_type.dart';

class TicketService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a new ticket type
  Future<TicketType> createTicketType(String eventId, TicketType ticket) async {
    try {
      final ticketData = {
        'event_id': eventId,
        'name': ticket.name,
        'description': ticket.description,
        'price': ticket.price,
        'capacity': ticket.capacity,
        'sold_count': ticket.soldCount,
        'is_active': ticket.isActive,
      };

      final response = await _supabase
          .from('ticket_types')
          .insert(ticketData)
          .select()
          .single();

      return TicketType.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create ticket type: $e');
    }
  }

  // Update a ticket type
  Future<TicketType> updateTicketType(String ticketId, TicketType ticket) async {
    try {
      final ticketData = {
        'name': ticket.name,
        'description': ticket.description,
        'price': ticket.price,
        'capacity': ticket.capacity,
        'sold_count': ticket.soldCount,
        'is_active': ticket.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('ticket_types')
          .update(ticketData)
          .eq('id', ticketId)
          .select()
          .single();

      return TicketType.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update ticket type: $e');
    }
  }

  // Delete a ticket type
  Future<void> deleteTicketType(String ticketId) async {
    try {
      await _supabase
          .from('ticket_types')
          .delete()
          .eq('id', ticketId);
    } catch (e) {
      throw Exception('Failed to delete ticket type: $e');
    }
  }

  // Get all ticket types for an event
  Future<List<TicketType>> getTicketTypes(String eventId) async {
    try {
      final response = await _supabase
          .from('ticket_types')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: true);

      return (response as List).map((json) => TicketType.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch ticket types: $e');
    }
  }

  // Get a single ticket type by ID
  Future<TicketType> getTicketTypeById(String ticketId) async {
    try {
      final response = await _supabase
          .from('ticket_types')
          .select()
          .eq('id', ticketId)
          .single();

      return TicketType.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch ticket type: $e');
    }
  }

  // Update sold count (when tickets are purchased)
  Future<void> updateSoldCount(String ticketId, int soldCount) async {
    try {
      await _supabase
          .from('ticket_types')
          .update({
            'sold_count': soldCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ticketId);
    } catch (e) {
      throw Exception('Failed to update sold count: $e');
    }
  }

  // Toggle ticket type active status
  Future<void> toggleActiveStatus(String ticketId, bool isActive) async {
    try {
      await _supabase
          .from('ticket_types')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ticketId);
    } catch (e) {
      throw Exception('Failed to toggle ticket type status: $e');
    }
  }

  // Get ticket sales summary for an event
  Future<Map<String, dynamic>> getTicketSalesSummary(String eventId) async {
    try {
      final ticketTypes = await getTicketTypes(eventId);

      final totalCapacity = ticketTypes.fold<int>(
        0,
        (sum, ticket) => sum + ticket.capacity,
      );

      final totalSold = ticketTypes.fold<int>(
        0,
        (sum, ticket) => sum + ticket.soldCount,
      );

      final totalRevenue = ticketTypes.fold<double>(
        0.0,
        (sum, ticket) => sum + (ticket.price * ticket.soldCount),
      );

      return {
        'total_capacity': totalCapacity,
        'total_sold': totalSold,
        'total_available': totalCapacity - totalSold,
        'total_revenue': totalRevenue,
        'ticket_types_count': ticketTypes.length,
        'sold_out_count': ticketTypes.where((t) => t.isSoldOut).length,
      };
    } catch (e) {
      throw Exception('Failed to get ticket sales summary: $e');
    }
  }
}
