// The rules behind Door control (website 20261122100000_door_exits_and_overrides.sql; brief section 18: "Controlled overrides require reason and authorized role", "Track exits if displaying
// live occupancy"). Pure Dart, so they are tested without a screen. Who may override, and what may be overridden, is decided by the database (door_override_entry): nothing here
// grants anything. An override admits a guest held back ONLY by the entry code; every other refusal stays as the scanner gave it.

/// The shortest and longest reason the database keeps.
const int overrideReasonMin = 5;
const int overrideReasonMax = 300;

/// Why an override cannot be sent yet, or null when the reason is fine.
String? validateOverrideReason(String reason) {
  final r = reason.trim();
  if (r.length < overrideReasonMin) return 'Write why, in at least $overrideReasonMin characters. It is kept with the override.';
  if (r.length > overrideReasonMax) return 'Keep the reason to $overrideReasonMax characters.';
  return null;
}

/// One of the club's nights, with how many are in and whether exits are tracked.
class ClubNight {
  const ClubNight({required this.eventId, required this.title, required this.startDate, this.endDate, required this.trackExits, required this.admitted, required this.exited, required this.inside});

  final String eventId;
  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final bool trackExits;
  final int admitted;
  final int exited;
  final int inside;
}

/// A row of door_club_nights, or null for anything the app cannot read (never guessed).
ClubNight? parseClubNight(Map<String, dynamic> row) {
  final id = row['event_id'];
  final title = row['title'];
  final start = DateTime.tryParse('${row['start_date']}');
  final end = row['end_date'] == null ? null : DateTime.tryParse('${row['end_date']}');
  final track = row['track_exits'];
  final admitted = row['admitted'];
  final exited = row['exited'];
  final inside = row['inside'];
  if (id is! String || title is! String || start == null || track is! bool || admitted is! int || exited is! int || inside is! int) return null;
  return ClubNight(eventId: id, title: title, startDate: start, endDate: end, trackExits: track, admitted: admitted, exited: exited, inside: inside);
}

/// The line under a night's title: how many are in. "Inside now" only where exits are tracked, otherwise "checked in".
String nightFigure(ClubNight n) => n.trackExits ? '${n.inside} inside now · ${n.admitted} checked in · ${n.exited} left' : '${n.admitted} checked in';

/// Every answer an override can end in, all from the database.
enum OverrideResult {
  ok('ok'),
  group('group'),
  tooMany('too_many'),
  noOverrideNeeded('no_override_needed'),
  notPaid('not_paid'),
  refunded('refunded'),
  expired('expired'),
  alreadyCheckedIn('already_checked_in'),
  wrongEvent('wrong_event'),
  notFound('not_found');

  const OverrideResult(this.db);

  final String db;

  static OverrideResult? fromDb(Object? value) {
    if (value is! String) return null;
    for (final r in values) {
      if (r.db == value) return r;
    }
    return null;
  }
}

class OverrideOutcome {
  const OverrideOutcome(this.result, {this.customerName, this.eventTitle, this.tierName, this.quantity, this.admitted, this.remaining});

  final OverrideResult result;
  final String? customerName;
  final String? eventTitle;
  final String? tierName;
  final int? quantity;

  /// Guests of the ticket who are in after this answer, and who may still come in.
  final int? admitted;
  final int? remaining;

  bool get done => result == OverrideResult.ok;

  /// A group ticket: nobody was admitted, the person must choose how many.
  bool get needsCount => result == OverrideResult.group;
}

OverrideOutcome? parseOverrideOutcome(Map<String, dynamic>? row) {
  if (row == null) return null;
  final result = OverrideResult.fromDb(row['result']);
  if (result == null) return null;
  return OverrideOutcome(
    result,
    customerName: row['customer_name'] as String?,
    eventTitle: row['event_title'] as String?,
    tierName: row['tier_name'] as String?,
    quantity: row['quantity'] as int?,
    admitted: row['admitted'] as int?,
    remaining: row['remaining'] as int?,
  );
}

enum OverrideTone { ok, warn, error }

class OverrideCopy {
  const OverrideCopy(this.label, this.hint, this.tone);

  final String label;
  final String hint;
  final OverrideTone tone;
}

/// What an answer tells the manager. A refusal says it is still a refusal: an override is only for the entry code.
OverrideCopy overrideCopy(OverrideOutcome o) => switch (o.result) {
  OverrideResult.ok => OverrideCopy(
    'Admitted',
    '${o.customerName ?? 'The guest'} is in. ${(o.remaining ?? 0) > 0 ? '${o.remaining} more may still come in on this ticket. ' : ''}Your reason is kept.',
    OverrideTone.ok,
  ),
  OverrideResult.group => OverrideCopy('Group ticket', 'This ticket covers ${o.quantity ?? 'several'} guests. Choose how many are coming in now.', OverrideTone.warn),
  OverrideResult.tooMany => OverrideCopy('More than this ticket allows', 'Only ${o.remaining ?? 0} may still come in. Choose fewer.', OverrideTone.warn),
  OverrideResult.noOverrideNeeded => const OverrideCopy('No override needed', 'Nothing is holding this ticket back. The door can scan it as usual.', OverrideTone.warn),
  OverrideResult.notPaid => const OverrideCopy('Not paid', 'An override cannot admit an unpaid order.', OverrideTone.error),
  OverrideResult.refunded => const OverrideCopy('Refunded', 'An override cannot admit a refunded order.', OverrideTone.error),
  OverrideResult.expired => const OverrideCopy('Event has ended', 'An override cannot admit a guest to an event that is over.', OverrideTone.error),
  OverrideResult.alreadyCheckedIn => const OverrideCopy('Already checked in', 'Everyone on this ticket is already in.', OverrideTone.warn),
  OverrideResult.wrongEvent => const OverrideCopy('Not for this event', 'This ticket is for a different event.', OverrideTone.error),
  OverrideResult.notFound => const OverrideCopy('Ticket not found', 'This code is not a BottlesUp ticket. Check it and try again.', OverrideTone.error),
};

/// One recorded override.
class OverrideLogEntry {
  const OverrideLogEntry({required this.overriddenAt, required this.customerName, required this.guests, required this.reason, required this.byMe});

  final DateTime overriddenAt;
  final String customerName;
  final int guests;
  final String reason;
  final bool byMe;
}

OverrideLogEntry? parseOverrideLogEntry(Map<String, dynamic> row) {
  final at = DateTime.tryParse('${row['overridden_at']}');
  final name = row['customer_name'];
  final guests = row['guests'];
  final reason = row['reason'];
  final byMe = row['by_me'];
  if (at == null || name is! String || guests is! int || reason is! String || byMe is! bool) return null;
  return OverrideLogEntry(overriddenAt: at, customerName: name, guests: guests, reason: reason, byMe: byMe);
}
