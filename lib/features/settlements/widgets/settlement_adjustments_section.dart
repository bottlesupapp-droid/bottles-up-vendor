import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../logic/settlement_adjustment_rules.dart';
import '../logic/settlement_rules.dart';
import '../providers/settlement_providers.dart';
import '../screens/settlements_screen.dart' show toneOf;
import 'settlement_dialogs.dart';

/// "Adjustments after payment" for a PAID settlement (brief sections 25 and 26; scenario 23 "Refund after settlement"): what was paid (shown unchanged), each refund, chargeback or correction that
/// came after, what the organizer is owed after them, and what is still to be settled, with the history. Record only: nothing is paid or taken back from here. What the person may do about each
/// adjustment is whatever the database says (`can`); the buttons are those and nothing else.
class SettlementAdjustmentsSection extends ConsumerStatefulWidget {
  const SettlementAdjustmentsSection({super.key, required this.agreementId, required this.clubName, required this.organizerName, this.clock = DateTime.now});

  final String agreementId;
  final String clubName;
  final String organizerName;
  final DateTime Function() clock;

  @override
  ConsumerState<SettlementAdjustmentsSection> createState() => _SettlementAdjustmentsSectionState();
}

class _SettlementAdjustmentsSectionState extends ConsumerState<SettlementAdjustmentsSection> {
  bool _busy = false;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _reload() => ref.invalidate(settlementAdjustmentsProvider(widget.agreementId));

  /// Runs one step. A refusal is the database's own sentence; either way the section reads again, so it shows what the database says now.
  Future<void> _run(Future<void> Function() step, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await step();
      _say(done);
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      _reload();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _when(DateTime? t) => t == null ? '' : DateFormat('MMM d, HH:mm').format(t.toLocal());

  Future<void> _record(SettlementAdjustments a) async {
    final entry = await showAdjustmentRecordDialog(context, netCents: a.netCents, currency: a.currency);
    if (entry == null || !mounted) return;
    final checked = checkAdjustmentRecordForm(kind: entry.kind, amount: entry.amount, reason: entry.reason, reference: entry.reference, netCents: a.netCents, currency: a.currency);
    await _run(() async {
      await ref.read(settlementServiceProvider).recordAdjustment(a.settlementId!, kind: checked.kind!, amountCents: checked.cents!, reason: checked.reason!, reference: checked.reference);
    }, 'The adjustment is recorded. The payment above is unchanged.');
  }

  Future<void> _acknowledge(SettlementAdjustment x) async {
    await _run(() async {
      await ref.read(settlementServiceProvider).acknowledgeAdjustment(x.id);
    }, 'Thank you. The club can see that you have seen it.');
  }

  Future<void> _question(SettlementAdjustment x) async {
    final text = await showTextDialog(
      context,
      title: 'Ask a question',
      hint: 'What would you like to ask?',
      message: 'The club sees your question and answers it. Nothing changes until they do.',
      confirmLabel: 'Send question',
      validate: checkQuestion,
    );
    if (text == null || !mounted) return;
    await _run(() => ref.read(settlementServiceProvider).questionAdjustment(x.id, text), 'Your question has been sent.');
  }

  Future<void> _answer(SettlementAdjustment x) async {
    final text = await showTextDialog(
      context,
      title: 'Answer the question',
      hint: 'Your answer',
      message: x.disputedReason == null ? null : 'The organizer asked: "${x.disputedReason}"',
      confirmLabel: 'Send answer',
      validate: checkAnswer,
    );
    if (text == null || !mounted) return;
    await _run(() => ref.read(settlementServiceProvider).answerAdjustment(x.id, text), 'Answered. The adjustment is open again.');
  }

  Future<void> _settle(SettlementAdjustments a, SettlementAdjustment x) async {
    final owes = adjustmentOwesText(direction: x.direction, cents: x.amountCents, club: widget.clubName, organizer: widget.organizerName, currency: a.currency);
    final entry = await showPaymentDialog(
      context,
      payableCents: x.amountCents.abs(),
      currency: a.currency,
      recipient: x.direction == 'club_owes_organizer' ? widget.organizerName : widget.clubName,
      clock: widget.clock,
      title: 'Record the payment',
      message: 'Only record a payment that has ALREADY been made, outside BottlesUp ($owes). Nothing is sent from here.',
      helper: 'Exactly the adjustment',
      check: (amount, reference, evidence) => checkAdjustmentSettleForm(amount, reference, evidence, adjustmentCents: x.amountCents, currency: a.currency),
    );
    if (entry == null || !mounted) return;
    final checked = checkAdjustmentSettleForm(entry.amount, entry.reference, entry.evidence, adjustmentCents: x.amountCents, currency: a.currency);
    await _run(() async {
      await ref.read(settlementServiceProvider).settleAdjustment(x.id, amountCents: checked.cents!, paidOn: entry.paidOn, reference: checked.reference!, evidence: checked.evidence);
    }, 'The payment is recorded.');
  }

  Future<void> _waive(SettlementAdjustments a, SettlementAdjustment x) async {
    final text = await showTextDialog(
      context,
      title: 'Do not recover this amount',
      hint: 'Why is it not being recovered?',
      message:
          '${settlementMoney(x.amountCents.abs(), currency: a.currency)} was paid to ${widget.organizerName} that they were not owed. It stays on record as "Not recovered", and cannot be changed afterwards.',
      confirmLabel: 'Do not recover',
      validate: checkWaiveReason,
    );
    if (text == null || !mounted) return;
    await _run(() => ref.read(settlementServiceProvider).waiveAdjustment(x.id, text), 'Recorded as not recovered.');
  }

  Widget _fact(ThemeData theme, String label, String value, {Key? key, bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: Text(label, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: 12),
        Expanded(flex: 6, child: Text(value, key: key, textAlign: TextAlign.right, style: strong ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)),
      ],
    ),
  );

