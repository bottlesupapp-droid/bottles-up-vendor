import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../../core/utils/plain_error.dart';
import '../../../shared/services/supabase_service.dart';
import '../providers/bookings_provider.dart';

/// The filters over the list, in the design's order. "All" shows everything; the others match a booking's status.
const bookingFilters = ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled'];

/// Bookings, as the design draws it: a back button, a strip of three figures, the status filters as pill tabs and one card per booking with its status, what it is
/// for, and what is left to do (confirm or cancel a pending one, complete a confirmed one).
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String _filter = bookingFilters.first;

  String _statusOf(Map<String, dynamic> b) => (b['status'] as String? ?? 'pending').toLowerCase();

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(bookingsProvider);
    final bu = context.bu;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const BuDetailAppBar(eyebrow: 'Business', title: 'Bookings'),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BuIconTile(icon: Ionicons.calendar_outline, size: 56),
                    const SizedBox(height: BuSpace.l),
                    Text('No bookings yet', style: text.titleLarge),
                    const SizedBox(height: BuSpace.s),
                    Text('Bookings will appear here when customers reserve your events', style: text.bodyMedium?.copyWith(color: bu.muted), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final shown = _filter == 'All' ? bookings : bookings.where((b) => _statusOf(b) == _filter.toLowerCase()).toList();
          int count(String status) => bookings.where((b) => _statusOf(b) == status).length;
          final revenue = bookings.where((b) => const {'confirmed', 'completed'}.contains(_statusOf(b))).fold<num>(0, (sum, b) => sum + ((b['totalPrice'] as num?) ?? 0));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bookingsProvider),
            child: ListView(
              key: const Key('bookings-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
              children: [
                Row(
                  children: [
                    Expanded(child: _Figure(label: 'Bookings', value: '${bookings.length}', figureKey: const Key('bookings-total'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(
                      child: _Figure(label: 'To confirm', value: '${count('pending')}', tone: count('pending') > 0 ? BuTone.attention : BuTone.neutral, figureKey: const Key('bookings-pending')),
                    ),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'Sales', value: '\$${revenue.toStringAsFixed(0)}', figureKey: const Key('bookings-sales'))),
                  ],
                ),
                const SizedBox(height: BuSpace.l),
                BuPillTabs(labels: [for (final f in bookingFilters) f], selected: _filter, tabKeyPrefix: 'booking-filter', onSelected: (f) => setState(() => _filter = f)),
                const SizedBox(height: BuSpace.m),
                Padding(
                  padding: const EdgeInsets.only(bottom: BuSpace.m),
                  child: Text('${shown.length} ${shown.length == 1 ? 'booking' : 'bookings'}', key: const Key('bookings-count'), style: text.bodySmall?.copyWith(color: bu.muted)),
                ),
                if (shown.isEmpty)
                  BuCard(key: const Key('bookings-none'), child: Text('No ${_filter.toLowerCase()} bookings.', style: text.bodyMedium?.copyWith(color: bu.muted)))
                else
                  for (final b in shown) _BookingCard(booking: b, onStatusChanged: () => ref.invalidate(bookingsProvider)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Ionicons.alert_circle, size: 56, color: bu.red),
                    const SizedBox(height: BuSpace.l),
                    Text(couldNotLoad('bookings', error), textAlign: TextAlign.center),
                    const SizedBox(height: BuSpace.l),
                    FilledButton(onPressed: () => ref.invalidate(bookingsProvider), child: const Text('Retry')),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

/// One of the three figures at the top: a small label over a big number.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.figureKey, this.tone = BuTone.neutral});

  final String label;
  final String value;
  final Key figureKey;
  final BuTone tone;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final color = tone == BuTone.attention ? bu.amber : bu.ink;
    return BuCard(
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.m, vertical: BuSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, key: figureKey, style: text.headlineSmall?.copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onStatusChanged;

  const _BookingCard({required this.booking, required this.onStatusChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final eventDetails = booking['eventDetails'] as Map<String, dynamic>? ?? {};
    final totalPrice = booking['totalPrice'] as num? ?? 0;
    final numberOfTickets = booking['numberOfTickets'] as int? ?? 0;
    final status = booking['status'] as String? ?? 'pending';
    final bookedAt = booking['bookedAt'] != null ? DateTime.parse(booking['bookedAt'].toString()) : DateTime.now();
    final id = booking['id']?.toString();

    Widget line(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [Icon(icon, size: 15, color: bu.muted), const SizedBox(width: 6), Expanded(child: Text(value, style: text.bodyMedium?.copyWith(color: bu.muted)))]),
    );
    Widget fact(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: text.bodyMedium?.copyWith(color: bu.muted)), Text(value, style: text.bodyMedium?.copyWith(fontWeight: strong ? FontWeight.w700 : FontWeight.w500))],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.m),
      child: BuCard(
        key: Key('booking-${id ?? 'unknown'}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Booking #${id != null && id.length >= 8 ? id.substring(0, 8) : (id ?? 'Unknown')}', style: text.labelLarge?.copyWith(color: bu.muted))),
                BuStatusPill(status.toUpperCase(), tone: _toneOf(status)),
              ],
            ),
            if (eventDetails['title'] != null) ...[const SizedBox(height: BuSpace.s), Text('${eventDetails['title']}', style: text.titleLarge)],
            if (eventDetails['venue'] != null) line(Ionicons.location_outline, '${eventDetails['venue']}'),
            if (eventDetails['date'] != null) line(Ionicons.calendar_outline, _formatDate(eventDetails['date'])),
            const SizedBox(height: BuSpace.m),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: BuSpace.m, vertical: BuSpace.s),
              decoration: BoxDecoration(color: bu.panel2, borderRadius: BorderRadius.circular(BuRadius.control)),
              child: Column(
                children: [
                  fact('Tickets', '$numberOfTickets'),
                  Divider(height: 1, color: bu.line),
                  fact('Total Amount', '\$${totalPrice.toStringAsFixed(2)}', strong: true),
                  Divider(height: 1, color: bu.line),
                  fact('Booked On', '${bookedAt.day}/${bookedAt.month}/${bookedAt.year}'),
                ],
              ),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: BuSpace.m),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('booking-cancel'),
                      onPressed: () => _updateStatus(context, ref, id, 'cancelled'),
                      icon: const Icon(Ionicons.close, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(foregroundColor: bu.red, side: BorderSide(color: bu.red.withValues(alpha: 0.6))),
                    ),
                  ),
                  const SizedBox(width: BuSpace.m),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('booking-confirm'),
                      onPressed: () => _updateStatus(context, ref, id, 'confirmed'),
                      icon: const Icon(Ionicons.checkmark, size: 16),
                      label: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'confirmed') ...[
              const SizedBox(height: BuSpace.m),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('booking-complete'),
                  onPressed: () => _updateStatus(context, ref, id, 'completed'),
                  icon: const Icon(Ionicons.checkmark_done, size: 16),
                  label: const Text('Mark Completed'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String? bookingId, String newStatus) async {
    if (bookingId == null) return;
    final service = ref.read(supabaseServiceProvider);
    final ok = await service.updateBookingStatus(bookingId, newStatus);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Booking $newStatus' : 'Failed to update booking'), backgroundColor: ok ? context.bu.green : context.bu.red));
    }
    if (ok) onStatusChanged();
  }

  BuTone _toneOf(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return BuTone.good;
      case 'completed':
        return BuTone.brand;
      case 'pending':
        return BuTone.attention;
      case 'cancelled':
        return BuTone.bad;
      default:
        return BuTone.neutral;
    }
  }

  String _formatDate(dynamic date) {
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown Date';
    }
  }
}
