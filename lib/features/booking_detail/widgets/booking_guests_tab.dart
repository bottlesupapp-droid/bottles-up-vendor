import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../../server_desk/widgets/desk_chip.dart';
import '../logic/booking_detail_rules.dart';
import '../providers/booking_detail_providers.dart';

/// The Guests tab of a booking: the holder, each invited guest (in or not, ticket e-mailed or not), the party and the table's limit, and how many
/// more guests can be invited. No contact details are ever shown (the database does not send them).
class BookingGuestsTab extends ConsumerWidget {
  const BookingGuestsTab({super.key, required this.bookingId});

  final String bookingId;

  static String _when(DateTime t) => DateFormat('MMM d, HH:mm').format(t);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(bookingGuestsProvider(bookingId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingGuestsProvider(bookingId));
        try {
          await ref.read(bookingGuestsProvider(bookingId).future);
        } catch (_) {
          // The tab shows the failure itself.
        }
      },
      child: ListView(
        key: const Key('guests-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          data.when(
            loading: () => const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            error: (error, _) {
              final e = opsLoadFailureFor(error, 'the guests');
              return Column(
                children: [
                  Text(e.message, key: const Key('guests-error'), textAlign: TextAlign.center),
                  if (!e.unavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(key: const Key('guests-retry'), onPressed: () => ref.invalidate(bookingGuestsProvider(bookingId)), child: const Text('Try again')),
                    ),
                ],
              );
            },
            data: (g) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(allowanceLine(g), key: const Key('guests-allowance'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(admissionNote, key: const Key('guests-admission-note'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Card(
                  key: const Key('guest-holder'),
                  child: ListTile(
                    title: Text(g.holderName),
                    subtitle: const Text('Booking holder'),
                    trailing: g.holderIsIn
                        ? DeskChip(key: const Key('holder-in'), text: 'In ${_when(g.holderCheckedInAt!)}', color: const Color(0xFF66BB6A))
                        : const DeskChip(key: Key('holder-not-in'), text: 'Not in yet', color: Color(0xFF9E9E9E)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(guestsInLine(g), key: const Key('guests-in-line'), style: theme.textTheme.titleSmall),
                for (final guest in g.guests)
                  Card(
                    key: Key('guest-${guest.id}'),
                    child: ListTile(
                      title: Text(guest.name),
                      subtitle: Text(guest.ticketSent ? 'Ticket e-mailed' : 'Ticket not e-mailed yet'),
                      trailing: guest.isIn
                          ? DeskChip(key: Key('guest-in-${guest.id}'), text: 'In ${_when(guest.checkedInAt!)}', color: const Color(0xFF66BB6A))
                          : DeskChip(key: Key('guest-not-in-${guest.id}'), text: 'Not in yet', color: const Color(0xFF9E9E9E)),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Guests\' contact details are not shown here.', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
