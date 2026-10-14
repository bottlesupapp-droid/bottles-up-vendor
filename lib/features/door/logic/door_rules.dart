// The rules behind the door scanner (Phase 2 brief, section 18 and "Door" in section 2): what each scan outcome means to the
// person at the door, when a camera read should be acted on, and how to read what the database returns. Pure Dart, so they
// are tested without a camera. Who may admit whom is decided by the database (door_scan_ticket, in the website repo's
// 20261009100000_door_scanner.sql); nothing here grants anything. The wording matches the website's door screen on purpose:
// the same guest must get the same answer from either.

/// Every answer a scan can end in. The first ten come from the database; the last two are raised by the app.
enum DoorResult {
  ok('ok'),
  alreadyCheckedIn('already_checked_in'),
  notPaid('not_paid'),
  notFound('not_found'),
  expired('expired'),
  codeRequired('code_required'),
  codeIncorrect('code_incorrect'),
  codeExpired('code_expired'),
  noCodeRequested('no_code_requested'),
  wrongEvent('wrong_event'),
  accessEnded('access_ended'),
  scanError('scan_error');

  const DoorResult(this.db);

  /// The value stored by the database ("already_checked_in"), or the app's own marker for the last two.
  final String db;

  /// A result the database can return. Null for anything else: an unknown answer is never guessed to be "ok".
  static DoorResult? fromDb(Object? value) {
    if (value is! String) return null;
    for (final r in values) {
      if (r.db == value && r != accessEnded && r != scanError) return r;
    }
    return null;
  }
}

enum Tone { ok, warn, error }

class ResultCopy {
  const ResultCopy(this.label, this.hint, this.tone);

  final String label;

  /// One sentence telling the person what to do next.
  final String hint;
  final Tone tone;
}

const Map<DoorResult, ResultCopy> resultCopy = {
  DoorResult.ok: ResultCopy('Admit', 'Let them in.', Tone.ok),
  DoorResult.alreadyCheckedIn:
      ResultCopy('Already checked in', 'This ticket has already been used. Check with the guest.', Tone.warn),
  DoorResult.notPaid: ResultCopy('Not paid', 'This order was never paid, or was refunded. Do not admit.', Tone.error),
  DoorResult.notFound:
      ResultCopy('Ticket not found', 'This code is not a BottlesUp ticket. Try again or search by name.', Tone.error),
  DoorResult.expired: ResultCopy('Event has ended', 'This ticket is for an event that is over.', Tone.error),
  DoorResult.codeRequired: ResultCopy(
      'Entry code required', 'This ticket is non-transferable. Ask the guest for the 6-digit code from their email.', Tone.warn),
  DoorResult.codeIncorrect: ResultCopy('Code is incorrect', 'Check the code with the guest and try again.', Tone.error),
  DoorResult.codeExpired: ResultCopy(
      'Code expired or locked', 'Ask the guest to request a new code from their ticket email.', Tone.error),
  DoorResult.noCodeRequested: ResultCopy(
      'No code requested yet', 'Ask the guest to request their entry code from their ticket email.', Tone.error),
  DoorResult.wrongEvent:
      ResultCopy('Not for this event', 'This ticket is for a different event. Do not admit it here.', Tone.error),
  DoorResult.accessEnded: ResultCopy('Your access has ended',
      'Your shift or invitation is over, or you were signed out. Sign in again or ask your manager.', Tone.error),
  DoorResult.scanError: ResultCopy('Scan failed', 'Something went wrong. Try again.', Tone.error),
};

/// The outcomes after which the guest should be asked for their entry code.
bool needsEntryCode(DoorResult r) =>
    r == DoorResult.codeRequired ||
    r == DoorResult.codeIncorrect ||
    r == DoorResult.codeExpired ||
    r == DoorResult.noCodeRequested;

/// Only these let the person type a code again. Expired, locked or never requested is final: the guest has to ask for a new one.
bool canRetryCode(DoorResult r) => r == DoorResult.codeRequired || r == DoorResult.codeIncorrect;

// ---------------------------------------------------------------------------
// What a camera read should do
// ---------------------------------------------------------------------------

/// An identical read is ignored for this long, so a ticket still in front of the camera after "Scan next" is not counted twice.
const Duration sameCodeCooldown = Duration(seconds: 5);

/// What was scanned or typed, cleaned up: surrounding spaces removed and a sane length. Empty means nothing to check.
String normalizeScan(String raw) {
  final t = raw.trim();
  return t.length > 200 ? t.substring(0, 200) : t;
}

/// Whether a read should be acted on: not while a check is running, not while a result is showing (the camera keeps reading
/// underneath), not for nothing, and not for the same code again within the cooldown.
bool shouldProcessScan({
  required String code,
  required bool busy,
  required bool paused,
  String? lastCode,
  DateTime? lastAt,
  required DateTime now,
  Duration cooldown = sameCodeCooldown,
}) {
  if (busy || paused) return false;
  if (normalizeScan(code).isEmpty) return false;
  if (lastCode != null && lastAt != null && lastCode == code && now.difference(lastAt) < cooldown) return false;
  return true;
}

// ---------------------------------------------------------------------------
// Reading what the database returns
// ---------------------------------------------------------------------------

