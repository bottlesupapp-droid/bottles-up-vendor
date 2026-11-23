import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../workspace/models/workspace.dart';
import '../logic/business_name_rules.dart';
import '../services/business_name_service.dart';

/// Renames the business: the call to make, given the new name. In the app it is the service; tests give their own.
typedef RenameBusiness = Future<BusinessRenamed> Function(String name);

/// The business name in Settings. The owner (or the event organizer) of the business sees "Change" and can rename it, with a confirmation first; everybody else sees the name and who may change it.
///
/// Changing it takes two steps, so a name is never changed by one stray tap: a box with the new name (checked as the person types), then "Change the business name?" that says what will happen
/// (upcoming events show the new name, events already held keep the old one, and the next change is possible after [businessNameGapDays] days). The name on screen updates at once on success.
class BusinessNameRow extends StatefulWidget {
  const BusinessNameRow({
    super.key,
    required this.workspace,
    this.rename,
    this.onRenamed,
  });

  final Workspace workspace;

  /// Null when this build cannot rename (then the row is read only).
  final RenameBusiness? rename;

  /// Called after a successful rename, e.g. to refresh the workspace list.
  final void Function(BusinessRenamed renamed)? onRenamed;

  @override
  State<BusinessNameRow> createState() => _BusinessNameRowState();
}

class _BusinessNameRowState extends State<BusinessNameRow> {
  late String _name = widget.workspace.orgName;

  bool get _canChange =>
      widget.rename != null && canRenameBusiness(widget.workspace);

  Future<void> _change() async {
    final renamed = await showModalBottomSheet<BusinessRenamed>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RenameSheet(current: _name, rename: widget.rename!),
    );
    if (renamed == null || !mounted) return;
    setState(() => _name = renamed.name);
    widget.onRenamed?.call(renamed);
    final events = renamed.eventsUpdated;
    final shown =
        events == 0
            ? ''
            : ' $events upcoming ${events == 1 ? 'event shows' : 'events show'} it.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('The business is now called ${renamed.name}.$shown'),
        key: const Key('business-name-done'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _name.isEmpty ? 'Your business' : _name;
    return ListTile(
      key: const Key('settings-business-name'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Ionicons.business_outline),
      title: Text(shown, key: const Key('business-name-text')),
      subtitle: Text(
        _canChange
            ? 'Business name'
            : 'Business name. Only the business owner can change it.',
      ),
      trailing:
          _canChange
              ? Text(
                'Change',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.bu.orange,
                  fontWeight: FontWeight.w700,
                ),
              )
              : null,
      onTap: _canChange ? _change : null,
    );
  }
}

/// The box for the new name. Closes with the result of a successful rename (or nothing when cancelled).
class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.current, required this.rename});

  final String current;
  final RenameBusiness rename;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );
  String?
  _refused; // what the database said last time, until the person edits again
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// What is wrong with the box as it stands (including "that is already the name", so an unchanged box is never ready to continue).
  String? get _problem =>
      businessNameProblem(_controller.text, current: widget.current);

  Future<void> _continue() async {
    final newName = tidyBusinessName(_controller.text);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            key: const Key('business-name-confirm-dialog'),
            title: const Text('Change the business name?'),
            content: Text(
              'From "${widget.current}" to "$newName".\n\n'
              'Guests will see the new name on your upcoming events. Events that have already started or finished keep the old name.\n\n'
              'You will not be able to change it again for $businessNameGapDays days.',
            ),
            actions: [
              TextButton(
                key: const Key('business-name-cancel'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('business-name-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Change name'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _refused = null;
    });
    try {
      final done = await widget.rename(newName);
      if (mounted) Navigator.of(context).pop(done);
    } on BusinessRenameFailed catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _refused = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _refused =
              'The name could not be changed. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Say what is wrong as soon as the box differs from what it opened with (adding only spaces to the same name is told "already the name", not silently refused).
    final edited = _controller.text != widget.current;
    final problem = edited ? _problem : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BuSpace.page,
        0,
        BuSpace.page,
        MediaQuery.viewInsetsOf(context).bottom + BuSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Business name', style: theme.textTheme.titleMedium),
          const SizedBox(height: BuSpace.s),
          TextField(
            key: const Key('business-name-field'),
            controller: _controller,
            enabled: !_saving,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength:
                businessNameMax +
                20, // a little room: the rule below says what is too long, instead of the box refusing to type
            decoration: InputDecoration(
              labelText: 'New business name',
              errorText: problem ?? _refused,
              counterText: '',
            ),
            onChanged: (_) => setState(() => _refused = null),
          ),
          const SizedBox(height: BuSpace.xs),
          Text(
            '$businessNameMin to $businessNameMax characters. It can be changed once every $businessNameGapDays days.',
            key: const Key('business-name-rules'),
            style: theme.textTheme.bodySmall?.copyWith(color: context.bu.muted),
          ),
          const SizedBox(height: BuSpace.l),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('business-name-sheet-cancel'),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: BuSpace.m),
              Expanded(
                child: FilledButton(
                  key: const Key('business-name-continue'),
                  onPressed: (!_saving && _problem == null) ? _continue : null,
                  child:
                      _saving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
