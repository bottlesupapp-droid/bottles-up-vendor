import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../workspace/widgets/business_signup_card.dart';

/// "Create account" no longer creates one here. Business accounts are made on the website (it builds the organization
/// and the first workspace in one step) and staff join by invitation, so this explains that and opens the website.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
