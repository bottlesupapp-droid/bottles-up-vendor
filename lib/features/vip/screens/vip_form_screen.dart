import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/logic/chat_rules.dart' show ChatPerson;
import '../../chat/providers/chat_providers.dart' show chatPeopleProvider;
import '../../ops/services/ops_rpc.dart';
import '../logic/vip_rules.dart';
import '../providers/vip_providers.dart';
import '../widgets/vip_date_field.dart';

/// Add a VIP guest, or change one. If it cannot be saved, everything typed stays on the screen.
class VipFormScreen extends ConsumerStatefulWidget {
  const VipFormScreen({super.key, required this.venueId, this.existing});

  final String venueId;
  final VipProfile? existing;

  @override
  ConsumerState<VipFormScreen> createState() => _VipFormScreenState();
}

class _VipFormScreenState extends ConsumerState<VipFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _tier = TextEditingController(text: widget.existing?.tier ?? 'VIP');
  late final _prefs = TextEditingController(text: widget.existing?.preferences);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late DateTime? _from = widget.existing?.validFrom ?? DateTime.now();
  late DateTime? _until = widget.existing?.validUntil;
  late String? _host = widget.existing?.hostId;
  String? _problem;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _tier, _prefs, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final problem = checkVipForm(name: _name.text, email: _email.text, phone: _phone.text, tier: _tier.text, validFrom: _from, validUntil: _until, preferences: _prefs.text, notes: _notes.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    final details = <String, dynamic>{
      'name': _name.text.trim(),
      'email': _opt(_email),
      'phone': _opt(_phone),
      'tier': _opt(_tier) ?? 'VIP',
      'valid_from': _from == null ? null : isoDay(_from!),
      'valid_until': _until == null ? null : isoDay(_until!),
      'preferences': _opt(_prefs),
      'notes': _opt(_notes),
      'host': _host,
    };
    try {
      final service = ref.read(vipServiceProvider);
      if (_editing) {
        await service.update(widget.existing!.id, details);
      } else {
        // On creation only what was filled in is sent; the database fills in the rest.
        await service.add(widget.venueId, {for (final e in details.entries) if (e.value != null) e.key: e.value});
      }
      if (mounted) Navigator.of(context).pop(true);
    } on OpsActionException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final people = ref.watch(chatPeopleProvider(widget.venueId));
    final staff = people.asData?.value ?? const <ChatPerson>[];
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Change guest' : 'Add a VIP guest')),
      body: SafeArea(
        child: ListView(
          key: const Key('vip-form'),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(key: const Key('vip-name'), controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name'), onChanged: (_) => setState(() => _problem = null)),
            TextField(key: const Key('vip-email'), controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), onChanged: (_) => setState(() => _problem = null)),
            TextField(key: const Key('vip-phone'), controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'), onChanged: (_) => setState(() => _problem = null)),
            TextField(key: const Key('vip-tier'), controller: _tier, decoration: const InputDecoration(labelText: 'Tier', hintText: 'For example Gold'), onChanged: (_) => setState(() => _problem = null)),
            const SizedBox(height: 4),
            VipDateField(label: 'Valid from', value: _from, onChanged: (d) => setState(() => _from = d)),
            VipDateField(label: 'Valid until', value: _until, optional: true, emptyLabel: 'No end date', onChanged: (d) => setState(() => _until = d)),
            DropdownButtonFormField<String?>(
              key: const Key('vip-host'),
              initialValue: staff.any((p) => p.userId == _host) ? _host : null,
              decoration: const InputDecoration(labelText: 'Host (the contact at the club)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('No host')),
                for (final p in staff) DropdownMenuItem<String?>(value: p.userId, child: Text('${p.name} · ${p.roleLabel}')),
              ],
              onChanged: (v) => setState(() => _host = v),
            ),
            TextField(key: const Key('vip-prefs'), controller: _prefs, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Service preferences (servers see these)'), onChanged: (_) => setState(() => _problem = null)),
            TextField(key: const Key('vip-notes'), controller: _notes, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Private notes (managers only)'), onChanged: (_) => setState(() => _problem = null)),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('vip-problem'), style: TextStyle(color: theme.colorScheme.error))),
            const SizedBox(height: 12),
            FilledButton(key: const Key('vip-save'), onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
          ],
        ),
      ),
    );
  }
}
