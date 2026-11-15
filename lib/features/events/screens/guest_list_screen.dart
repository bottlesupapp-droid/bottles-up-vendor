import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/plain_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';

import '../../../shared/models/analytics_models.dart';
import '../providers/guest_list_provider.dart';
import '../../../core/ui/bu_kit.dart';

/// The filters over the guest list.
const guestFilters = ['All', 'Arrived', 'Waiting'];

class GuestListScreen extends ConsumerStatefulWidget {
  final String eventId;

  const GuestListScreen({
    super.key,
    required this.eventId,
  });

  @override
  ConsumerState<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends ConsumerState<GuestListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = guestFilters.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final csvString = await file.readAsString();

        // Parse CSV
        List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);

        if (csvData.isEmpty) {
          _showError('CSV file is empty');
          return;
        }

        // Assuming CSV format: Name, Email, Phone, Ticket Type, Notes
        List<GuestListEntry> guests = [];

        // Skip header row
        for (int i = 1; i < csvData.length; i++) {
          final row = csvData[i];
          if (row.length >= 2) {
            guests.add(GuestListEntry(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}_$i',
              name: row[0].toString().trim(),
              email: row.length > 1 ? row[1].toString().trim() : null,
              phone: row.length > 2 ? row[2].toString().trim() : null,
              ticketType: row.length > 3 ? row[3].toString().trim() : null,
              notes: row.length > 4 ? row[4].toString().trim() : null,
            ));
          }
        }

        if (guests.isEmpty) {
          _showError('No valid guest data found in CSV');
          return;
        }

        // Upload to database
        final success = await ref.read(guestListProvider(widget.eventId).notifier)
            .bulkUploadGuests(guests);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully uploaded ${guests.length} guests'),
              backgroundColor: BuTokens.dark.green,
            ),
          );
          ref.invalidate(guestListProvider(widget.eventId));
        }
      }
    } catch (e) {
      _showError(couldNot('upload CSV', e));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: BuTokens.dark.red,
      ),
    );
  }

  Future<void> _addManualGuest() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Guest'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                ),
                maxLines: 2,
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
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      final guest = GuestListEntry(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        name: nameController.text.trim(),
        email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
        phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );

      final success = await ref.read(guestListProvider(widget.eventId).notifier)
          .addGuest(guest);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guest added successfully'),
            backgroundColor: BuTokens.dark.green,
          ),
        );
        ref.invalidate(guestListProvider(widget.eventId));
      }
    }
  }

  void _showCSVFormatHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Format'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your CSV file should have the following columns:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('1. Name (Required)'),
              Text('2. Email (Optional)'),
              Text('3. Phone (Optional)'),
              Text('4. Ticket Type (Optional)'),
              Text('5. Notes (Optional)'),
              SizedBox(height: 16),
              Text(
                'Example:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Name,Email,Phone,Ticket Type,Notes\n'
                'John Doe,john@example.com,+1234567890,VIP,Table 5\n'
                'Jane Smith,jane@example.com,+0987654321,General,',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final guestListAsync = ref.watch(guestListProvider(widget.eventId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BuDetailAppBar(
        eyebrow: 'Event',
        title: 'Guest List',
        actions: [
          IconButton(key: const Key('guests-help'), icon: const Icon(Ionicons.help_circle_outline), onPressed: _showCSVFormatHelp, tooltip: 'CSV Format Help'),
          IconButton(key: const Key('guests-upload'), icon: const Icon(Ionicons.cloud_upload_outline), onPressed: _pickAndUploadCSV, tooltip: 'Upload CSV'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(key: const Key('guests-add'), onPressed: _addManualGuest, icon: const Icon(Ionicons.person_add_outline), label: const Text('Add Guest')),
      body: guestListAsync.when(
        data: (guests) {
          final arrived = guests.where((g) => g.checkedIn).length;
          final byFilter = switch (_filter) {
            'Arrived' => guests.where((g) => g.checkedIn).toList(),
            'Waiting' => guests.where((g) => !g.checkedIn).toList(),
            _ => guests,
          };
          final shown = _searchQuery.isEmpty
              ? byFilter
              : byFilter.where((guest) {
                  return guest.name.toLowerCase().contains(_searchQuery) || (guest.email?.toLowerCase().contains(_searchQuery) ?? false) || (guest.phone?.contains(_searchQuery) ?? false);
                }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(guestListProvider(widget.eventId)),
            child: ListView(
              key: const Key('guests-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, 88), // room for the Add button
              children: [
                Row(
                  children: [
                    Expanded(child: _Figure(label: 'Guests', value: '${guests.length}', figureKey: const Key('guests-total'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'Arrived', value: '$arrived', figureKey: const Key('guests-arrived'))),
                    const SizedBox(width: BuSpace.m),
                    Expanded(child: _Figure(label: 'Waiting', value: '${guests.length - arrived}', figureKey: const Key('guests-waiting'))),
                  ],
                ),
                const SizedBox(height: BuSpace.l),
                TextField(
                  key: const Key('guests-search'),
                  controller: _searchController,
                  decoration: const InputDecoration(hintText: 'Search guests', prefixIcon: Icon(Ionicons.search_outline, size: 18)),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
                const SizedBox(height: BuSpace.m),
                BuPillTabs(labels: guestFilters, selected: _filter, tabKeyPrefix: 'guest-filter', onSelected: (f) => setState(() => _filter = f)),
                const SizedBox(height: BuSpace.l),
                if (shown.isEmpty)
                  BuCard(
                    key: const Key('guests-none'),
                    child: Column(
                      children: [
                        BuIconTile(icon: Ionicons.people_outline, size: 52),
                        const SizedBox(height: BuSpace.m),
                        Text(guests.isEmpty ? 'No guests yet' : 'No guests found', style: text.titleMedium),
                        if (guests.isEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Add guests manually or upload a CSV file', style: text.bodySmall?.copyWith(color: bu.muted)),
                        ],
                      ],
                    ),
                  )
                else
                  for (final guest in shown) _buildGuestCard(guest),
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
                FilledButton(onPressed: () => ref.invalidate(guestListProvider(widget.eventId)), child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestCard(GuestListEntry guest) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final tint = guest.checkedIn ? bu.green : bu.amber;

    return Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.m),
      child: BuCard(
        key: Key('guest-${guest.id}'),
        padding: const EdgeInsets.all(BuSpace.m + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(BuRadius.control)),
              child: Icon(guest.checkedIn ? Ionicons.checkmark : Ionicons.person, color: tint, size: 22),
            ),
            const SizedBox(width: BuSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(guest.name, style: text.titleMedium),
                  if (guest.email != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(guest.email!, style: text.bodySmall?.copyWith(color: bu.muted))),
                  if (guest.phone != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(guest.phone!, style: text.bodySmall?.copyWith(color: bu.muted))),
                  if (guest.ticketType != null) Padding(padding: const EdgeInsets.only(top: 6), child: BuStatusPill(guest.ticketType!, tone: BuTone.brand)),
                ],
              ),
            ),
            if (guest.checkedIn)
              Column(
                key: Key('guest-arrived-${guest.id}'),
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Ionicons.checkmark_circle, color: bu.green), const SizedBox(height: 4), Text('Checked In', style: text.labelSmall?.copyWith(color: bu.muted))],
              )
            else
              IconButton(
                key: Key('guest-checkin-${guest.id}'),
                icon: const Icon(Ionicons.checkmark_circle_outline),
                onPressed: () async {
                  final success = await ref.read(guestListProvider(widget.eventId).notifier).checkInGuest(guest.id);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${guest.name} checked in'), backgroundColor: bu.green));
                    ref.invalidate(guestListProvider(widget.eventId));
                  }
                },
                tooltip: 'Check In',
              ),
          ],
        ),
      ),
    );
  }
}

/// One of the figures at the top of the list: a big number over a small label.
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
