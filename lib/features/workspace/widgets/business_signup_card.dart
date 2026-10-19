import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/business_signup.dart';
import '../providers/workspace_providers.dart';

/// "Starting a business?": business accounts are created on the website, so this opens it. Nothing is created here.
class BusinessSignupCard extends ConsumerWidget {
  const BusinessSignupCard({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final uri = businessSignupUri(ref.read(siteUrlProvider));
    var opened = false;
    try {
      opened = await ref.read(urlOpenerProvider)(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the website. Go to $uri in your browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Starting a business?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Create a business account on our website, as a venue owner or an event organizer. '
              'Then sign in here with the same email and password and your workspace appears.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('business-signup-button'),
              onPressed: () => _open(context, ref),
              child: const Text('Create a business account'),
            ),
          ],
        ),
      ),
    );
  }
}
