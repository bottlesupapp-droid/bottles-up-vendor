import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/plain_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/ui/bu_kit.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../../core/utils/responsive_utils.dart' as utils;
import '../../../shared/models/analytics_models.dart';
import '../providers/analytics_provider.dart';

Color _primaryColor = BuTokens.dark.orange;

/// The last seven days, oldest first, each with the bookings made that day (a day with none is 0). Read from the account's own bookings, never invented.
List<(DateTime, int)> bookingsPerDay(List<BookingTrend> trends, DateTime now) {
  final days = [for (var back = 6; back >= 0; back--) DateTime(now.year, now.month, now.day - back)];
  return [for (final day in days) (day, trends.where((t) => _sameDay(t.date, day)).fold<int>(0, (sum, t) => sum + t.bookings))];
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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

    final bu = context.bu;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.m),
            child: BuPageHeader(eyebrow: 'Performance', title: 'Reports'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BuSpace.page),
            child: Container(
              key: const Key('reports-tabs'),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: bu.panel, borderRadius: BorderRadius.circular(BuRadius.control + 2)),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                labelPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: bu.raised, borderRadius: BorderRadius.circular(BuRadius.control - 2)),
                labelColor: bu.ink,
                unselectedLabelColor: bu.muted,
                labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: bu.ink),
                unselectedLabelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Overview', height: 38),
                  Tab(text: 'Revenue', height: 38),
                  Tab(text: 'Events', height: 38),
                  Tab(text: 'Inquiries', height: 38),
                ],
              ),
            ),
          ),
          const SizedBox(height: BuSpace.m),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTabWithState(context),
                _buildRevenueTab(context),
                _buildEventsTab(context),
                _buildInquiriesTabWithState(context),
              ],
            ),
          ),
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
            Icon(Ionicons.alert_circle_outline, size: 64, color: BuTokens.dark.muted),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: BuSpace.xl), child: Text(loadFailedMessage('your analytics'), key: const Key('analytics-error'), textAlign: TextAlign.center)),
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
            Icon(Ionicons.alert_circle_outline, size: 64, color: BuTokens.dark.muted),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: BuSpace.xl), child: Text(loadFailedMessage('your analytics'), key: const Key('analytics-error'), textAlign: TextAlign.center)),
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

    return ResponsiveWrapper(
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(organizerAnalyticsProvider);
          await ref.read(organizerAnalyticsProvider.future);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, 100),
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
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: BuStatTile(key: const Key('report-bookings'), label: 'Total bookings', value: data.totalBookings.toString(), note: '${data.confirmedBookings} confirmed')),
            const SizedBox(width: 10),
            Expanded(child: BuStatTile(key: const Key('report-revenue'), label: 'Total revenue', value: NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(data.totalRevenue), note: 'Gross · before fees')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: BuStatTile(key: const Key('report-inquiries'), label: 'Pending inquiries', value: data.pendingInquiries.toString(), note: 'Waiting for a reply', trend: data.pendingInquiries > 0 ? 'Reply' : null, trendTone: BuTone.attention)),
            const SizedBox(width: 10),
            Expanded(child: BuStatTile(key: const Key('report-confirmed'), label: 'Confirmed', value: data.confirmedBookings.toString(), note: 'Bookings you can count on')),
          ],
        ),
      ],
    );
  }

  Widget _buildBookingTrendsChart(BuildContext context, dynamic data) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final days = bookingsPerDay((data.bookingTrends as List).cast<BookingTrend>(), DateTime.now());
    final total = days.fold<int>(0, (sum, d) => sum + d.$2);
    final peak = days.fold<int>(0, (m, d) => d.$2 > m ? d.$2 : m);
    final top = (peak < 4 ? 4 : peak + 1).toDouble();
    final step = (top / 4).ceilToDouble();
    final label = text.labelSmall?.copyWith(color: bu.muted, fontSize: 11);
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return BuCard(
      key: const Key('report-trend'),
      padding: const EdgeInsets.all(BuSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BuEyebrow('Last 7 days'),
          const SizedBox(height: 4),
          Text('Booking Trends', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(total == 0 ? 'No bookings in the last 7 days.' : '$total ${total == 1 ? 'booking' : 'bookings'} in the last 7 days.', key: const Key('report-trend-total'), style: text.bodySmall?.copyWith(color: bu.muted)),
          const SizedBox(height: BuSpace.l),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: top,
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: step, getDrawingHorizontalLine: (_) => FlLine(color: bu.line, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: step,
                      getTitlesWidget: (v, meta) => v == v.roundToDouble() ? Text('${v.toInt()}', style: label) : const SizedBox.shrink(),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(weekdays[days[i].$1.weekday - 1], style: label));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].$2.toDouble())],
                    isCurved: false,
                    color: _primaryColor,
                    barWidth: 3,
                    dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 3, color: _primaryColor, strokeWidth: 0)),
                    belowBarData: BarAreaData(show: true, color: _primaryColor.withValues(alpha: 0.10)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BuTokens.dark.panel,
        borderRadius: BorderRadius.circular(BuRadius.card),
        border: Border.all(color: BuTokens.dark.hairline),
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
          Text(label, style: TextStyle(color: BuTokens.dark.muted)),
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
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(revenueBreakdownProvider);
            await ref.read(revenueBreakdownProvider.future);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, 100),
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
      error: (error, stack) => _failed(() => ref.invalidate(revenueBreakdownProvider), 'your revenue'),
    );
  }

  /// A failed read is said plainly with Retry; it is never shown as zero revenue or an empty list.
  Widget _failed(VoidCallback retry, String what) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loadFailedMessage(what), key: const Key('analytics-error'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      );

  Widget _buildRevenueBreakdown(BuildContext context, dynamic data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BuTokens.dark.panel,
        borderRadius: BorderRadius.circular(BuRadius.card),
        border: Border.all(color: BuTokens.dark.hairline),
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
          _buildRevenueItem('Ticket Sales', data.ticketSales, BuTokens.dark.orangeSoft),
          _buildRevenueItem('Table Sales', data.tableSales, BuTokens.dark.green),
          _buildRevenueItem('Bottle Sales', data.bottleSales, BuTokens.dark.soft),
          _buildRevenueItem('Other Sales', data.otherSales, BuTokens.dark.amber),
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
                  color: isTotal ? null : BuTokens.dark.muted,
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
        color: BuTokens.dark.panel,
        borderRadius: BorderRadius.circular(BuRadius.card),
        border: Border.all(color: BuTokens.dark.hairline),
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
            Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No revenue data available',
                  style: TextStyle(color: BuTokens.dark.muted),
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
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(eventPerformanceInsightsProvider);
            await ref.read(eventPerformanceInsightsProvider.future);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: insights.map((insight) => _buildEventPerformanceCard(context, insight)).toList(),
            ),
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _failed(() => ref.invalidate(eventPerformanceInsightsProvider), 'your events'),
    );
  }

  Widget _buildEventPerformanceCard(BuildContext context, dynamic insight) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BuTokens.dark.panel,
        borderRadius: BorderRadius.circular(BuRadius.card),
        border: Border.all(color: BuTokens.dark.hairline),
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
                  BuTokens.dark.orangeSoft,
                ),
              ),
              Expanded(
                child: _buildPerformanceMetric(
                  'RSVP',
                  insight.rsvpCount.toString(),
                  BuTokens.dark.soft,
                ),
              ),
              Expanded(
                child: _buildPerformanceMetric(
                  'Checked In',
                  insight.checkedInCount.toString(),
                  BuTokens.dark.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(
            'Conversion Rate',
            insight.conversionRate,
            BuTokens.dark.orangeSoft,
          ),
          const SizedBox(height: 8),
          _buildProgressBar(
            'Attendance Rate',
            insight.attendanceRate,
            BuTokens.dark.green,
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
          style: TextStyle(
            fontSize: 12,
            color: BuTokens.dark.muted,
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
            Text(label, style: TextStyle(fontSize: 12, color: BuTokens.dark.muted)),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: BuTokens.dark.muted.withOpacity(0.2),
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
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(organizerAnalyticsProvider);
          await ref.read(organizerAnalyticsProvider.future);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, 100),
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
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No inquiries yet',
                      style: TextStyle(color: BuTokens.dark.muted),
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

    Color statusColor;
    switch (inquiry.status) {
      case 'accepted':
        statusColor = BuTokens.dark.green;
        break;
      case 'rejected':
        statusColor = BuTokens.dark.red;
        break;
      default:
        statusColor = BuTokens.dark.amber;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BuTokens.dark.panel,
        borderRadius: BorderRadius.circular(BuRadius.card),
        border: Border.all(color: BuTokens.dark.hairline),
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
            style: TextStyle(
              color: _primaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            inquiry.message,
            style: TextStyle(color: BuTokens.dark.muted, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM dd, yyyy').format(inquiry.createdAt),
            style: TextStyle(color: BuTokens.dark.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
