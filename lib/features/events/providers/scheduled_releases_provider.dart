import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/analytics_models.dart';

class ScheduledReleasesNotifier extends StateNotifier<AsyncValue<List<ScheduledTicketRelease>>> {
  final String eventId;

  ScheduledReleasesNotifier(this.eventId) : super(const AsyncValue.loading()) {
    _loadReleases();
  }

  Future<void> _loadReleases() async {
    state = const AsyncValue.loading();
    try {
      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('scheduled_releases')
          .select()
          .eq('event_id', eventId)
          .order('release_date', ascending: true);

      final releases = (data as List).map((release) {
        return ScheduledTicketRelease(
          id: release['id'],
          eventId: release['event_id'],
          name: release['name'],
          releaseDate: DateTime.parse(release['release_date']),
          ticketQuantity: release['ticket_quantity'],
          price: (release['price'] as num).toDouble(),
          isActive: release['is_active'] ?? true,
          createdAt: DateTime.parse(release['created_at']),
        );
      }).toList();

      state = AsyncValue.data(releases);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> addRelease(ScheduledTicketRelease release) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('scheduled_releases').insert({
        'event_id': eventId,
        'name': release.name,
        'release_date': release.releaseDate.toIso8601String(),
        'ticket_quantity': release.ticketQuantity,
        'price': release.price,
        'is_active': true,
        'tickets_sold': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Reload releases after adding
      await _loadReleases();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteRelease(String releaseId) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('scheduled_releases')
          .delete()
          .eq('id', releaseId);

      // Reload releases after deleting
      await _loadReleases();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final scheduledReleasesProvider = StateNotifierProvider.family<
    ScheduledReleasesNotifier,
    AsyncValue<List<ScheduledTicketRelease>>,
    String>((ref, eventId) {
  return ScheduledReleasesNotifier(eventId);
});
