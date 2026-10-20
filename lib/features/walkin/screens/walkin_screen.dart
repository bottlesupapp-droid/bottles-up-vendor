import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../ops/services/ops_rpc.dart';
import '../../refunds/providers/refund_providers.dart';
import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../../table_service/screens/table_detail_screen.dart';
import '../logic/walkin_rules.dart';
import '../providers/walkin_providers.dart';

/// Add a walk-in (club manager or owner): pick the arrival time and a table that is really free, take the guest's name and email, read out the terms, confirm.
/// The booking is made in one step by the database, which counts what is left while it holds the table, so the last table cannot be given twice; if someone
/// else got it first the screen says so and shows what is left now. The deposit is DUE at the club: Confirm does not mark anything as paid, and the next step
/// is Record a payment on the table's page, where cash and card and their checking stay separate and visible. What was typed is kept when anything fails.
class WalkinScreen extends ConsumerStatefulWidget {
  const WalkinScreen({super.key, required this.venueId, required this.venueName, required this.night, this.openTable});

  final String venueId;
  final String? venueName;

  /// The business night this walk-in is for, 'YYYY-MM-DD'.
  final String night;

  /// Opens the booked table's page. Replaced in tests.
  final void Function(BuildContext context, String bookingId, String title)? openTable;

  @override
  ConsumerState<WalkinScreen> createState() => _WalkinScreenState();
}

