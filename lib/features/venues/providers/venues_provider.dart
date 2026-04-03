import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/venue_model.dart';
import '../../../shared/models/venue_request_model.dart';
import '../services/venue_request_service.dart';

/// Provider for the venue request service
final venueRequestServiceProvider = Provider<VenueRequestService>((ref) {
  return VenueRequestService();
});

/// Provider to get list of venues with optional filters
final venuesListProvider = FutureProvider.family.autoDispose<List<Venue>, ({String? city, int? minCapacity})>(
  (ref, params) async {
    final service = ref.watch(venueRequestServiceProvider);
    return service.getVenues(
      city: params.city,
      minCapacity: params.minCapacity,
    );
  },
);

/// Provider to get a single venue by ID
final venueByIdProvider = FutureProvider.family.autoDispose<Venue?, String>(
  (ref, venueId) async {
    final service = ref.watch(venueRequestServiceProvider);
    return service.getVenueById(venueId);
  },
);

/// Provider to get organizer's venue requests
final organizerRequestsProvider = FutureProvider.family.autoDispose<List<VenueRequest>, String>(
  (ref, organizerId) async {
    final service = ref.watch(venueRequestServiceProvider);
    return service.getOrganizerRequests(organizerId);
  },
);

/// Provider to get venue owner's requests
final venueOwnerRequestsProvider = FutureProvider.family.autoDispose<List<VenueRequest>, ({String venueOwnerId, VenueRequestStatus? status})>(
  (ref, params) async {
    final service = ref.watch(venueRequestServiceProvider);
    return service.getVenueOwnerRequests(
      venueOwnerId: params.venueOwnerId,
      status: params.status,
    );
  },
);

/// Provider to get request statistics for organizer
final organizerRequestStatsProvider = FutureProvider.family.autoDispose<Map<String, int>, String>(
  (ref, organizerId) async {
    final service = ref.watch(venueRequestServiceProvider);
    return service.getOrganizerRequestStats(organizerId);
  },
);

/// Provider to get request statistics for venue owner
final venueOwnerRequestStatsProvider = FutureProvider.family.autoDispose<Map<String, int>, String>(
  (ref, venueOwnerId) async {
    final service = ref.watch(venueRequestServiceProvider);
    return service.getVenueOwnerRequestStats(venueOwnerId);
  },
);
