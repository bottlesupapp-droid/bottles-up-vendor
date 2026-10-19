import '../../core/utils/plain_error.dart';
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
      throw Exception(couldNot('fetch clubs', e));
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
      throw Exception(couldNot('fetch club', e));
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
      throw Exception(couldNot('create club', e));
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
      throw Exception(couldNot('update club', e));
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
      throw Exception(couldNot('delete club', e));
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
      throw Exception(couldNot('fetch categories', e));
    }
  }

  // Upload club image
  Future<String> uploadClubImage(String clubId, Uint8List imageBytes, String originalFileName) async {
    try {
      final userId = _supabase.auth.currentUser?.id ?? clubId;
      final fileExt = originalFileName.split('.').last.toLowerCase();
      final fileName = 'clubs/$userId/${clubId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('media').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final imageUrl = _supabase.storage.from('media').getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      throw Exception(couldNot('upload image', e));
    }
  }
}
