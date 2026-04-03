import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/analytics_models.dart';

class GuestListNotifier extends StateNotifier<AsyncValue<List<GuestListEntry>>> {
  final String eventId;

  GuestListNotifier(this.eventId) : super(const AsyncValue.loading()) {
    _loadGuests();
  }

  Future<void> _loadGuests() async {
    state = const AsyncValue.loading();
    try {
      final supabase = Supabase.instance.client;

      final data = await supabase
          .from('guest_list')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      final guests = (data as List).map((guest) {
        return GuestListEntry(
          id: guest['id'],
          name: guest['name'],
          email: guest['email'],
          phone: guest['phone'],
          ticketType: guest['ticket_type'],
          checkedIn: guest['checked_in'] ?? false,
          checkedInAt: guest['checked_in_at'] != null
              ? DateTime.parse(guest['checked_in_at'])
              : null,
          notes: guest['notes'],
        );
      }).toList();

      state = AsyncValue.data(guests);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> addGuest(GuestListEntry guest) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('guest_list').insert({
        'event_id': eventId,
        'name': guest.name,
        'email': guest.email,
        'phone': guest.phone,
        'ticket_type': guest.ticketType,
        'notes': guest.notes,
        'checked_in': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Reload guests after adding
      await _loadGuests();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> bulkUploadGuests(List<GuestListEntry> guests) async {
    try {
      final supabase = Supabase.instance.client;

      final guestsData = guests.map((g) => {
        'event_id': eventId,
        'name': g.name,
        'email': g.email,
        'phone': g.phone,
        'ticket_type': g.ticketType,
        'notes': g.notes,
        'checked_in': false,
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      await supabase.from('guest_list').insert(guestsData);

      // Reload guests after bulk upload
      await _loadGuests();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkInGuest(String guestId) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      await supabase.from('guest_list').update({
        'checked_in': true,
        'checked_in_at': DateTime.now().toIso8601String(),
        'checked_in_by': currentUserId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', guestId);

      // Reload guests after check-in
      await _loadGuests();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final guestListProvider = StateNotifierProvider.family<GuestListNotifier,
    AsyncValue<List<GuestListEntry>>, String>((ref, eventId) {
  return GuestListNotifier(eventId);
});
