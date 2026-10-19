import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/booking_detail_rules.dart';
import '../providers/booking_detail_providers.dart';

/// The Activity tab of a booking (manager and owner): what happened to it, newest first, by whom. Nothing is ever removed from it; a failed or
/// corrected payment stays, with what happened next.
class BookingActivityTab extends ConsumerWidget {
  const BookingActivityTab({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(bookingActivityProvider(bookingId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingActivityProvider(bookingId));
        try {
          await ref.read(bookingActivityProvider(bookingId).future);
        } catch (_) {
          // The tab shows the failure itself.
        }
      },
      child: ListView(
        key: const Key('activity-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          data.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = opsLoadFailureFor(error, 'the activity');
              return Column(
                children: [
                  Text(e.message, key: const Key('activity-error'), textAlign: TextAlign.center),
                  if (!e.unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(key: const Key('activity-retry'), onPressed: () => ref.invalidate(bookingActivityProvider(bookingId)), child: const Text('Try again')),
                    ),
                ],
              );
            },
            data: (entries) => entries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Nothing has been recorded on this booking yet.', key: const Key('activity-empty'), style: theme.textTheme.bodyMedium),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        ListTile(
                          key: Key('activity-$i'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(entries[i].kind == 'scan' ? Icons.qr_code_scanner : Icons.history, size: 20),
                          title: Text(activitySentence(entries[i])),
                          subtitle: Text('${entries[i].actor} · ${DateFormat('MMM d, HH:mm').format(entries[i].at)}'),
                        ),
                      const SizedBox(height: 8),
                      Text('Showing the latest ${entries.length}. Nothing is removed from this history.', style: theme.textTheme.bodySmall),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
