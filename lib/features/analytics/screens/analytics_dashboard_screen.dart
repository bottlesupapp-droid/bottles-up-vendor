import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../../core/utils/responsive_utils.dart' as utils;
import '../providers/analytics_provider.dart';

const Color _primaryColor = Color(0xFFFF6B35);

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState
    extends ConsumerState<AnalyticsDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Revenue'),
            Tab(text: 'Events'),
            Tab(text: 'Inquiries'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTabWithState(context),
          _buildRevenueTab(context),
          _buildEventsTab(context),
          _buildInquiriesTabWithState(context),
        ],
      ),
    );
  }

  Widget _buildOverviewTabWithState(BuildContext context) {
    final analyticsData = ref.watch(organizerAnalyticsProvider);

    return analyticsData.when(
      data: (data) => _buildOverviewTab(context, data),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Ionicons.alert_circle_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Error loading analytics: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(organizerAnalyticsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInquiriesTabWithState(BuildContext context) {
    final analyticsData = ref.watch(organizerAnalyticsProvider);

    return analyticsData.when(
      data: (data) => _buildInquiriesTab(context, data),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Ionicons.alert_circle_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(organizerAnalyticsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return ResponsiveWrapper(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(organizerAnalyticsProvider);
          await ref.read(organizerAnalyticsProvider.future);
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(utils.ResponsiveUtils.getResponsivePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key Metrics Cards
              _buildKeyMetricsGrid(context, data),

              SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

              // Booking Trends Chart
              _buildBookingTrendsChart(context, data),

              SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

              // Quick Stats
              _buildQuickStats(context, data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyMetricsGrid(BuildContext context, dynamic data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          context,
          'Total Bookings',
          data.totalBookings.toString(),
          Ionicons.ticket_outline,
          Colors.blue,
        ),
        _buildMetricCard(
          context,
          'Total Revenue',
          NumberFormat.currency(symbol: '\$').format(data.totalRevenue),
          Ionicons.cash_outline,
          Colors.green,
        ),
        _buildMetricCard(
          context,
          'Pending Inquiries',
          data.pendingInquiries.toString(),
          Ionicons.mail_unread_outline,
          Colors.orange,
        ),
        _buildMetricCard(
          context,
          'Confirmed Bookings',
          data.confirmedBookings.toString(),
          Ionicons.checkmark_circle_outline,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingTrendsChart(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Trends',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateSampleSpots(),
                    isCurved: true,
                    color: _primaryColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _primaryColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateSampleSpots() {
    return List.generate(7, (index) {
      return FlSpot(index.toDouble(), (index * 2 + 10).toDouble());
    });
  }

  Widget _buildQuickStats(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Statistics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Total Inquiries', data.totalInquiries.toString()),
          _buildStatRow('Accepted Inquiries', data.acceptedInquiries.toString()),
          _buildStatRow('Rejected Inquiries', data.rejectedInquiries.toString()),
          _buildStatRow('Cancelled Bookings', data.cancelledBookings.toString()),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTab(BuildContext context) {
    final revenueData = ref.watch(revenueBreakdownProvider);

    return revenueData.when(
      data: (data) => ResponsiveWrapper(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(revenueBreakdownProvider);
            await ref.read(revenueBreakdownProvider.future);
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.all(utils.ResponsiveUtils.getResponsivePadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRevenueBreakdown(context, data),
                SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),
                _buildRevenueByEvent(context, data),
              ],
            ),
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildRevenueBreakdown(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue Breakdown',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildRevenueItem('Ticket Sales', data.ticketSales, Colors.blue),
          _buildRevenueItem('Table Sales', data.tableSales, Colors.green),
          _buildRevenueItem('Bottle Sales', data.bottleSales, Colors.purple),
          _buildRevenueItem('Other Sales', data.otherSales, Colors.orange),
          const Divider(height: 32),
          _buildRevenueItem(
            'Total Revenue',
            data.totalRevenue,
            _primaryColor,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueItem(String label, double amount, Color color, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isTotal ? null : Colors.grey,
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
                  fontSize: isTotal ? 18 : 16,
                ),
              ),
            ],
          ),
          Text(
            NumberFormat.currency(symbol: '\$').format(amount),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isTotal ? 20 : 16,
              color: isTotal ? _primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueByEvent(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue by Event',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (data.revenueByEvent.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No revenue data available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...data.revenueByEvent.map((event) => ListTile(
                  title: Text(event.eventName),
                  subtitle: Text('${event.bookings} bookings'),
                  trailing: Text(
                    NumberFormat.currency(symbol: '\$').format(event.revenue),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildEventsTab(BuildContext context) {
    final performanceData = ref.watch(eventPerformanceInsightsProvider);

    return performanceData.when(
      data: (insights) => ResponsiveWrapper(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(eventPerformanceInsightsProvider);
            await ref.read(eventPerformanceInsightsProvider.future);
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.all(utils.ResponsiveUtils.getResponsivePadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: insights.map((insight) => _buildEventPerformanceCard(context, insight)).toList(),
            ),
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildEventPerformanceCard(BuildContext context, dynamic insight) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.eventName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPerformanceMetric(
                  'Sold',
                  '${insight.soldTickets}/${insight.totalTickets}',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildPerformanceMetric(
                  'RSVP',
                  insight.rsvpCount.toString(),
                  Colors.purple,
                ),
              ),
              Expanded(
                child: _buildPerformanceMetric(
                  'Checked In',
                  insight.checkedInCount.toString(),
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(
            'Conversion Rate',
            insight.conversionRate,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildProgressBar(
            'Attendance Rate',
            insight.attendanceRate,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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
    );
  }

  Widget _buildProgressBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey.withOpacity(0.2),
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildInquiriesTab(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return ResponsiveWrapper(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(organizerAnalyticsProvider);
          await ref.read(organizerAnalyticsProvider.future);
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.all(utils.ResponsiveUtils.getResponsivePadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Inquiries',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (data.recentInquiries.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No inquiries yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...data.recentInquiries.map((inquiry) => _buildInquiryCard(context, inquiry)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryCard(BuildContext context, dynamic inquiry) {
    final theme = Theme.of(context);

    Color statusColor;
    switch (inquiry.status) {
      case 'accepted':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  inquiry.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  inquiry.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inquiry.eventName,
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            inquiry.message,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM dd, yyyy').format(inquiry.createdAt),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
