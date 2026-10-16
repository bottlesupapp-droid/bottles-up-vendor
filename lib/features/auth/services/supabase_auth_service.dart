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
      // shouldCreateUser: false. This app signs people IN; accounts are created on the website, so an unknown number must
      // not quietly become a new account.
      await _auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: false,
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

      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  // The signed-in person's row in the classic `vendors` table, or null when there is none. THROWS when the lookup itself
  // fails, so "no row" is never confused with "could not ask". This app never creates the row (accounts are created on the
  // website); it used to create one for every account that signed in, which turned website and customer accounts into
  // classic vendors.
  Future<VendorUser?> findVendorUser(String uid) async {
    final response =
        await _client.from('vendors').select().eq('id', uid).maybeSingle();
    return response == null ? null : VendorUser.fromMap(response);
  }

  // Same lookup for callers that only want an answer: a failed lookup reads as "no row".
  Future<VendorUser?> getVendorUser(String uid) async {
    try {
      return await findVendorUser(uid);
    } catch (e) {
      print('Error getting vendor user: $e');
      return null;
    }
  }

  // Update vendor user data — upsert so onboarding works even when the
  // vendors row doesn't exist yet (avoids PostgREST 404 on .update()).
  Future<void> updateVendorUser(VendorUser user) async {
    try {
      await _client
          .from('vendors')
          .upsert(user.toMap());
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
      case 'Signups not allowed for otp':
        return 'No account was found for this number. Accounts are created on our website; sign in with your email instead.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}

// Provider for Supabase auth service
final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService();
});