class ScanOutcome {
  const ScanOutcome(
    this.result, {
    this.customerName,
    this.eventTitle,
    this.tierName,
    this.quantity,
    this.attemptsRemaining,
  });

  final DoorResult result;
  final String? customerName;
  final String? eventTitle;
  final String? tierName;
  final int? quantity;

  /// Tries left on the entry code, when the database says.
  final int? attemptsRemaining;

  bool get admitted => result == DoorResult.ok;
}

String? _text(Object? v) => v is String && v.isNotEmpty ? v : null;
int? _int(Object? v) => v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);

/// One door_scan_ticket / door_verify_ticket_code row. A result this code does not know is a failed scan, never "ok".
ScanOutcome parseScanOutcome(Map<String, dynamic>? row) {
  final result = DoorResult.fromDb(row?['result']) ?? DoorResult.scanError;
  return ScanOutcome(
    result,
    customerName: _text(row?['customer_name']),
    eventTitle: _text(row?['event_title']),
    tierName: _text(row?['tier_name']),
    quantity: _int(row?['quantity']),
    attemptsRemaining: _int(row?['attempts_remaining']),
  );
}

/// What a failed call means at the door. "Not authorized" is the database saying this person no longer holds a door role
/// (the shift ended, they were removed, or they are signed out); anything else is a failed scan to retry.
DoorResult outcomeFromErrorMessage(String message) {
  return RegExp(r'not authori[sz]ed|access has ended|signed out', caseSensitive: false).hasMatch(message)
      ? DoorResult.accessEnded
      : DoorResult.scanError;
}

class DoorEvent {
  const DoorEvent({
    required this.eventId,
    required this.title,
    required this.venueName,
    required this.startDate,
    this.endDate,
    required this.scope,
    required this.guestsExpected,
    required this.guestsAdmitted,
  });

  final String eventId;
  final String title;
  final String venueName;
  final DateTime startDate;
  final DateTime? endDate;

  /// 'event' when the person is assigned to this event directly, 'venue' when they cover the club.
  final String scope;
  final int guestsExpected;
  final int guestsAdmitted;
}

DoorEvent? parseDoorEvent(Map<String, dynamic> row) {
  final id = row['event_id'];
  final title = row['title'];
  final start = row['start_date'] is String ? DateTime.tryParse(row['start_date'] as String) : null;
  if (id is! String || title is! String || start == null) return null;
  return DoorEvent(
    eventId: id,
    title: title,
    venueName: _text(row['venue_name']) ?? '',
    startDate: start,
    endDate: row['end_date'] is String ? DateTime.tryParse(row['end_date'] as String) : null,
    scope: row['scope'] == 'event' ? 'event' : 'venue',
    guestsExpected: _int(row['guests_expected']) ?? 0,
    guestsAdmitted: _int(row['guests_admitted']) ?? 0,
  );
}

class Guest {
  const Guest({
    required this.orderId,
    required this.name,
    required this.ticketCode,
    required this.tierName,
    required this.quantity,
    this.checkedInAt,
    required this.needsCode,
  });

  final String orderId;
  final String name;
  final String ticketCode;
  final String tierName;
  final int quantity;
  final DateTime? checkedInAt;
  final bool needsCode;

  bool get isIn => checkedInAt != null;
}

Guest? parseGuest(Map<String, dynamic> row) {
  final order = row['order_id'];
  final code = row['ticket_code'];
  if (order is! String || code is! String) return null;
  return Guest(
    orderId: order,
    name: _text(row['customer_name']) ?? 'Guest',
    ticketCode: code,
    tierName: _text(row['tier_name']) ?? '',
    quantity: _int(row['quantity']) ?? 1,
    checkedInAt: row['checked_in_at'] is String ? DateTime.tryParse(row['checked_in_at'] as String) : null,
    needsCode: row['needs_code'] == true,
  );
}

// ---------------------------------------------------------------------------
// Wording
// ---------------------------------------------------------------------------

/// "12 of 80 guests in".
String admittedSummary(DoorEvent e) =>
    '${e.guestsAdmitted} of ${e.guestsExpected} guest${e.guestsExpected == 1 ? '' : 's'} in';

/// 0 to 100, a whole number, never above 100 and 0 when nobody is expected.
int admittedPercent(DoorEvent e) {
  if (e.guestsExpected <= 0) return 0;
  final p = (e.guestsAdmitted / e.guestsExpected * 100).round();
  return p > 100 ? 100 : p;
}

/// The event a screen should start on: one that is already running, otherwise the next to start.
DoorEvent? defaultEvent(List<DoorEvent> events, {DateTime? now}) {
  if (events.isEmpty) return null;
  final at = now ?? DateTime.now();
  for (final e in events) {
    if (!e.startDate.isAfter(at)) return e;
  }
  return events.first;
}

/// The sentence for a failed load of events or guests (a scan itself never throws; see the service).
String doorLoadMessage({required bool unavailable, required bool accessEnded}) {
  if (unavailable) return 'Door scanning is not set up on this server yet.';
  if (accessEnded) return 'Your access has ended, or you are signed out.';
  return 'This could not be loaded. Check your connection and try again.';
}
