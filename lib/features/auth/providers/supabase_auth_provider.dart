import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/user_model.dart';
import '../services/supabase_auth_service.dart';

// Auth state
class SupabaseAuthState {
  final bool isLoading;
  final User? supabaseUser;
  final VendorUser? vendorUser;
  final String? error;

  const SupabaseAuthState({
    this.isLoading = false,
    this.supabaseUser,
    this.vendorUser,
    this.error,
  });

  SupabaseAuthState copyWith({
    bool? isLoading,
    User? supabaseUser,
    VendorUser? vendorUser,
    String? error,
  }) {
    return SupabaseAuthState(
      isLoading: isLoading ?? this.isLoading,
      supabaseUser: supabaseUser ?? this.supabaseUser,
      vendorUser: vendorUser ?? this.vendorUser,
      error: error,
    );
  }

  bool get isAuthenticated => supabaseUser != null;
  bool get isVendorComplete => vendorUser != null;
}

// Auth provider
class SupabaseAuthNotifier extends StateNotifier<SupabaseAuthState> {
  final SupabaseAuthService _authService;

  SupabaseAuthNotifier(this._authService) : super(const SupabaseAuthState()) {
    // Listen to auth state changes
    _authService.authStateChanges.listen((AuthState authState) {
      if (authState.session?.user != null) {
        _loadVendorUser(authState.session!.user);
      } else {
        state = const SupabaseAuthState();
      }
    });
    
    // Check if user is already authenticated
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      _loadVendorUser(currentUser);
    }
  }

  // Sign in
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // User will be loaded via auth state listener
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Register
  Future<void> register({
    required String email,
    required String password,
    required String name,
    String? businessName,
    String? phoneNumber,
    String? vendorType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        businessName: businessName,
        phoneNumber: phoneNumber,
        vendorType: vendorType,
      );
      // User will be loaded via auth state listener
    } catch (e) {
      String errorMessage = e.toString();

      // Provide more user-friendly error messages
      if (errorMessage.contains('Database setup required') ||
          errorMessage.contains('Vendors table does not exist') ||
          errorMessage.contains('relation "vendors" does not exist')) {
        errorMessage = 'DATABASE_SETUP_REQUIRED';
      } else if (errorMessage.contains('duplicate key')) {
        errorMessage = 'An account with this email already exists.';
      } else if (errorMessage.contains('Database error')) {
        errorMessage = 'Registration failed due to a database error. Please try again.';
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.signOut();
      state = const SupabaseAuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Sign in with phone (send OTP)
  Future<void> signInWithPhone(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.signInWithPhone(phoneNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Verify OTP
  Future<void> verifyOTP({
    required String phoneNumber,
    required String token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authService.verifyOTP(
        phoneNumber: phoneNumber,
        token: token,
      );
      // User will be loaded via auth state listener
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Update vendor user
  Future<void> updateVendorUser(VendorUser user) async {
    try {
      await _authService.updateVendorUser(user);
      state = state.copyWith(vendorUser: user);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Load vendor user data
  Future<void> _loadVendorUser(User supabaseUser) async {
    state = state.copyWith(
      isLoading: true,
      supabaseUser: supabaseUser,
      error: null,
    );

    try {
      final vendorUser = await _authService.getVendorUser(supabaseUser.id);
      state = state.copyWith(
        isLoading: false,
        vendorUser: vendorUser,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Check permission
  Future<bool> hasPermission(String permission) async {
    if (state.supabaseUser == null) return false;
    return await _authService.hasPermission(
      state.supabaseUser!.id,
      permission,
    );
  }
}

// Auth provider
final supabaseAuthProvider = StateNotifierProvider<SupabaseAuthNotifier, SupabaseAuthState>((ref) {
  final authService = ref.watch(supabaseAuthServiceProvider);
  return SupabaseAuthNotifier(authService);
});

// Convenience providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(supabaseAuthProvider).isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseAuthProvider).supabaseUser;
});

final currentVendorUserProvider = Provider<VendorUser?>((ref) {
  return ref.watch(supabaseAuthProvider).vendorUser;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(supabaseAuthProvider).error;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(supabaseAuthProvider).isLoading;
});