import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/password_recovery_service.dart';
import 'supabase_auth_provider.dart';

/// One place the screens get the reset flow from, so a test can hand them a fake. It is told to hold back the app's sign-in state while a reset is open.
final passwordRecoveryServiceProvider = Provider<PasswordRecoveryService>((ref) {
  final auth = ref.read(supabaseAuthProvider.notifier);
  return PasswordRecoveryService(auth: SupabaseRecoveryAuth(), begin: auth.beginPasswordRecovery, end: auth.endPasswordRecovery);
});
