import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/club.dart';

class ClubService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all clubs (for vendors to see their clubs)
  Future<List<Club>> getVendorClubs() async {
    try {
      final response = await _supabase
          .from('clubs')
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((json) => Club.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch clubs: $e');
    }
  }

  // Get a single club by ID
  Future<Club> getClubById(String clubId) async {
    try {
      final response = await _supabase
          .from('clubs')
          .select()
          .eq('id', clubId)
          .single();

      return Club.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch club: $e');
    }
  }

  // Create a new club
  Future<Club> createClub(CreateClubRequest request) async {
    try {
      final response = await _supabase
          .from('clubs')
          .insert(request.toJson())
          .select()
          .single();

      return Club.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create club: $e');
    }
  }

  // Update an existing club
  Future<Club> updateClub(String clubId, UpdateClubRequest request) async {
    try {
      final response = await _supabase
          .from('clubs')
          .update(request.toJson())
          .eq('id', clubId)
          .select()
          .single();

      return Club.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update club: $e');
    }
  }

  // Delete a club
  Future<void> deleteClub(String clubId) async {
    try {
      await _supabase
          .from('clubs')
          .delete()
          .eq('id', clubId);
    } catch (e) {
      throw Exception('Failed to delete club: $e');
    }
  }

  // Get categories for clubs
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

  // Upload club image
  Future<String> uploadClubImage(String clubId, Uint8List imageBytes, String originalFileName) async {
    try {
      final fileExt = originalFileName.split('.').last;
      final fileName = '$clubId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await _supabase.storage
          .from('club-images')
          .uploadBinary(fileName, imageBytes);

      final imageUrl = _supabase.storage
          .from('club-images')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
