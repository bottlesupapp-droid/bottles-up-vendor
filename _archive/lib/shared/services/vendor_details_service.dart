import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_details.dart';

class VendorDetailsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get vendor details for the current user
  Future<VendorDetails?> getVendorDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('vendor_details')
          .select()
          .eq('vendor_id', user.id)
          .single();

      return VendorDetails.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        // No rows returned - vendor details not found
        return null;
      }
      throw Exception('Failed to fetch vendor details: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch vendor details: $e');
    }
  }

  /// Create new vendor details
  Future<VendorDetails> createVendorDetails(VendorDetails vendorDetails) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final data = vendorDetails.toJson();
      data['vendor_id'] = user.id;

      final response = await _supabase
          .from('vendor_details')
          .insert(data)
          .select()
          .single();

      return VendorDetails.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create vendor details: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create vendor details: $e');
    }
  }

  /// Update existing vendor details
  Future<VendorDetails> updateVendorDetails(VendorDetails vendorDetails) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final data = vendorDetails.toJson();
      data.remove('id'); // Remove id as it shouldn't be updated
      data.remove('vendor_id'); // Remove vendor_id as it shouldn't be updated
      data.remove('created_at'); // Remove created_at as it shouldn't be updated

      final response = await _supabase
          .from('vendor_details')
          .update(data)
          .eq('vendor_id', user.id)
          .select()
          .single();

      return VendorDetails.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update vendor details: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update vendor details: $e');
    }
  }

  /// Upsert vendor details (create if not exists, update if exists)
  Future<VendorDetails> upsertVendorDetails(VendorDetails vendorDetails) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final data = vendorDetails.toJson();
      data['vendor_id'] = user.id;
      data.remove('id'); // Remove id for upsert
      data.remove('created_at'); // Remove created_at for upsert

      final response = await _supabase
          .from('vendor_details')
          .upsert(data, onConflict: 'vendor_id')
          .select()
          .single();

      return VendorDetails.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to upsert vendor details: ${e.message}');
    } catch (e) {
      throw Exception('Failed to upsert vendor details: $e');
    }
  }

  /// Delete vendor details
  Future<void> deleteVendorDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase
          .from('vendor_details')
          .delete()
          .eq('vendor_id', user.id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete vendor details: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete vendor details: $e');
    }
  }

  /// Check if vendor details exist for current user
  Future<bool> hasVendorDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('vendor_details')
          .select('id')
          .eq('vendor_id', user.id)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get vendor details by vendor ID (for admin purposes)
  Future<VendorDetails?> getVendorDetailsById(String vendorId) async {
    try {
      final response = await _supabase
          .from('vendor_details')
          .select()
          .eq('vendor_id', vendorId)
          .single();

      return VendorDetails.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return null;
      }
      throw Exception('Failed to fetch vendor details: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch vendor details: $e');
    }
  }

  /// Get all vendor details (for admin purposes)
  Future<List<VendorDetails>> getAllVendorDetails() async {
    try {
      final response = await _supabase
          .from('vendor_details')
          .select()
          .order('created_at', ascending: false);

      return response.map((json) => VendorDetails.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch all vendor details: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch all vendor details: $e');
    }
  }

  /// Update verification status (for admin purposes)
  Future<VendorDetails> updateVerificationStatus(
    String vendorId,
    bool isVerified,
    String verificationStatus,
    String? verificationNotes,
  ) async {
    try {
      final data = {
        'is_verified': isVerified,
        'verification_status': verificationStatus,
        'verification_notes': verificationNotes,
      };

      final response = await _supabase
          .from('vendor_details')
          .update(data)
          .eq('vendor_id', vendorId)
          .select()
          .single();

      return VendorDetails.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update verification status: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update verification status: $e');
    }
  }
}
