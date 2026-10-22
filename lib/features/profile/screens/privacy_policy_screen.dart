import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../workspace/providers/workspace_providers.dart' show siteUrlProvider;
import '../logic/data_collected.dart';

/// Opens an address outside the app. Replaced in tests.
final privacyLinkOpenerProvider = Provider<Future<bool> Function(Uri uri)>((ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

/// Privacy: what this app collects, in plain facts (see [dataCollected]), and the way to read BottlesUp's full privacy policy on the website. It used to be generic placeholder text with an
/// invented address and phone number; the legal wording is BottlesUp's to supply, so nothing here pretends to be it.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openPolicy(BuildContext context, WidgetRef ref) async {
    final base = ref.read(siteUrlProvider);
    final opened = await ref.read(privacyLinkOpenerProvider)(Uri.parse('$base/privacy-policy'));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The privacy policy could not be opened. Check your connection and try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('What this app collects', style: TextStyle(fontWeight: FontWeight.w600))),
      body: ListView(
        key: const Key('data-collected'),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Ionicons.shield_checkmark_outline, color: theme.colorScheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is a plain list of what the app does with your information. It is not the legal privacy policy; that is on the website.',
                    key: const Key('data-collected-intro'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(key: const Key('open-full-policy'), onPressed: () => _openPolicy(context, ref), icon: const Icon(Icons.open_in_new, size: 18), label: const Text('Read the full privacy policy')),
          const SizedBox(height: 24),
          for (final s in dataCollected)
            Padding(
              key: Key('data-${s.title}'),
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  for (final l in s.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(l, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
