import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/setup_forms.dart';
import '../../providers/owner_providers.dart';
import '../../services/venue_setup_service.dart';
import '../../widgets/setup_common.dart';

/// Add or edit one kind of table. Pops true once it is saved. Each problem is said before anything is sent; a refusal from the
/// database is shown here, in the form, so nothing typed is lost. Where the table sits on the floor plan, and its photo, are not
/// touched by an edit.
class TableTypeFormScreen extends ConsumerStatefulWidget {
  const TableTypeFormScreen({super.key, required this.venueId, this.row});

  final String venueId;

  /// The table being edited; null adds a new one.
  final TableTypeRow? row;

  @override
  ConsumerState<TableTypeFormScreen> createState() =>
      _TableTypeFormScreenState();
}

class _TableTypeFormScreenState extends ConsumerState<TableTypeFormScreen> {
  late final TableTypeForm _initial =
      widget.row == null
          ? const TableTypeForm()
          : tableTypeFormFrom(widget.row!);
  late final _name = TextEditingController(text: _initial.name);
  late final _description = TextEditingController(text: _initial.description);
  late final _max = TextEditingController(text: _initial.maxGuests);
  late final _min = TextEditingController(text: _initial.minGuests);
  late final _count = TextEditingController(text: _initial.inventoryCount);
  late final _spend = TextEditingController(text: _initial.minSpend);
  late final _deposit = TextEditingController(text: _initial.deposit);
  late final _rate = TextEditingController(text: _initial.hourlyRate);
  late final _hours = TextEditingController(text: _initial.minHours);
  late final _badge = TextEditingController(text: _initial.badgeLabel);
  late PricingMode _mode = _initial.pricingMode;
  late bool _featured = _initial.isFeatured;
  List<String> _problems = const [];
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _max,
      _min,
      _count,
      _spend,
      _deposit,
      _rate,
      _hours,
      _badge,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  TableTypeForm get _form => TableTypeForm(
    name: _name.text,
    description: _description.text,
    maxGuests: _max.text,
    minGuests: _min.text,
    inventoryCount: _count.text,
    minSpend: _spend.text,
    deposit: _deposit.text,
    pricingMode: _mode,
    hourlyRate: _rate.text,
    minHours: _hours.text,
    badgeLabel: _badge.text,
    isFeatured: _featured,
  );

  Future<void> _save() async {
    if (_saving) return;
    final problems = validateTableTypeForm(_form);
    setState(() => _problems = problems);
    if (problems.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(venueSetupServiceProvider)
          .saveTableType(
            widget.venueId,
            widget.row?.typeId,
            tableTypePayload(_form),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on SetupEditException catch (e) {
      if (mounted) {
        setState(() {
          _problems = [e.message];
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget field(
      Key key,
      TextEditingController c,
      String label, {
      String? hint,
      String? helper,
      TextInputType? type,
      int? maxLength,
      int lines = 1,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: c,
        keyboardType: type,
        maxLines: lines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          counterText: '',
        ),
      ),
    );
    const money = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.row == null ? 'Add a table' : 'Edit ${widget.row!.name}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(
            const Key('field-name'),
            _name,
            'Name',
            hint: 'VIP booth',
            maxLength: 120,
          ),
          field(
            const Key('field-description'),
            _description,
            'Description (optional)',
            maxLength: 2000,
            lines: 2,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: field(
                  const Key('field-max'),
                  _max,
                  'Maximum guests',
                  hint: '8',
                  type: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: field(
                  const Key('field-min'),
                  _min,
                  'Minimum guests',
                  helper: 'Optional',
                  type: TextInputType.number,
                ),
              ),
            ],
          ),
          field(
            const Key('field-count'),
            _count,
            'Number of tables',
            helper: 'How many of this kind you have. 0 stops bookings.',
            type: TextInputType.number,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: field(
                  const Key('field-spend'),
                  _spend,
                  'Minimum spend (\$)',
                  hint: '1500',
                  helper: 'Empty for none',
                  type: money,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: field(
                  const Key('field-deposit'),
                  _deposit,
                  'Deposit (\$)',
                  hint: '500',
                  helper: 'Empty for none',
                  type: money,
                ),
              ),
            ],
          ),
          Text('Pricing', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<PricingMode>(
            key: const Key('pricing-mode'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: PricingMode.flat,
                label: Text('One price for the night'),
              ),
              ButtonSegment(
                value: PricingMode.hourly,
                label: Text('By the hour'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          if (_mode == PricingMode.hourly)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(
                    const Key('field-rate'),
                    _rate,
                    'Hourly rate (\$)',
                    hint: '200',
                    type: money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(
                    const Key('field-hours'),
                    _hours,
                    'Minimum hours',
                    helper: 'Empty means 1',
                    type: TextInputType.number,
                  ),
                ),
              ],
            ),
          field(
            const Key('field-badge'),
            _badge,
            'Badge (optional)',
            helper: 'A short label such as "Popular" or "Best view".',
            maxLength: 40,
          ),
          SwitchListTile(
            key: const Key('switch-featured'),
            title: const Text('Feature this table'),
            value: _featured,
            onChanged: (v) => setState(() => _featured = v),
          ),
          const SizedBox(height: 8),
          ProblemsBox(problems: _problems),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save-table'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save table'),
          ),
          const SizedBox(height: 8),
          Text(
            'Photos, where a table sits on the floor plan, and its seating, view and amenities are set up on the website for now; editing here never changes them.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
