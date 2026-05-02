import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/ticket_service.dart';
import '../models/ticket_type.dart';

class ManageTicketTiersScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventName;

  const ManageTicketTiersScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  ConsumerState<ManageTicketTiersScreen> createState() => _ManageTicketTiersScreenState();
}

class _ManageTicketTiersScreenState extends ConsumerState<ManageTicketTiersScreen> {
  final TicketService _ticketService = TicketService();
  List<TicketType> _ticketTiers = [];
  bool _isLoading = true;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _loadTicketTiers();
  }

  Future<void> _loadTicketTiers() async {
    setState(() => _isLoading = true);
    try {
      final tiers = await _ticketService.getTicketTypes(widget.eventId);
      final summary = await _ticketService.getTicketSalesSummary(widget.eventId);
      setState(() {
        _ticketTiers = tiers;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ticket tiers: $e')),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({TicketType? existingTier}) async {
    final nameController = TextEditingController(text: existingTier?.name ?? '');
    final descriptionController = TextEditingController(text: existingTier?.description ?? '');
    final priceController = TextEditingController(
      text: existingTier != null ? existingTier.price.toString() : '',
    );
    final capacityController = TextEditingController(
      text: existingTier != null ? existingTier.capacity.toString() : '',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingTier == null ? 'Add Ticket Tier' : 'Edit Ticket Tier'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tier Name *',
                    hintText: 'e.g., Early Bird, VIP, General Admission',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Tier name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    hintText: '25.00',
                    prefixText: '\$ ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Price is required';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Capacity *',
                    hintText: '100',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Capacity is required';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    final capacity = int.parse(value);
                    if (existingTier != null && capacity < existingTier.soldCount) {
                      return 'Capacity cannot be less than sold (${existingTier.soldCount})';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _saveTier(
                  existingTier: existingTier,
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  price: double.parse(priceController.text),
                  capacity: int.parse(capacityController.text),
                );
              }
            },
            child: Text(existingTier == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTier({
    TicketType? existingTier,
    required String name,
    String? description,
    required double price,
    required int capacity,
  }) async {
    try {
      if (existingTier == null) {
        // Create new tier
        final newTier = TicketType(
          id: const Uuid().v4(),
          eventId: widget.eventId,
          name: name,
          description: description,
          price: price,
          capacity: capacity,
          soldCount: 0,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _ticketService.createTicketType(widget.eventId, newTier);
      } else {
        // Update existing tier
        final updatedTier = existingTier.copyWith(
          name: name,
          description: description,
          price: price,
          capacity: capacity,
        );
        await _ticketService.updateTicketType(existingTier.id, updatedTier);
      }

      await _loadTicketTiers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existingTier == null ? 'Ticket tier added successfully!' : 'Ticket tier updated successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save ticket tier: $e')),
        );
      }
    }
  }

  Future<void> _deleteTier(TicketType tier) async {
    if (tier.soldCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete a tier with sold tickets')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ticket Tier'),
        content: Text('Are you sure you want to delete "${tier.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _ticketService.deleteTicketType(tier.id);
        await _loadTicketTiers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ticket tier deleted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete ticket tier: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(TicketType tier) async {
    try {
      await _ticketService.toggleActiveStatus(tier.id, !tier.isActive);
      await _loadTicketTiers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tier.isActive ? 'Ticket tier deactivated' : 'Ticket tier activated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Ticket Tiers'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTicketTiers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Info Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.darkContainerDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Ionicons.calendar_outline,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.eventName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Summary Card
                    if (_summary != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.darkCardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ticket Sales Summary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryItem(
                                    'Total Capacity',
                                    _summary!['total_capacity'].toString(),
                                    Ionicons.people_outline,
                                  ),
                                ),
                                Expanded(
                                  child: _buildSummaryItem(
                                    'Sold',
                                    _summary!['total_sold'].toString(),
                                    Ionicons.ticket_outline,
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryItem(
                                    'Available',
                                    _summary!['total_available'].toString(),
                                    Ionicons.checkmark_circle_outline,
                                    Colors.blue,
                                  ),
                                ),
                                Expanded(
                                  child: _buildSummaryItem(
                                    'Revenue',
                                    '\$${_summary!['total_revenue'].toStringAsFixed(2)}',
                                    Ionicons.cash_outline,
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ticket Tiers (${_ticketTiers.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _showAddEditDialog(),
                          icon: const Icon(Ionicons.add_outline, size: 20),
                          label: const Text('Add Tier'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Ticket Tiers List
                    if (_ticketTiers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            children: [
                              Icon(
                                Ionicons.ticket_outline,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No ticket tiers yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _showAddEditDialog(),
                                child: const Text('Add your first tier'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(_ticketTiers.length, (index) {
                        final tier = _ticketTiers[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTierCard(tier),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTierCard(TicketType tier) {
    final theme = Theme.of(context);
    final percentSold = tier.percentageSold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.darkCardDecoration.copyWith(
        border: Border.all(
          color: tier.isActive
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tier.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!tier.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Inactive',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        if (tier.isSoldOut)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Sold Out',
                              style: TextStyle(fontSize: 10, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                    if (tier.description != null && tier.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tier.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Ionicons.ellipsis_vertical),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: () => Future.delayed(
                      Duration.zero,
                      () => _showAddEditDialog(existingTier: tier),
                    ),
                    child: const Row(
                      children: [
                        Icon(Ionicons.create_outline, size: 18),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    onTap: () => Future.delayed(Duration.zero, () => _toggleActive(tier)),
                    child: Row(
                      children: [
                        Icon(
                          tier.isActive ? Ionicons.pause_outline : Ionicons.play_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(tier.isActive ? 'Deactivate' : 'Activate'),
                      ],
                    ),
                  ),
                  if (tier.soldCount == 0)
                    PopupMenuItem(
                      onTap: () => Future.delayed(Duration.zero, () => _deleteTier(tier)),
                      child: const Row(
                        children: [
                          Icon(Ionicons.trash_outline, size: 18, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '\$${tier.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sold',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${tier.soldCount} / ${tier.capacity}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      tier.availableTickets.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percentSold / 100,
            backgroundColor: theme.colorScheme.surfaceVariant,
            color: percentSold >= 90
                ? Colors.red
                : percentSold >= 70
                    ? Colors.orange
                    : Colors.green,
          ),
          const SizedBox(height: 4),
          Text(
            '${percentSold.toStringAsFixed(1)}% sold',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
