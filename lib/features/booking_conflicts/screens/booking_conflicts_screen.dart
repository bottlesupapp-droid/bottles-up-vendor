import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ops/services/ops_rpc.dart' show OpsActionException;
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../server_desk/widgets/desk_chip.dart';
import '../../table_service/screens/table_detail_screen.dart';
import '../../workspace/models/workspace.dart';
import '../logic/conflict_rules.dart';
import '../providers/conflict_providers.dart';

Future<void> _defaultContact(Uri uri) async {
  await launchUrl(uri);
}

/// What the manager chose when closing a conflict.
class ConflictAnswer {
  const ConflictAnswer(this.how, this.note);

  final ConflictResolution how;
  final String note;
}

/// Asks how the conflict was settled and for a few words. Replaced in tests.
typedef ConflictAsker = Future<ConflictAnswer?> Function(BuildContext context, BookingConflict conflict);

Future<ConflictAnswer?> askHowSettled(BuildContext context, BookingConflict conflict) {
  return showModalBottomSheet<ConflictAnswer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SettleSheet(conflict: conflict),
  );
}

class _SettleSheet extends StatefulWidget {
  const _SettleSheet({required this.conflict});

  final BookingConflict conflict;

  @override
  State<_SettleSheet> createState() => _SettleSheetState();
}

