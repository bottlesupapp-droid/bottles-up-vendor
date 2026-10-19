import 'package:intl/intl.dart';

import '../../ops/logic/ops_json.dart';

/// The venue's VIP list. Who may keep it, who sees which perks, that a limited perk cannot be used past its limit and that an ended or
/// expired membership uses nothing are the database's rules. This file reads what it sends, words it, and checks what was typed.

class VipPerkKind {
  const VipPerkKind(this.id, this.label, this.hint);

  final String id;
  final String label;
  final String hint;
}

const List<VipPerkKind> vipPerkKinds = [
  VipPerkKind('entry', 'Entry', 'Priority entry or another entry benefit; the door redeems it.'),
  VipPerkKind('service', 'Service', 'Something at the table or bar; servers redeem it.'),
  VipPerkKind('discount', 'Discount', 'A discount or an approved allowance; only a manager redeems it.'),
];

String perkKindLabel(String id) => vipPerkKinds.where((k) => k.id == id).firstOrNull?.label ?? id;

class VipMember {
  const VipMember({required this.id, required this.name, required this.tier, required this.status, required this.perks, required this.invited, this.validUntil, this.hostName, this.lastVisit});

  final String id;
  final String name;
  final String tier;

  /// 'active', 'expired', 'upcoming' or 'ended'.
  final String status;
  final DateTime? validUntil;
  final String? hostName;
  final int perks;
  final DateTime? lastVisit;
  final bool invited;

  bool get active => status == 'active';
}

VipMember? parseVipMember(Map<String, dynamic> r) {
  final id = opsStr(r, 'member_id');
  if (id == null) return null;
  return VipMember(
    id: id,
    name: opsStr(r, 'name') ?? 'Guest',
    tier: opsStr(r, 'tier') ?? 'VIP',
    status: opsStr(r, 'status') ?? 'active',
    validUntil: opsTime(r, 'valid_until'),
    hostName: opsStr(r, 'host_name'),
    perks: opsInt(r, 'perks'),
    lastVisit: opsTime(r, 'last_visit'),
    invited: opsBool(r, 'invited'),
  );
}

String vipStatusLabel(String status) => switch (status) {
      'active' => 'Active',
      'expired' => 'Expired',
      'upcoming' => 'Not started yet',
      'ended' => 'Ended',
      _ => status,
    };

class VipPerk {
  const VipPerk({required this.id, required this.kind, required this.label, required this.period, required this.used, this.maxUses, this.active = true});

  final String id;
  final String kind;
  final String label;
  final int? maxUses;

  /// 'night' or 'total'.
  final String period;
  final int used;
  final bool active;

  bool get exhausted => maxUses != null && used >= maxUses!;

  /// "1 of 1 tonight", "2 of 3 in total", or "no limit".
  String get usage => maxUses == null ? 'No limit' : '$used of $maxUses ${period == 'night' ? 'tonight' : 'in total'}';
}

VipPerk? parseVipPerk(Object? p) {
  if (p is! Map) return null;
  final r = Map<String, dynamic>.from(p);
  final id = opsStr(r, 'perk_id');
  if (id == null) return null;
  return VipPerk(
    id: id,
    kind: opsStr(r, 'kind') ?? 'service',
    label: opsStr(r, 'label') ?? 'Perk',
    maxUses: r['max_uses'] == null ? null : opsInt(r, 'max_uses'),
    period: opsStr(r, 'period') ?? 'night',
    used: opsInt(r, 'used'),
    active: r['active'] != false,
  );
}

List<VipPerk> _perks(Object? list) => [
      if (list is List)
        for (final p in list)
          if (parseVipPerk(p) != null) parseVipPerk(p)!,
    ];

class VipVisit {
  const VipVisit({required this.night, required this.perk, required this.byName, this.note});

  final String night;
  final String perk;
  final String byName;
  final String? note;
}

