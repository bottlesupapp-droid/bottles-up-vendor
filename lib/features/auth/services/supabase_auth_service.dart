import '../../../core/utils/plain_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../ops/services/ops_rpc.dart' show EdgeInvoker, OpsRpc;
import '../../../shared/models/user_model.dart';

/// Deleting the account failed. [message] is a plain sentence for the person; the reason went to the log.
class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => 'AccountDeletionException($message)';
}

class SupabaseAuthService {
  /// [invoker] calls one of the website's edge functions as the signed-in person; [clearSession] forgets the sign-in on this phone without asking the server (the account
  /// is gone by then). Both are replaced in tests.
  SupabaseAuthService({EdgeInvoker? invoker, Future<void> Function()? clearSession})
      : _invoker = invoker,
        _clearSession = clearSession;

  final EdgeInvoker? _invoker;
  final Future<void> Function()? _clearSession;

  SupabaseClient get _client => SupabaseConfig.client;
  GoTrueClient get _auth => SupabaseConfig.auth;

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
      throw Exception(couldNot('sign out', e));
    }
  }

  /// Deletes the signed-in person's account, whatever kind it is: the website's `delete-account` function removes the sign-in itself, and everything that hangs off it (the
  /// classic vendors row, the workspace memberships) goes with it. The records people made (bookings, orders, payments, scans, messages) stay with the business, no longer
  /// pointing at the account (website migrations 20261029100000 and 20261030100000). It used to call the database function delete_account(), which only deleted the classic
  /// `vendors` row and so did nothing for an account without one.
  ///
  /// Throws [AccountDeletionException] and leaves the person signed in when it did not go through; when it did, the sign-in is forgotten on this phone.
  Future<void> deleteAccount() async {
    dynamic answer;
    try {
      answer = await OpsRpc(invoker: _invoker).invoke('delete-account', const <String, dynamic>{});
    } on FunctionException catch (e) {
      logProblem('delete account', e);
      if (e.status == 401) {
        throw const AccountDeletionException('Your sign-in has expired. Sign in again, then try again.');
      }
      throw const AccountDeletionException('We could not delete your account. Check your connection and try again.');
    } catch (e) {
      logProblem('delete account', e);
      throw const AccountDeletionException('We could not delete your account. Check your connection and try again.');
    }
    if (answer is! Map || answer['success'] != true) {
      logProblem('delete account', 'unexpected answer: $answer');
      throw const AccountDeletionException('We could not confirm that your account was deleted. Check your connection and try again.');
    }
    // It is gone: forget the sign-in on this phone. The server is not asked (it no longer knows this person); a failure here changes nothing for the person.
    try {
      final clear = _clearSession;
      if (clear != null) {
        await clear();
      } else {
        await _auth.signOut(scope: SignOutScope.local);
      }
    } catch (e) {
      logProblem('forget the sign-in after deleting the account', e);
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
      throw Exception(couldNot('send OTP', e));
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
      throw Exception(couldNot('verify OTP', e));
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
      throw Exception(couldNot('update vendor user', e));
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
        return 'No BottlesUp Business account found with this email.';
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