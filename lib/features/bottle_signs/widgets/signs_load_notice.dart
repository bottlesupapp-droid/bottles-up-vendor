import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
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
    return BuCard(
      key: const Key('signs-notice'),
      accent: context.bu.amber,
      margin: const EdgeInsets.only(top: BuSpace.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Ionicons.create_outline, color: context.bu.amber, size: 20),
              const SizedBox(width: BuSpace.m),
              Expanded(child: Text(failure.message, key: const Key('signs-notice-text'))),
            ],
          ),
          if (!failure.accessEnded)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(key: const Key('signs-notice-retry'), onPressed: onRetry, child: const Text('Try again')),
            ),
        ],
      ),
    );
  }
}
