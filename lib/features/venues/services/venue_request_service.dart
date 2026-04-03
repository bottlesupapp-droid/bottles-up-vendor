import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../shared/models/venue_model.dart';
import '../../../shared/models/venue_request_model.dart';
import '../../../shared/models/event_model.dart';
import '../../../shared/models/user_model.dart';

class VenueRequestService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Get all venues (for organizers to browse)
  Future<List<Venue>> getVenues({
    String? city,
    int? minCapacity,
    VenueStatus? status,
  }) async {
    try {
      var query = _client.from('clubs').select();

      // Filter by city
      if (city != null && city.isNotEmpty) {
        query = query.contains('address->city', city);
      }

      // Filter by capacity
      if (minCapacity != null) {
        query = query.gte('capacity', minCapacity);
      }

      // Filter by status (default to active venues)
      if (status != null) {
        query = query.eq('status', status.name);
      } else {
        query = query.eq('status', 'active');
      }

      final response = await query.order('name');

      return (response as List).map((json) => Venue.fromJson(json)).toList();
    } catch (e) {
      print('Error getting venues: $e');
      throw Exception('Failed to load venues: $e');
    }
  }

  /// Get a single venue by ID
  Future<Venue?> getVenueById(String venueId) async {
    try {
      final response = await _client
          .from('clubs')
          .select()
          .eq('id', venueId)
          .maybeSingle();

      if (response == null) return null;

      return Venue.fromJson(response);
    } catch (e) {
      print('Error getting venue: $e');
      throw Exception('Failed to load venue: $e');
    }
  }

  /// Create a venue request (organizer sends proposal to venue)
  Future<VenueRequest> createVenueRequest({
    required VendorUser organizer,
    required CreateVenueRequestData requestData,
  }) async {
    // Only organizers can create venue requests
    if (organizer.role != 'organizer') {
      throw Exception('Only organizers can send venue requests');
    }

    try {
      final data = requestData.toJson();
      data['organizer_id'] = organizer.id;

      final response = await _client
          .from('venue_requests')
          .insert(data)
          .select()
          .single();

      return VenueRequest.fromJson(response);
    } catch (e) {
      print('Error creating venue request: $e');
      throw Exception('Failed to create venue request: $e');
    }
  }

  /// Get venue requests by organizer
  Future<List<VenueRequest>> getOrganizerRequests(String organizerId) async {
    try {
      final response = await _client
          .from('venue_requests')
          .select()
          .eq('organizer_id', organizerId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => VenueRequest.fromJson(json)).toList();
    } catch (e) {
      print('Error getting organizer requests: $e');
      throw Exception('Failed to load requests: $e');
    }
  }

  /// Get venue requests for a venue owner
  Future<List<VenueRequest>> getVenueOwnerRequests({
    required String venueOwnerId,
    VenueRequestStatus? status,
  }) async {
    try {
      // First get all venues owned by this user
      final venuesResponse = await _client
          .from('clubs')
          .select('id')
          .eq('owner_id', venueOwnerId);

      final venuesList = venuesResponse as List;
      if (venuesList.isEmpty) return [];

      final venueIds = venuesList.map((v) => v['id'] as String).toList();

      // Then get all requests for those venues
      var query = _client
          .from('venue_requests')
          .select()
          .inFilter('venue_id', venueIds);

      // Filter by status if provided
      if (status != null) {
        query = query.eq('status', status.name);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((json) => VenueRequest.fromJson(json)).toList();
    } catch (e) {
      print('Error getting venue owner requests: $e');
      throw Exception('Failed to load requests: $e');
    }
  }

  /// Approve venue request and create event
  Future<EventModel> approveVenueRequest({
    required String requestId,
    required VendorUser venueOwner,
    String? notes,
  }) async {
    // Only venue owners can approve
    if (venueOwner.role != 'venue_owner') {
      throw Exception('Only venue owners can approve requests');
    }

    try {
      // Get the request
      final requestResponse = await _client
          .from('venue_requests')
          .select()
          .eq('id', requestId)
          .single();

      final request = VenueRequest.fromJson(requestResponse);

      // Verify the venue belongs to this owner
      final venue = await getVenueById(request.venueId);
      if (venue == null || venue.ownerId != venueOwner.id) {
        throw Exception('You can only approve requests for your own venues');
      }

      // Update request status to approved
      await _client
          .from('venue_requests')
          .update({
            'status': 'approved',
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Create event from approved request
      final eventData = {
        'name': request.eventTitle,
        'description': request.eventDescription,
        'club_id': request.venueId,
        'user_id': request.organizerId, // Organizer as event creator
        'event_date': request.eventDate!.toIso8601String().split('T')[0],
        'start_time': request.eventProposal['start_time'],
        'end_time': request.eventProposal['end_time'],
        'flyer_image_url': request.flyerUrl,
        'max_capacity': request.expectedAttendance ?? venue.capacity ?? 100,
        'status': 'draft', // Event starts as draft, organizer can publish later
        'is_active': true,
        'current_bookings': 0,
        'rsvp_count': 0,
        'table_booking_count': 0,
        'revenue': 0,
        'sales_count': 0,
      };

      final eventResponse = await _client
          .from('events')
          .insert(eventData)
          .select()
          .single();

      return EventModel.fromJson(eventResponse);
    } catch (e) {
      print('Error approving venue request: $e');
      throw Exception('Failed to approve request: $e');
    }
  }

  /// Decline venue request
  Future<void> declineVenueRequest({
    required String requestId,
    required VendorUser venueOwner,
    required String reason,
  }) async {
    // Only venue owners can decline
    if (venueOwner.role != 'venue_owner') {
      throw Exception('Only venue owners can decline requests');
    }

    try {
      // Get the request to verify ownership
      final requestResponse = await _client
          .from('venue_requests')
          .select()
          .eq('id', requestId)
          .single();

      final request = VenueRequest.fromJson(requestResponse);

      // Verify the venue belongs to this owner
      final venue = await getVenueById(request.venueId);
      if (venue == null || venue.ownerId != venueOwner.id) {
        throw Exception('You can only decline requests for your own venues');
      }

      // Update request status to declined
      await _client
          .from('venue_requests')
          .update({
            'status': 'declined',
            'decline_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      print('Error declining venue request: $e');
      throw Exception('Failed to decline request: $e');
    }
  }

  /// Get request with venue and organizer details
  Future<Map<String, dynamic>> getRequestWithDetails(String requestId) async {
    try {
      final requestResponse = await _client
          .from('venue_requests')
          .select('*, clubs(*), vendors(*)')
          .eq('id', requestId)
          .single();

      return requestResponse;
    } catch (e) {
      print('Error getting request details: $e');
      throw Exception('Failed to load request details: $e');
    }
  }

  /// Get request statistics for venue owner
  Future<Map<String, int>> getVenueOwnerRequestStats(String venueOwnerId) async {
    try {
      final requests = await getVenueOwnerRequests(venueOwnerId: venueOwnerId);

      return {
        'total': requests.length,
        'pending': requests.where((r) => r.isPending).length,
        'approved': requests.where((r) => r.isApproved).length,
        'declined': requests.where((r) => r.isDeclined).length,
      };
    } catch (e) {
      return {'total': 0, 'pending': 0, 'approved': 0, 'declined': 0};
    }
  }

  /// Get request statistics for organizer
  Future<Map<String, int>> getOrganizerRequestStats(String organizerId) async {
    try {
      final requests = await getOrganizerRequests(organizerId);

      return {
        'total': requests.length,
        'pending': requests.where((r) => r.isPending).length,
        'approved': requests.where((r) => r.isApproved).length,
        'declined': requests.where((r) => r.isDeclined).length,
      };
    } catch (e) {
      return {'total': 0, 'pending': 0, 'approved': 0, 'declined': 0};
    }
  }
}
