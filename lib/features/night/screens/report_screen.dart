import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/widgets/ops_async_view.dart';
import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../../table_service/widgets/night_bar.dart';
import '../logic/night_rules.dart';
import '../logic/report_pdf.dart';
import '../providers/night_providers.dart';

/// The nightly report for one club, for the signed-in person's role: the manager and owner see everything, the payment verifier the money,
/// security only security. It says whether it is preliminary or final, and can be shared as a PDF with the same words.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.venueId, this.venueName, this.initialNight, this.clock = DateTime.now});

  final String venueId;
  final String? venueName;
  final String? initialNight;
  final DateTime Function() clock;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late String _night = widget.initialNight ?? currentNight(widget.clock());
  bool _sharing = false;

  String get _tonight => currentNight(widget.clock());
  NightQuery get _query => NightQuery(widget.venueId, _night);

  Future<void> _share(NightReport report) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = buildReportDocument(report);
      final bytes = await buildReportPdf(doc);
      await ref.read(shareReportProvider)(bytes, doc.fileName);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('The PDF could not be made or shared. Try again.')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = ref.watch(nightReportProvider(_query));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(nightReportProvider(_query)),
      child: ListView(
        key: const Key('report-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          NightBar(night: _night, tonight: _tonight, onChanged: (n) => setState(() => _night = n)),
          const SizedBox(height: 8),
          OpsAsyncView<NightReport>(
            value: report,
            what: 'the report',
            errorKey: const Key('report-error'),
            onRetry: () => ref.invalidate(nightReportProvider(_query)),
            builder: (r) {
              final doc = buildReportDocument(r);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title, key: const Key('report-title'), style: theme.textTheme.headlineSmall),
                  Text(doc.subtitle, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Chip(
                    key: const Key('report-status'),
                    avatar: Icon(r.isFinal ? Icons.lock_outline : Icons.hourglass_empty, size: 16),
                    label: Text(doc.statusLine, style: theme.textTheme.labelMedium),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('report-share'),
                    onPressed: _sharing ? null : () => _share(r),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(_sharing ? 'Making the PDF…' : 'Share as PDF'),
                  ),
                  const SizedBox(height: 12),
                  for (final (i, s) in doc.sections.indexed)
                    Card(
                      key: Key('report-section-$i'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            for (final row in s.rows)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(row.label, style: row.strong ? const TextStyle(fontWeight: FontWeight.w700) : null)),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(row.value, textAlign: TextAlign.end, style: row.strong ? const TextStyle(fontWeight: FontWeight.w700) : null)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
