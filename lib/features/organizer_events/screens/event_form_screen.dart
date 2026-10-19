import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_time_picker.dart';
import '../../owner/widgets/photo_field.dart';
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../logic/organizer_events_rules.dart';
import '../providers/organizer_events_providers.dart';
import '../services/organizer_events_service.dart';

/// Create or change a draft. Pops true once it is saved. Each problem is said before anything is sent; a refusal from the database
/// is shown here, in the form, so nothing typed is lost. The cover photo is uploaded as soon as it is chosen and saved with the draft.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, required this.orgId, this.event, this.pickDateTime = pickDateAndTime, this.clock = DateTime.now});

  final String orgId;

  /// The draft being changed; null adds a new one.
  final OrgEvent? event;
  final DateTimePicker pickDateTime;
  final DateTime Function() clock;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  late final EventForm _initial = widget.event == null ? const EventForm() : eventFormFrom(widget.event!);
  late final _title = TextEditingController(text: _initial.title);
  late final _description = TextEditingController(text: _initial.description);
  late final _venue = TextEditingController(text: _initial.venueName);
  late final _address = TextEditingController(text: _initial.address);
  late final _category = TextEditingController(text: _initial.category);
  late final _capacity = TextEditingController(text: _initial.capacity);
  late DateTime? _starts = _initial.starts;
  late DateTime? _ends = _initial.ends;
  late String _cover = _initial.coverImageUrl;
  List<String> _problems = const [];
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _venue, _address, _category, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  EventForm get _form => EventForm(
        title: _title.text,
        description: _description.text,
        venueName: _venue.text,
        address: _address.text,
        starts: _starts,
        ends: _ends,
        category: _category.text,
        capacity: _capacity.text,
        coverImageUrl: _cover,
      );

  Future<void> _pick(bool start) async {
    final now = widget.clock();
    final initial = (start ? _starts : _ends) ?? (start ? now : (_starts ?? now).add(const Duration(hours: 6)));
    final picked = await widget.pickDateTime(context, initial);
    if (picked == null || !mounted) return;
    setState(() => start ? _starts = picked : _ends = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await submitEventForm(_form, widget.orgId, widget.event?.eventId, ref.read(organizerEventsServiceProvider));
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

  String _when(DateTime? t, String empty) => t == null ? empty : DateFormat('EEE, MMM d, y, h:mm a', 'en_US').format(t.toLocal());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget field(Key key, TextEditingController c, String label, {String? hint, TextInputType? type, int? maxLength, int lines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: key,
            controller: c,
            keyboardType: type,
            minLines: lines,
            maxLines: lines,
            maxLength: maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), counterText: ''),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(widget.event == null ? 'Create event' : 'Edit ${widget.event!.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('It is saved as a private draft. The BottlesUp team publishes it and sets up tickets with you.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          field(const Key('field-title'), _title, 'Title', hint: 'Rooftop Sessions', maxLength: EventLimits.title + 20),
          field(const Key('field-description'), _description, 'Description', hint: 'What guests can expect', lines: 4),
          field(const Key('field-venue'), _venue, 'Venue or place name', hint: 'The Roof', maxLength: EventLimits.venueName + 20),
          field(const Key('field-address'), _address, 'Address (optional)', hint: '1 King St W, Toronto'),
          Text('Starts', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          OutlinedButton(key: const Key('pick-start'), onPressed: () => _pick(true), child: Text(_when(_starts, 'Choose when it starts'))),
          const SizedBox(height: 12),
          Text('Ends (optional)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: OutlinedButton(key: const Key('pick-end'), onPressed: () => _pick(false), child: Text(_when(_ends, 'Choose when it ends')))),
              if (_ends != null) IconButton(key: const Key('clear-end'), tooltip: 'Remove the end', icon: const Icon(Icons.close), onPressed: () => setState(() => _ends = null)),
            ],
          ),
          const SizedBox(height: 4),
          Text("Times are in your device's time zone (${DateTime.now().timeZoneName}).", key: const Key('zone-note'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          field(const Key('field-category'), _category, 'Category (optional)', hint: 'Club night', maxLength: EventLimits.category + 10),
          field(const Key('field-capacity'), _capacity, 'Capacity (optional)', hint: '250', type: TextInputType.number),
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
          FilledButton(key: const Key('save-event'), onPressed: _saving || _uploading ? null : _save, child: Text(_saving ? 'Saving…' : (widget.event == null ? 'Create draft' : 'Save draft'))),
        ],
      ),
    );
  }
}