  Widget _item(ThemeData theme, SettlementAdjustments a, SettlementAdjustment x) {
    final info = adjustmentStatusInfo(x.status);
    Widget action(String key, String label, VoidCallback onTap, {bool primary = false}) =>
        primary ? FilledButton(key: Key(key), onPressed: _busy ? null : onTap, child: Text(label)) : OutlinedButton(key: Key(key), onPressed: _busy ? null : onTap, child: Text(label));
    final actions = [
      if (x.can.settle) action('adjustment-settle-${x.id}', 'Record the payment', () => _settle(a, x), primary: true),
      if (x.can.answer) action('adjustment-answer-${x.id}', 'Answer the question', () => _answer(x), primary: true),
      if (x.can.acknowledge) action('adjustment-ack-${x.id}', 'I have seen this', () => _acknowledge(x), primary: true),
      if (x.can.waive) action('adjustment-waive-${x.id}', 'Do not recover it', () => _waive(a, x)),
      if (x.can.question) action('adjustment-question-${x.id}', 'Ask a question', () => _question(x)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: BuSpace.m),
      child: BuCard(
        key: Key('adjustment-${x.id}'),
        accent: x.status == 'disputed' ? context.bu.red : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${adjustmentKindLabel(x.kind)} ${signedMoney(x.amountCents, currency: a.currency)}', key: Key('adjustment-title-${x.id}'), style: theme.textTheme.titleMedium)),
                BuStatusPill(info.label, key: Key('adjustment-status-${x.id}'), tone: toneOf(info.tone)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              adjustmentOutcomeText(status: x.status, direction: x.direction, cents: x.amountCents, club: widget.clubName, organizer: widget.organizerName, currency: a.currency),
              key: Key('adjustment-owes-${x.id}'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text('Why: ${x.reason}', key: Key('adjustment-reason-${x.id}'), style: theme.textTheme.bodySmall),
            if (x.sourceRef != null) Text('Reference: ${x.sourceRef}', key: Key('adjustment-ref-${x.id}'), style: theme.textTheme.bodySmall),
            Text('Recorded by ${x.recordedByName ?? 'the club'}, ${_when(x.recordedAt)}', key: Key('adjustment-recorded-${x.id}'), style: theme.textTheme.bodySmall),
            if (x.status == 'disputed' && x.disputedReason != null) ...[
              const SizedBox(height: 8),
              Text('Question from the organizer: ${x.disputedReason}', key: Key('adjustment-question-text-${x.id}'), style: theme.textTheme.bodyMedium),
            ],
            if (x.status == 'settled') ...[
              const SizedBox(height: 8),
              Text(x.resolutionLabel ?? 'Recorded external payment', key: Key('adjustment-resolution-label-${x.id}'), style: theme.textTheme.titleSmall),
              _fact(theme, 'Amount', settlementMoney(x.resolvedAmountCents ?? 0, currency: a.currency), key: Key('adjustment-resolved-amount-${x.id}')),
              if (x.resolvedOn != null) _fact(theme, 'Paid on', DateFormat('EEE d MMM yyyy').format(x.resolvedOn!), key: Key('adjustment-resolved-on-${x.id}')),
              _fact(theme, 'Reference', x.resolutionReference ?? '', key: Key('adjustment-resolved-ref-${x.id}')),
              if (x.resolutionNote != null) _fact(theme, 'Evidence', x.resolutionNote!, key: Key('adjustment-resolved-evidence-${x.id}')),
              if (x.resolvedByName != null) Text('Recorded by ${x.resolvedByName}, ${_when(x.resolvedAt)}', style: theme.textTheme.bodySmall),
              Text('Nothing was sent from BottlesUp: this records a payment made outside it.', style: theme.textTheme.bodySmall),
            ],
            if (x.status == 'waived') ...[
              const SizedBox(height: 8),
              Text(x.resolutionLabel ?? 'Not recovered', key: Key('adjustment-resolution-label-${x.id}'), style: theme.textTheme.titleSmall),
              Text(x.resolutionNote ?? '', key: Key('adjustment-waived-reason-${x.id}'), style: theme.textTheme.bodyMedium),
              if (x.resolvedByName != null) Text('Decided by ${x.resolvedByName}, ${_when(x.resolvedAt)}', style: theme.textTheme.bodySmall),
            ],
            if (x.acknowledgedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Acknowledged by ${x.acknowledgedByName ?? 'the organizer'}, ${_when(x.acknowledgedAt)}', key: Key('adjustment-acknowledged-${x.id}'), style: theme.textTheme.bodySmall),
              ),
            if (actions.isNotEmpty) ...[const SizedBox(height: BuSpace.m), Wrap(spacing: 8, runSpacing: 8, key: Key('adjustment-actions-${x.id}'), children: actions)],
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme, SettlementAdjustments a) {
    if (!a.applies) return const SizedBox.shrink();
    final lines = adjustmentSummaryLines(a, club: widget.clubName, organizer: widget.organizerName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++) _fact(theme, lines[i].label, lines[i].value, strong: lines[i].strong, key: Key(lines[i].strong ? 'adjustments-net' : 'adjustments-line-$i')),
              const Divider(height: 24),
              Text(adjustmentsNote, key: const Key('adjustments-note'), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        if (a.canRecord) ...[
          const SizedBox(height: BuSpace.m),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(key: const Key('adjustment-record'), onPressed: _busy ? null : () => _record(a), child: const Text('Record an adjustment')),
          ),
        ],
        const SizedBox(height: BuSpace.m),
        if (a.isEmpty)
          Text('No adjustments after payment.', key: const Key('adjustments-empty'), style: theme.textTheme.bodyMedium)
        else
          for (final x in a.items) _item(theme, a, x),
        if (a.log.isNotEmpty) ...[
          const SizedBox(height: BuSpace.l),
          const BuSectionHeader(title: 'History of the adjustments'),
          const SizedBox(height: BuSpace.s),
          BuListCard(
            children: [
              for (var i = 0; i < a.log.length; i++)
                BuListRow(
                  key: Key('adjustment-log-$i'),
                  title: adjustmentLogLine(a.log[i], currency: a.currency),
                  subtitle: '${a.log[i].byMe ? 'You' : a.log[i].byName} · ${_when(a.log[i].at)}${a.log[i].note == null ? '' : '\n${a.log[i].note}'}',
                  maxSubtitleLines: 4,
                  showChevron: false,
                ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = ref.watch(settlementAdjustmentsProvider(widget.agreementId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: BuSpace.xl),
        const BuSectionHeader(title: 'Adjustments after payment'),
        const SizedBox(height: BuSpace.s),
        OpsAsyncView<SettlementAdjustments>(
          value: value,
          what: 'the adjustments after payment',
          keepWhileReloading: true,
          errorKey: const Key('adjustments-error'),
          onRetry: _reload,
          builder: (a) => _body(theme, a),
        ),
      ],
    );
  }
}
