import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../logic/settlement_rules.dart';
import '../providers/settlement_providers.dart';
import '../widgets/settlement_dialogs.dart';
import 'settlements_screen.dart' show toneOf;

/// One settlement: the agreed terms, the calculation line by line, the payment record, and the history. What the person may do is whatever the database says (`can`); the buttons are
/// those and nothing else. The club's sales figure is shown as the venue's own ("Venue-reported"), never as counted by BottlesUp.
class SettlementDetailScreen extends ConsumerStatefulWidget {
  const SettlementDetailScreen({super.key, required this.agreementId, this.clock = DateTime.now});

  final String agreementId;
  final DateTime Function() clock;

  @override
  ConsumerState<SettlementDetailScreen> createState() => _SettlementDetailScreenState();
}

class _SettlementDetailScreenState extends ConsumerState<SettlementDetailScreen> {
  bool _busy = false;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Runs one step. A refusal is the database's own sentence; either way the page reads the settlement again, so it shows what the database says now.
  Future<void> _run(Future<void> Function() step, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await step();
      _say(done);
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      ref.invalidate(settlementDetailProvider(widget.agreementId));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSales(SettlementDetail d) async {
    final entry = await showMoneyNoteDialog(
      context,
      title: d.settlement == null ? 'Enter the bar sales' : 'Change the bar sales',
      message: 'The eligible bar sales for ${d.eventTitle}, as the club reports them. The agreement says which revenue is eligible. The share is worked out from this figure.',
      amountLabel: 'Eligible bar sales (CAD)',
      amountHint: 'For example 8,000.00',
      noteLabel: 'Where the figure comes from',
      noteHint: 'For example "Closing report of Fri 14 Nov, reviewed"',
      confirmLabel: 'Save',
      initialAmount: d.settlement == null ? '' : '${d.settlement!.eligibleSalesCents ~/ 100}.${(d.settlement!.eligibleSalesCents % 100).toString().padLeft(2, '0')}',
      validate: (a, n) => checkSalesForm(a, n).error,
    );
    if (entry == null || !mounted) return;
    final checked = checkSalesForm(entry.amount, entry.note);
    await _run(() async {
      await ref.read(settlementServiceProvider).saveSales(d.agreementId, checked.cents!, checked.note!);
    }, 'The bar sales are saved. Look at the share below.');
  }

  Future<void> _adjust(SettlementDetail d) async {
    final s = d.settlement!;
    final entry = await showMoneyNoteDialog(
      context,
      title: 'Adjust the amount owed',
      message:
          'Owed now: ${settlementMoney(s.payableCents, currency: s.currency)}. A later refund or a correction goes here, with the reason. Use a minus sign to take off. An approved settlement goes back to Estimated.',
      amountLabel: 'Plus or minus (CAD)',
      amountHint: 'For example -50.00',
      noteLabel: 'Why',
      noteHint: 'For example "Refund of a Friday bottle"',
      confirmLabel: 'Save adjustment',
      validate: (a, n) => checkAdjustmentForm(a, n, payableCents: s.payableCents).error,
    );
    if (entry == null || !mounted) return;
    final checked = checkAdjustmentForm(entry.amount, entry.note, payableCents: s.payableCents);
    await _run(() async {
      await ref.read(settlementServiceProvider).adjust(s.id, checked.cents!, checked.note!);
    }, 'The adjustment is saved.');
  }

  Future<void> _review(SettlementDetail d) async {
    final s = d.settlement!;
    final yes = await confirmSettlementStep(
      context,
      title: 'Mark as reviewed?',
      message: 'You are saying the figures are right: ${settlementMoney(s.payableCents, currency: s.currency)} owed to ${d.organizerName}. The owner then approves it.',
      confirmLabel: 'Mark as reviewed',
    );
    if (!yes || !mounted) return;
    await _run(() => ref.read(settlementServiceProvider).review(s.id), 'Marked as reviewed.');
  }

  Future<void> _approve(SettlementDetail d) async {
    final s = d.settlement!;
    final yes = await confirmSettlementStep(
      context,
      title: 'Approve this settlement?',
      message:
          'You approve ${settlementMoney(s.payableCents, currency: s.currency)} as owed to ${d.organizerName}. Nothing is paid by approving: afterwards you record the payment once it has been made.',
      confirmLabel: 'Approve',
    );
    if (!yes || !mounted) return;
    await _run(() => ref.read(settlementServiceProvider).approve(s.id), 'Approved. Record the payment once it has been made.');
  }

  Future<void> _pay(SettlementDetail d) async {
    final s = d.settlement!;
    final entry = await showPaymentDialog(context, payableCents: s.payableCents, currency: s.currency, recipient: d.organizerName, clock: widget.clock);
    if (entry == null || !mounted) return;
    final checked = checkPaymentForm(entry.amount, entry.reference, entry.evidence, payableCents: s.payableCents, currency: s.currency);
    await _run(() async {
      await ref.read(settlementServiceProvider).recordPayment(s.id, amountCents: checked.cents!, paidOn: entry.paidOn, reference: checked.reference!, evidence: checked.evidence);
    }, 'The payment is recorded.');
  }

  Future<void> _acknowledge(SettlementDetail d) async {
    await _run(() async {
      await ref.read(settlementServiceProvider).acknowledge(d.settlement!.id);
    }, 'Thank you. The club can see that you have seen it.');
  }

  Future<void> _question(SettlementDetail d) async {
    final text = await showTextDialog(
      context,
      title: 'Ask a question',
      hint: 'What would you like to ask?',
      message: 'The club sees your question and answers it. Nothing changes in the figures until they do.',
      confirmLabel: 'Send question',
      validate: checkQuestion,
    );
    if (text == null || !mounted) return;
    await _run(() => ref.read(settlementServiceProvider).question(d.settlement!.id, text), 'Your question has been sent.');
  }

  Future<void> _resolve(SettlementDetail d) async {
    final text = await showTextDialog(
      context,
      title: 'Answer the question',
      hint: 'Your answer',
      message: d.settlement?.disputedReason == null ? null : 'The organizer asked: "${d.settlement!.disputedReason}"',
      confirmLabel: 'Send answer',
      validate: checkAnswer,
    );
    if (text == null || !mounted) return;
    await _run(() => ref.read(settlementServiceProvider).resolve(d.settlement!.id, text), 'Answered. The settlement is back to Estimated.');
  }

  String _when(DateTime? t) => t == null ? '' : DateFormat('MMM d, HH:mm').format(t.toLocal());

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

  List<Widget> _actions(SettlementDetail d) {
    final c = d.can;
    Widget primary(String key, String label, VoidCallback onTap) => FilledButton(key: Key(key), onPressed: _busy ? null : onTap, child: Text(label));
    Widget secondary(String key, String label, VoidCallback onTap) => OutlinedButton(key: Key(key), onPressed: _busy ? null : onTap, child: Text(label));
    return [
      if (c.saveSales) (d.settlement == null ? primary : secondary)('settlement-save-sales', d.settlement == null ? 'Enter the bar sales' : 'Change the bar sales', () => _saveSales(d)),
      if (c.review) primary('settlement-review', 'Mark as reviewed', () => _review(d)),
      if (c.approve) primary('settlement-approve', 'Approve', () => _approve(d)),
      if (c.recordPayment) primary('settlement-pay', 'Record the payment', () => _pay(d)),
      if (c.resolve) primary('settlement-resolve', 'Answer the question', () => _resolve(d)),
      if (c.acknowledge) primary('settlement-ack', 'I have seen this', () => _acknowledge(d)),
      if (c.adjust) secondary('settlement-adjust', 'Adjust the amount', () => _adjust(d)),
      if (c.question) secondary('settlement-question', 'Ask a question', () => _question(d)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(settlementDetailProvider(widget.agreementId));
    return Scaffold(
      appBar: const BuDetailAppBar(eyebrow: 'Money', title: 'Settlement'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(settlementDetailProvider(widget.agreementId)),
          child: ListView(
            key: const Key('settlement-detail'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xl),
            children: [
              OpsAsyncView<SettlementDetail>(
                value: detail,
                what: 'the settlement figures',
                keepWhileReloading: true,
                errorKey: const Key('settlement-error'),
                onRetry: () => ref.invalidate(settlementDetailProvider(widget.agreementId)),
                builder: (d) {
                  final s = d.settlement;
                  final info = settlementStatusInfo(s?.status);
                  final actions = _actions(d);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BuCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.eventTitle, key: const Key('settlement-event'), style: theme.textTheme.titleLarge),
                            if (d.eventStart != null) Text(DateFormat('EEE d MMM yyyy').format(d.eventStart!.toLocal()), style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text('${d.venueName} pays ${d.organizerName}', key: const Key('settlement-parties'), style: theme.textTheme.bodyMedium),
                            const SizedBox(height: BuSpace.m),
                            Row(
                              children: [
                                BuStatusPill(info.label, key: const Key('settlement-status'), tone: toneOf(info.tone)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(info.note, key: const Key('settlement-status-note'), style: theme.textTheme.bodySmall)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: BuSpace.m),
                      const BuSectionHeader(title: 'Agreed terms'),
                      const SizedBox(height: BuSpace.s),
                      BuCard(
                        child:
                            d.terms == null || !d.hasShare
                                ? Text('This agreement has no share of bar sales, so there is nothing to settle.', key: const Key('settlement-no-share'), style: theme.textTheme.bodyMedium)
                                : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _fact(theme, 'Organizer\'s share', d.terms!.summary, key: const Key('settlement-terms')),
                                    if (d.terms!.eligibleRevenue != null) _fact(theme, 'Eligible revenue', d.terms!.eligibleRevenue!),
                                    if (d.terms!.refunds != null) _fact(theme, 'Refunds', d.terms!.refunds!),
                                    if (d.terms!.taxesTipsFees != null) _fact(theme, 'Taxes, tips and fees', d.terms!.taxesTipsFees!),
                                    if (d.terms!.settlementTiming != null) _fact(theme, 'When it is settled', d.terms!.settlementTiming!),
                                    if (d.agreementVersion != null) _fact(theme, 'Agreement version', '${d.agreementVersion}${d.agreementEnded ? ' (the agreement has ended)' : ''}'),
                                  ],
                                ),
                      ),
                      if (s != null) ...[
                        const SizedBox(height: BuSpace.l),
                        const BuSectionHeader(title: 'Calculation'),
                        const SizedBox(height: BuSpace.s),
                        BuCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final line in calculationLines(d.terms, s)) _fact(theme, line.label, line.value, strong: line.strong, key: line.strong ? const Key('settlement-owed') : null),
                              const Divider(height: 24),
                              Text('Source: ${s.salesNote}', key: const Key('settlement-source'), style: theme.textTheme.bodySmall),
                              if (s.enteredByName != null) Text('Entered by ${s.enteredByName}, ${_when(s.enteredAt)}', style: theme.textTheme.bodySmall),
                              if (s.adjustmentNote != null && s.adjustmentCents != 0)
                                Text('Last adjustment: ${s.adjustmentNote}', key: const Key('settlement-adjustment-note'), style: theme.textTheme.bodySmall),
                              if (s.reviewedByName != null) Text('Reviewed by ${s.reviewedByName}, ${_when(s.reviewedAt)}', key: const Key('settlement-reviewed'), style: theme.textTheme.bodySmall),
                              if (s.approvedByName != null) Text('Approved by ${s.approvedByName}, ${_when(s.approvedAt)}', key: const Key('settlement-approved'), style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                      if (s != null && s.status == 'disputed')
                        Padding(
                          padding: const EdgeInsets.only(top: BuSpace.m),
                          child: BuCard(
                            accent: context.bu.red,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Question from the organizer', style: theme.textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(s.disputedReason ?? '', key: const Key('settlement-question-text'), style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                      if (s != null && s.isPaid)
                        Padding(
                          padding: const EdgeInsets.only(top: BuSpace.m),
                          child: BuCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.paymentLabel ?? 'Recorded external payment', key: const Key('settlement-payment-label'), style: theme.textTheme.titleSmall),
                                const SizedBox(height: 4),
                                _fact(theme, 'Paid by', d.venueName),
                                _fact(theme, 'Paid to', d.organizerName),
                                _fact(theme, 'Amount', settlementMoney(s.paidAmountCents ?? 0, currency: s.currency), key: const Key('settlement-paid-amount')),
                                if (s.paidOn != null) _fact(theme, 'Paid on', DateFormat('EEE d MMM yyyy').format(s.paidOn!), key: const Key('settlement-paid-on')),
                                _fact(theme, 'Reference', s.paymentReference ?? '', key: const Key('settlement-paid-reference')),
                                if (s.paymentEvidence != null) _fact(theme, 'Evidence', s.paymentEvidence!),
                                if (s.paidRecordedByName != null) _fact(theme, 'Recorded by', '${s.paidRecordedByName}, ${_when(s.paidRecordedAt)}', key: const Key('settlement-recorded-by')),
                                Text('Nothing was sent from BottlesUp: this records a payment made outside it.', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      if (s != null && s.acknowledgedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: BuSpace.s),
                          child: Text(
                            'Acknowledged by ${s.acknowledgedByName ?? 'the organizer'}, ${_when(s.acknowledgedAt)}',
                            key: const Key('settlement-acknowledged'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: BuSpace.l),
                        Wrap(spacing: 8, runSpacing: 8, key: const Key('settlement-actions'), children: actions),
                      ] else if (s != null)
                        Padding(
                          padding: const EdgeInsets.only(top: BuSpace.m),
                          child: Text(d.side == 'organizer' ? 'Nothing for you to do here.' : 'Nothing more to do here.', key: const Key('settlement-nothing'), style: theme.textTheme.bodySmall),
                        ),
                      if (d.log.isNotEmpty) ...[
                        const SizedBox(height: BuSpace.xl),
                        const BuSectionHeader(title: 'History'),
                        const SizedBox(height: BuSpace.s),
                        BuListCard(
                          children: [
                            for (var i = 0; i < d.log.length; i++)
                              BuListRow(
                                key: Key('settlement-log-$i'),
                                title: logLine(d.log[i], currency: s?.currency ?? 'cad'),
                                subtitle: '${d.log[i].byMe ? 'You' : d.log[i].byName} · ${_when(d.log[i].at)}${d.log[i].note == null ? '' : '\n${d.log[i].note}'}',
                                maxSubtitleLines: 4,
                                showChevron: false,
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
