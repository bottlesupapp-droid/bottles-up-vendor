import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/owner_providers.dart';
import '../services/owner_service.dart';

/// "Are you sure" before something is removed. Closing it, or Keep, changes nothing.
Future<bool> confirmRemove(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder:
        (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              key: const Key('keep'),
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Keep it'),
            ),
            FilledButton(
              key: const Key('confirm-remove'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
              ),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
  );
  return yes ?? false;
}

/// What is wrong with a form, in plain words, shown where the person is looking.
class ProblemsBox extends StatelessWidget {
  const ProblemsBox({super.key, required this.problems});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    if (problems.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('problems'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFC62828).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFC62828).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final p in problems) Text(p)],
      ),
    );
  }
}

/// A failed load of an editor's list: what is wrong, and a retry unless the server simply is not set up.
class EditorLoadError extends StatelessWidget {
  const EditorLoadError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e =
        error is OwnerLoadException
            ? error as OwnerLoadException
            : const OwnerLoadException(unavailable: false, accessEnded: false);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.message,
              key: const Key('editor-error'),
              textAlign: TextAlign.center,
            ),
            if (!e.unavailable) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('editor-retry'),
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// After a change: read the editor's list again, and the venue's setup checklist (the step may now be done, or not).
void refreshAfterChange(
  WidgetRef ref,
  String venueId,
  void Function() invalidateList,
) {
  invalidateList();
  ref.invalidate(venueSetupProvider(venueId));
}

void say(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
