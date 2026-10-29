import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../logic/table_map_rules.dart';
import '../providers/table_map_providers.dart';

/// How many guests a booking of this table includes (club owner or manager). Empty means "not stated": the booking is not described as including any admission. A stated number
/// cannot be more than the table seats. New bookings carry the number they were made with; changing it never rewrites a booking that exists. Pops true once saved.
class IncludedAdmissionsDialog extends ConsumerStatefulWidget {
  const IncludedAdmissionsDialog({super.key, required this.venueId, required this.tableTypeId, required this.tableName, required this.maxGuests, this.current});

  final String venueId;
  final String tableTypeId;
  final String tableName;
  final int maxGuests;
  final int? current;

  @override
  ConsumerState<IncludedAdmissionsDialog> createState() => _IncludedAdmissionsDialogState();
}

class _IncludedAdmissionsDialogState extends ConsumerState<IncludedAdmissionsDialog> {
  late final _text = TextEditingController(text: widget.current?.toString() ?? '');
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem = validateIncludedAdmissions(_text.text, widget.maxGuests);
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(tableMapServiceProvider).setIncludedAdmissions(widget.venueId, widget.tableTypeId, includedAdmissionsValue(_text.text));
      if (mounted) Navigator.of(context).pop(true);
    } on OpsActionException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Admissions included in ${widget.tableName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How many guests does a booking of this table include? Leave it empty if you have not decided; use 0 if the booking is not admission. It seats up to ${widget.maxGuests}.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('admissions-field'),
            controller: _text,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Guests included', errorText: _problem, errorMaxLines: 3, border: const OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(key: const Key('admissions-cancel'), onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(key: const Key('admissions-save'), onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save')),
      ],
    );
  }
}
