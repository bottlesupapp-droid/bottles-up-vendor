import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/sales_source_rules.dart';
import '../providers/sales_source_providers.dart';

/// Sending the club's closing report for a night: the period, the gross, discounts and refunds, and whether the figures include what BottlesUp recorded. Nothing is sent until every part is said.
class ClosingReportFormScreen extends ConsumerStatefulWidget {
  const ClosingReportFormScreen({super.key, required this.venueId, this.venueName, this.clock = DateTime.now, this.pickTime});

  final String venueId;
  final String? venueName;
  final DateTime Function() clock;

  /// Replaced in tests: asks for a time of day.
  final Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initial)? pickTime;

  @override
  ConsumerState<ClosingReportFormScreen> createState() => _ClosingReportFormScreenState();
}

class _ClosingReportFormScreenState extends ConsumerState<ClosingReportFormScreen> {
  late ClosingReportForm _form = ClosingReportForm(night: DateFormat('yyyy-MM-dd').format(widget.clock().subtract(const Duration(days: 1))));
  final _gross = TextEditingController();
  final _discount = TextEditingController();
  final _refund = TextEditingController();
  final _note = TextEditingController();
  bool _tried = false;
  bool _sending = false;
  String? _failure;

  @override
  void dispose() {
    _gross.dispose();
    _discount.dispose();
    _refund.dispose();
    _note.dispose();
    super.dispose();
  }

  void _update(ClosingReportForm f) => setState(() => _form = f);

  Future<void> _pickNight() async {
    final today = widget.clock();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_form.night) ?? today,
      firstDate: today.subtract(const Duration(days: 90)),
      lastDate: today,
    );
    if (picked != null) _update(_form.copy(night: DateFormat('yyyy-MM-dd').format(picked)));
  }

  Future<void> _pickTime({required bool start}) async {
    final minutes = start ? _form.startMinutes : _form.endMinutes;
    final initial = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final picked = await (widget.pickTime?.call(context, initial) ?? showTimePicker(context: context, initialTime: initial));
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    _update(start ? _form.copy(startMinutes: m) : _form.copy(endMinutes: m));
  }

  String _timeText(int minutes) => DateFormat('h:mm a').format(DateTime(2026, 1, 1, minutes ~/ 60, minutes % 60));

  Future<void> _send() async {
    setState(() => _tried = true);
    if (_form.problem(now: widget.clock()) != null) return;
    setState(() {
      _sending = true;
      _failure = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(salesSourceServiceProvider).send(widget.venueId, _form);
      ref.invalidate(closingReportsProvider(widget.venueId));
      messenger.showSnackBar(const SnackBar(content: Text('Closing report sent. Someone else will check it.')));
      navigator.pop();
    } on OpsActionException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = _tried ? _form.problem(now: widget.clock()) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Send a closing report')),
      body: ListView(
        key: const Key('closing-report-form'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (widget.venueName != null) Text(widget.venueName!, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('The club\'s own figures for one night. They are shown as Venue-reported sales, beside what BottlesUp recorded, and never added to it.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          ListTile(
            key: const Key('closing-night'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Night'),
            subtitle: Text(nightText(_form.night)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickNight,
          ),
          Row(
            children: [
              Expanded(
                child: ListTile(key: const Key('closing-start'), contentPadding: EdgeInsets.zero, title: const Text('From'), subtitle: Text(_timeText(_form.startMinutes)), onTap: () => _pickTime(start: true)),
              ),
              Expanded(
                child: ListTile(key: const Key('closing-end'), contentPadding: EdgeInsets.zero, title: const Text('To'), subtitle: Text(_timeText(_form.endMinutes)), onTap: () => _pickTime(start: false)),
              ),
            ],
          ),
          TextField(key: const Key('closing-gross'), controller: _gross, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Gross sales', prefixText: '\$ '), onChanged: (v) => _update(_form.copy(grossText: v))),
          TextField(key: const Key('closing-discount'), controller: _discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Discounts (optional)', prefixText: '\$ '), onChanged: (v) => _update(_form.copy(discountText: v))),
          TextField(key: const Key('closing-refund'), controller: _refund, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Refunds (optional)', prefixText: '\$ '), onChanged: (v) => _update(_form.copy(refundText: v))),
          const SizedBox(height: 12),
          Text('Do these figures include what BottlesUp recorded?', style: theme.textTheme.titleSmall),
          RadioGroup<bool>(
            groupValue: _form.includesBottlesUp,
            onChanged: (v) => _update(_form.copy(includesBottlesUp: v)),
            child: const Column(
              children: [
                RadioListTile<bool>(key: Key('closing-includes-yes'), value: true, contentPadding: EdgeInsets.zero, title: Text('Yes: the till also took the table and bottle sales BottlesUp recorded'), subtitle: Text('BottlesUp\'s part is taken off, so it is not counted twice.')),
                RadioListTile<bool>(key: Key('closing-includes-no'), value: false, contentPadding: EdgeInsets.zero, title: Text('No: bar and other sales only')),
              ],
            ),
          ),
          TextField(key: const Key('closing-note'), controller: _note, maxLines: 3, maxLength: 300, decoration: const InputDecoration(labelText: 'Note (optional)'), onChanged: (v) => _update(_form.copy(note: v))),
          if (problem != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(problem, key: const Key('closing-problem'), style: TextStyle(color: theme.colorScheme.error))),
          if (_failure != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_failure!, key: const Key('closing-failure'), style: TextStyle(color: theme.colorScheme.error))),
          const SizedBox(height: 12),
          FilledButton(key: const Key('closing-send'), onPressed: _sending ? null : _send, child: Text(_sending ? 'Sending…' : 'Send the report')),
        ],
      ),
    );
  }
}
