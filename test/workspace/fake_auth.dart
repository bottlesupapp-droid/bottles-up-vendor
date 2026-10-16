import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/shared/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A signed-in (or signed-out) auth state without a Supabase client, and a record of the sign-outs.
class FakeAuthNotifier extends StateNotifier<SupabaseAuthState> implements SupabaseAuthNotifier {
  FakeAuthNotifier(super.state);

  int signOuts = 0;

  @override
  Future<void> signOut() async {
    signOuts++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

User supabaseUser([String id = 'u1']) =>
    User(id: id, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-10-16T00:00:00Z');

VendorUser vendorRow({required bool onboardingCompleted}) => VendorUser(
      id: 'u1',
      email: 'a@x.test',
      onboardingCompleted: onboardingCompleted,
      createdAt: DateTime(2026, 10, 16),
      updatedAt: DateTime(2026, 10, 16),
    );

Override fakeAuth(FakeAuthNotifier notifier) => supabaseAuthProvider.overrideWith((ref) => notifier);
