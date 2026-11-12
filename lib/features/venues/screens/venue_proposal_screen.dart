import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/plain_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import '../../../shared/models/venue_model.dart';
import '../../../shared/models/venue_request_model.dart';
import '../../../shared/models/user_model.dart';
import '../providers/venues_provider.dart';

class VenueProposalScreen extends ConsumerStatefulWidget {
  final Venue venue;
  final VendorUser organizer;

  const VenueProposalScreen({
    super.key,
    required this.venue,
    required this.organizer,
  });

  @override
  ConsumerState<VenueProposalScreen> createState() => _VenueProposalScreenState();
}

class _VenueProposalScreenState extends ConsumerState<VenueProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventTitleController = TextEditingController();
  final _eventDescriptionController = TextEditingController();
  final _expectedAttendanceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _flyerUrl;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _eventTitleController.dispose();
    _eventDescriptionController.dispose();
    _expectedAttendanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Event Proposal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Venue Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proposing to:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: BuTokens.dark.muted,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.venue.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (widget.venue.city != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Ionicons.location, size: 14, color: BuTokens.dark.muted),
                          const SizedBox(width: 4),
                          Text(
                            widget.venue.city!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: BuTokens.dark.muted,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Event Title
            TextFormField(
              controller: _eventTitleController,
              decoration: const InputDecoration(
                labelText: 'Event Title *',
                hintText: 'e.g., Summer Beach Party',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an event title';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Event Description
            TextFormField(
              controller: _eventDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Event Description *',
                hintText: 'Describe your event...',
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an event description';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Event Date
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Event Date *',
                  suffixIcon: Icon(Ionicons.calendar_outline),
                ),
                child: Text(
                  _selectedDate != null
                      ? DateFormat('EEEE, MMMM d, y').format(_selectedDate!)
                      : 'Select event date',
                  style: TextStyle(
                    color: _selectedDate != null ? null : BuTokens.dark.muted,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Time Range
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(isStartTime: true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        suffixIcon: Icon(Ionicons.time_outline),
                      ),
                      child: Text(
                        _startTime != null
                            ? _startTime!.format(context)
                            : 'Select time',
                        style: TextStyle(
                          color: _startTime != null ? null : BuTokens.dark.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(isStartTime: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        suffixIcon: Icon(Ionicons.time_outline),
                      ),
                      child: Text(
                        _endTime != null
                            ? _endTime!.format(context)
                            : 'Select time',
                        style: TextStyle(
                          color: _endTime != null ? null : BuTokens.dark.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Expected Attendance
            TextFormField(
              controller: _expectedAttendanceController,
              decoration: InputDecoration(
                labelText: 'Expected Attendance *',
                hintText: 'Number of guests',
                suffixIcon: const Icon(Ionicons.people_outline),
                helperText: widget.venue.capacity != null
                    ? 'Venue capacity: ${widget.venue.capacity}'
                    : null,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter expected attendance';
                }
                final attendance = int.tryParse(value);
                if (attendance == null || attendance <= 0) {
                  return 'Please enter a valid number';
                }
                if (widget.venue.capacity != null && attendance > widget.venue.capacity!) {
                  return 'Exceeds venue capacity of ${widget.venue.capacity}';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Flyer Upload
            Card(
              child: InkWell(
                onTap: _pickFlyer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_flyerUrl != null)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(_flyerUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: BuTokens.dark.muted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Ionicons.image, size: 48, color: BuTokens.dark.muted),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload Event Flyer',
                                  style: TextStyle(color: BuTokens.dark.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_flyerUrl != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Ionicons.checkmark_circle, color: BuTokens.dark.green, size: 20),
                            const SizedBox(width: 8),
                            const Text('Flyer uploaded'),
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: () {
                                setState(() => _flyerUrl = null);
                              },
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Additional Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes (Optional)',
                hintText: 'Any special requests or information...',
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProposal,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Proposal'),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = now;
    final lastDate = DateTime(now.year + 2);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime({required bool isStartTime}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickFlyer() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // TODO: Upload to Supabase Storage and get URL
      // For now, we'll use a placeholder
      setState(() {
        _flyerUrl = 'https://placehold.co/600x400/png?text=Event+Flyer';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Flyer uploaded successfully'),
            backgroundColor: BuTokens.dark.green,
          ),
        );
      }
    }
  }

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an event date'),
          backgroundColor: BuTokens.dark.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final requestData = CreateVenueRequestData(
        venueId: widget.venue.id,
        eventTitle: _eventTitleController.text.trim(),
        eventDescription: _eventDescriptionController.text.trim(),
        eventDate: _selectedDate!,
        startTime: _startTime?.format(context),
        endTime: _endTime?.format(context),
        flyerUrl: _flyerUrl,
        expectedAttendance: int.parse(_expectedAttendanceController.text.trim()),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final service = ref.read(venueRequestServiceProvider);
      await service.createVenueRequest(
        organizer: widget.organizer,
        requestData: requestData,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proposal sent successfully!'),
            backgroundColor: BuTokens.dark.green,
          ),
        );

        // Navigate back
        Navigator.pop(context);
        Navigator.pop(context); // Also pop the venue detail screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(couldNot('send proposal', e)),
            backgroundColor: BuTokens.dark.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