class _SettleSheetState extends State<_SettleSheet> {
  ConflictResolution? _how;
  final _note = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How was it settled?', style: theme.textTheme.titleMedium),
            Text('${widget.conflict.customerName} · ${conflictWhere(widget.conflict)}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final c in ConflictResolution.values)
              ListTile(
                key: Key('how-${c.db}'),
                contentPadding: EdgeInsets.zero,
                title: Text(c.label),
                subtitle: Text(c.hint),
                leading: Icon(_how == c ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                onTap: () => setState(() {
                  _how = c;
                  _problem = null;
                }),
              ),
            TextField(
              key: const Key('settle-note'),
              controller: _note,
              maxLines: 3,
              maxLength: conflictNoteMax,
              decoration: const InputDecoration(labelText: 'What was done', hintText: 'For example: moved to table 4, guest called'),
              onChanged: (_) => setState(() => _problem = null),
            ),
            if (_problem != null) Text(_problem!, key: const Key('settle-problem'), style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('settle-save'),
                onPressed: () {
                  final problem = validateResolution(_how, _note.text);
                  if (problem != null) {
                    setState(() => _problem = problem);
                    return;
                  }
                  Navigator.of(context).pop(ConflictAnswer(_how!, _note.text));
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Double-booked tables (club manager, and the owner for any of their clubs): guests who paid after the table had gone to someone else. The guest has been sent no confirmation. The manager
/// calls them, moves the booking to another table or refunds it (from the booking's own page), and then closes the conflict here. The database checks that a "moved" really no longer
/// overbooks its table and that a "refunded" booking really is refunded or cancelled.
class BookingConflictsScreen extends ConsumerStatefulWidget {
  const BookingConflictsScreen({
    super.key,
    required this.workspace,
    this.contact = _defaultContact,
    this.ask = askHowSettled,
    this.clock = DateTime.now,
  });

  final Workspace workspace;
  final Future<void> Function(Uri uri) contact;
  final ConflictAsker ask;

  /// The device clock, replaced in tests.
  final DateTime Function() clock;

  @override
  ConsumerState<BookingConflictsScreen> createState() => _BookingConflictsScreenState();
}

class _BookingConflictsScreenState extends ConsumerState<BookingConflictsScreen> {
  String? _chosenVenue;
  bool _showSettled = false;
  final Set<String> _busy = {};

  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;
  ConflictsQuery get _query => ConflictsQuery(_venueId ?? '', includeSettled: _showSettled);

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _reload() => ref.invalidate(bookingConflictsProvider(_query));

  Future<void> _call(Uri uri) async {
    try {
      await widget.contact(uri);
    } catch (_) {
      _say('This could not be opened on this phone.');
    }
  }

  Future<void> _settle(BookingConflict c) async {
    final answer = await widget.ask(context, c);
    if (answer == null || !mounted) return;
    setState(() => _busy.add(c.conflictId));
    try {
      await ref.read(bookingConflictServiceProvider).resolve(c.conflictId, answer.how, answer.note);
      _say('Saved: ${answer.how.label.toLowerCase()}.');
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      // Read it again either way: after a refusal the list shows what the database says now.
      _reload();
      if (mounted) setState(() => _busy.remove(c.conflictId));
    }
  }

  void _open(BookingConflict c) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => TableDetailScreen(bookingId: c.bookingId, title: '${c.tableName} · ${c.customerName}', clock: widget.clock),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final venue = _venueId;
    if (venue == null) {
      return VenuePicker(
        workspace: widget.workspace,
        title: 'Double-booked tables',
        listKey: const Key('conflicts-pick-club'),
        itemKeyPrefix: 'conflicts-club-',
        onPick: (id) => setState(() => _chosenVenue = id),
      );
    }
    final theme = Theme.of(context);
    final conflicts = ref.watch(bookingConflictsProvider(_query));
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        try {
          await ref.read(bookingConflictsProvider(_query).future);
        } catch (_) {
          // The list shows the failure itself.
        }
      },
      child: ListView(
        key: const Key('conflicts'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text(
            'A guest who pays after their 10 minutes are up can find the table taken. They keep their payment, but get no confirmation until you have sorted it out: call them, move the booking to another table or refund it, then close it here.',
            style: theme.textTheme.bodyMedium,
          ),
          SwitchListTile(
            key: const Key('show-settled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Show the ones already settled'),
            value: _showSettled,
            onChanged: (v) => setState(() => _showSettled = v),
          ),
          OpsAsyncView<List<BookingConflict>>(
            value: conflicts,
            what: 'the double-booked tables',
            errorKey: const Key('conflicts-error'),
            onRetry: _reload,
            builder: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _showSettled ? 'No table has been double-booked.' : 'No table is double-booked. Nothing for you to do.',
                    key: const Key('conflicts-empty'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                );
              }
              return Column(children: [for (final c in list) _card(theme, c)]);
            },
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, BookingConflict c) {
    final busy = _busy.contains(c.conflictId);
    return Card(
      key: Key('conflict-${c.conflictId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(c.customerName, style: theme.textTheme.titleMedium)),
                DeskChip(
                  key: Key('conflict-status-${c.conflictId}'),
                  text: c.isOpen ? 'Needs you' : 'Settled',
                  color: c.isOpen ? const Color(0xFFFFB300) : const Color(0xFF66BB6A),
                ),
              ],
            ),
            Text(conflictWhere(c), key: Key('conflict-where-${c.conflictId}'), style: theme.textTheme.bodyMedium),
            if (c.confirmationCode != null) Text(c.confirmationCode!, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text(paidLine(c), style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(conflictSentence(c), key: Key('conflict-line-${c.conflictId}')),
            if (!c.isOpen && c.resolutionNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('“${c.resolutionNote}”', key: Key('conflict-note-${c.conflictId}'), style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ),
            if (c.isOpen) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (c.customerPhone != null)
                    OutlinedButton.icon(
                      key: Key('call-${c.conflictId}'),
                      onPressed: () => _call(Uri(scheme: 'tel', path: c.customerPhone)),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Call'),
                    ),
                  if (c.customerEmail != null)
                    OutlinedButton.icon(
                      key: Key('email-${c.conflictId}'),
                      onPressed: () => _call(Uri(scheme: 'mailto', path: c.customerEmail)),
                      icon: const Icon(Icons.mail_outline, size: 18),
                      label: const Text('E-mail'),
                    ),
                  OutlinedButton(key: Key('open-${c.conflictId}'), onPressed: () => _open(c), child: const Text('Open booking')),
                  FilledButton(key: Key('settle-${c.conflictId}'), onPressed: busy ? null : () => _settle(c), child: const Text('Mark as settled')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
