import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/setup_forms.dart';
import '../../providers/owner_providers.dart';
import '../../services/venue_setup_service.dart';
import '../../widgets/photo_field.dart';
import '../../widgets/setup_common.dart';

/// Add or edit one bottle. Pops true once it is saved. Each problem is said before anything is sent; a refusal from the database
/// is shown here, in the form, so nothing typed is lost.
class BottleFormScreen extends ConsumerStatefulWidget {
  const BottleFormScreen({super.key, required this.venueId, required this.orgId, this.row});

  final String venueId;

  /// The business the venue belongs to: the photo is uploaded into its folder.
  final String orgId;

  /// The bottle being edited; null adds a new one.
  final BottleRow? row;

  @override
  ConsumerState<BottleFormScreen> createState() => _BottleFormScreenState();
}

class _BottleFormScreenState extends ConsumerState<BottleFormScreen> {
  late final BottleForm _initial =
      widget.row == null ? const BottleForm() : bottleFormFrom(widget.row!);
  late final _name = TextEditingController(text: _initial.name);
  late final _price = TextEditingController(text: _initial.price);
  late final _size = TextEditingController(text: _initial.size);
  late final _category = TextEditingController(text: _initial.category);
  late final _description = TextEditingController(text: _initial.description);
  late final _stock = TextEditingController(text: _initial.stock);
  late bool _available = _initial.isAvailable;
  late bool _soldOut = _initial.isSoldOut;
  late String _image = _initial.imageUrl;
  List<String> _problems = const [];
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_name, _price, _size, _category, _description, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  BottleForm get _form => BottleForm(
    name: _name.text,
    size: _size.text,
    category: _category.text,
    description: _description.text,
    price: _price.text,
    stock: _stock.text,
    imageUrl: _image,
    isAvailable: _available,
    isSoldOut: _soldOut,
  );

  Future<void> _save() async {
    if (_saving) return;
    final problems = validateBottleForm(_form);
    setState(() => _problems = problems);
    if (problems.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(venueSetupServiceProvider)
          .saveBottle(
            widget.venueId,
            widget.row?.bottleId,
            bottlePayload(_form),
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
    Widget field(
      Key key,
      TextEditingController c,
      String label, {
      String? hint,
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
          border: const OutlineInputBorder(),
          counterText: '',
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.row == null ? 'Add a bottle' : 'Edit ${widget.row!.name}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(
            const Key('field-name'),
            _name,
            'Name',
            hint: 'Grey Goose',
            maxLength: 120,
          ),
          field(
            const Key('field-price'),
            _price,
            'Price (\$)',
            hint: '195',
            type: const TextInputType.numberWithOptions(decimal: true),
          ),
          Row(
            children: [
              Expanded(
                child: field(
                  const Key('field-size'),
                  _size,
                  'Size (optional)',
                  hint: '750ml',
                  maxLength: 40,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: field(
                  const Key('field-category'),
                  _category,
                  'Category (optional)',
                  hint: 'Vodka',
                  maxLength: 40,
                ),
              ),
            ],
          ),
          field(
            const Key('field-description'),
            _description,
            'Description (optional)',
            maxLength: 1000,
            lines: 2,
          ),
          field(
            const Key('field-stock'),
            _stock,
            'Stock (optional)',
            type: TextInputType.number,
          ),
          Text(
            'Leave stock empty if you do not count bottles. Guests cannot order more than you have.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          PhotoField(
            key: const Key('bottle-photo'),
            orgId: widget.orgId,
            label: 'Photo (optional)',
            value: _image,
            hint: 'Guests see it on the menu. JPEG, PNG or WebP, up to 5 MB.',
            onChanged: (url) => setState(() => _image = url),
            onBusyChanged: (busy) => setState(() => _uploading = busy),
          ),
          SwitchListTile(
            key: const Key('switch-available'),
            title: const Text('On the menu'),
            value: _available,
            onChanged: (v) => setState(() => _available = v),
          ),
          SwitchListTile(
            key: const Key('switch-soldout'),
            title: const Text('Sold out'),
            value: _soldOut,
            onChanged: (v) => setState(() => _soldOut = v),
          ),
          const SizedBox(height: 8),
          ProblemsBox(problems: _problems),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('save-bottle'),
            onPressed: _saving || _uploading ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save bottle'),
          ),
        ],
      ),
    );
  }
}
