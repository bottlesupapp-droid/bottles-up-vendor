import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../models/event_filter.dart';

class EventFilterBottomSheet extends StatefulWidget {
  final EventFilter currentFilter;
  final Function(EventFilter) onApply;
  final List<String> availableCities;

  const EventFilterBottomSheet({
    super.key,
    required this.currentFilter,
    required this.onApply,
    this.availableCities = const [],
  });

  @override
  State<EventFilterBottomSheet> createState() => _EventFilterBottomSheetState();
}

class _EventFilterBottomSheetState extends State<EventFilterBottomSheet> {
  late EventFilter _tempFilter;

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Events',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Ionicons.close_outline),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Filter Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // City Filter
                    _buildSectionTitle('City', theme),
                    const SizedBox(height: 12),
                    _buildCityDropdown(theme),

                    const SizedBox(height: 24),

                    // Date Range Filter
                    _buildSectionTitle('Date Range', theme),
                    const SizedBox(height: 12),
                    _buildDateRangePicker(theme),

                    const SizedBox(height: 24),

                    // Status Filter
                    _buildSectionTitle('Status', theme),
                    const SizedBox(height: 12),
                    _buildStatusChips(theme),

                    const SizedBox(height: 24),

                    // Search Query (optional)
                    _buildSectionTitle('Search', theme),
                    const SizedBox(height: 12),
                    _buildSearchField(theme),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _applyFilters,
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildCityDropdown(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _tempFilter.city,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          hintText: 'All Cities',
          prefixIcon: const Icon(Ionicons.location_outline, size: 20),
        ),
        dropdownColor: theme.scaffoldBackgroundColor,
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('All Cities'),
          ),
          ...widget.availableCities.map(
            (city) => DropdownMenuItem<String>(
              value: city,
              child: Text(city),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _tempFilter = _tempFilter.copyWith(city: value);
          });
        },
      ),
    );
  }

  Widget _buildDateRangePicker(ThemeData theme) {
    final startDate = _tempFilter.startDate;
    final endDate = _tempFilter.endDate;

    return Column(
      children: [
        // Start Date
        InkWell(
          onTap: () => _selectStartDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Ionicons.calendar_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    startDate != null
                        ? 'From: ${_formatDate(startDate)}'
                        : 'Start Date (Optional)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: startDate != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (startDate != null)
                  IconButton(
                    icon: const Icon(Ionicons.close_circle_outline, size: 20),
                    onPressed: () {
                      setState(() {
                        _tempFilter = _tempFilter.copyWith(startDate: null);
                      });
                    },
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // End Date
        InkWell(
          onTap: () => _selectEndDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Ionicons.calendar_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    endDate != null
                        ? 'To: ${_formatDate(endDate)}'
                        : 'End Date (Optional)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: endDate != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (endDate != null)
                  IconButton(
                    icon: const Icon(Ionicons.close_circle_outline, size: 20),
                    onPressed: () {
                      setState(() {
                        _tempFilter = _tempFilter.copyWith(endDate: null);
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChips(ThemeData theme) {
    final availableStatuses = [
      'draft',
      'published',
      'upcoming',
      'completed',
      'cancelled',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableStatuses.map((status) {
        final isSelected = _tempFilter.statuses.contains(status);
        return FilterChip(
          label: Text(_capitalizeStatus(status)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              final updatedStatuses = List<String>.from(_tempFilter.statuses);
              if (selected) {
                updatedStatuses.add(status);
              } else {
                updatedStatuses.remove(status);
              }
              _tempFilter = _tempFilter.copyWith(statuses: updatedStatuses);
            });
          },
          selectedColor: theme.colorScheme.primaryContainer,
          checkmarkColor: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        );
      }).toList(),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      controller: TextEditingController(text: _tempFilter.searchQuery),
      decoration: InputDecoration(
        hintText: 'Search events...',
        prefixIcon: const Icon(Ionicons.search_outline, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _tempFilter = _tempFilter.copyWith(
            searchQuery: value.isEmpty ? null : value,
          );
        });
      },
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempFilter.startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _tempFilter = _tempFilter.copyWith(startDate: picked);
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempFilter.endDate ?? DateTime.now(),
      firstDate: _tempFilter.startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _tempFilter = _tempFilter.copyWith(endDate: picked);
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _tempFilter = EventFilter.initial();
    });
  }

  void _applyFilters() {
    widget.onApply(_tempFilter);
    Navigator.pop(context);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _capitalizeStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }
}
