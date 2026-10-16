import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ops_rpc.dart';

/// The four states every list screen has: loading, a failure that says what happened (with Try again unless nothing can be done),
/// nothing to show (said in words), and the data.
class OpsAsyncView<T> extends StatelessWidget {
  const OpsAsyncView({
    super.key,
    required this.value,
    required this.what,
    required this.builder,
    this.emptyText,
    this.isEmpty,
    this.onRetry,
    this.errorKey = const Key('ops-error'),
    this.emptyKey = const Key('ops-empty'),
  });

  final AsyncValue<T> value;

  /// What is being loaded, in the plural, for the failure sentence: "handovers".
  final String what;
  final Widget Function(T data) builder;
  final bool Function(T data)? isEmpty;
  final String? emptyText;
  final VoidCallback? onRetry;
  final Key errorKey;
  final Key emptyKey;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
      error: (error, _) {
        final e = opsLoadFailureFor(error, what);
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              Text(e.message, key: errorKey, textAlign: TextAlign.center),
              if (!e.unavailable && onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(key: const Key('ops-retry'), onPressed: onRetry, child: const Text('Try again')),
                ),
            ],
          ),
        );
      },
      data: (data) {
        if (isEmpty != null && isEmpty!(data)) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(emptyText ?? 'Nothing here yet.', key: emptyKey, textAlign: TextAlign.center),
          );
        }
        return builder(data);
      },
    );
  }
}
