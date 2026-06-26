import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../../core/utils/responsive_utils.dart' as utils;
import '../providers/event_details_provider.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EditEventScreen({super.key, required this.eventId});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketPriceController = TextEditingController();
  final _maxCapacityController = TextEditingController();
  final _termsController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  final _dressCodeController = TextEditingController();
  final _minAgeController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedClubId;
  String? _selectedZoneId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 0);

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  File? _newFlyerImage;
  String? _existingFlyerUrl;
  final ImagePicker _imagePicker = ImagePicker();

  Event? _originalEvent;

  @override
  void initState() {
    super.initState();
    _loadEventAndData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _ticketPriceController.dispose();
    _maxCapacityController.dispose();
    _termsController.dispose();
    _specialInstructionsController.dispose();
    _dressCodeController.dispose();
    _minAgeController.dispose();
    super.dispose();
  }

  Future<void> _loadEventAndData() async {
    setState(() => _isLoading = true);
    try {
      final eventService = EventService();

      // Load event data and dropdown options in parallel
      final futures = await Future.wait([
        eventService.getEventById(widget.eventId),
        eventService.getCategories(),
        eventService.getClubs(),
        eventService.getZones(),
      ]);

      final event = futures[0] as Event;
      _originalEvent = event;

      // Pre-fill form with event data
      _nameController.text = event.name;
      _descriptionController.text = event.description ?? '';
      _ticketPriceController.text = event.ticketPrice.toString();
      _maxCapacityController.text = event.maxCapacity.toString();
      _termsController.text = event.termsAndConditions ?? '';
      _specialInstructionsController.text = event.specialInstructions ?? '';
      _dressCodeController.text = event.dressCode ?? '';
      _minAgeController.text = event.minAge?.toString() ?? '';

      _selectedCategoryId = event.categoryId;
      _selectedClubId = event.clubId;
      _selectedZoneId = event.zoneId.isEmpty ? null : event.zoneId;
      _selectedDate = event.eventDate;

      // Parse start and end times
      final startTimeParts = event.startTime.split(':');
      _startTime = TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      );

      final endTimeParts = event.endTime.split(':');
      _endTime = TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      );

      _existingFlyerUrl = event.images?.isNotEmpty == true ? event.images!.first : null;

      setState(() {
        _categories = futures[1] as List<Map<String, dynamic>>;
        _clubs = futures[2] as List<Map<String, dynamic>>;
        _zones = futures[3] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load event: $e')),
        );
        context.pop();
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Auto-adjust end time if it's before start time
        if (_endTime.hour < picked.hour ||
            (_endTime.hour == picked.hour && _endTime.minute <= picked.minute)) {
          _endTime = TimeOfDay(hour: picked.hour + 3, minute: picked.minute);
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _pickFlyerImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _newFlyerImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final eventService = EventService();

      // Upload new flyer image if selected
      List<String>? flyerUrls;
      if (_newFlyerImage != null) {
        final bytes = await _newFlyerImage!.readAsBytes();
        final fileName = 'flyer_${DateTime.now().millisecondsSinceEpoch}.jpg';
        flyerUrls = await eventService.uploadEventImages(
          widget.eventId,
          [bytes],
          [fileName],
        );
      } else if (_existingFlyerUrl != null) {
        flyerUrls = [_existingFlyerUrl!];
      }

      final request = UpdateEventRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        clubId: _selectedClubId,
        zoneId: _selectedZoneId, // nullable — only sent if vendor selected one
        images: flyerUrls,
        eventDate: _selectedDate,
        startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        ticketPrice: double.parse(_ticketPriceController.text),
        maxCapacity: int.parse(_maxCapacityController.text),
        dressCode: _dressCodeController.text.trim().isEmpty
            ? null
            : _dressCodeController.text.trim(),
        minAge: _minAgeController.text.trim().isEmpty
            ? null
            : int.parse(_minAgeController.text.trim()),
        termsAndConditions: _termsController.text.trim().isEmpty
            ? null
            : _termsController.text.trim(),
        specialInstructions: _specialInstructionsController.text.trim().isEmpty
            ? null
            : _specialInstructionsController.text.trim(),
      );

      await eventService.updateEvent(widget.eventId, request);

      // Invalidate the event details provider to refresh data
      ref.invalidate(eventDetailsProvider(widget.eventId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update event: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: ResponsiveText.titleLarge('Edit Event'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: ResponsiveText.titleLarge('Edit Event'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ResponsiveWrapper(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(utils.ResponsiveUtils.getResponsivePadding(context)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                ResponsiveContainer(
                  decoration: AppTheme.darkContainerDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Ionicons.create_outline,
                            color: theme.colorScheme.primary,
                            size: utils.ResponsiveUtils.getResponsiveIconSize(context),
                          ),
                          SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.75),
                          Expanded(
                            child: ResponsiveText.headlineSmall(
                              'Edit Event Details',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.75),
                      ResponsiveText.bodyLarge(
                        'Update your event information below',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                // Basic Information Section
                _buildSectionHeader(context, 'Event Information', Ionicons.information_circle_outline),
                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                ResponsiveContainer(
                  decoration: AppTheme.darkCardDecoration,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Event Name *',
                        hint: 'Enter event name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Event name is required';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Enter event description',
                        maxLines: 3,
                      ),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildDropdownField(
                        label: 'Category',
                        value: _selectedCategoryId,
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category['id'],
                            child: Text(category['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                // Venue Section
                _buildSectionHeader(context, 'Venue & Zone', Ionicons.location_outline),
                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                ResponsiveContainer(
                  decoration: AppTheme.darkCardDecoration,
                  child: Column(
                    children: [
                      _buildDropdownField(
                        label: 'Club (Optional)',
                        value: _selectedClubId,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Select a club (optional)'),
                          ),
                          ..._clubs.map((club) {
                            return DropdownMenuItem<String>(
                              value: club['id'],
                              child: Text(club['name']),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedClubId = value;
                          });
                        },
                      ),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildDropdownField(
                        label: 'Zone *',
                        value: _selectedZoneId,
                        items: _zones.map((zone) {
                          return DropdownMenuItem<String>(
                            value: zone['id'],
                            child: Text('${zone['name']} (${zone['capacity']} capacity)'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedZoneId = value;
                          });
                        },
                        validator: (_) => null, // zone optional — many events created without one
                      ),
                    ],
                  ),
                ),

                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                // Date & Time Section
                _buildSectionHeader(context, 'Date & Time', Ionicons.calendar_outline),
                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                ResponsiveContainer(
                  decoration: AppTheme.darkCardDecoration,
                  child: Column(
                    children: [
                      _buildDateField(
                        label: 'Event Date *',
                        value: _selectedDate,
                        onTap: _selectDate,
                      ),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeField(
                              label: 'Start Time *',
                              value: _startTime,
                              onTap: _selectStartTime,
                            ),
                          ),
                          SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                          Expanded(
                            child: _buildTimeField(
                              label: 'End Time *',
                              value: _endTime,
                              onTap: _selectEndTime,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                // Pricing & Capacity Section
                _buildSectionHeader(context, 'Pricing & Capacity', Ionicons.cash_outline),
                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                ResponsiveContainer(
                  decoration: AppTheme.darkCardDecoration,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _ticketPriceController,
                          label: 'Ticket Price *',
                          hint: '25.00',
                          keyboardType: TextInputType.number,
                          prefix: '\$',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ticket price is required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      Expanded(
                        child: _buildTextField(
                          controller: _maxCapacityController,
                          label: 'Max Capacity *',
                          hint: '100',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Max capacity is required';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                // Flyer Upload Section
                _buildSectionHeader(context, 'Event Flyer', Ionicons.image_outline),
                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                ResponsiveContainer(
                  decoration: AppTheme.darkCardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_newFlyerImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _newFlyerImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      ] else if (_existingFlyerUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _existingFlyerUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Ionicons.image_outline, size: 48),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      ],
                      OutlinedButton.icon(
                        onPressed: _pickFlyerImage,
                        icon: Icon(_newFlyerImage == null && _existingFlyerUrl == null
                            ? Ionicons.cloud_upload_outline
                            : Ionicons.refresh_outline),
                        label: Text(_newFlyerImage == null && _existingFlyerUrl == null
                            ? 'Upload Flyer'
                            : 'Change Flyer'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      if (_newFlyerImage != null || _existingFlyerUrl != null) ...[
                        SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _newFlyerImage = null;
                              _existingFlyerUrl = null;
                            });
                          },
                          icon: const Icon(Ionicons.trash_outline, color: Colors.red),
                          label: const Text('Remove Flyer', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                // Additional Information Section
                _buildSectionHeader(context, 'Additional Information', Ionicons.document_text_outline),
                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                ResponsiveContainer(
                  decoration: AppTheme.darkCardDecoration,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _dressCodeController,
                        label: 'Dress Code',
                        hint: 'e.g., Smart Casual, Formal, etc.',
                      ),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildTextField(
                        controller: _minAgeController,
                        label: 'Minimum Age',
                        hint: '18',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final age = int.tryParse(value);
                            if (age == null || age < 0 || age > 100) {
                              return 'Please enter a valid age between 0-100';
                            }
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildTextField(
                        controller: _termsController,
                        label: 'Terms & Conditions',
                        hint: 'Enter terms and conditions',
                        maxLines: 3,
                      ),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildTextField(
                        controller: _specialInstructionsController,
                        label: 'Special Instructions',
                        hint: 'Enter special instructions for attendees',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 3),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _updateEvent,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update Event'),
                  ),
                ),

                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
        ResponsiveText.titleMedium(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          '${value.day}/${value.month}/${value.year}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          value.format(context),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
