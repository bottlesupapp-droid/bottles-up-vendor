import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/vip/services/vip_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException refuse(String message) => PostgrestException(message: message, code: 'P0001');

class FakePerk {
  FakePerk(this.id, this.kind, this.label, {this.max, this.period = 'night', this.active = true});

  final String id;
  final String kind;
  final String label;
  final int? max;
  final String period;
  bool active;
  int usedTonight = 0;
  int usedTotal = 0;
}

class FakeVip {
  FakeVip(this.id, this.name, {this.email, this.phone, this.tier = 'VIP', this.status = 'active', this.host, this.preferences, this.notes, this.code = 'ABCD1234'});

  final String id;
  String name;
  String? email;
  String? phone;
  String tier;
  String status;
  String? host;
  String? preferences;
  String? notes;
  String code;
  String? hostId;
  DateTime? validFrom = DateTime.utc(2026, 10, 1);
  DateTime? validUntil;
  DateTime? invitedAt;
  String? endedReason;
  final List<FakePerk> perks = [];
  final List<({String perk, String night, String by, String? note})> visits = [];
}

/// The database's VIP functions as a fake with the same sentences the SQL raises. [role] is who is signed in: 'manager', 'owner', 'server',
/// 'door' or 'security'. A server sees service perks and preferences; the door entry perks; only a manager sees contact and notes.
class FakeVipBackend {
  FakeVipBackend({this.role = 'manager'});

  String role;
  final List<FakeVip> members = [];
  final List<({String function, Map<String, dynamic>? params})> calls = [];
  bool offline = false;
  bool missing = false;
  int _ids = 100;

  VipService get service => VipService(rpc: OpsRpc(rpc: call));

  bool get _manager => role == 'manager' || role == 'owner';

  List<Map<String, dynamic>> calledWith(String function) => [
        for (final c in calls)
          if (c.function == function) c.params ?? const {},
      ];

  FakeVip member(String id) => members.firstWhere((m) => m.id == id);

