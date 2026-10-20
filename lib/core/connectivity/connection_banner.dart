import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import 'connection_monitor.dart';

/// Shown at the top of a workspace while the phone cannot reach the server. Says what it means in plain words, offers Try again, and disappears by itself when the
/// connection is back. Nothing is blocked: screens still show their own failure messages and keep what was typed.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionMonitorProvider);
    if (state.online) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFFC62828),
      child: Container(
        key: const Key('connection-banner'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Ionicons.cloud_offline_outline, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You're offline. Nothing can be saved until the connection is back.",
                key: const Key('connection-banner-text'),
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
            TextButton(
              key: const Key('connection-retry'),
              onPressed: state.checking ? null : () => ref.read(connectionMonitorProvider.notifier).check(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(state.checking ? 'Checking…' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
