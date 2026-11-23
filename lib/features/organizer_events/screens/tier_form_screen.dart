import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/utils/date_time_picker.dart';
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../logic/event_tickets_rules.dart';
import '../logic/organizer_events_rules.dart';
import '../providers/organizer_events_providers.dart';
import '../services/organizer_tiers_service.dart';

/// Add a ticket type, or change one. Pops true once it is saved. Each problem is said before anything is sent; a refusal from the database is
/// shown here, in the form, so nothing typed is lost. A type that has sold keeps its name and price (the boxes are switched off and say why).
class TierFormScreen extends ConsumerStatefulWidget {
  const TierFormScreen({
    super.key,
    required this.orgId,
    required this.event,
    this.tier,
    this.others = const [],
    this.pickDateTime = pickDateAndTime,
    this.clock = DateTime.now,
  });

  final String orgId;
  final OrgEvent event;

  /// The type being changed; null adds a new one.
  final OrgTier? tier;

  /// Every ticket type of the event (to refuse the same name twice and a 21st type).
  final List<OrgTier> others;
  final DateTimePicker pickDateTime;
  final DateTime Function() clock;

  @override
  ConsumerState<TierFormScreen> createState() => _TierFormScreenState();
}

class _TierFormScreenState extends ConsumerState<TierFormScreen> {
  late final TierForm _initial =
      widget.tier == null ? const TierForm() : tierFormFrom(widget.tier!);
  late final _name = TextEditingController(text: _initial.name);
  late final _price = TextEditingController(text: _initial.price);
  late final _capacity = TextEditingController(text: _initial.capacity);
  late DateTime? _starts = _initial.starts;
  late DateTime? _ends = _initial.ends;
  List<String> _problems = const [];
  bool _saving = false;

  bool get _locked => widget.tier?.hasSold ?? false;

  @override
  void dispose() {
    for (final c in [_name, _price, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  TierForm get _form => TierForm(
    name: _name.text,
    price: _price.text,
    capacity: _capacity.text,
    starts: _starts,
    ends: _ends,
  );

  Future<void> _pick(bool start) async {
    final now = widget.clock();
    final initial =
        (start ? _starts : _ends) ??
        (start ? now : (_starts ?? now).add(const Duration(days: 1)));
    final picked = await widget.pickDateTime(context, initial);
    if (picked == null || !mounted) return;
    setState(() => start ? _starts = picked : _ends = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await submitTierForm(
      _form,
      orgId: widget.orgId,
      event: widget.event,
      service: ref.read(organizerTiersServiceProvider),
      existing: widget.tier,
      others: widget.others,
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _problems = result.problems;
      _saving = false;
    });
  }

  String _when(DateTime? t, String empty) =>
      t == null
          ? empty
          : DateFormat('EEE, MMM d, y, h:mm a', 'en_US').format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.tier == null
              ? 'Add a ticket type'
              : 'Change ${widget.tier!.name}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'For ${widget.event.title}. Guests see it once the event is published.',
            style: theme.textTheme.bodySmall,
          ),
          if (_locked) ...[
            const SizedBox(height: 12),
            Text(
              'Tickets of this type have been sold, so its name and price cannot change. You can still raise the quantity or change when sales end. To sell at another price, add a new ticket type.',
              key: const Key('locked-note'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('field-tier-name'),
            controller: _name,
            enabled: !_locked,
            maxLength: TierLimits.name + 20,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'General admission',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('field-tier-price'),
            controller: _price,
            enabled: !_locked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (CAD)',
              hintText: '25.00. Use 0 for free',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('field-tier-capacity'),
            controller: _capacity,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity',
              hintText: '200',
              helperText:
                  widget.tier != null && widget.tier!.soldCount > 0
                      ? '${widget.tier!.soldCount} sold so far'
                      : null,
            ),
          ),
          const SizedBox(height: 16),
          Text('Sales start (optional)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pick-sale-start'),
                  onPressed: () => _pick(true),
                  child: Text(
                    _when(_starts, 'On sale as soon as it is published'),
                  ),
                ),
              ),
              if (_starts != null)
                IconButton(
                  key: const Key('clear-sale-start'),
                  tooltip: 'Remove the start',
                  icon: const Icon(Ionicons.close),
                  onPressed: () => setState(() => _starts = null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Sales end (optional)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pick-sale-end'),
                  onPressed: () => _pick(false),
                  child: Text(_when(_ends, 'On sale until the event ends')),
                ),
              ),
              if (_ends != null)
                IconButton(
                  key: const Key('clear-sale-end'),
                  tooltip: 'Remove the end',
                  icon: const Icon(Ionicons.close),
                  onPressed: () => setState(() => _ends = null),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Times are in your device's time zone (${DateTime.now().timeZoneName}). Sales close at the end time: nobody can buy from that moment.",
            key: const Key('zone-note'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ProblemsBox(problems: _problems),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save-tier'),
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Saving…'
                  : (widget.tier == null ? 'Add ticket type' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}