  Map<String, dynamic> _perkJson(FakePerk k) => {'perk_id': k.id, 'kind': k.kind, 'label': k.label, 'max_uses': k.max, 'period': k.period, 'active': k.active, 'used': k.period == 'night' ? k.usedTonight : k.usedTotal};

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add((function: function, params: params));
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    switch (function) {
      case 'vip_list':
        {
          if (!_manager) throw refuse('not allowed');
          final q = ((params!['p_search'] as String?) ?? '').toLowerCase();
          final ended = params['p_include_ended'] == true;
          return [
            for (final m in members.where((m) => (ended || m.status != 'ended') && (q.isEmpty || m.name.toLowerCase().contains(q) || m.code.toLowerCase() == q)))
              {
                'member_id': m.id,
                'name': m.name,
                'tier': m.tier,
                'status': m.status,
                'valid_until': m.validUntil?.toIso8601String(),
                'host_name': m.host,
                'perks': m.perks.where((k) => k.active).length,
                'last_visit': m.visits.isEmpty ? null : m.visits.first.night,
                'invited': m.invitedAt != null,
              },
          ];
        }
      case 'vip_detail':
        {
          if (!_manager) throw refuse('not allowed');
          final m = members.where((m) => m.id == params!['p_member']).firstOrNull ?? (throw refuse('not allowed'));
          return {
            'member_id': m.id,
            'name': m.name,
            'email': m.email,
            'phone': m.phone,
            'tier': m.tier,
            'status': m.status,
            'valid_from': m.validFrom?.toIso8601String(),
            'valid_until': m.validUntil?.toIso8601String(),
            'host_id': m.hostId,
            'host_name': m.host,
            'preferences': m.preferences,
            'notes': m.notes,
            'credential_code': m.code,
            'invited_at': m.invitedAt?.toIso8601String(),
            'ended_reason': m.endedReason,
            'perks': [for (final k in m.perks) _perkJson(k)],
            'visits': [for (final v in m.visits) {'night': v.night, 'perk': v.perk, 'by_name': v.by, 'note': v.note}],
          };
        }
      case 'vip_add':
        {
          if (!_manager) throw refuse('not allowed');
          final d = Map<String, dynamic>.from(params!['p_details'] as Map);
          final name = (d['name'] as String?)?.trim() ?? '';
          if (name.length < 2) throw refuse('enter the guest\'s name');
          if (d['email'] == null && d['phone'] == null) throw refuse('enter an email or a phone number');
          final m = FakeVip('v${_ids++}', name, email: (d['email'] as String?)?.toLowerCase(), phone: d['phone'] as String?, tier: (d['tier'] as String?) ?? 'VIP', preferences: d['preferences'] as String?, notes: d['notes'] as String?)
            ..hostId = d['host'] as String?
            ..host = d['host'] == null ? null : 'Mia Manager'
            ..validUntil = d['valid_until'] == null ? null : DateTime.parse(d['valid_until'] as String);
          members.add(m);
          return m.id;
        }
      case 'vip_update':
        {
          if (!_manager) throw refuse('not allowed');
          final m = member(params!['p_member'] as String);
          final d = Map<String, dynamic>.from(params['p_details'] as Map);
          final email = d.containsKey('email') ? d['email'] as String? : m.email;
          final phone = d.containsKey('phone') ? d['phone'] as String? : m.phone;
          if (email == null && phone == null) throw refuse('enter an email or a phone number');
          m.name = (d['name'] as String?) ?? m.name;
          m.email = email;
          m.phone = phone;
          m.tier = (d['tier'] as String?) ?? m.tier;
          m.preferences = d.containsKey('preferences') ? d['preferences'] as String? : m.preferences;
          m.notes = d.containsKey('notes') ? d['notes'] as String? : m.notes;
          if (d.containsKey('host')) {
            m.hostId = d['host'] as String?;
            m.host = d['host'] == null ? null : 'Mia Manager';
          }
          m.validUntil = d.containsKey('valid_until') ? (d['valid_until'] == null ? null : DateTime.parse(d['valid_until'] as String)) : m.validUntil;
          return null;
        }
      case 'vip_end':
        {
          if (!_manager) throw refuse('not allowed');
          final m = member(params!['p_member'] as String);
          if (m.status == 'ended') throw refuse('this membership has already ended');
          final reason = (params['p_reason'] as String).trim();
          if (reason.length < 3) throw refuse('say why the membership is ending');
          m.status = 'ended';
          m.endedReason = reason;
          return null;
        }
      case 'vip_reinstate':
        {
          if (!_manager) throw refuse('not allowed');
          final m = member(params!['p_member'] as String);
          if (m.status != 'ended') throw refuse('this membership has not ended');
          m.status = 'active';
          m.endedReason = null;
          return null;
        }
      case 'vip_add_perk':
        {
          if (!_manager) throw refuse('not allowed');
          final m = member(params!['p_member'] as String);
          final kind = params['p_kind'];
          if (kind is! String || !const {'entry', 'service', 'discount'}.contains(kind)) throw refuse('choose entry, service or discount');
          if ((params['p_label'] as String).trim().length < 2) throw refuse('say what the perk is');
          final k = FakePerk('k${_ids++}', kind, (params['p_label'] as String).trim(), max: params['p_max_uses'] as int?, period: (params['p_period'] as String?) ?? 'night');
          m.perks.add(k);
          return k.id;
        }
      case 'vip_end_perk':
        {
          if (!_manager) throw refuse('not allowed');
          final k = members.expand((m) => m.perks).where((k) => k.id == params!['p_perk']).firstOrNull ?? (throw refuse('not allowed'));
          if (!k.active) throw refuse('this perk has already ended');
          k.active = false;
          return null;
        }
      case 'vip_invite':
        {
          if (!_manager) throw refuse('not allowed');
          final m = member(params!['p_member'] as String);
          if (m.email == null) throw refuse('this guest has no email address to invite');
          if (m.invitedAt != null) throw refuse('an invitation was queued a moment ago');
          m.invitedAt = DateTime.utc(2026, 10, 9, 21);
          return {'queued': true};
        }
      case 'vip_lookup':
        {
          if (role == 'security' || role == 'stranger') throw refuse('not allowed');
          final q = (params!['p_query'] as String).trim();
          if (q.length < 3) throw refuse('type at least 3 letters of the name, or the credential code');
          bool visible(FakePerk k) => k.active && (_manager || (role == 'server' && k.kind == 'service') || (role == 'door' && k.kind == 'entry'));
          return [
            for (final m in members.where((m) => m.name.toLowerCase().contains(q.toLowerCase()) || m.code.toLowerCase() == q.toLowerCase()).take(10))
              {
                'member_id': m.id,
                'name': m.name,
                'tier': m.tier,
                'status': m.status,
                'valid_until': m.validUntil?.toIso8601String(),
                'host_name': m.host,
                'preferences': _manager || role == 'server' ? m.preferences : null,
                'email': _manager ? m.email : null,
                'phone': _manager ? m.phone : null,
                'notes': _manager ? m.notes : null,
                'perks': m.status == 'active' ? [for (final k in m.perks.where(visible)) _perkJson(k)] : <Map<String, dynamic>>[],
              },
          ];
        }
      case 'vip_redeem':
        {
          final pair = members.expand((m) => m.perks.map((k) => (m, k))).where((e) => e.$2.id == params!['p_perk']).firstOrNull ?? (throw refuse('not allowed'));
          final (m, k) = pair;
          final allowed = _manager || (role == 'server' && k.kind == 'service') || (role == 'door' && k.kind == 'entry');
          if (!allowed) throw refuse('not allowed');
          if (m.status != 'active') throw refuse('this membership is not active (${m.status})');
          if (!k.active) throw refuse('this perk has ended');
          final used = k.period == 'night' ? k.usedTonight : k.usedTotal;
          if (k.max != null && used >= k.max!) throw refuse('this benefit has already been used $used of ${k.max} ${k.period == 'night' ? 'tonight' : 'in total'}');
          k.usedTonight++;
          k.usedTotal++;
          m.visits.insert(0, (perk: k.label, night: '2026-10-09', by: 'Me', note: params!['p_note'] as String?));
          return {'redemption_id': 'r${_ids++}', 'used': used + 1, 'max_uses': k.max, 'uses_left': k.max == null ? null : k.max! - used - 1};
        }
    }
    throw StateError('unexpected call $function');
  }
}
