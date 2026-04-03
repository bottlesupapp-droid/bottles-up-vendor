import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../../core/utils/responsive_utils.dart' as utils;

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketPriceController = TextEditingController();
  final _maxCapacityController = TextEditingController();
  final _termsController = TextEditingController();
  final _specialInstructionsController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedClubId;
  String? _selectedZoneId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 0);

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _ticketPriceController.dispose();
    _maxCapacityController.dispose();
    _termsController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final eventService = EventService();
      
      final futures = await Future.wait([
        eventService.getCategories(),
        eventService.getClubs(),
        eventService.getZones(),
      ]);

      setState(() {
        _categories = futures[0];
        _clubs = futures[1];
        _zones = futures[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
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

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final eventService = EventService();
      
      final request = CreateEventRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        categoryId: _selectedCategoryId,
        clubId: _selectedClubId,
        zoneId: _selectedZoneId!,
        eventDate: _selectedDate,
        startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        ticketPrice: double.parse(_ticketPriceController.text),
        maxCapacity: int.parse(_maxCapacityController.text),
        termsAndConditions: _termsController.text.trim().isEmpty 
            ? null 
            : _termsController.text.trim(),
        specialInstructions: _specialInstructionsController.text.trim().isEmpty 
            ? null 
            : _specialInstructionsController.text.trim(),
      );

      await eventService.createEvent(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: ResponsiveText.titleLarge('Create Event'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
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
                                  Ionicons.add_circle_outline,
                                  color: theme.colorScheme.primary,
                                  size: utils.ResponsiveUtils.getResponsiveIconSize(context),
                                ),
                                SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.75),
                                Expanded(
                                  child: ResponsiveText.headlineSmall(
                                    'Create New Event',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.75),
                            ResponsiveText.bodyLarge(
                              'Fill in the details below to create a new event',
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
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a zone';
                                }
                                return null;
                              },
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

                      // Additional Information Section
                      _buildSectionHeader(context, 'Additional Information', Ionicons.document_text_outline),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                      ResponsiveContainer(
                        decoration: AppTheme.darkCardDecoration,
                        child: Column(
                          children: [
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
                          onPressed: _isSubmitting ? null : _createEvent,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create Event'),
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
      initialValue: value,
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