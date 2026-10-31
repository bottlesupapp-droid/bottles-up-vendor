import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/sign_rules.dart';

/// Said above a list of orders when their signs could not be read, with Try again: a sign that is on an order must not go missing quietly (the bottle would go out without it). Nothing is
/// shown while they load, when they loaded, or where the server does not have bottle signs yet.
class SignsLoadNotice extends StatelessWidget {
  const SignsLoadNotice({super.key, required this.signs, required this.onRetry});

  final AsyncValue<Map<String, LineSign>> signs;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = signs.error;
    if (error == null) return const SizedBox.shrink();
    final failure = opsLoadFailureFor(error, 'the bottle signs');
    if (failure.unavailable) return const SizedBox.shrink();
    return Card(
      key: const Key('signs-notice'),
      child: ListTile(
        leading: const Icon(Icons.edit_note),
        title: Text(failure.message, key: const Key('signs-notice-text')),
        trailing: failure.accessEnded ? null : TextButton(key: const Key('signs-notice-retry'), onPressed: onRetry, child: const Text('Try again')),
      ),
    );
  }
}
