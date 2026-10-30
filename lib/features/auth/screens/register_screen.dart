import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../workspace/logic/workspace_routing.dart' show pendingInviteToken;
import '../../workspace/widgets/business_signup_card.dart';
import '../providers/supabase_auth_provider.dart';
import '../services/social_sign_in_service.dart';
import '../widgets/social_sign_in_buttons.dart';

/// "Create account" no longer creates one here. Business accounts are made on the website (it builds the organization
/// and the first workspace in one step) and staff join by invitation, so this explains that and opens the website.
/// Google and Apple are offered here too, for a person who has made their business on the website or holds an invitation: they sign in the same way as on the sign-in page, and a Google or Apple
/// identity with no business behind it is told to create one on the website (see [SocialSignInService]); nothing is created in the app.
class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  Future<void> _socialSignIn(WidgetRef ref, SocialProvider provider) =>
      ref.read(supabaseAuthProvider.notifier).signInWithSocial(provider, allowNewAccount: pendingInviteToken.value != null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(supabaseAuthProvider);
    // A person who is already signed in (a login with no workspace yet) does not need another sign-in here.
    final offerSocial = !authState.isAuthenticated && socialProvidersFor(defaultTargetPlatform).isNotEmpty;

    ref.listen<String?>(authErrorProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next), backgroundColor: theme.colorScheme.error));
        ref.read(supabaseAuthProvider.notifier).clearError();
      }
    });
    ref.listen<bool>(isAuthenticatedProvider, (previous, next) {
      if (next) context.go('/dashboard');
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Accounts are created on our website.', key: const Key('register-title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          const BusinessSignupCard(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Joining a team?', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask the venue owner, manager or organizer to invite you. Open the invitation link from your email, '
                    'then sign in here with the email it was sent to.',
                  ),
                ],
              ),
            ),
          ),
          if (offerSocial) ...[
            const SizedBox(height: 24),
            Text('Made your business on the website, or have an invitation?', key: const Key('register-social-title'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Continue with Google or Apple, using the same email as your business account or invitation.'),
            const SizedBox(height: 16),
            SocialSignInButtons(showDivider: false, enabled: !authState.isLoading, onPressed: (provider) => _socialSignIn(ref, provider)),
          ],
          const SizedBox(height: 12),
          TextButton(
            key: const Key('back-to-sign-in'),
            onPressed: () => context.go('/login'),
            child: const Text('I already have an account: sign in'),
          ),
        ],
      ),
    );
  }
}
