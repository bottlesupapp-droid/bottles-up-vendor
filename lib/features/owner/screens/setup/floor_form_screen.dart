import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/venue_profile_rules.dart';
import '../../providers/owner_providers.dart';
import '../../services/venue_setup_service.dart';
import '../../widgets/photo_field.dart';
import '../../widgets/setup_common.dart';

/// Add or change one floor: a name and its floor plan picture. Pops true once it is saved. Each problem is said before anything is
/// sent; a refusal from the database is shown here, in the form, so nothing typed is lost. Where each table sits on the floor is
/// set from the floor list (Place tables).
class FloorFormScreen extends ConsumerStatefulWidget {
  const FloorFormScreen({super.key, required this.venueId, required this.orgId, this.floor});

  final String venueId;
  final String orgId;

  /// The floor being changed; null adds a new one.
  final FloorRow? floor;

  @override
  ConsumerState<FloorFormScreen> createState() => _FloorFormScreenState();
}

class _FloorFormScreenState extends ConsumerState<FloorFormScreen> {
  late final _label = TextEditingController(text: widget.floor?.label ?? '');
  late String _image = widget.floor?.imageUrl ?? '';
  List<String> _problems = const [];
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final problems = validateFloorForm(_label.text, _image);
    setState(() => _problems = problems);
    if (problems.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(venueSetupServiceProvider).saveFloor(widget.venueId, widget.floor?.floorId, _label.text, _image);
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.floor == null ? 'Add a floor' : 'Edit ${widget.floor!.label}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('field-label'),
            controller: _label,
            maxLength: ProfileLimits.floorLabel + 20,
            decoration: const InputDecoration(labelText: 'Floor name', hintText: 'Main room', border: OutlineInputBorder(), counterText: ''),
          ),
          const SizedBox(height: 16),
          PhotoField(
            key: const Key('floor-photo'),
            orgId: widget.orgId,
            label: 'Floor plan image',
            value: _image,
            wide: true,
            required: true,
            hint: 'A top-down picture or drawing of the room. JPEG, PNG or WebP, up to 5 MB.',
            onChanged: (url) => setState(() => _image = url),
            onBusyChanged: (busy) => setState(() => _uploading = busy),
          ),
          const SizedBox(height: 16),
          ProblemsBox(problems: _problems),
          const SizedBox(height: 12),
          FilledButton(key: const Key('save-floor'), onPressed: _saving || _uploading ? null : _save, child: Text(_saving ? 'Saving…' : 'Save floor')),
        ],
      ),
    );
  }
}
