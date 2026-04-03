import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/venue_request_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../providers/venues_provider.dart';

class VenueOwnerRequestsScreen extends ConsumerStatefulWidget {
  const VenueOwnerRequestsScreen({super.key});

  @override
  ConsumerState<VenueOwnerRequestsScreen> createState() => _VenueOwnerRequestsScreenState();
}

class _VenueOwnerRequestsScreenState extends ConsumerState<VenueOwnerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VenueRequestStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      switch (_tabController.index) {
        case 0:
          _selectedStatus = null; // All
          break;
        case 1:
          _selectedStatus = VenueRequestStatus.pending;
          break;
        case 2:
          _selectedStatus = VenueRequestStatus.approved;
          break;
        case 3:
          _selectedStatus = VenueRequestStatus.declined;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentVendorUserProvider);

    if (userAsync == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in to view requests'),
        ),
      );
    }

    final requestsAsync = ref.watch(venueOwnerRequestsProvider((
      venueOwnerId: userAsync.id,
      status: _selectedStatus,
    )));

    final statsAsync = ref.watch(venueOwnerRequestStatsProvider(userAsync.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Venue Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: statsAsync.when(
                data: (stats) => _buildTabLabel('All', stats['total'] ?? 0),
                loading: () => const Text('All'),
                error: (_, __) => const Text('All'),
              ),
            ),
            Tab(
              child: statsAsync.when(
                data: (stats) => _buildTabLabel('Pending', stats['pending'] ?? 0),
                loading: () => const Text('Pending'),
                error: (_, __) => const Text('Pending'),
              ),
            ),
            Tab(
              child: statsAsync.when(
                data: (stats) => _buildTabLabel('Approved', stats['approved'] ?? 0),
                loading: () => const Text('Approved'),
                error: (_, __) => const Text('Approved'),
              ),
            ),
            Tab(
              child: statsAsync.when(
                data: (stats) => _buildTabLabel('Declined', stats['declined'] ?? 0),
                loading: () => const Text('Declined'),
                error: (_, __) => const Text('Declined'),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(venueOwnerRequestsProvider((
            venueOwnerId: userAsync.id,
            status: _selectedStatus,
          )));
          ref.invalidate(venueOwnerRequestStatsProvider(userAsync.id));
        },
        child: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return _buildEmptyState();
            }
            return _buildRequestsList(requests, userAsync);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState(error.toString()),
        ),
      ),
    );
  }

  Widget _buildTabLabel(String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRequestsList(List<VenueRequest> requests, VendorUser user) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _RequestCard(
          request: request,
          venueOwner: user,
          onActionComplete: () {
            // Refresh the lists
            ref.invalidate(venueOwnerRequestsProvider((
              venueOwnerId: user.id,
              status: _selectedStatus,
            )));
            ref.invalidate(venueOwnerRequestStatsProvider(user.id));
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_selectedStatus) {
      case VenueRequestStatus.pending:
        message = 'No pending requests';
        icon = Icons.inbox;
        break;
      case VenueRequestStatus.approved:
        message = 'No approved requests';
        icon = Icons.check_circle_outline;
        break;
      case VenueRequestStatus.declined:
        message = 'No declined requests';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'No requests yet';
        icon = Icons.inbox;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Event organizers can browse your venue\nand send proposals',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 24),
          Text(
            'Failed to Load Requests',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final VenueRequest request;
  final VendorUser venueOwner;
  final VoidCallback onActionComplete;

  const _RequestCard({
    required this.request,
    required this.venueOwner,
    required this.onActionComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status badge
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.eventTitle ?? 'Untitled Event',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      if (request.eventDate != null)
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('EEEE, MMM d, y').format(request.eventDate!),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(context),
              ],
            ),
          ),

          const Divider(height: 1),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.eventDescription != null) ...[
                  Text(
                    request.eventDescription!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                ],

                // Event Details Row
                Row(
                  children: [
                    if (request.expectedAttendance != null) ...[
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${request.expectedAttendance} guests',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (request.eventProposal['start_time'] != null) ...[
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${request.eventProposal['start_time']}${request.eventProposal['end_time'] != null ? ' - ${request.eventProposal['end_time']}' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Flyer if available
                if (request.flyerUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      request.flyerUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Notes or decline reason
                if (request.notes != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.notes!,
                            style: TextStyle(color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (request.declineReason != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Decline Reason:',
                                style: TextStyle(
                                  color: Colors.red[900],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                request.declineReason!,
                                style: TextStyle(color: Colors.red[900]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons for pending requests
                if (request.isPending) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _declineRequest(context, ref),
                          icon: const Icon(Icons.close),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveRequest(context, ref),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],

                // Timestamp
                const SizedBox(height: 12),
                Text(
                  'Received ${DateFormat('MMM d, y • h:mm a').format(request.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color badgeColor;
    IconData icon;
    String text;

    if (request.isPending) {
      badgeColor = Colors.orange;
      icon = Icons.pending;
      text = 'Pending';
    } else if (request.isApproved) {
      badgeColor = Colors.green;
      icon = Icons.check_circle;
      text = 'Approved';
    } else {
      badgeColor = Colors.red;
      icon = Icons.cancel;
      text = 'Declined';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Request'),
        content: Text(
          'Approve "${request.eventTitle}" and create the event?\n\nThe event will be created in draft status for the organizer to finalize.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final service = ref.read(venueRequestServiceProvider);
      await service.approveVenueRequest(
        requestId: request.id,
        venueOwner: venueOwner,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved! Event created successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        onActionComplete();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Decline "${request.eventTitle}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for declining *',
                hintText: 'Please provide a reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      reasonController.dispose();
      return;
    }

    try {
      final service = ref.read(venueRequestServiceProvider);
      await service.declineVenueRequest(
        requestId: request.id,
        venueOwner: venueOwner,
        reason: reasonController.text.trim(),
      );

      reasonController.dispose();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request declined'),
            backgroundColor: Colors.orange,
          ),
        );
        onActionComplete();
      }
    } catch (e) {
      reasonController.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