class _WalkinScreenState extends ConsumerState<WalkinScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String? _slotId;
  String? _tableId;
  int _guests = 2;
  int _hours = 2;
  bool _terms = false;
  bool _busy = false;
  List<String> _problems = const [];
  WalkinResult? _result;
  String _resultTitle = '';

  WalkinQuery get _query => WalkinQuery(widget.venueId, widget.night);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  WalkinTable? _table(List<WalkinSlot> slots) {
    for (final s in slots) {
      if (s.id != _slotId) continue;
      for (final t in s.tables) {
        if (t.id == _tableId) return t;
      }
    }
    return null;
  }

  void _pickTable(WalkinTable t) {
    setState(() {
      _tableId = t.id;
      _problems = const [];
      _guests = _guests.clamp(t.minGuests ?? 1, t.maxGuests);
      if (t.hourly) _hours = (_hours < (t.minHours ?? 1)) ? (t.minHours ?? 1) : _hours;
      _terms = false;
    });
  }

  Future<void> _confirm(List<WalkinSlot> slots) async {
    final table = _table(slots);
    if (_busy || _result != null || table == null || _slotId == null) return;
    final found = validateWalkin(WalkinForm(name: _name.text, email: _email.text, phone: _phone.text, guests: _guests, hours: table.hourly ? _hours : null, terms: _terms), table);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(walkinServiceProvider).create(
            venueId: widget.venueId,
            night: widget.night,
            tableTypeId: table.id,
            slotId: _slotId!,
            guests: _guests,
            hours: table.hourly ? _hours : null,
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
          );
      if (!mounted) return;
      setState(() {
        _result = r;
        _resultTitle = '${table.name} · ${_name.text.trim()}';
        _busy = false;
      });
    } on OpsActionException catch (e) {
      if (!mounted) return;
      // Whatever went wrong, what is left now may be different: read it again, and keep what was typed.
      ref.invalidate(walkinOptionsProvider(_query));
      setState(() {
        _problems = [e.message];
        _busy = false;
        if (isSoldOutRefusal(e.message)) _terms = false;
      });
    }
  }

  void _openTable(WalkinResult r) {
    final open = widget.openTable;
    if (open != null) {
      open(context, r.bookingId, _resultTitle);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TableDetailScreen(bookingId: r.bookingId, title: _resultTitle)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Add walk-in')),
      body: SafeArea(child: result != null ? _done(context, result, theme) : _form(context, theme)),
    );
  }

  Widget _done(BuildContext context, WalkinResult r, ThemeData theme) => ListView(
        key: const Key('walkin-done'),
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF66BB6A)),
          const SizedBox(height: 8),
          Text('Booked', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          Text(_resultTitle, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: InkWell(
              onTap: () => Clipboard.setData(ClipboardData(text: r.code)),
              child: Text(r.code, key: const Key('walkin-code'), style: theme.textTheme.headlineMedium?.copyWith(fontFamily: 'monospace', letterSpacing: 2)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            r.dueCents > 0 ? 'Deposit due at the club: ${formatDollars(r.dueCents)}. Nothing is recorded as paid yet.' : 'Nothing is due.',
            key: const Key('walkin-due'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('The guest is seated and a confirmation e-mail is queued. ${r.tablesLeft == 0 ? 'No tables of this kind are left for that time.' : '${r.tablesLeft} of this kind left for that time.'}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          if (r.dueCents > 0)
            FilledButton.icon(key: const Key('walkin-record'), onPressed: () => _openTable(r), icon: const Icon(Icons.add_card_outlined), label: const Text('Record the deposit')),
          if (r.dueCents <= 0) FilledButton(key: const Key('walkin-open'), onPressed: () => _openTable(r), child: const Text('Open the table')),
          const SizedBox(height: 8),
          OutlinedButton(key: const Key('walkin-finish'), onPressed: () => Navigator.of(context).pop(true), child: const Text('Done')),
        ],
      );

  Widget _form(BuildContext context, ThemeData theme) {
    final options = ref.watch(walkinOptionsProvider(_query));
    return options.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final e = opsLoadFailureFor(error, 'the tables');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.message, key: const Key('walkin-error'), textAlign: TextAlign.center),
                if (!e.unavailable && !e.accessEnded) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(key: const Key('walkin-retry'), onPressed: () => ref.invalidate(walkinOptionsProvider(_query)), child: const Text('Try again')),
                ],
              ],
            ),
          ),
        );
      },
      data: (slots) {
        if (slots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('This club has no arrival times or tables set up for tonight, so there is nothing to book. Add them in the venue setup.', key: const Key('walkin-none'), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            ),
          );
        }
        final slot = slots.where((s) => s.id == _slotId).firstOrNull;
        final table = _table(slots);
        final deposit = table?.depositFor(table.hourly ? _hours : null);
        return ListView(
          key: const Key('walkin-form'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (widget.venueName != null) Text(widget.venueName!, style: theme.textTheme.titleMedium),
            Text('Walk-ins are booked for tonight. The table is taken as soon as you confirm.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Text('Arrival time', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in slots)
                  ChoiceChip(
                    key: Key('walkin-slot-${s.id}'),
                    label: Text(s.hasFreeTable ? slotLabel(s) : '${slotLabel(s)} · full'),
                    selected: s.id == _slotId,
                    onSelected: s.hasFreeTable && !_busy
                        ? (_) => setState(() {
                              _slotId = s.id;
                              _tableId = null;
                              _problems = const [];
                            })
                        : null,
                  ),
              ],
            ),
            if (slot != null) ...[
              const SizedBox(height: 16),
              Text('Table', style: theme.textTheme.titleSmall),
              for (final t in slot.tables)
                Card(
                  key: Key('walkin-table-${t.id}'),
                  color: t.id == _tableId ? theme.colorScheme.primary.withValues(alpha: 0.12) : null,
                  child: ListTile(
                    enabled: t.isFree && !_busy,
                    selected: t.id == _tableId,
                    title: Text(t.name),
                    subtitle: Text(tableLine(t)),
                    trailing: t.id == _tableId ? const Icon(Icons.check_circle) : null,
                    onTap: t.isFree && !_busy ? () => _pickTable(t) : null,
                  ),
                ),
            ],
            if (table != null) ...[
              const SizedBox(height: 16),
              Text('Guest', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(key: const Key('walkin-name'), controller: _name, enabled: !_busy, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(key: const Key('walkin-email'), controller: _email, enabled: !_busy, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email', helperText: 'The booking confirmation goes here.', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(key: const Key('walkin-phone'), controller: _phone, enabled: !_busy, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              _stepper('Guests', _guests, table.minGuests ?? 1, table.maxGuests, (v) => setState(() => _guests = v), 'walkin-guests'),
              if (table.hourly) _stepper('Hours', _hours, table.minHours ?? 1, 24, (v) => setState(() => _hours = v), 'walkin-hours'),
              const SizedBox(height: 16),
              Text('Terms', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final line in walkinTerms(table, table.hourly ? _hours : null)) Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text('• $line', style: theme.textTheme.bodyMedium)),
              ..._refundTerms(theme),
              CheckboxListTile(
                key: const Key('walkin-terms'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _terms,
                onChanged: _busy ? null : (v) => setState(() => _terms = v ?? false),
                title: const Text('The guest has been told these terms and agrees to them.'),
              ),
              if (_problems.isNotEmpty) ProblemsBox(problems: _problems),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('walkin-confirm'),
                onPressed: _busy ? null : () => _confirm(slots),
                child: Text(_busy ? 'Booking...' : (deposit != null && deposit > 0 ? 'Confirm walk-in · ${formatDollars(deposit)} due' : 'Confirm walk-in')),
              ),
            ] else if (_problems.isNotEmpty)
              ProblemsBox(problems: _problems),
          ],
        );
      },
    );
  }

  /// The club's refund policy, read out with the other terms. It is a bonus: when it cannot be read the terms are the same as before (the booking still carries the policy the
  /// club has, whichever way it is made).
  List<Widget> _refundTerms(ThemeData theme) {
    final policy = ref.watch(refundPolicyProvider(widget.venueId)).asData?.value;
    if (policy == null || policy.lines.isEmpty) return const [];
    return [
      Padding(padding: const EdgeInsets.only(top: 6), child: Text('Refunds', key: const Key('walkin-refund-title'), style: theme.textTheme.titleSmall)),
      for (final l in policy.lines) Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Text('• $l', key: const Key('walkin-refund-line'), style: theme.textTheme.bodyMedium)),
    ];
  }

  Widget _stepper(String label, int value, int min, int max, void Function(int) onChanged, String key) => Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(key: Key('$key-less'), onPressed: _busy || value <= min ? null : () => onChanged(value - 1), icon: const Icon(Icons.remove_circle_outline)),
          SizedBox(width: 32, child: Text('$value', key: Key('$key-value'), textAlign: TextAlign.center)),
          IconButton(key: Key('$key-more'), onPressed: _busy || value >= max ? null : () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline)),
        ],
      );
}