class VipProfile {
  const VipProfile({
    required this.id,
    required this.name,
    required this.tier,
    required this.status,
    required this.credentialCode,
    required this.perks,
    required this.visits,
    this.email,
    this.phone,
    this.validFrom,
    this.validUntil,
    this.hostId,
    this.hostName,
    this.preferences,
    this.notes,
    this.invitedAt,
    this.endedReason,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String tier;
  final String status;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? hostId;
  final String? hostName;
  final String? preferences;
  final String? notes;
  final String credentialCode;
  final DateTime? invitedAt;
  final String? endedReason;
  final List<VipPerk> perks;
  final List<VipVisit> visits;

  bool get ended => status == 'ended';
}

VipProfile? parseVipProfile(Map<String, dynamic> r) {
  final id = opsStr(r, 'member_id');
  if (id == null) return null;
  final visits = r['visits'];
  return VipProfile(
    id: id,
    name: opsStr(r, 'name') ?? 'Guest',
    email: opsStr(r, 'email'),
    phone: opsStr(r, 'phone'),
    tier: opsStr(r, 'tier') ?? 'VIP',
    status: opsStr(r, 'status') ?? 'active',
    validFrom: opsTime(r, 'valid_from'),
    validUntil: opsTime(r, 'valid_until'),
    hostId: opsStr(r, 'host_id'),
    hostName: opsStr(r, 'host_name'),
    preferences: opsStr(r, 'preferences'),
    notes: opsStr(r, 'notes'),
    credentialCode: opsStr(r, 'credential_code') ?? '',
    invitedAt: opsTime(r, 'invited_at'),
    endedReason: opsStr(r, 'ended_reason'),
    perks: _perks(r['perks']),
    visits: [
      if (visits is List)
        for (final v in visits)
          if (v is Map)
            VipVisit(
              night: v['night']?.toString() ?? '',
              perk: v['perk']?.toString() ?? '',
              byName: v['by_name']?.toString() ?? 'Staff member',
              note: v['note']?.toString(),
            ),
    ],
  );
}

/// A guest found at the club: what the database lets this person see. A server gets service perks and preferences, the door gets entry
/// perks; only a manager also gets contact details and notes.
class VipLookupResult {
  const VipLookupResult({required this.id, required this.name, required this.tier, required this.status, required this.perks, this.validUntil, this.hostName, this.preferences, this.email, this.phone, this.notes});

  final String id;
  final String name;
  final String tier;
  final String status;
  final DateTime? validUntil;
  final String? hostName;
  final String? preferences;
  final String? email;
  final String? phone;
  final String? notes;
  final List<VipPerk> perks;

  bool get active => status == 'active';
}

VipLookupResult? parseVipLookup(Map<String, dynamic> r) {
  final id = opsStr(r, 'member_id');
  if (id == null) return null;
  return VipLookupResult(
    id: id,
    name: opsStr(r, 'name') ?? 'Guest',
    tier: opsStr(r, 'tier') ?? 'VIP',
    status: opsStr(r, 'status') ?? 'active',
    validUntil: opsTime(r, 'valid_until'),
    hostName: opsStr(r, 'host_name'),
    preferences: opsStr(r, 'preferences'),
    email: opsStr(r, 'email'),
    phone: opsStr(r, 'phone'),
    notes: opsStr(r, 'notes'),
    perks: _perks(r['perks']),
  );
}

class RedeemOutcome {
  const RedeemOutcome({required this.used, this.maxUses, this.usesLeft});

  final int used;
  final int? maxUses;
  final int? usesLeft;
}

RedeemOutcome parseRedeemOutcome(Object? data) {
  final m = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  return RedeemOutcome(used: opsInt(m, 'used'), maxUses: m['max_uses'] == null ? null : opsInt(m, 'max_uses'), usesLeft: m['uses_left'] == null ? null : opsInt(m, 'uses_left'));
}

String redeemMessage(String perkLabel, RedeemOutcome o) =>
    o.usesLeft == null ? '$perkLabel recorded.' : '$perkLabel recorded. ${o.usesLeft == 0 ? 'No uses left.' : '${o.usesLeft} left.'}';

String formatVipDate(DateTime? d) => d == null ? '' : DateFormat('d MMM y').format(d);

String isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

// -------------------------------------------------------------------------------------------------------------------------------------
// What was typed
// -------------------------------------------------------------------------------------------------------------------------------------

final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? checkVipForm({required String name, required String email, required String phone, required String tier, DateTime? validFrom, DateTime? validUntil, String preferences = '', String notes = ''}) {
  if (name.trim().length < 2) return 'Enter the guest\'s name.';
  if (name.trim().length > 80) return 'Keep the name to 80 characters or fewer.';
  final e = email.trim();
  final p = phone.trim();
  if (e.isEmpty && p.isEmpty) return 'Enter an email or a phone number.';
  if (e.isNotEmpty && !_email.hasMatch(e)) return 'That does not look like an email address.';
  if (p.isNotEmpty && p.length < 5) return 'That phone number is too short.';
  if (tier.trim().isNotEmpty && tier.trim().length < 2) return 'The tier needs at least 2 characters.';
  if (tier.trim().length > 40) return 'Keep the tier to 40 characters or fewer.';
  if (validFrom != null && validUntil != null && validUntil.isBefore(validFrom)) return 'The end date is before the start date.';
  if (preferences.trim().length > 300) return 'Keep the service preferences to 300 characters or fewer.';
  if (notes.trim().length > 500) return 'Keep the notes to 500 characters or fewer.';
  return null;
}

({int? maxUses, String? error}) checkPerkForm({required String label, required String maxText}) {
  final l = label.trim();
  if (l.length < 2) return (maxUses: null, error: 'Say what the perk is.');
  if (l.length > 80) return (maxUses: null, error: 'Keep the perk to 80 characters or fewer.');
  final t = maxText.trim();
  if (t.isEmpty) return (maxUses: null, error: null);
  final n = int.tryParse(t);
  if (n == null || n < 1 || n > 1000) return (maxUses: null, error: 'The limit has to be from 1 to 1000, or empty for no limit.');
  return (maxUses: n, error: null);
}

String? checkVipSearch(String query) => query.trim().length < 3 ? 'Type at least 3 letters of the name, or the credential code.' : null;
