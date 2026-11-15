import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/plain_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/ticket_service.dart';
import '../models/ticket_type.dart';
import '../../../core/ui/bu_kit.dart';

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
  TicketService get _ticketService => ref.read(ticketServiceProvider);
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
          SnackBar(content: Text(couldNotLoad('ticket tiers', e))),
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
          SnackBar(content: Text(couldNot('save ticket tier', e))),
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
            style: FilledButton.styleFrom(backgroundColor: BuTokens.dark.red),
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
            SnackBar(content: Text(couldNot('delete ticket tier', e))),
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
          SnackBar(content: Text(couldNot('update status', e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final summary = _summary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BuDetailAppBar(eyebrow: widget.eventName, title: 'Ticket Tiers'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTicketTiers,
              child: ListView(
                key: const Key('tiers-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
                children: [
                  if (summary != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: BuStatTile(key: const Key('tiers-sold'), label: 'Sold', value: '${summary['total_sold']}', note: 'of ${summary['total_capacity']}')),
                        const SizedBox(width: BuSpace.m),
                        Expanded(child: BuStatTile(key: const Key('tiers-revenue'), label: 'Revenue', value: '\$${(summary['total_revenue'] as num).toStringAsFixed(2)}', note: 'Gross')),
                      ],
                    ),
                    const SizedBox(height: BuSpace.m),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: BuStatTile(key: const Key('tiers-available'), label: 'Available', value: '${summary['total_available']}', note: 'Still to sell')),
                        const SizedBox(width: BuSpace.m),
                        Expanded(child: BuStatTile(key: const Key('tiers-capacity'), label: 'Capacity', value: '${summary['total_capacity']}', note: 'All tiers')),
                      ],
                    ),
                    const SizedBox(height: BuSpace.xl),
                  ],
                  Row(
                    children: [
                      Expanded(child: Text('Ticket Tiers (${_ticketTiers.length})', key: const Key('tiers-count'), style: text.titleLarge)),
                      FilledButton.icon(key: const Key('tier-add'), onPressed: () => _showAddEditDialog(), icon: const Icon(Ionicons.add_outline, size: 20), label: const Text('Add Tier')),
                    ],
                  ),
                  const SizedBox(height: BuSpace.l),
                  if (_ticketTiers.isEmpty)
                    BuCard(
                      key: const Key('tiers-empty'),
                      child: Column(
                        children: [
                          BuIconTile(icon: Ionicons.ticket_outline, size: 52),
                          const SizedBox(height: BuSpace.m),
                          Text('No ticket tiers yet', style: text.titleMedium),
                          const SizedBox(height: 4),
                          Text('Tiers set the price and how many tickets each kind has.', style: text.bodySmall?.copyWith(color: bu.muted), textAlign: TextAlign.center),
                          const SizedBox(height: BuSpace.s),
                          TextButton(key: const Key('tier-add-first'), onPressed: () => _showAddEditDialog(), child: const Text('Add your first tier')),
                        ],
                      ),
                    )
                  else
                    for (final tier in _ticketTiers) Padding(padding: const EdgeInsets.only(bottom: BuSpace.m), child: _buildTierCard(tier)),
                ],
              ),
            ),
    );
  }

  Widget _buildTierCard(TicketType tier) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final percentSold = tier.percentageSold;
    final barColor = percentSold >= 90
        ? bu.red
        : percentSold >= 70
            ? bu.amber
            : bu.green;

    Widget fact(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(label, style: text.bodySmall?.copyWith(color: bu.muted)), const SizedBox(height: 2), Text(value, style: text.titleSmall?.copyWith(color: color))],
          ),
        );

    return BuCard(
      key: Key('tier-${tier.id}'),
      highlight: tier.isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(tier.name, style: text.titleMedium),
                        if (!tier.isActive) const BuStatusPill('Inactive'),
                        if (tier.isSoldOut) const BuStatusPill('Sold Out', tone: BuTone.bad),
                      ],
                    ),
                    if (tier.description != null && tier.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(tier.description!, style: text.bodySmall?.copyWith(color: bu.muted)),
                    ],
                  ],
                ),
              ),
              PopupMenuButton(
                key: Key('tier-menu-${tier.id}'),
                icon: const Icon(Ionicons.ellipsis_vertical),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    key: const Key('tier-edit'),
                    onTap: () => Future.delayed(Duration.zero, () => _showAddEditDialog(existingTier: tier)),
                    child: const Row(children: [Icon(Ionicons.create_outline, size: 18), SizedBox(width: 12), Text('Edit')]),
                  ),
                  PopupMenuItem(
                    key: const Key('tier-toggle'),
                    onTap: () => Future.delayed(Duration.zero, () => _toggleActive(tier)),
                    child: Row(children: [Icon(tier.isActive ? Ionicons.pause_outline : Ionicons.play_outline, size: 18), const SizedBox(width: 12), Text(tier.isActive ? 'Deactivate' : 'Activate')]),
                  ),
                  if (tier.soldCount == 0)
                    PopupMenuItem(
                      key: const Key('tier-delete'),
                      onTap: () => Future.delayed(Duration.zero, () => _deleteTier(tier)),
                      child: Row(children: [Icon(Ionicons.trash_outline, size: 18, color: bu.red), const SizedBox(width: 12), Text('Delete', style: TextStyle(color: bu.red))]),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: BuSpace.m),
          Row(
            children: [
              fact('Price', '\$${tier.price.toStringAsFixed(2)}', color: bu.orangeSoft),
              fact('Sold', '${tier.soldCount} / ${tier.capacity}'),
              fact('Available', tier.availableTickets.toString()),
            ],
          ),
          const SizedBox(height: BuSpace.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(BuRadius.pill),
            child: LinearProgressIndicator(value: percentSold / 100, minHeight: 6, backgroundColor: bu.line, color: barColor),
          ),
          const SizedBox(height: 6),
          Text('${percentSold.toStringAsFixed(1)}% sold', style: text.bodySmall?.copyWith(color: bu.muted)),
        ],
      ),
    );
  }
}
