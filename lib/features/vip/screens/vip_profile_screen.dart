import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/ops_async_view.dart';
import '../../ops/widgets/ops_dialogs.dart';
import '../logic/vip_rules.dart';
import '../providers/vip_providers.dart';
import 'vip_form_screen.dart';

/// One VIP guest as the manager sees them: contact, validity, host, preferences and private notes, the perks with how much of each has
/// been used, and the visits. A perk can be redeemed or ended here; the guest can be invited (queued, never "sent"), changed or ended.
class VipProfileScreen extends ConsumerStatefulWidget {
  const VipProfileScreen({super.key, required this.memberId, required this.venueId});

  final String memberId;
  final String venueId;

  @override
  ConsumerState<VipProfileScreen> createState() => _VipProfileScreenState();
}

class _VipProfileScreenState extends ConsumerState<VipProfileScreen> {
  final Set<String> _busy = {};

  void _refresh() => ref.invalidate(vipProfileProvider(widget.memberId));

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(String key, Future<String?> Function() action) async {
    setState(() => _busy.add(key));
    try {
      final note = await action();
      if (note != null) _say(note);
    } on OpsActionException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
      _refresh();
    }
  }

  Future<void> _edit(VipProfile p) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => VipFormScreen(venueId: widget.venueId, existing: p)));
    if (saved == true) _refresh();
  }

  Future<void> _end(VipProfile p) async {
    final reason = await showTextDialog(
      context,
      title: 'End this membership',
      hint: 'Why is it ending?',
      confirmLabel: 'End membership',
      validate: (t) => t.trim().length < 3 ? 'Say why the membership is ending.' : (t.trim().length > 300 ? 'Keep the reason to 300 characters or fewer.' : null),
    );
    if (reason == null || !mounted) return;
    await _run('end', () async {
      await ref.read(vipServiceProvider).end(p.id, reason);
      return 'Membership ended.';
    });
  }

  Future<void> _addPerk(VipProfile p) async {
    final draft = await showDialog<_PerkDraft>(context: context, builder: (_) => const _PerkDialog());
    if (draft == null || !mounted) return;
    await _run('perk', () async {
      await ref.read(vipServiceProvider).addPerk(p.id, draft.kind, draft.label, maxUses: draft.maxUses, period: draft.period);
      return 'Perk added.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(vipProfileProvider(widget.memberId));
    return Scaffold(
      appBar: AppBar(title: const Text('VIP guest')),
      body: SafeArea(
        child: ListView(
          key: const Key('vip-profile'),
          padding: const EdgeInsets.all(16),
          children: [
            OpsAsyncView<VipProfile>(
              value: profile,
              what: 'the guest',
              errorKey: const Key('vip-profile-error'),
              onRetry: _refresh,
              builder: (p) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: theme.textTheme.headlineSmall),
                  Text('${p.tier} · ${vipStatusLabel(p.status)}', key: const Key('vip-profile-status')),
                  if (p.ended && p.endedReason != null) Text('Ended: ${p.endedReason}', key: const Key('vip-ended-reason'), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  if (p.email != null) Text(p.email!, key: const Key('vip-profile-email')),
                  if (p.phone != null) Text(p.phone!),
                  Text('Valid ${formatVipDate(p.validFrom)}${p.validUntil == null ? ', no end date' : ' to ${formatVipDate(p.validUntil)}'}'),
                  if (p.hostName != null) Text('Host: ${p.hostName}'),
                  Text('Credential code: ${p.credentialCode}', key: const Key('vip-code')),
                  if (p.preferences != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Service preferences: ${p.preferences}')),
                  if (p.notes != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Private notes: ${p.notes}', key: const Key('vip-notes-shown'))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton(key: const Key('vip-edit'), onPressed: () => _edit(p), child: const Text('Change')),
                      if (!p.ended && p.email != null)
                        OutlinedButton(
                          key: const Key('vip-invite'),
                          onPressed: _busy.contains('invite')
                              ? null
                              : () => _run('invite', () async {
                                    await ref.read(vipServiceProvider).invite(p.id);
                                    return 'Invitation queued. It has not been sent yet.';
                                  }),
                          child: Text(p.invitedAt == null ? 'Invite' : 'Invite again'),
                        ),
                      if (p.ended)
                        OutlinedButton(
                          key: const Key('vip-reinstate'),
                          onPressed: _busy.contains('reinstate')
                              ? null
                              : () => _run('reinstate', () async {
                                    await ref.read(vipServiceProvider).reinstate(p.id);
                                    return 'Membership restored.';
                                  }),
                          child: const Text('Reinstate'),
                        )
                      else
                        OutlinedButton(key: const Key('vip-end'), onPressed: () => _end(p), child: const Text('End membership')),
                    ],
                  ),
                  if (p.invitedAt != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Invitation queued ${formatVipDate(p.invitedAt)}. It is sent by the messaging service, not from this screen.', key: const Key('vip-invited'), style: theme.textTheme.bodySmall)),
                  const Divider(height: 32),
                  Row(children: [Expanded(child: Text('Perks', style: theme.textTheme.titleMedium)), TextButton(key: const Key('vip-add-perk'), onPressed: p.ended ? null : () => _addPerk(p), child: const Text('Add a perk'))]),
                  if (p.perks.isEmpty) const Text('No perks yet.', key: Key('vip-no-perks')),
                  for (final k in p.perks)
                    Card(
                      key: Key('vip-perk-${k.id}'),
                      child: ListTile(
                        title: Text(k.label, style: TextStyle(decoration: k.active ? null : TextDecoration.lineThrough)),
                        subtitle: Text('${perkKindLabel(k.kind)} · ${k.usage}${k.active ? '' : ' · ended'}'),
                        trailing: !k.active
                            ? null
                            : Wrap(
                                spacing: 4,
                                children: [
                                  TextButton(
                                    key: Key('vip-redeem-${k.id}'),
                                    onPressed: k.exhausted || p.status != 'active' || _busy.contains(k.id)
                                        ? null
                                        : () => _run(k.id, () async => redeemMessage(k.label, await ref.read(vipServiceProvider).redeem(k.id))),
                                    child: const Text('Redeem'),
                                  ),
                                  IconButton(
                                    key: Key('vip-end-perk-${k.id}'),
                                    tooltip: 'End this perk',
                                    icon: const Icon(Icons.block, size: 20),
                                    onPressed: _busy.contains(k.id)
                                        ? null
                                        : () => _run(k.id, () async {
                                              await ref.read(vipServiceProvider).endPerk(k.id);
                                              return 'Perk ended.';
                                            }),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  const Divider(height: 32),
                  Text('Visits', style: theme.textTheme.titleMedium),
                  if (p.visits.isEmpty) const Text('No visits recorded.', key: Key('vip-no-visits')),
                  for (final (i, v) in p.visits.indexed)
                    ListTile(key: Key('vip-visit-$i'), contentPadding: EdgeInsets.zero, title: Text(v.perk), subtitle: Text('${v.night} · ${v.byName}${v.note == null ? '' : ' · ${v.note}'}')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerkDraft {
  const _PerkDraft(this.kind, this.label, this.maxUses, this.period);

  final String kind;
  final String label;
  final int? maxUses;
  final String period;
}

class _PerkDialog extends StatefulWidget {
  const _PerkDialog();

  @override
  State<_PerkDialog> createState() => _PerkDialogState();
}

class _PerkDialogState extends State<_PerkDialog> {
  final _label = TextEditingController();
  final _max = TextEditingController();
  String _kind = 'service';
  String _period = 'night';
  String? _problem;

  @override
  void dispose() {
    _label.dispose();
    _max.dispose();
    super.dispose();
  }

  void _save() {
    final c = checkPerkForm(label: _label.text, maxText: _max.text);
    if (c.error != null) {
      setState(() => _problem = c.error);
      return;
    }
    Navigator.of(context).pop(_PerkDraft(_kind, _label.text.trim(), c.maxUses, _period));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add a perk'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [for (final k in vipPerkKinds) ChoiceChip(key: Key('perk-kind-${k.id}'), label: Text(k.label), selected: _kind == k.id, onSelected: (_) => setState(() => _kind = k.id))],
            ),
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(vipPerkKinds.firstWhere((k) => k.id == _kind).hint, style: theme.textTheme.bodySmall)),
            TextField(key: const Key('perk-label'), controller: _label, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What is it?'), onChanged: (_) => setState(() => _problem = null)),
            TextField(key: const Key('perk-max'), controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limit (empty for none)'), onChanged: (_) => setState(() => _problem = null)),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(key: const Key('perk-period-night'), label: const Text('Per night'), selected: _period == 'night', onSelected: (_) => setState(() => _period = 'night')),
                ChoiceChip(key: const Key('perk-period-total'), label: const Text('In total'), selected: _period == 'total', onSelected: (_) => setState(() => _period = 'total')),
              ],
            ),
            if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('perk-problem'), style: TextStyle(color: theme.colorScheme.error))),
          ],
        ),
      ),
      actions: [
        TextButton(key: const Key('perk-back'), onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        FilledButton(key: const Key('perk-save'), onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
