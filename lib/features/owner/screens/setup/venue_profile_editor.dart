import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/venue_profile_rules.dart';
import '../../providers/owner_providers.dart';
import '../../services/owner_service.dart' show OwnerLoadException;
import '../../services/venue_setup_service.dart';
import '../../widgets/photo_field.dart';
import '../../widgets/setup_common.dart';

/// Venue profile (owner and manager): the name, description, address and cover photo guests see. The database lets only the venue's
/// owner or manager do this, and changes only the fields sent: never the venue's status or slug (the BottlesUp team takes a venue
/// live), and not its gallery.
class VenueProfileEditor extends ConsumerWidget {
  const VenueProfileEditor({super.key, required this.venueId, required this.orgId});

  final String venueId;
  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(venueProfileProvider(venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Venue profile')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EditorLoadError(error: e is OwnerLoadException ? e : const OwnerLoadException(unavailable: false, accessEnded: false), onRetry: () => ref.invalidate(venueProfileProvider(venueId))),
        data: (p) => _ProfileForm(venueId: venueId, orgId: orgId, profile: p),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.venueId, required this.orgId, required this.profile});

  final String venueId;
  final String orgId;
  final VenueProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final ProfileForm _initial = profileFormFrom(widget.profile);
  late final _name = TextEditingController(text: _initial.name);
  late final _description = TextEditingController(text: _initial.description);
  late final _address = TextEditingController(text: _initial.address);
  late String _cover = _initial.coverImageUrl;
  List<String> _problems = const [];
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  ProfileForm get _form => ProfileForm(name: _name.text, description: _description.text, address: _address.text, coverImageUrl: _cover);

  Future<void> _save() async {
    if (_saving) return;
    final problems = validateProfileForm(_form);
    setState(() => _problems = problems);
    if (problems.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(venueSetupServiceProvider).saveProfile(widget.venueId, profilePayload(_form));
      if (!mounted) return;
      ref.invalidate(ownerVenuesProvider(widget.orgId));
      ref.invalidate(venueSetupProvider(widget.venueId));
      say(context, 'Venue profile saved.');
      Navigator.of(context).pop(true);
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(key: const Key('field-name'), controller: _name, maxLength: 140, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), counterText: '')),
        const SizedBox(height: 12),
        TextField(
          key: const Key('field-description'),
          controller: _description,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Description (optional)', alignLabelWithHint: true, border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(key: const Key('field-address'), controller: _address, decoration: const InputDecoration(labelText: 'Address (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        PhotoField(
          key: const Key('cover-photo'),
          orgId: widget.orgId,
          label: 'Cover photo (optional)',
          value: _cover,
          wide: true,
          hint: 'JPEG, PNG or WebP, up to 5 MB.',
          onChanged: (url) => setState(() => _cover = url),
          onBusyChanged: (busy) => setState(() => _uploading = busy),
        ),
        const SizedBox(height: 16),
        ProblemsBox(problems: _problems),
        const SizedBox(height: 12),
        FilledButton(key: const Key('save-profile'), onPressed: _saving || _uploading ? null : _save, child: Text(_saving ? 'Saving…' : 'Save venue profile')),
        const SizedBox(height: 8),
        Text('Taking a venue live, and its booking address, are done by the BottlesUp team. The gallery is added on the website for now.', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
