import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../owner/widgets/setup_common.dart' show ProblemsBox, say;
import '../logic/table_map_rules.dart';
import '../providers/table_map_providers.dart';

/// Who receives a table deposit and what it is for (club owner or manager; brief 15 Oct, section 15): the venue, the approved organizer, or a split, and a reservation fee,
/// a credit toward the minimum spend, or admission. It applies to bookings made from now on; every booking keeps the terms it was made under. Whether the deposit counts
/// toward the bottle bill is BottlesUp's switch and decides which purposes are possible, so the screen offers only those. What was chosen is kept when saving fails.
class DepositTermsScreen extends ConsumerStatefulWidget {
  const DepositTermsScreen({super.key, required this.venueId});

  final String venueId;

  @override
  ConsumerState<DepositTermsScreen> createState() => _DepositTermsScreenState();
}

class _DepositTermsScreenState extends ConsumerState<DepositTermsScreen> {
  DepositTermsForm? _form;
  late final TextEditingController _pct = TextEditingController();
  bool _busy = false;
  bool _seeded = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _pct.dispose();
    super.dispose();
  }

  DepositTermsForm _current(DepositSettings s) => _form ?? depositFormFrom(s.terms);

  void _update(DepositSettings s, {DepositRecipient? recipient, DepositPurpose? purpose}) {
    final f = _current(s);
    setState(() {
      _form = DepositTermsForm(recipient: recipient ?? f.recipient, venuePctText: _pct.text, purpose: purpose ?? f.purpose);
      _problems = const [];
    });
  }

  Future<void> _save(DepositSettings s) async {
    if (_busy) return;
    final f = DepositTermsForm(recipient: _current(s).recipient, venuePctText: _pct.text, purpose: _current(s).purpose);
    final found = validateDepositTerms(f, depositIsCredit: s.depositIsCredit);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(tableMapServiceProvider).saveDepositTerms(widget.venueId, f);
      if (!mounted) return;
      ref.invalidate(depositSettingsProvider(widget.venueId));
      // What is on screen is what was saved, so it stays as it is.
      setState(() => _busy = false);
      say(context, 'Saved. It applies to bookings made from now on; existing bookings keep the terms they were made under.');
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
    final settings = ref.watch(depositSettingsProvider(widget.venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Deposit terms')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final e = opsLoadFailureFor(error, 'the deposit terms');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.message, key: const Key('deposit-terms-error'), textAlign: TextAlign.center),
                  if (!e.unavailable && !e.accessEnded) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(key: const Key('deposit-terms-retry'), onPressed: () => ref.invalidate(depositSettingsProvider(widget.venueId)), child: const Text('Try again')),
                  ],
                ],
              ),
            ),
          );
        },
        data: (s) {
          final f = _current(s);
          // The percentage box shows what is saved until the person types.
          if (!_seeded) {
            _seeded = true;
            _pct.text = f.venuePctText;
          }
          final purposes = purposesFor(depositIsCredit: s.depositIsCredit);
          return ListView(
            key: const Key('deposit-terms'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            children: [
              Text(
                s.terms == null
                    ? 'You have not chosen yet. Until you do, the venue keeps the deposit${s.depositIsCredit ? ' as a credit toward the minimum spend' : ' as a reservation fee'}.'
                    : depositTermsLine(s.terms!),
                key: const Key('deposit-terms-now'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text('Applies to bookings made from now on. Bookings that exist keep the terms they were made under.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              Text('Who receives the deposit', style: theme.textTheme.titleMedium),
              RadioGroup<DepositRecipient>(
                groupValue: f.recipient,
                onChanged: (v) {
                  if (!_busy && v != null) _update(s, recipient: v);
                },
                child: Column(
                  children: [
                    for (final r in DepositRecipient.values)
                      RadioListTile<DepositRecipient>(key: Key('recipient-${r.db}'), value: r, contentPadding: EdgeInsets.zero, title: Text(r.label), subtitle: Text(r.explanation)),
                  ],
                ),
              ),
              if (f.recipient == DepositRecipient.split)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    key: const Key('deposit-venue-pct'),
                    controller: _pct,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _problems = const []),
                    decoration: InputDecoration(
                      labelText: 'The venue\'s share (%)',
                      helperText: () {
                        final n = int.tryParse(_pct.text.trim());
                        return n != null && n >= 1 && n <= 99 ? 'The organizer gets ${100 - n}%.' : 'Between 1 and 99. The organizer gets the rest.';
                      }(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text('What the deposit is for', style: theme.textTheme.titleMedium),
              RadioGroup<DepositPurpose>(
                groupValue: f.purpose,
                onChanged: (v) {
                  if (!_busy && v != null) _update(s, purpose: v);
                },
                child: Column(
                  children: [
                    for (final p in purposes)
                      RadioListTile<DepositPurpose>(key: Key('purpose-${p.db}'), value: p, contentPadding: EdgeInsets.zero, title: Text(p.label), subtitle: Text(p.explanation)),
                  ],
                ),
              ),
              Text(
                s.depositIsCredit
                    ? 'The deposit is credited toward the bottle bill at this venue, so it can only be a credit toward the minimum spend. The BottlesUp team can change that.'
                    : 'The deposit is not credited toward the bottle bill at this venue, so it is a reservation fee or admission. The BottlesUp team can switch the credit on.',
                key: const Key('deposit-credit-explained'),
                style: theme.textTheme.bodySmall,
              ),
              if (_problems.isNotEmpty) ...[const SizedBox(height: 12), ProblemsBox(problems: _problems)],
              const SizedBox(height: 16),
              FilledButton(key: const Key('deposit-terms-save'), onPressed: _busy ? null : () => _save(s), child: Text(_busy ? 'Saving...' : 'Save')),
            ],
          );
        },
      ),
    );
  }
}
