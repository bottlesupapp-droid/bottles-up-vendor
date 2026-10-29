import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/widgets/setup_common.dart' show ProblemsBox, say;
import '../logic/refund_rules.dart';
import '../providers/refund_providers.dart';

class _Rule {
  _Rule(String hours, String percent)
      : hours = TextEditingController(text: hours),
        percent = TextEditingController(text: percent);

  final TextEditingController hours;
  final TextEditingController percent;

  void dispose() {
    hours.dispose();
    percent.dispose();
  }
}

/// The venue's refund policy (owner or manager; brief 15 Oct, sections 26 and 31): up to six rules "cancel at least this many hours before arrival: this percent of the deposit back",
/// whether there is no refund once the guests have arrived, and a short note. Guests read it before they pay and the BottlesUp team can see every venue's. A booking keeps the policy it was
/// made under, so changing it affects bookings made from now on. The sentences a guest will read are shown as the rules are edited. What was typed is kept when saving fails.
class RefundPolicyScreen extends ConsumerStatefulWidget {
  const RefundPolicyScreen({super.key, required this.venueId});

  final String venueId;

  @override
  ConsumerState<RefundPolicyScreen> createState() => _RefundPolicyScreenState();
}

class _RefundPolicyScreenState extends ConsumerState<RefundPolicyScreen> {
  final List<_Rule> _rules = [];
  final _note = TextEditingController();
  bool _noRefundAfterCheckIn = true;
  bool _seeded = false;
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    for (final r in _rules) {
      r.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  void _seed(RefundPolicy saved) {
    if (_seeded) return;
    _seeded = true;
    final f = policyFormFrom(saved);
    _rules.addAll([for (final t in f.tiers) _Rule(t.hours, t.percent)]);
    _noRefundAfterCheckIn = f.noRefundAfterCheckIn;
    _note.text = f.note;
  }

  RefundPolicyForm get _form => RefundPolicyForm(
        tiers: [for (final r in _rules) TierForm(hours: r.hours.text, percent: r.percent.text)],
        noRefundAfterCheckIn: _noRefundAfterCheckIn,
        note: _note.text,
      );

  void _changed() => setState(() => _problems = const []);

  void _add() {
    if (_rules.length >= maxRefundRules || _busy) return;
    setState(() {
      _rules.add(_Rule('', ''));
      _problems = const [];
    });
  }

  void _remove(int i) {
    if (_busy) return;
    setState(() {
      _rules.removeAt(i).dispose();
      _problems = const [];
    });
  }

  Future<void> _save(RefundPolicy saved) async {
    if (_busy) return;
    final found = validatePolicy(_form);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(refundServiceProvider).savePolicy(widget.venueId, _form);
      if (!mounted) return;
      ref.invalidate(refundPolicyProvider(widget.venueId));
      setState(() => _busy = false);
      say(context, 'Saved. Bookings made from now on carry this policy; bookings that exist keep the one they were made under.');
    } on OpsActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _problems = [e.message];
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policy = ref.watch(refundPolicyProvider(widget.venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Refund policy')),
      body: policy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final e = opsLoadFailureFor(error, 'the refund policy');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.message, key: const Key('policy-error'), textAlign: TextAlign.center),
                  if (!e.unavailable && !e.accessEnded) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(key: const Key('policy-retry'), onPressed: () => ref.invalidate(refundPolicyProvider(widget.venueId)), child: const Text('Try again')),
                  ],
                ],
              ),
            ),
          );
        },
        data: (saved) {
          _seed(saved);
          final preview = previewLines(_form);
          return ListView(
            key: const Key('refund-policy'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            children: [
              Text(
                saved.hasPolicy
                    ? 'Guests read this before they pay, and the BottlesUp team can see it. Bookings keep the policy they were made under.'
                    : 'You have not set a refund policy yet, so refunds are decided case by case. The two rules below are a starting point: change them, then save.',
                key: const Key('policy-intro'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text('Rules', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('The more notice a guest gives, the more they get back. A guest who cancels later than every rule gets nothing.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              if (_rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No rules: the deposit is not refundable.', key: const Key('policy-no-rules'), style: theme.textTheme.bodyMedium),
                ),
              for (var i = 0; i < _rules.length; i++)
                Padding(
                  key: ObjectKey(_rules[i]),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: Key('rule-$i-hours'),
                          controller: _rules[i].hours,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _changed(),
                          decoration: const InputDecoration(labelText: 'Hours before arrival', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: Key('rule-$i-percent'),
                          controller: _rules[i].percent,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _changed(),
                          decoration: const InputDecoration(labelText: 'Percent back', border: OutlineInputBorder()),
                        ),
                      ),
                      IconButton(key: Key('rule-$i-remove'), tooltip: 'Remove this rule', onPressed: _busy ? null : () => _remove(i), icon: const Icon(Icons.remove_circle_outline)),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(key: const Key('rule-add'), onPressed: _busy || _rules.length >= maxRefundRules ? null : _add, icon: const Icon(Icons.add, size: 18), label: const Text('Add a rule')),
                  if (_rules.isNotEmpty)
                    TextButton(
                      key: const Key('rule-clear'),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                for (final r in _rules) {
                                  r.dispose();
                                }
                                _rules.clear();
                                _problems = const [];
                              }),
                      child: const Text('Deposit is not refundable'),
                    ),
                ],
              ),
              if (_rules.length >= maxRefundRules) Text('A policy can have $maxRefundRules rules at most.', key: const Key('rule-limit'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('policy-after-arrival'),
                contentPadding: EdgeInsets.zero,
                title: const Text('No refund once the guests have arrived'),
                value: _noRefundAfterCheckIn,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _noRefundAfterCheckIn = v;
                          _problems = const [];
                        }),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('policy-note'),
                controller: _note,
                enabled: !_busy,
                maxLines: 2,
                maxLength: maxPolicyNote,
                onChanged: (_) => _changed(),
                decoration: const InputDecoration(labelText: 'A note for guests (optional)', border: OutlineInputBorder(), counterText: ''),
              ),
              const SizedBox(height: 16),
              Text('What guests will read', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              if (preview.isEmpty)
                Text('Fix the problems above to see it.', key: const Key('policy-preview-none'), style: theme.textTheme.bodySmall)
              else
                Column(
                  key: const Key('policy-preview'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final l in preview) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $l'))],
                ),
              if (_problems.isNotEmpty) ...[const SizedBox(height: 12), ProblemsBox(problems: _problems)],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('policy-save'),
                onPressed: _busy || !policyChanged(saved, _form) ? null : () => _save(saved),
                child: Text(_busy ? 'Saving...' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
