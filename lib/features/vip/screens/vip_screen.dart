import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/venue_picker.dart';
import '../../workspace/models/workspace.dart';
import '../logic/vip_rules.dart';
import '../providers/vip_providers.dart';
import 'vip_form_screen.dart';
import 'vip_profile_screen.dart';

/// VIP guests (manager; the owner for any of their clubs): the club's list, searched by name or credential code, with a way to add a
/// guest. Ended memberships are hidden unless asked for. A guest's contact details and notes are shown here, to managers only.
class VipScreen extends ConsumerStatefulWidget {
  const VipScreen({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends ConsumerState<VipScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _includeEnded = false;
  String? _chosenVenue;

  String? get _venueId => widget.workspace.venueId ?? _chosenVenue;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ({String venueId, String search, bool includeEnded}) get _key => (venueId: _venueId ?? '', search: _query, includeEnded: _includeEnded);

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => VipFormScreen(venueId: _venueId!)));
    if (saved == true) ref.invalidate(vipListProvider(_key));
  }

  Future<void> _open(VipMember m) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => VipProfileScreen(memberId: m.id, venueId: _venueId!)));
    ref.invalidate(vipListProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venueId = _venueId;
    if (venueId == null) {
      return VenuePicker(workspace: widget.workspace, title: 'VIP guests', listKey: const Key('vip-pick-club'), itemKeyPrefix: 'vip-club-', onPick: (id) => setState(() => _chosenVenue = id));
    }
    final list = ref.watch(vipListProvider(_key));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(vipListProvider(_key)),
      child: ListView(
        key: const Key('vip-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          Row(
            children: [
              Expanded(child: Text('VIP guests', style: theme.textTheme.headlineSmall)),
              FilledButton.icon(key: const Key('vip-add'), onPressed: _add, icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Add')),
            ],
          ),
          if (widget.workspace.venueId == null) TextButton(key: const Key('vip-change-club'), onPressed: () => setState(() => _chosenVenue = null), child: const Text('Choose another club')),
          TextField(
            key: const Key('vip-search'),
            controller: _search,
            decoration: InputDecoration(labelText: 'Search by name or credential code', suffixIcon: IconButton(key: const Key('vip-search-go'), icon: const Icon(Icons.search), onPressed: () => setState(() => _query = _search.text.trim()))),
            onSubmitted: (v) => setState(() => _query = v.trim()),
          ),
          SwitchListTile(key: const Key('vip-show-ended'), contentPadding: EdgeInsets.zero, title: const Text('Show ended memberships'), value: _includeEnded, onChanged: (v) => setState(() => _includeEnded = v)),
          OpsAsyncView<List<VipMember>>(
            value: list,
            what: 'VIP guests',
            isEmpty: (d) => d.isEmpty,
            emptyText: _query.isEmpty ? 'No VIP guests yet. Add the first one.' : 'No one matches that.',
            emptyKey: const Key('vip-empty'),
            errorKey: const Key('vip-error'),
            onRetry: () => ref.invalidate(vipListProvider(_key)),
            builder: (members) => Column(
              children: [
                for (final m in members)
                  Card(
                    key: Key('vip-member-${m.id}'),
                    child: ListTile(
                      onTap: () => _open(m),
                      title: Text(m.name),
                      subtitle: Text('${m.tier}${m.hostName == null ? '' : ' · host ${m.hostName}'} · ${m.perks} ${m.perks == 1 ? 'perk' : 'perks'}'),
                      trailing: Text(vipStatusLabel(m.status), key: Key('vip-status-${m.id}'), style: theme.textTheme.labelMedium?.copyWith(color: m.active ? null : theme.colorScheme.error)),
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
