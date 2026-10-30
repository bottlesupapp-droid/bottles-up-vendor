import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../providers/booking_detail_providers.dart';

/// The sign the guest asked for on their bottles at checkout ("Happy Birthday"), on the booking's page so the server carries it to the table with the bottles. Nothing is shown when
/// the guest asked for none, while it loads, or where the server does not have the function yet; a read that fails says so, with Try again, because a sign the guest paid for
/// must not go missing quietly.
class BookingSignCard extends ConsumerWidget {
  const BookingSignCard({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref.watch(bookingSignProvider(bookingId)).when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) {
            final failure = opsLoadFailureFor(error, 'the bottle sign');
            if (failure.unavailable) return const SizedBox.shrink();
            return Card(
              key: const Key('sign-error-card'),
              child: ListTile(
                title: Text(failure.message, key: const Key('sign-error')),
                trailing: failure.accessEnded ? null : TextButton(key: const Key('sign-retry'), onPressed: () => ref.invalidate(bookingSignProvider(bookingId)), child: const Text('Try again')),
              ),
            );
          },
          data: (sign) {
            if (sign == null) return const SizedBox.shrink();
            return Card(
              key: const Key('sign-card'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sign for the bottles', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(sign, key: const Key('sign-text'), style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    Text('The guest asked for this to go with the bottles.', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            );
          },
        );
  }
}
