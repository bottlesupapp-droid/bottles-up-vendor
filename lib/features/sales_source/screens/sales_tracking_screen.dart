import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/sales_source_rules.dart';
import '../providers/sales_source_providers.dart';
import 'closing_report_form_screen.dart';

/// Venue Settings, Sales Tracking (brief section 24): where this club's sales come from, and, for a club on closing report upload, the reports it has sent and the ones waiting to be checked. The club's owner or
/// manager chooses the source and sends reports; the owner or a payment verifier checks them, never the person who sent one. Connected POS is shown as not available.
class SalesTrackingScreen extends ConsumerStatefulWidget {
  const SalesTrackingScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<SalesTrackingScreen> createState() => _SalesTrackingScreenState();
}

class _SalesTrackingScreenState extends ConsumerState<SalesTrackingScreen> {
  bool _saving = false;

  String? get _venueId => widget.workspace.venueId;

  Future<void> _choose(SalesSource source) async {
    final venueId = _venueId!;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(salesSourceServiceProvider).saveSource(venueId, source);
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      ref.invalidate(salesSourceProvider(venueId));
      ref.invalidate(closingReportsProvider(venueId));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(ClosingReport r, {required bool accept}) async {
    final messenger = ScaffoldMessenger.of(context);
    String? note;
    if (!accept) {
      note = await _askWhy();
      if (note == null) return;
    }
    try {
      await ref.read(salesSourceServiceProvider).review(r.id, accept: accept, note: note);
      messenger.showSnackBar(SnackBar(content: Text(accept ? 'Report accepted.' : 'Report not accepted.')));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      ref.invalidate(closingReportsProvider(_venueId!));
    }
  }

  Future<String?> _askWhy() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Why is it not accepted?'),
        content: TextField(key: const Key('refuse-reason'), controller: controller, maxLength: 300, maxLines: 3, decoration: const InputDecoration(hintText: 'At least 5 characters')),
        actions: [
          TextButton(key: const Key('refuse-cancel'), onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const Key('refuse-confirm'),
            onPressed: () {
              if (controller.text.trim().length >= 5) Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Not accepted'),
          ),
        ],
      ),
    );
  }

  Widget _choice(SalesSource source, SalesSource current, bool editable, ThemeData theme) {
    final selected = source == current;
    return Card(
      key: Key('source-${source.wire}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.4), width: selected ? 2 : 1)),
      child: ListTile(
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? theme.colorScheme.primary : null),
        title: Text(source.label),
        subtitle: Text(source.blurb),
        onTap: editable && !selected && !_saving ? () => _choose(source) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = _venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This workspace is not tied to a club, so there is no sales source to show.', key: Key('sales-no-venue'), textAlign: TextAlign.center)));
    }
    final role = widget.workspace.role;
    final source = ref.watch(salesSourceProvider(venueId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(salesSourceProvider(venueId));
        ref.invalidate(closingReportsProvider(venueId));
      },
      child: ListView(
        key: const Key('sales-tracking'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('Sales Tracking', style: theme.textTheme.headlineSmall),
          if (widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Where this club\'s sales come from. Every report says which it is, and the sources are never added together.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          OpsAsyncView<SalesSource>(
            value: source,
            what: 'the sales source',
            errorKey: const Key('sales-error'),
            onRetry: () => ref.invalidate(salesSourceProvider(venueId)),
            builder: (current) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!canChooseSource(role)) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Only the owner or a manager of the club can change this.', key: const Key('sales-read-only'), style: theme.textTheme.bodySmall)),
                _choice(SalesSource.entries, current, canChooseSource(role), theme),
                _choice(SalesSource.upload, current, canChooseSource(role), theme),
                Card(
                  key: const Key('source-pos'),
                  child: ListTile(leading: const Icon(Icons.block), title: const Text(posLabel), subtitle: const Text(posUnavailableText), enabled: false),
                ),
                if (current == SalesSource.upload) ..._reports(venueId, role, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _reports(String venueId, WorkspaceRole role, ThemeData theme) {
    final reports = ref.watch(closingReportsProvider(venueId));
    return [
      const SizedBox(height: 16),
      Text('Closing reports', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      if (canSendClosingReport(role))
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('send-closing-report'),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => ClosingReportFormScreen(venueId: venueId, venueName: widget.workspace.venueName, clock: widget.clock)))
                .then((_) => ref.invalidate(closingReportsProvider(venueId))),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Send a closing report'),
          ),
        ),
      OpsAsyncView<List<ClosingReport>>(
        value: reports,
        what: 'the closing reports',
        errorKey: const Key('reports-error'),
        isEmpty: (l) => l.isEmpty,
        emptyText: 'No closing reports yet.',
        emptyKey: const Key('reports-empty'),
        onRetry: () => ref.invalidate(closingReportsProvider(venueId)),
        builder: (list) => Column(
          children: [
            for (final r in list)
              Card(
                key: Key('report-${r.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reportSummaryLine(r), style: theme.textTheme.titleSmall),
                      Text('${periodText(r.periodStart, r.periodEnd)} · gross ${formatDollars(r.grossCents)}, discounts ${formatDollars(r.discountCents)}, refunds ${formatDollars(r.refundCents)}', style: theme.textTheme.bodySmall),
                      Text(r.includesBottlesUp ? 'Includes what BottlesUp recorded.' : 'Bar and other sales only.', style: theme.textTheme.bodySmall),
                      if (r.note != null) Text('Note: ${r.note}', style: theme.textTheme.bodySmall),
                      if (r.reviewNote != null) Text('Checker: ${r.reviewNote}', style: theme.textTheme.bodySmall),
                      if (r.mine && r.status == ClosingReportStatus.submitted) Text('You sent this one, so someone else has to check it.', key: Key('mine-${r.id}'), style: theme.textTheme.bodySmall),
                      if (r.canReview)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(key: Key('accept-${r.id}'), onPressed: () => _review(r, accept: true), child: const Text('Accept')),
                              OutlinedButton(key: Key('refuse-${r.id}'), onPressed: () => _review(r, accept: false), child: const Text('Not accepted')),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
