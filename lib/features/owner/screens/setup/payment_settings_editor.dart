import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/payment_rules.dart';
import '../../providers/owner_providers.dart';
import '../../services/venue_setup_service.dart';
import '../../../table_map/logic/table_map_rules.dart' show depositTermsLine;
import '../../../table_map/providers/table_map_providers.dart';
import '../../../table_map/screens/deposit_terms_screen.dart';
import '../../widgets/setup_common.dart';

/// Payment settings (owner or manager of the venue; brief 15 Oct, section 15). Bottle payments can be changed (it applies to bookings made from
/// now on; existing bookings keep the way they were made). Deposits are shown per table with the way to change them (the tables editor); whether the
/// deposit counts toward the bottle bill is shown and explained but not changeable here. Payouts say plainly that they are not available yet.
class PaymentSettingsEditor extends ConsumerStatefulWidget {
  const PaymentSettingsEditor({super.key, required this.venueId, required this.orgId, this.onEditTables});

  final String venueId;
  final String orgId;

  /// Opens the tables editor (where the deposit of each table is set). Null hides the link.
  final VoidCallback? onEditTables;

  @override
  ConsumerState<PaymentSettingsEditor> createState() => _PaymentSettingsEditorState();
}

class _PaymentSettingsEditorState extends ConsumerState<PaymentSettingsEditor> {
  /// What the person has chosen but not saved. Kept if saving fails, so nothing typed or picked is lost.
  BottlePaymentMode? _picked;
  bool _busy = false;
  String? _problem;

  Future<void> _save(PaymentRules saved) async {
    final mode = _picked;
    if (mode == null || _busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await ref.read(venueSetupServiceProvider).savePaymentRules(widget.venueId, mode);
      if (!mounted) return;
      refreshAfterChange(ref, widget.venueId, () => ref.invalidate(paymentRulesProvider(widget.venueId)));
      setState(() => _picked = null);
      say(context, 'Saved: ${mode.label}. It applies to bookings made from now on; existing bookings keep how they were made.');
    } on SetupEditException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Who receives the deposit and what it is for: the line that says so now, and the way to change it.
  Widget _depositTerms(ThemeData theme) {
    final terms = ref.watch(depositSettingsProvider(widget.venueId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        terms.when(
          loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          error: (_, __) => Text('We could not load who receives the deposit.', key: const Key('deposit-terms-load-failed'), style: theme.textTheme.bodySmall),
          data: (s) => Text(s.terms == null ? 'Who receives the deposit: not chosen yet (the venue keeps it).' : depositTermsLine(s.terms!), key: const Key('deposit-terms-line')),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('deposit-terms-open'),
            onPressed: () async {
              await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => DepositTermsScreen(venueId: widget.venueId)));
              if (mounted) ref.invalidate(depositSettingsProvider(widget.venueId));
            },
            child: const Text('Who receives the deposit, and what it is for'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = ref.watch(paymentRulesProvider(widget.venueId));
    final tables = ref.watch(tableTypesProvider(widget.venueId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payment settings')),
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EditorLoadError(error: e, onRetry: () => ref.invalidate(paymentRulesProvider(widget.venueId))),
        data: (saved) {
          final selected = _picked ?? saved.mode;
          return ListView(
            key: const Key('payment-settings'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            children: [
              Text('Bottles', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('How guests pay for bottles when they book. Changing it applies to bookings made from now on; existing bookings keep how they were made.', style: theme.textTheme.bodySmall),
              RadioGroup<BottlePaymentMode>(
                groupValue: selected,
                onChanged: (v) {
                  if (_busy) return;
                  setState(() {
                    _picked = v;
                    _problem = null;
                  });
                },
                child: Column(
                  children: [
                    for (final m in BottlePaymentMode.values)
                      RadioListTile<BottlePaymentMode>(
                        key: Key('mode-${m.db}'),
                        value: m,
                        contentPadding: EdgeInsets.zero,
                        title: Text(m.label),
                        subtitle: Text(m.explanation),
                      ),
                  ],
                ),
              ),
              if (saved.mode == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('This venue has a setting this app does not recognise. Choose one of the three to replace it.', key: const Key('mode-unknown'), style: theme.textTheme.bodySmall),
                ),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_problem!, key: const Key('payment-problem'), style: TextStyle(color: theme.colorScheme.error)),
                ),
              FilledButton(
                key: const Key('payment-save'),
                onPressed: _busy || !paymentChanged(saved, _picked) ? null : () => _save(saved),
                child: Text(_busy ? 'Saving...' : 'Save'),
              ),
              const SizedBox(height: 24),
              Text('Deposits', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Each table has its own deposit, or none. A required deposit is paid online when the guest books.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              tables.when(
                loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
                error: (_, __) => Text('We could not load the tables. Open the tables editor to see their deposits.', key: const Key('deposit-load-failed'), style: theme.textTheme.bodySmall),
                data: (list) => list.isEmpty
                    ? Text('No tables yet. Add table types, with their deposit, in the tables editor.', key: const Key('deposit-none'), style: theme.textTheme.bodyMedium)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final t in list) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(depositLine(t), key: Key('deposit-${t.typeId}')))],
                      ),
              ),
              if (widget.onEditTables != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(key: const Key('deposit-edit-tables'), onPressed: widget.onEditTables, child: const Text('Edit tables and deposits')),
                ),
              const SizedBox(height: 8),
              _depositTerms(theme),
              const SizedBox(height: 8),
              Text(depositCreditLabel(saved.depositIsCredit), key: const Key('deposit-credit')),
              const SizedBox(height: 4),
              Text(depositCreditNote, key: const Key('deposit-credit-note'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              Text('Paying at the venue', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(atVenueNote, style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              Text('Payouts', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(payoutNote, key: const Key('payout-note'), style: theme.textTheme.bodySmall),
            ],
          );
        },
      ),
    );
  }
}
