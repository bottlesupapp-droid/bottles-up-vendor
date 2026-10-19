import 'package:flutter/material.dart';

import '../logic/agreement_rules.dart';

/// What the terms form returns: the terms to propose and an optional note for the other side.
class TermsProposal {
  const TermsProposal(this.terms, this.note);

  final Map<String, dynamic> terms;
  final String? note;
}

/// Terms for an agreement: a form with every term the brief lists. A share of bar sales must say its threshold, how it is worked out
/// ("above" and "all once reached" are different amounts), and how refunds and taxes, tips and fees are treated; the sample below the form
/// shows what the share would come to, before anyone accepts. Starts from [initial] when changing an existing version.
class TermsFormScreen extends StatefulWidget {
  const TermsFormScreen({super.key, this.initial = const {}, this.title = 'Propose terms'});

  final Map<String, dynamic> initial;
  final String title;

  @override
  State<TermsFormScreen> createState() => _TermsFormScreenState();
}

class _TermsFormScreenState extends State<TermsFormScreen> {
  late final Map<String, TextEditingController> _c = {
    for (final s in termSpecs)
      if (s.kind != TermKind.choice) s.key: TextEditingController(text: _initialText(s)),
  };
  late String? _ownership = widget.initial['ticket_ownership']?.toString();
  late String? _formula = widget.initial['formula']?.toString();
  final _note = TextEditingController();
  final _sample = TextEditingController(text: '10000');
  String? _problem;

  String _initialText(TermSpec s) {
    final v = widget.initial[s.key];
    if (v == null) return '';
    if (s.kind == TermKind.money) return ((v as num) / 100).toStringAsFixed(2);
    if (s.kind == TermKind.percent) return termValueLabel(s.key, v).replaceAll('%', '');
    return '$v';
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _note.dispose();
    _sample.dispose();
    super.dispose();
  }

  Map<String, String> _typed() => {
        for (final e in _c.entries) e.key: e.value.text,
        if (_ownership != null) 'ticket_ownership': _ownership!,
        if (_formula != null) 'formula': _formula!,
      };

  void _send() {
    final built = buildTerms(_typed());
    if (built.error != null) {
      setState(() => _problem = built.error);
      return;
    }
    final note = _note.text.trim();
    if (note.length > 500) {
      setState(() => _problem = 'Keep the note to 500 characters or fewer.');
      return;
    }
    Navigator.of(context).pop(TermsProposal(built.terms!, note.isEmpty ? null : note));
  }

  Widget _field(TermSpec s) {
    final theme = Theme.of(context);
    if (s.key == 'ticket_ownership') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.label, style: theme.textTheme.labelLarge),
          Wrap(
            spacing: 8,
            children: [for (final e in ticketOwnershipLabels.entries) ChoiceChip(key: Key('term-ownership-${e.key}'), label: Text(e.value), selected: _ownership == e.key, onSelected: (sel) => setState(() => _ownership = sel ? e.key : null))],
          ),
        ],
      );
    }
    if (s.key == 'formula') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.label, style: theme.textTheme.labelLarge),
          for (final e in formulaLabels.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ChoiceChip(
                  key: Key('term-formula-${e.key}'),
                  label: Text(e.value),
                  selected: _formula == e.key,
                  onSelected: (sel) => setState(() {
                    _formula = sel ? e.key : null;
                    _problem = null;
                  }),
                ),
              ),
            ),
        ],
      );
    }
    return TextField(
      key: Key('term-${s.key}'),
      controller: _c[s.key],
      minLines: 1,
      maxLines: s.kind == TermKind.longText ? 4 : 2,
      keyboardType: switch (s.kind) { TermKind.count => TextInputType.number, TermKind.percent || TermKind.money => const TextInputType.numberWithOptions(decimal: true), _ => TextInputType.text },
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: s.label, hintText: s.hint, prefixText: s.kind == TermKind.money ? r'$ ' : null),
      onChanged: (_) => setState(() => _problem = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final built = buildTerms(_typed());
    final cents = parseMoneyToCents(_sample.text);
    final sample = built.terms == null || cents == null ? null : sampleSentence(built.terms!, cents);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          key: const Key('terms-form'),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Fill in what you want to propose. The other side reads it, discusses it, and accepts or proposes a change. Nothing is agreed until both sides have accepted the same version.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            for (final s in termSpecs) Padding(padding: const EdgeInsets.only(bottom: 10), child: _field(s)),
            const Divider(height: 24),
            Text('Sample calculation', style: theme.textTheme.titleSmall),
            TextField(key: const Key('sample-sales'), controller: _sample, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'If bar sales were', prefixText: r'$ '), onChanged: (_) => setState(() {})),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(sample ?? 'Add a share of bar sales to see a sample.', key: const Key('sample-result'), style: theme.textTheme.bodyMedium),
            ),
            TextField(key: const Key('terms-note'), controller: _note, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'A note for the other side (optional)')),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('terms-problem'), style: TextStyle(color: theme.colorScheme.error))),
            const SizedBox(height: 12),
            FilledButton(key: const Key('terms-send'), onPressed: _send, child: const Text('Send proposal')),
            const SizedBox(height: 4),
            Text('Sample amounts are only an illustration.', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
