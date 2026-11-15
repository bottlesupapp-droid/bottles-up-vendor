import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/plain_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/analytics_models.dart';
import '../providers/scheduled_releases_provider.dart';
import '../../../core/ui/bu_kit.dart';

class ScheduledReleasesScreen extends ConsumerWidget {
  final String eventId;

  const ScheduledReleasesScreen({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(scheduledReleasesProvider(eventId));
    final bu = context.bu;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const BuDetailAppBar(eyebrow: 'Event', title: 'Scheduled Releases'),
      floatingActionButton: FloatingActionButton.extended(key: const Key('releases-add'), onPressed: () => _showAddReleaseDialog(context, ref), icon: const Icon(Ionicons.add), label: const Text('Add Release')),
      body: releasesAsync.when(
        data: (releases) {
          if (releases.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
                child: Column(
                  key: const Key('releases-empty'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BuIconTile(icon: Ionicons.calendar_outline, size: 56),
                    const SizedBox(height: BuSpace.l),
                    Text('No scheduled releases', style: text.titleLarge),
                    const SizedBox(height: BuSpace.s),
                    Text('Create timed ticket releases to build anticipation', style: text.bodyMedium?.copyWith(color: bu.muted), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          final now = DateTime.now();
          final upcoming = releases.where((r) => r.releaseDate.isAfter(now)).length;
          final tickets = releases.fold<int>(0, (sum, r) => sum + r.ticketQuantity);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(scheduledReleasesProvider(eventId)),
            child: ListView(
              key: const Key('releases-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, 88), // room for the Add button
              children: [
                Row(
                  children: [
                    Expanded(child: _Figure(label: 'Releases', value: '${releases.length}', figureKey: const Key('releases-total'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'Upcoming', value: '$upcoming', figureKey: const Key('releases-upcoming'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'Tickets', value: '$tickets', figureKey: const Key('releases-tickets'))),
                  ],
                ),
                const SizedBox(height: BuSpace.l),
                for (final release in releases) _buildReleaseCard(context, release, ref),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Ionicons.alert_circle_outline, size: 56, color: bu.red),
                const SizedBox(height: BuSpace.l),
                Text(couldNotLoad('this page', error), textAlign: TextAlign.center),
                const SizedBox(height: BuSpace.l),
                FilledButton(onPressed: () => ref.invalidate(scheduledReleasesProvider(eventId)), child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseCard(BuildContext context, ScheduledTicketRelease release, WidgetRef ref) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final isUpcoming = release.releaseDate.isAfter(DateTime.now());
    final tint = isUpcoming ? bu.amber : bu.green;

    Widget fact(IconData icon, String value) => Expanded(
          child: Row(children: [Icon(icon, size: 15, color: bu.muted), const SizedBox(width: 6), Expanded(child: Text(value, style: text.bodySmall?.copyWith(color: bu.soft)))]),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.m),
      child: BuCard(
        key: Key('release-${release.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: tint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(BuRadius.control)),
                  child: Icon(isUpcoming ? Ionicons.time_outline : Ionicons.checkmark_circle, color: tint, size: 21),
                ),
                const SizedBox(width: BuSpace.m),
                Expanded(child: Text(release.name, style: text.titleMedium)),
                if (!release.isActive) const BuStatusPill('Inactive'),
              ],
            ),
            const SizedBox(height: BuSpace.m),
            Row(children: [fact(Ionicons.calendar_outline, DateFormat('MMM dd, yyyy HH:mm').format(release.releaseDate))]),
            const SizedBox(height: BuSpace.s),
            Row(children: [fact(Ionicons.ticket_outline, '${release.ticketQuantity} tickets'), fact(Ionicons.cash_outline, NumberFormat.currency(symbol: '\$').format(release.price))]),
            const SizedBox(height: BuSpace.s),
            Row(
              children: [
                Expanded(
                  child: isUpcoming
                      ? Text('Releases ${_getTimeUntil(release.releaseDate)}', key: Key('release-status-${release.id}'), style: text.labelLarge?.copyWith(color: bu.amber))
                      : Text('Released', key: Key('release-status-${release.id}'), style: text.labelLarge?.copyWith(color: bu.green, fontWeight: FontWeight.w600)),
                ),
                IconButton(key: Key('release-edit-${release.id}'), icon: const Icon(Ionicons.create_outline, size: 20), onPressed: () => _showEditReleaseDialog(context, ref, release), tooltip: 'Edit'),
                IconButton(key: Key('release-delete-${release.id}'), icon: const Icon(Ionicons.trash_outline, size: 20), color: bu.red, onPressed: () => _confirmDelete(context, ref, release.id), tooltip: 'Delete'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeUntil(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.inDays > 0) {
      return 'in ${diff.inDays} day${diff.inDays > 1 ? 's' : ''}';
    } else if (diff.inHours > 0) {
      return 'in ${diff.inHours} hour${diff.inHours > 1 ? 's' : ''}';
    } else {
      return 'in ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    }
  }

  Future<void> _showAddReleaseDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Scheduled Release'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Release Name *',
                    hintText: 'e.g., Early Bird, General Sale',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Ticket Quantity *',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Release Date & Time'),
                  subtitle: Text(DateFormat('MMM dd, yyyy HH:mm').format(selectedDate)),
                  trailing: const Icon(Ionicons.calendar_outline),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    quantityController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final release = ScheduledTicketRelease(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        eventId: eventId,
        name: nameController.text.trim(),
        releaseDate: selectedDate,
        ticketQuantity: int.parse(quantityController.text),
        price: double.parse(priceController.text),
        createdAt: DateTime.now(),
      );

      final success = await ref
          .read(scheduledReleasesProvider(eventId).notifier)
          .addRelease(release);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scheduled release added'),
            backgroundColor: BuTokens.dark.green,
          ),
        );
        ref.invalidate(scheduledReleasesProvider(eventId));
      }
    }
  }

  Future<void> _showEditReleaseDialog(
      BuildContext context, WidgetRef ref, ScheduledTicketRelease release) async {
    // Similar to add dialog but pre-filled
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit feature - To be implemented')),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String releaseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Release'),
        content: const Text('Are you sure you want to delete this scheduled release?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BuTokens.dark.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(scheduledReleasesProvider(eventId).notifier)
          .deleteRelease(releaseId);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Release deleted'),
            backgroundColor: BuTokens.dark.green,
          ),
        );
        ref.invalidate(scheduledReleasesProvider(eventId));
      }
    }
  }
}

/// One of the figures at the top of a list page: a big number over a small label.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.figureKey});

  final String label;
  final String value;
  final Key figureKey;

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    return BuCard(
      padding: const EdgeInsets.symmetric(horizontal: BuSpace.m, vertical: BuSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, key: figureKey, style: text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall?.copyWith(color: bu.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
