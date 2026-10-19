import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/logic/chat_rules.dart' show ChatPerson;
import '../../chat/providers/chat_providers.dart' show chatPeopleProvider;
import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../../table_service/providers/table_service_providers.dart' show NightQuery;
import '../../table_service/widgets/night_bar.dart';
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/security_rules.dart';
import '../providers/security_providers.dart';

/// Tasks (security's tab, and the manager's from More): a manager gives a task to a member of security, or leaves it for any of them;
/// the person marks it done. Security sees the tasks given to them and the ones nobody has taken yet.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  late String _night = currentNight(widget.clock());
  final Set<String> _busy = {};

  String get _tonight => currentNight(widget.clock());
  NightQuery get _query => NightQuery(widget.workspace.venueId ?? '', _night);
  bool get _isManager => widget.workspace.role == WorkspaceRole.manager || widget.workspace.role == WorkspaceRole.owner;

  void _refresh() {
    ref.invalidate(securityTasksProvider(_query));
    ref.invalidate(securitySummaryProvider(_query));
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _newTask() async {
    var people = const <ChatPerson>[];
    try {
      people = [for (final p in await ref.read(chatPeopleProvider(_query.venueId).future)) if (p.role == 'security') p];
    } catch (_) {
      // The task can still be left for anyone on security.
    }
    if (!mounted) return;
    final draft = await showDialog<_TaskDraft>(context: context, builder: (_) => _NewTaskDialog(people: people));
    if (draft == null || !mounted) return;
    try {
      await ref.read(securityServiceProvider).createTask(_query.venueId, _night, title: draft.title, details: draft.details, assigneeId: draft.assigneeId);
      _say('Task added.');
    } on OpsActionException catch (e) {
      _say(e.message);
    }
    _refresh();
  }

  Future<void> _step(SecurityTask t, TaskStep step) async {
    String? note;
    if (step == TaskStep.cancel) {
      note = await showTextDialog(context, title: 'Cancel this task', hint: 'Why? (optional)', confirmLabel: 'Cancel task', validate: (t) => t.trim().length > 300 ? 'Keep the note to 300 characters or fewer.' : null);
      if (note == null || !mounted) return;
    }
    setState(() => _busy.add(t.id));
    try {
      final changed = await ref.read(securityServiceProvider).taskStep(t.id, step, note: note);
      _say(changed
          ? switch (step) { TaskStep.claim => 'You have taken this task.', TaskStep.done => 'Marked done.', TaskStep.cancel => 'Task cancelled.' }
          : 'Nothing changed: this task was already dealt with.');
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(t.id));
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = widget.workspace.venueId;
    if (venueId == null || venueId.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This workspace is not tied to a club, so there are no tasks to show.', key: Key('tasks-no-venue'), textAlign: TextAlign.center)));
    }
    final tasks = ref.watch(securityTasksProvider(_query));
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        key: const Key('tasks-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Row(
            children: [
              Expanded(child: Text('Tasks', style: theme.textTheme.headlineSmall)),
              if (_isManager) FilledButton.icon(key: const Key('task-new'), onPressed: _newTask, icon: const Icon(Icons.add, size: 18), label: const Text('New task')),
            ],
          ),
          if (widget.workspace.venueName != null) Text(widget.workspace.venueName!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          NightBar(night: _night, tonight: _tonight, onChanged: (n) => setState(() => _night = n)),
          OpsAsyncView<List<SecurityTask>>(
            value: tasks,
            what: 'tasks',
            isEmpty: (d) => d.isEmpty,
            emptyText: _isManager ? 'No tasks for this night. Add one for the security team.' : 'No tasks for you tonight.',
            emptyKey: const Key('tasks-empty'),
            errorKey: const Key('tasks-error'),
            onRetry: _refresh,
            builder: (list) => Column(
              children: [
                for (final t in list)
                  Card(
                    key: Key('task-${t.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: theme.textTheme.titleMedium?.copyWith(decoration: t.open ? null : TextDecoration.lineThrough)),
                          if (t.details != null) Text(t.details!),
                          const SizedBox(height: 4),
                          Text(
                            switch (t.status) {
                              'done' => 'Done${t.closedByName == null ? '' : ' by ${t.closedByName}'}${t.closingNote == null ? '' : ': ${t.closingNote}'}',
                              'cancelled' => 'Cancelled${t.closingNote == null ? '' : ': ${t.closingNote}'}',
                              _ => 'For: ${t.assigneeLabel}',
                            },
                            key: Key('task-status-${t.id}'),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (taskSteps(t).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  for (final s in taskSteps(t))
                                    s == TaskStep.cancel
                                        ? OutlinedButton(key: Key('task-${s.id}-${t.id}'), onPressed: _busy.contains(t.id) ? null : () => _step(t, s), child: Text(s.label))
                                        : FilledButton(key: Key('task-${s.id}-${t.id}'), onPressed: _busy.contains(t.id) ? null : () => _step(t, s), child: Text(s.label)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDraft {
  const _TaskDraft(this.title, this.details, this.assigneeId);

  final String title;
  final String? details;
  final String? assigneeId;
}

class _NewTaskDialog extends StatefulWidget {
  const _NewTaskDialog({required this.people});

  final List<ChatPerson> people;

  @override
  State<_NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<_NewTaskDialog> {
  final _title = TextEditingController();
  final _details = TextEditingController();
  String? _assignee;
  String? _problem;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  void _save() {
    final problem = checkTaskForm(title: _title.text, details: _details.text);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop(_TaskDraft(_title.text.trim(), _details.text.trim().isEmpty ? null : _details.text.trim(), _assignee));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(key: const Key('task-title'), controller: _title, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What needs doing?'), onChanged: (_) => setState(() => _problem = null)),
            TextField(key: const Key('task-details'), controller: _details, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Details (optional)'), onChanged: (_) => setState(() => _problem = null)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('task-assignee'),
              initialValue: _assignee,
              decoration: const InputDecoration(labelText: 'Give it to'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Anyone on security')),
                for (final p in widget.people) DropdownMenuItem<String?>(value: p.userId, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _assignee = v),
            ),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('task-problem'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('task-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('task-save'), onPressed: _save, child: const Text('Add task')),
      ],
    );
  }
}
