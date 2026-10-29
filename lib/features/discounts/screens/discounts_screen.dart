import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../owner/widgets/setup_common.dart' show ProblemsBox;
import '../../workspace/models/workspace.dart';
import '../../workspace/models/workspace_role.dart';
import '../logic/discount_rules.dart';
import '../providers/discount_providers.dart';

/// Discounts (club manager, and the owner for any of their clubs): the requests waiting for approval, and the limits. The owner sets the limits (the biggest discount a server and a manager
/// may give on their own, the free bottles a night, and whether discounts combine); a manager reads them and approves what is above a server's limit but within their own; the owner
/// decides anything. Nobody approves their own request. Until limits are set, staff cannot give their own discounts.
class DiscountsScreen extends ConsumerStatefulWidget {
  const DiscountsScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends ConsumerState<DiscountsScreen> {
  String? _chosenVenue;

  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  @override
  Widget build(BuildContext context) {
    final venue = _venueId;
    if (venue == null) {
      return VenuePicker(workspace: widget.workspace, title: 'Discounts', listKey: const Key('discounts-pick-club'), itemKeyPrefix: 'discounts-club-', onPick: (id) => setState(() => _chosenVenue = id));
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(key: Key('tab-waiting'), text: 'Waiting for approval'), Tab(key: Key('tab-limits'), text: 'Limits')]),
          Expanded(
            child: TabBarView(
              children: [
                _WaitingTab(venueId: venue),
                _LimitsTab(venueId: venue, isOwner: widget.workspace.role == WorkspaceRole.owner),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingTab extends ConsumerStatefulWidget {
  const _WaitingTab({required this.venueId});

  final String venueId;

  @override
  ConsumerState<_WaitingTab> createState() => _WaitingTabState();
}

class _WaitingTabState extends ConsumerState<_WaitingTab> {
  void _reload() => ref.invalidate(pendingConcessionsProvider(widget.venueId));

  Future<void> _decide(PendingConcession p, bool approve) async {
    final message = await showDialog<String>(context: context, builder: (_) => DecideConcessionDialog(pending: p, approve: approve));
    _reload();
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = ref.watch(pendingConcessionsProvider(widget.venueId));
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        try {
          await ref.read(pendingConcessionsProvider(widget.venueId).future);
        } catch (_) {
          // The list shows the failure itself.
        }
      },
      child: ListView(
        key: const Key('discounts-waiting'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          OpsAsyncView<List<PendingConcession>>(
            value: pending,
            what: 'the requests',
            errorKey: const Key('discounts-error'),
            onRetry: _reload,
            isEmpty: (d) => d.isEmpty,
            emptyKey: const Key('discounts-empty'),
            emptyText: 'Nothing is waiting for approval.',
            builder: (list) => Column(
              children: [
                for (final p in list)
                  Card(
                    key: Key('pending-${p.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title, style: theme.textTheme.titleMedium),
                          Text('${p.guestName} · ${p.tableName}${p.code == null ? '' : ' · ${p.code}'}', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Text(p.reason),
                          const SizedBox(height: 4),
                          Text('Asked by ${p.requestedBy} (${p.requestedRole}) · ${DateFormat('MMM d, HH:mm').format(p.createdAt)}', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 8),
                          if (p.canDecide)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(key: Key('decline-${p.id}'), onPressed: () => _decide(p, false), child: const Text('Decline')),
                                const SizedBox(width: 8),
                                FilledButton(key: Key('approve-${p.id}'), onPressed: () => _decide(p, true), child: const Text('Approve')),
                              ],
                            )
                          else
                            Text(cannotDecideWhy(p)!, key: Key('cannot-${p.id}'), style: theme.textTheme.bodySmall),
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

/// Approve or decline one waiting request. Declining needs a reason the person can be told. Stays open, with what was typed, when the database refuses. Pops with the message to show.
class DecideConcessionDialog extends ConsumerStatefulWidget {
  const DecideConcessionDialog({super.key, required this.pending, required this.approve});

  final PendingConcession pending;
  final bool approve;

  @override
  ConsumerState<DecideConcessionDialog> createState() => _DecideConcessionDialogState();
}

class _DecideConcessionDialogState extends ConsumerState<DecideConcessionDialog> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    final problem = validateConcessionDecision(approve: widget.approve, note: _note.text);
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      final answer = await ref.read(discountServiceProvider).decide(widget.pending.id, widget.approve, _note.text);
      if (mounted) Navigator.of(context).pop(answer == 'applied' ? 'Approved: ${widget.pending.title}. It is applied to the table.' : 'Declined: ${widget.pending.title}.');
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
    final p = widget.pending;
    return AlertDialog(
      title: Text('${widget.approve ? 'Approve' : 'Decline'} ${p.title}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${p.guestName} · ${p.tableName}. ${p.reason}'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('decide-note'),
            controller: _note,
            enabled: !_busy,
            maxLength: 300,
            decoration: InputDecoration(labelText: widget.approve ? 'Note (optional)' : 'Why is it declined? (they are told)', errorText: _problem, errorMaxLines: 4, border: const OutlineInputBorder(), counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(key: const Key('decide-back'), onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Not now')),
        FilledButton(key: const Key('decide-go'), onPressed: _busy ? null : _go, child: Text(_busy ? 'Saving...' : (widget.approve ? 'Approve' : 'Decline'))),
      ],
    );
  }
}

class _LimitsTab extends ConsumerStatefulWidget {
  const _LimitsTab({required this.venueId, required this.isOwner});

  final String venueId;
  final bool isOwner;

  @override
  ConsumerState<_LimitsTab> createState() => _LimitsTabState();
}

class _LimitsTabState extends ConsumerState<_LimitsTab> {
  final _serverPercent = TextEditingController();
  final _managerPercent = TextEditingController();
  final _serverBottles = TextEditingController();
  final _managerBottles = TextEditingController();
  bool _stacking = false;
  bool _seeded = false;
  bool _busy = false;
  List<String> _problems = const [];

  @override
  void dispose() {
    _serverPercent.dispose();
    _managerPercent.dispose();
    _serverBottles.dispose();
    _managerBottles.dispose();
    super.dispose();
  }

  void _seed(DiscountLimits saved) {
    if (_seeded) return;
    _seeded = true;
    final f = limitsFormFrom(saved);
    _serverPercent.text = f.serverPercent;
    _managerPercent.text = f.managerPercent;
    _serverBottles.text = f.serverBottles;
    _managerBottles.text = f.managerBottles;
    _stacking = f.allowStacking;
  }

  LimitsForm get _form => LimitsForm(
        serverPercent: _serverPercent.text,
        managerPercent: _managerPercent.text,
        serverBottles: _serverBottles.text,
        managerBottles: _managerBottles.text,
        allowStacking: _stacking,
      );

  Future<void> _save() async {
    if (_busy) return;
    final found = validateLimits(_form);
    setState(() => _problems = found);
    if (found.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(discountServiceProvider).saveLimits(widget.venueId, _form);
      if (!mounted) return;
      ref.invalidate(discountLimitsProvider(widget.venueId));
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved. Servers and managers can give discounts and free bottles within these limits.')));
    } on OpsActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _problems = [e.message];
        _busy = false;
      });
    }
  }

  Widget _field(String key, TextEditingController c, String label, {String? helper}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: Key(key),
          controller: c,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _problems = const []),
          decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 2, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limits = ref.watch(discountLimitsProvider(widget.venueId));
    return ListView(
      key: const Key('discounts-limits-tab'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
      children: [
        OpsAsyncView<DiscountLimits>(
          value: limits,
          what: 'the limits',
          errorKey: const Key('limits-error'),
          onRetry: () => ref.invalidate(discountLimitsProvider(widget.venueId)),
          builder: (saved) {
            _seed(saved);
            final words = limitsWords(saved);
            if (!widget.isOwner) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in words) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(w, key: const Key('limits-word'))),
                  const SizedBox(height: 8),
                  Text('Only the owner changes these limits.', key: const Key('limits-owner-only'), style: theme.textTheme.bodySmall),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final w in words) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(w, key: const Key('limits-word'))),
                const SizedBox(height: 16),
                Text('Change the limits', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _field('limit-server-percent', _serverPercent, 'Server: biggest discount (%)', helper: 'Of the table\'s bottles. 0 means a server cannot give one.'),
                _field('limit-manager-percent', _managerPercent, 'Manager: biggest discount (%)', helper: 'At least as much as a server\'s.'),
                _field('limit-server-bottles', _serverBottles, 'Server: free bottles a night'),
                _field('limit-manager-bottles', _managerBottles, 'Managers: free bottles a night, shared', helper: 'At least as many as a server\'s.'),
                SwitchListTile(
                  key: const Key('limit-stacking'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Let discounts combine'),
                  subtitle: const Text('Off: a table can carry one discount.'),
                  value: _stacking,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _stacking = v;
                            _problems = const [];
                          }),
                ),
                if (_problems.isNotEmpty) ...[const SizedBox(height: 8), ProblemsBox(problems: _problems)],
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('limits-save'),
                  onPressed: _busy || !limitsChanged(saved, _form) ? null : _save,
                  child: Text(_busy ? 'Saving...' : 'Save the limits'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
