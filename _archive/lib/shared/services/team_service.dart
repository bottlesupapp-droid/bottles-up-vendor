import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/events/models/event_team_member.dart';

class TeamService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Add a team member to an event
  Future<EventTeamMember> addTeamMember(String eventId, EventTeamMember member) async {
    try {
      final memberData = {
        'event_id': eventId,
        'name': member.name,
        'email': member.email,
        'phone': member.phone,
        'role': member.role,
      };

      final response = await _supabase
          .from('event_team')
          .insert(memberData)
          .select()
          .single();

      return EventTeamMember.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add team member: $e');
    }
  }

  // Update a team member
  Future<EventTeamMember> updateTeamMember(String memberId, EventTeamMember member) async {
    try {
      final memberData = {
        'name': member.name,
        'email': member.email,
        'phone': member.phone,
        'role': member.role,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('event_team')
          .update(memberData)
          .eq('id', memberId)
          .select()
          .single();

      return EventTeamMember.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update team member: $e');
    }
  }

  // Remove a team member
  Future<void> removeTeamMember(String memberId) async {
    try {
      await _supabase
          .from('event_team')
          .delete()
          .eq('id', memberId);
    } catch (e) {
      throw Exception('Failed to remove team member: $e');
    }
  }

  // Get all team members for an event
  Future<List<EventTeamMember>> getTeamMembers(String eventId) async {
    try {
      final response = await _supabase
          .from('event_team')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: true);

      return (response as List).map((json) => EventTeamMember.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch team members: $e');
    }
  }

  // Get a single team member by ID
  Future<EventTeamMember> getTeamMemberById(String memberId) async {
    try {
      final response = await _supabase
          .from('event_team')
          .select()
          .eq('id', memberId)
          .single();

      return EventTeamMember.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch team member: $e');
    }
  }

  // Get team members by role
  Future<List<EventTeamMember>> getTeamMembersByRole(String eventId, String role) async {
    try {
      final response = await _supabase
          .from('event_team')
          .select()
          .eq('event_id', eventId)
          .eq('role', role)
          .order('created_at', ascending: true);

      return (response as List).map((json) => EventTeamMember.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch team members by role: $e');
    }
  }

  // Get team summary (count by role)
  Future<Map<String, int>> getTeamSummary(String eventId) async {
    try {
      final teamMembers = await getTeamMembers(eventId);

      final summary = <String, int>{};
      for (final member in teamMembers) {
        summary[member.role] = (summary[member.role] ?? 0) + 1;
      }

      return summary;
    } catch (e) {
      throw Exception('Failed to get team summary: $e');
    }
  }

  // Bulk add team members
  Future<List<EventTeamMember>> bulkAddTeamMembers(
    String eventId,
    List<EventTeamMember> members,
  ) async {
    try {
      final memberDataList = members.map((member) => {
        'event_id': eventId,
        'name': member.name,
        'email': member.email,
        'phone': member.phone,
        'role': member.role,
      }).toList();

      final response = await _supabase
          .from('event_team')
          .insert(memberDataList)
          .select();

      return (response as List).map((json) => EventTeamMember.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to bulk add team members: $e');
    }
  }
}
