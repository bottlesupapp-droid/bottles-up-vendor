import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';
import '../../venues/providers/venues_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';

class SimpleCreateEventScreen extends ConsumerStatefulWidget {
  const SimpleCreateEventScreen({super.key});

  @override
  ConsumerState<SimpleCreateEventScreen> createState() => _SimpleCreateEventScreenState();
}

class _SimpleCreateEventScreenState extends ConsumerState<SimpleCreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketPriceController = TextEditingController(text: '0');
  final _maxCapacityController = TextEditingController(text: '100');

  String? _selectedVenueId;
  String? _selectedZoneId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 0);

  bool _isLoading = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _zones = [];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _ticketPriceController.dispose();
    _maxCapacityController.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final eventService = EventService();
      final zones = await eventService.getZones();
      if (mounted) {
        setState(() {
          _zones = zones;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _zones = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load zones: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadZones,
            ),
          ),
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
      final user = ref.read(currentVendorUserProvider);
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final eventService = EventService();

      final request = CreateEventRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        clubId: _selectedVenueId!,
        zoneId: _selectedZoneId!,
        eventDate: _selectedDate,
        startTime: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime: '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        ticketPrice: double.tryParse(_ticketPriceController.text) ?? 0.0,
        maxCapacity: int.tryParse(_maxCapacityController.text) ?? 100,
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(myVenuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : venuesAsync.when(
        data: (venues) {
          if (venues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_city, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No Venues Found'),
                  const SizedBox(height: 8),
                  const Text('Please create a venue first before creating events.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/onboarding/venue'),
                    child: const Text('Create Venue'),
                  ),
                ],
              ),
            );
          }

          if (_zones.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, size: 80, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text('No Zones Available'),
                  const SizedBox(height: 8),
                  const Text('Please contact support to set up event zones.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadZones,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Event Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Event Name *',
                      hintText: 'Enter event name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Event name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter event description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Venue Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVenueId,
                    decoration: const InputDecoration(
                      labelText: 'Venue *',
                      border: OutlineInputBorder(),
                    ),
                    items: venues.map((venue) {
                      return DropdownMenuItem(
                        value: venue.id,
                        child: Text(venue.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedVenueId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a venue';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Zone Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedZoneId,
                    decoration: const InputDecoration(
                      labelText: 'Zone *',
                      border: OutlineInputBorder(),
                    ),
                    items: _zones.map((zone) {
                      return DropdownMenuItem(
                        value: zone['id'] as String,
                        child: Text(zone['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedZoneId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a zone';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Ticket Price
                  TextFormField(
                    controller: _ticketPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Ticket Price *',
                      hintText: 'Enter ticket price',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ticket price is required';
                      }
                      final price = double.tryParse(value);
                      if (price == null || price < 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Max Capacity
                  TextFormField(
                    controller: _maxCapacityController,
                    decoration: const InputDecoration(
                      labelText: 'Max Capacity *',
                      hintText: 'Enter maximum capacity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Max capacity is required';
                      }
                      final capacity = int.tryParse(value);
                      if (capacity == null || capacity <= 0) {
                        return 'Please enter a valid capacity';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Event Date
                  ListTile(
                    title: const Text('Event Date *'),
                    subtitle: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    onTap: _selectDate,
                  ),
                  const SizedBox(height: 16),

                  // Start and End Time
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time *'),
                          subtitle: Text(_startTime.format(context)),
                          trailing: const Icon(Icons.access_time),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          onTap: _selectStartTime,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListTile(
                          title: const Text('End Time *'),
                          subtitle: Text(_endTime.format(context)),
                          trailing: const Icon(Icons.access_time),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          onTap: _selectEndTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _createEvent,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator()
                        : const Text('Create Event'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to Load Venues',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(myVenuesProvider);
                      _loadZones();
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
