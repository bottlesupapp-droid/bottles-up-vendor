import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/analytics_models.dart';
import '../providers/scheduled_releases_provider.dart';

class ScheduledReleasesScreen extends ConsumerWidget {
  final String eventId;

  const ScheduledReleasesScreen({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final releasesAsync = ref.watch(scheduledReleasesProvider(eventId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Scheduled Ticket Releases'),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReleaseDialog(context, ref),
        icon: const Icon(Ionicons.add),
        label: const Text('Add Release'),
      ),
      body: releasesAsync.when(
        data: (releases) {
          if (releases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Ionicons.calendar_outline, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No scheduled releases',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create timed ticket releases to build anticipation',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(scheduledReleasesProvider(eventId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: releases.length,
              itemBuilder: (context, index) {
                final release = releases[index];
                return _buildReleaseCard(context, theme, release, ref);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Ionicons.alert_circle_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(scheduledReleasesProvider(eventId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseCard(BuildContext context, ThemeData theme,
      ScheduledTicketRelease release, WidgetRef ref) {
    final isUpcoming = release.releaseDate.isAfter(DateTime.now());
    final isPast = release.releaseDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUpcoming ? Ionicons.time_outline : Ionicons.checkmark_circle,
                  color: isUpcoming ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    release.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!release.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'INACTIVE',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Ionicons.calendar_outline,
                    DateFormat('MMM dd, yyyy HH:mm').format(release.releaseDate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    Ionicons.ticket_outline,
                    '${release.ticketQuantity} tickets',
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    Ionicons.cash_outline,
                    NumberFormat.currency(symbol: '\$').format(release.price),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isPast)
                  const Text(
                    'Released',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                  )
                else if (isUpcoming)
                  Text(
                    'Releases ${_getTimeUntil(release.releaseDate)}',
                    style: const TextStyle(color: Colors.orange),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Ionicons.create_outline, size: 20),
                      onPressed: () => _showEditReleaseDialog(context, ref, release),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Ionicons.trash_outline, size: 20),
                      color: Colors.red,
                      onPressed: () => _confirmDelete(context, ref, release.id),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
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
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Ticket Quantity *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
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
          const SnackBar(
            content: Text('Scheduled release added'),
            backgroundColor: Colors.green,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          const SnackBar(
            content: Text('Release deleted'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(scheduledReleasesProvider(eventId));
      }
    }
  }
}
