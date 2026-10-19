import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/services/ops_rpc.dart';
import '../logic/vip_rules.dart';
import '../providers/vip_providers.dart';

/// VIP lookup at the club (servers, and managers): type 3+ letters of a name, or the credential code, and see what this person is allowed
/// to see. A server sees service perks and preferences only. An expired or ended membership is shown as such, with no perks to use.
class VipLookupScreen extends ConsumerStatefulWidget {
  const VipLookupScreen({super.key, required this.venueId, this.clock = DateTime.now});

  final String venueId;
  final DateTime Function() clock;

  @override
  ConsumerState<VipLookupScreen> createState() => _VipLookupScreenState();
}

class _VipLookupScreenState extends ConsumerState<VipLookupScreen> {
  final _query = TextEditingController();
  List<VipLookupResult>? _results;
  String? _problem;
  bool _busy = false;
  final Set<String> _redeeming = {};

  String get _night => currentNight(widget.clock());

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final problem = checkVipSearch(_query.text);
    if (problem != null) {
      setState(() {
        _problem = problem;
        _results = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final found = await ref.read(vipServiceProvider).lookup(widget.venueId, _query.text, night: _night);
      if (mounted) setState(() => _results = found);
    } on OpsActionException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e.message;
          _results = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem(VipPerk perk) async {
    setState(() => _redeeming.add(perk.id));
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      final outcome = await ref.read(vipServiceProvider).redeem(perk.id, night: _night);
      messenger.showSnackBar(SnackBar(content: Text(redeemMessage(perk.label, outcome))));
    } on OpsActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _redeeming.remove(perk.id));
      if (mounted) await _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('VIP lookup')),
      body: SafeArea(
        child: ListView(
          key: const Key('vip-lookup'),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('lookup-query'),
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(labelText: 'Name or credential code', errorText: _problem, suffixIcon: IconButton(key: const Key('lookup-go'), icon: const Icon(Icons.search), onPressed: _busy ? null : _search)),
              onSubmitted: (_) => _search(),
              onChanged: (_) {
                if (_problem != null) setState(() => _problem = null);
              },
            ),
            const SizedBox(height: 8),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (results != null && results.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No VIP guest matches that.', key: Key('lookup-none'))),
            for (final r in results ?? const <VipLookupResult>[])
              Card(
                key: Key('lookup-result-${r.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: theme.textTheme.titleMedium),
                      Text('${r.tier} · ${vipStatusLabel(r.status)}${r.validUntil == null ? '' : ' · until ${formatVipDate(r.validUntil)}'}', key: Key('lookup-status-${r.id}'), style: TextStyle(color: r.active ? null : theme.colorScheme.error)),
                      if (r.hostName != null) Text('Host: ${r.hostName}'),
                      if (r.preferences != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Preferences: ${r.preferences}', key: Key('lookup-prefs-${r.id}'))),
                      if (r.email != null || r.phone != null) Text([if (r.email != null) r.email!, if (r.phone != null) r.phone!].join(' · '), key: Key('lookup-contact-${r.id}')),
                      if (r.notes != null) Text('Notes: ${r.notes}', key: Key('lookup-notes-${r.id}')),
                      if (!r.active) const Padding(padding: EdgeInsets.only(top: 6), child: Text('No benefits can be used.', key: Key('lookup-no-benefits')))
                      else if (r.perks.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('No benefits for you to give.', key: Key('lookup-no-perks')))
                      else
                        for (final k in r.perks)
                          ListTile(
                            key: Key('lookup-perk-${k.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(k.label),
                            subtitle: Text('${perkKindLabel(k.kind)} · ${k.usage}'),
                            trailing: FilledButton(key: Key('lookup-redeem-${k.id}'), onPressed: k.exhausted || _redeeming.contains(k.id) ? null : () => _redeem(k), child: Text(k.exhausted ? 'Used' : 'Redeem')),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
