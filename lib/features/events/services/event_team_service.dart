import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_team_member.dart';

/// The team of an event (DJs, security, staff): the four things the Team & Lineup page does to the `event_team_members` table. They used to be written inline in the page,
/// which made the page impossible to show without a live database; the queries are unchanged. The database client is looked up when it is first needed, so the service can be
/// made (and replaced by a fake) where Supabase has not been started.
class EventTeamService {
  EventTeamService([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  /// Everyone on the event's team, oldest first.
  Future<List<EventTeamMember>> list(String eventId) async {
    final response = await _db.from('event_team_members').select().eq('event_id', eventId).order('created_at', ascending: true);
    return (response as List).map((json) => EventTeamMember.fromJson(json)).toList();
  }

  Future<void> add({required String eventId, required String name, required String role, String? email, String? phone}) async {
    await _db.from('event_team_members').insert({'event_id': eventId, 'name': name, 'role': role, 'email': email, 'phone': phone});
  }

  Future<void> update(String id, {required String name, required String role, String? email, String? phone}) async {
    await _db.from('event_team_members').update({'name': name, 'role': role, 'email': email, 'phone': phone, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<void> remove(String id) async {
    await _db.from('event_team_members').delete().eq('id', id);
  }
}

final eventTeamServiceProvider = Provider<EventTeamService>((ref) => EventTeamService());
