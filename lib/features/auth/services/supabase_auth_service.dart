import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../shared/models/user_model.dart';

class SupabaseAuthService {
  final SupabaseClient _client = SupabaseConfig.client;
  final GoTrueClient _auth = SupabaseConfig.auth;

  // Get current user stream
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<AuthResponse> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String? businessName,
    String? phoneNumber,
    String? vendorType,
  }) async {
    try {
      // Create Supabase auth user
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'business_name': businessName,
          'phone': phoneNumber,
          'vendor_type': vendorType,
        },
      );

      if (response.user != null) {
        // Create vendor document with new schema
        await _createVendorUserDocument(
          VendorUser(
            id: response.user!.id,
            email: email,
            phone: phoneNumber,
            businessName: businessName,
            onboardingCompleted: false,
            twoFaEnabled: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            role: vendorType ?? 'staff', // Use the role from registration
          ),
        );
      }

      return response;

    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      // Call the database function to delete the account
      // This function deletes the vendor record, which triggers the auth user deletion
      await _client.rpc('delete_account');
      
      // Sign out
      await signOut();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with phone number (send OTP)
  Future<void> signInWithPhone(String phoneNumber) async {
    try {
      await _auth.signInWithOtp(
        phone: phoneNumber,
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }

  // Verify OTP
  Future<AuthResponse> verifyOTP({
    required String phoneNumber,
    required String token,
  }) async {
    try {
      final response = await _auth.verifyOTP(
        phone: phoneNumber,
        token: token,
        type: OtpType.sms,
      );

      // Create vendor document if needed
      if (response.user != null) {
        // Check if vendor user exists, if not create one
        final vendorUser = await getVendorUser(response.user!.id);
        if (vendorUser == null) {
          await _createVendorUserDocument(
            VendorUser(
              id: response.user!.id,
              email: response.user!.email ?? '',
              phone: phoneNumber,
              businessName: 'Bottles Up Vendor',
              onboardingCompleted: false,
              twoFaEnabled: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              role: 'staff',
            ),
          );
        }
      }

      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  // Get vendor user data
  Future<VendorUser?> getVendorUser(String uid) async {
    try {
      final response = await _client
          .from('vendors')
          .select()
          .eq('id', uid)
          .maybeSingle();
      
      if (response != null) {
        return VendorUser.fromMap(response);
      } else {
        // Auto-create vendor document for existing Supabase Auth users
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.id == uid) {
          final newVendorUser = VendorUser(
            id: uid,
            email: currentUser.email ?? 'Unknown Email',
            phone: currentUser.userMetadata?['phone'],
            businessName: currentUser.userMetadata?['business_name'] ?? 'Bottles Up Vendor',
            logoUrl: currentUser.userMetadata?['avatar_url'],
            onboardingCompleted: false,
            twoFaEnabled: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            role: currentUser.userMetadata?['vendor_type'] ?? 'staff',
          );

          // Try to create the document asynchronously
          _createVendorUserDocumentAsync(newVendorUser);

          return newVendorUser;
        }
      }
      return null;
    } catch (e) {
      print('Error getting vendor user: $e');
      return null;
    }
  }

  // Update vendor user data
  Future<void> updateVendorUser(VendorUser user) async {
    try {
      await _client
          .from('vendors')
          .update(user.toMap())
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to update vendor user: $e');
    }
  }

  // Check if user has permission (based on role)
  Future<bool> hasPermission(String uid, String permission) async {
    try {
      final vendorUser = await getVendorUser(uid);
      if (vendorUser == null) return false;

      // Role-based permissions
      if (vendorUser.role == 'venue_owner') return true; // Full access
      if (vendorUser.role == 'organizer') return true; // Full access
      if (vendorUser.role == 'promoter') {
        // Promoters have limited access
        return ['read_events', 'read_bookings'].contains(permission);
      }
      if (vendorUser.role == 'staff') {
        // Staff have very limited access
        return ['read_events'].contains(permission);
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Private methods



  // Create vendor user document asynchronously without blocking
  void _createVendorUserDocumentAsync(VendorUser user) {
    Future.microtask(() async {
      try {
        await _createVendorUserDocument(user);
        print('Vendor document created successfully for: ${user.id}');
      } catch (e) {
        print('Warning: Failed to create vendor document: $e');
        // Don't throw - this is non-blocking
      }
    });
  }

  Future<void> _createVendorUserDocument(VendorUser user) async {
    try {
      await _client
          .from('vendors')
          .insert(user.toMap());
    } catch (e) {
      String errorMsg = e.toString();
      
      if (errorMsg.contains('relation "vendors" does not exist')) {
        throw Exception('Database setup required. Please run the database setup script.');
      } else if (errorMsg.contains('duplicate key')) {
        print('Vendor user already exists: ${user.id}');
        return;
      } else if (errorMsg.contains('permission denied')) {
        throw Exception('Database permissions issue. Please check RLS policies.');
      } else {
        throw Exception('Failed to create vendor user document: $e');
      }
    }
  }


  String _handleAuthException(AuthException e) {
    switch (e.message) {
      case 'Invalid login credentials':
        return 'Invalid email or password.';
      case 'User already registered':
        return 'An account already exists with this email.';
      case 'Weak password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'Invalid email':
        return 'Please enter a valid email address.';
      case 'User not found':
        return 'No vendor account found with this email.';
      case 'Too many requests':
        return 'Too many failed attempts. Please try again later.';
      case 'Invalid OTP':
        return 'Invalid or expired OTP. Please try again.';
      case 'OTP expired':
        return 'OTP has expired. Please request a new one.';
      case 'Invalid phone number':
        return 'Please enter a valid phone number.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}

// Provider for Supabase auth service
final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService();
});