import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';

import '../../../shared/models/analytics_models.dart';
import '../providers/guest_list_provider.dart';

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
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(guestListProvider(widget.eventId));
        }
      }
    } catch (e) {
      _showError('Failed to upload CSV: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
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
          const SnackBar(
            content: Text('Guest added successfully'),
            backgroundColor: Colors.green,
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
    final theme = Theme.of(context);
    final guestListAsync = ref.watch(guestListProvider(widget.eventId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Guest List'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Ionicons.help_circle_outline),
            onPressed: _showCSVFormatHelp,
            tooltip: 'CSV Format Help',
          ),
          IconButton(
            icon: const Icon(Ionicons.cloud_upload_outline),
            onPressed: _pickAndUploadCSV,
            tooltip: 'Upload CSV',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualGuest,
        icon: const Icon(Ionicons.person_add_outline),
        label: const Text('Add Guest'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search guests...',
                prefixIcon: const Icon(Ionicons.search_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Guest list
          Expanded(
            child: guestListAsync.when(
              data: (guests) {
                final filteredGuests = _searchQuery.isEmpty
                    ? guests
                    : guests.where((guest) {
                        return guest.name.toLowerCase().contains(_searchQuery) ||
                            (guest.email?.toLowerCase().contains(_searchQuery) ?? false) ||
                            (guest.phone?.contains(_searchQuery) ?? false);
                      }).toList();

                if (filteredGuests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Ionicons.people_outline,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No guests yet'
                              : 'No guests found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isEmpty)
                          const Text(
                            'Add guests manually or upload a CSV file',
                            style: TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(guestListProvider(widget.eventId));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredGuests.length,
                    itemBuilder: (context, index) {
                      final guest = filteredGuests[index];
                      return _buildGuestCard(guest, theme);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Ionicons.alert_circle_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(guestListProvider(widget.eventId));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestCard(GuestListEntry guest, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: guest.checkedIn ? Colors.green : Colors.orange,
          child: Icon(
            guest.checkedIn ? Ionicons.checkmark : Ionicons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          guest.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (guest.email != null) ...[
              const SizedBox(height: 4),
              Text(guest.email!, style: const TextStyle(fontSize: 13)),
            ],
            if (guest.phone != null) ...[
              const SizedBox(height: 2),
              Text(guest.phone!, style: const TextStyle(fontSize: 13)),
            ],
            if (guest.ticketType != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  guest.ticketType!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: guest.checkedIn
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Ionicons.checkmark_circle, color: Colors.green),
                  const SizedBox(height: 4),
                  Text(
                    'Checked In',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              )
            : IconButton(
                icon: const Icon(Ionicons.checkmark_circle_outline),
                onPressed: () async {
                  final success = await ref
                      .read(guestListProvider(widget.eventId).notifier)
                      .checkInGuest(guest.id);

                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${guest.name} checked in'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    ref.invalidate(guestListProvider(widget.eventId));
                  }
                },
                tooltip: 'Check In',
              ),
      ),
    );
  }
}
