import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_picker.dart';
import '../../owner/logic/owner_rules.dart' show OrgVenue;
import '../logic/team_rules.dart';
import '../providers/team_providers.dart';
import '../services/team_service.dart';

/// Shifts (owner and manager): a night or part of one at a club, which people can then be invited to for just that time. Lists the
/// upcoming and recent shifts and adds a new one. A shift that ends before it starts, or runs longer than 24 hours, is not saved.
class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key, required this.venues, this.pickDateTime = pickDateAndTime, this.clock = DateTime.now});

  final List<OrgVenue> venues;
  final DateTimePicker pickDateTime;
  final DateTime Function() clock;

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  final _name = TextEditingController();
  late String _venueId = widget.venues.first.id;
  DateTime? _start;
  DateTime? _end;
  String? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final initial = (start ? _start : _end) ?? _start ?? widget.clock();
    final picked = await widget.pickDateTime(context, initial);
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
      _problem = null;
    });
  }

  Future<void> _save() async {
    final problem = checkShiftForm(name: _name.text, start: _start, end: _end);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      await ref.read(teamServiceProvider).createShift(_venueId, _name.text, _start!, _end!);
      ref.invalidate(venueShiftsProvider(_venueId));
      if (!mounted) return;
      _name.clear();
      setState(() {
        _start = null;
        _end = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Shift added.')));
    } on TeamActionException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shifts = ref.watch(venueShiftsProvider(_venueId));
    return Scaffold(
      appBar: AppBar(title: const Text('Shifts')),
      body: SafeArea(
        child: ListView(
          key: const Key('shifts-list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text('A shift is a night or part of one. People can be invited to a shift and only have access for its hours.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (widget.venues.length > 1)
              DropdownButtonFormField<String>(
                key: const Key('shift-venue'),
                initialValue: _venueId,
                decoration: const InputDecoration(labelText: 'Club'),
                items: [for (final v in widget.venues) DropdownMenuItem(value: v.id, child: Text(v.name))],
                onChanged: (v) => setState(() => _venueId = v ?? _venueId),
              ),
            TextField(key: const Key('shift-name'), controller: _name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Name', hintText: 'For example Friday night'), onChanged: (_) => setState(() => _problem = null)),
            ListTile(key: const Key('shift-start'), contentPadding: EdgeInsets.zero, title: const Text('Starts'), subtitle: Text(_start == null ? 'Choose' : describeAccessTime(_start!)), onTap: () => _pick(true), trailing: const Icon(Icons.schedule, size: 18)),
            ListTile(key: const Key('shift-end'), contentPadding: EdgeInsets.zero, title: const Text('Ends'), subtitle: Text(_end == null ? 'Choose' : describeAccessTime(_end!)), onTap: () => _pick(false), trailing: const Icon(Icons.schedule, size: 18)),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_problem!, key: const Key('shift-problem'), style: TextStyle(color: theme.colorScheme.error))),
            const SizedBox(height: 8),
            FilledButton(key: const Key('shift-save'), onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Add shift')),
            const Divider(height: 32),
            Text('Upcoming and recent', style: theme.textTheme.titleMedium),
            shifts.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const Text('The shifts could not be loaded.', key: Key('shifts-error')),
              data: (list) => list.isEmpty
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No shifts yet.', key: Key('shifts-empty')))
                  : Column(
                      children: [
                        for (final s in list) ListTile(key: Key('shift-${s.shiftId}'), contentPadding: EdgeInsets.zero, title: Text(s.name), subtitle: Text('${describeShift(s.startsAt, s.endsAt)}${s.eventTitle == null ? '' : ' · ${s.eventTitle}'}')),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
