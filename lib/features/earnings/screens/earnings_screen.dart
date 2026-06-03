import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/services/earnings_service.dart';
import '../../../core/theme/app_theme.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  final EarningsService _earningsService = EarningsService();
  Map<String, dynamic>? _totalEarnings;
  List<Map<String, dynamic>> _earningsByEvent = [];
  List<Map<String, dynamic>> _payoutHistory = [];
  Map<String, dynamic>? _stripeAccount;
  Map<String, dynamic>? _stripeBalance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEarningsData();
  }

  Future<void> _loadEarningsData() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final futures = await Future.wait([
        _earningsService.getTotalEarnings(userId),
        _earningsService.getEarningsByEvent(userId),
        _earningsService.getPayoutHistory(userId),
        _earningsService.getStripeAccount(userId),
      ]);

      final stripeAccount = futures[3] as Map<String, dynamic>?;

      // Get Stripe balance if account exists
      Map<String, dynamic>? balance;
      if (stripeAccount != null && stripeAccount['account_id'] != null) {
        try {
          balance = await _earningsService.getStripeBalance(
            stripeAccount['account_id'],
          );
        } catch (e) {
          // Ignore if balance fetch fails
        }
      }

      setState(() {
        _totalEarnings = futures[0] as Map<String, dynamic>;
        _earningsByEvent = futures[1] as List<Map<String, dynamic>>;
        _payoutHistory = futures[2] as List<Map<String, dynamic>>;
        _stripeAccount = stripeAccount;
        _stripeBalance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load earnings: $e')),
        );
      }
    }
  }

  Future<void> _setupStripeConnect() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final email = Supabase.instance.client.auth.currentUser?.email;

      if (userId == null || email == null) {
        throw Exception('User not authenticated');
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await _earningsService.setupStripeConnect(
        vendorId: userId,
        email: email,
        businessName: 'Vendor Business', // TODO: Get from vendor profile
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Launch onboarding URL
        final uri = Uri.parse(result['onboarding_url']);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        // Refresh data after onboarding
        await Future.delayed(const Duration(seconds: 3));
        await _loadEarningsData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to setup Stripe: $e')),
        );
      }
    }
  }

  Future<void> _openStripeDashboard() async {
    if (_stripeAccount == null || _stripeAccount!['account_id'] == null) {
      return;
    }

    try {
      final dashboardUrl = await _earningsService.getConnectDashboardLink(
        _stripeAccount!['account_id'],
      );

      final uri = Uri.parse(dashboardUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open dashboard: $e')),
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
        title: const Text('Earnings'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_stripeAccount != null)
            IconButton(
              icon: const Icon(Ionicons.analytics_outline),
              onPressed: _openStripeDashboard,
              tooltip: 'Stripe Dashboard',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEarningsData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stripe Connect Setup Banner
                    if (_stripeAccount == null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.darkContainerDecoration.copyWith(
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Ionicons.wallet_outline,
                              size: 48,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Connect Your Bank Account',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Set up Stripe Connect to receive payouts directly to your bank account',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _setupStripeConnect,
                              icon: const Icon(Ionicons.card_outline),
                              label: const Text('Setup Payouts'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Total Earnings Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.darkContainerDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Ionicons.cash_outline,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Total Earnings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  'Total Revenue',
                                  '\$${(_totalEarnings?['total_revenue'] ?? 0).toStringAsFixed(2)}',
                                  Colors.green,
                                  Ionicons.trending_up,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatTile(
                                  'Pending',
                                  '\$${(_totalEarnings?['pending_amount'] ?? 0).toStringAsFixed(2)}',
                                  Colors.orange,
                                  Ionicons.time_outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatTile(
                                  'Bookings',
                                  '${_totalEarnings?['total_bookings'] ?? 0}',
                                  Colors.blue,
                                  Ionicons.ticket_outline,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatTile(
                                  'Events',
                                  '${_totalEarnings?['total_events'] ?? 0}',
                                  Colors.purple,
                                  Ionicons.calendar_outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Stripe Balance (if connected)
                    if (_stripeBalance != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.darkCardDecoration,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Ionicons.wallet,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Available Balance',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${(_stripeBalance!['available'] ?? 0).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Earnings by Event
                    const Text(
                      'Earnings by Event',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_earningsByEvent.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: AppTheme.darkCardDecoration,
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Ionicons.document_text_outline,
                                size: 48,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No earnings data yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _earningsByEvent.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final event = _earningsByEvent[index];
                          return _buildEventEarningsCard(event);
                        },
                      ),

                    const SizedBox(height: 32),

                    // Payout History
                    const Text(
                      'Payout History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_payoutHistory.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: AppTheme.darkCardDecoration,
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Ionicons.receipt_outline,
                                size: 48,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No payout history',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _payoutHistory.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final payout = _payoutHistory[index];
                          return _buildPayoutCard(payout);
                        },
                      ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventEarningsCard(Map<String, dynamic> event) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.darkCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event['event_name'] ?? 'Unknown Event',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '\$${(event['revenue'] ?? 0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Ionicons.calendar_outline,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM dd, yyyy').format(
                  DateTime.parse(event['event_date']),
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Ionicons.ticket_outline,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '${event['bookings_count']} bookings',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if ((event['pending'] ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Ionicons.time_outline,
                  size: 14,
                  color: Colors.orange[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Pending: \$${(event['pending'] ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> payout) {
    final status = payout['status'] ?? 'pending';
    final amount = (payout['amount'] ?? 0).toDouble();
    final createdAt = DateTime.parse(payout['created_at']);

    Color statusColor = Colors.grey;
    IconData statusIcon = Ionicons.time_outline;

    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Ionicons.checkmark_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Ionicons.time_outline;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Ionicons.close_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.darkCardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • HH:mm').format(createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
