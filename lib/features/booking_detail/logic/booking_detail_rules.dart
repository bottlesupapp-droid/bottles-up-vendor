import '../../owner/logic/setup_forms.dart' show formatDollars;
import '../../table_service/logic/table_service_rules.dart' show ServiceState;

// A booking's Guests and Activity tabs (developer brief 15 Oct, section 14). Pure Dart, tested without a screen. The database decides who may see
// them (website: desk_booking_guests, desk_booking_activity, 20261020110000_booking_guests_and_activity.sql) and never sends an e-mail address or a
// phone number; staff are named by profile name only.

class BookingGuest {
  const BookingGuest({required this.id, required this.name, required this.ticketSent, required this.checkedInAt});

  final String id;
  final String name;

  /// The guest's ticket was e-mailed to them.
  final bool ticketSent;

  /// Null until they are admitted at the door.
  final DateTime? checkedInAt;

  bool get isIn => checkedInAt != null;
}

class BookingGuests {
  const BookingGuests({
    required this.holderName,
    required this.holderCheckedInAt,
    required this.partySize,
    required this.maxGuests,
    required this.tableName,
    required this.guests,
    required this.guestsLeft,
  });

  final String holderName;
  final DateTime? holderCheckedInAt;

  /// The party the booking was made for.
  final int partySize;

  /// The table's guest limit: the holder and the invited guests together fit it.
  final int maxGuests;
  final String tableName;
  final List<BookingGuest> guests;

  /// How many more guests can still be invited.
  final int guestsLeft;

  bool get holderIsIn => holderCheckedInAt != null;
  int get guestsIn => guests.where((g) => g.isIn).length;
}

DateTime? _time(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

BookingGuests? parseBookingGuests(Map<String, dynamic> row) {
  final name = row['holder_name']?.toString();
  if (name == null) return null;
  final raw = row['guests'];
  return BookingGuests(
    holderName: name,
    holderCheckedInAt: _time(row['holder_checked_in_at']),
    partySize: _int(row['party_size']),
    maxGuests: _int(row['max_guests']),
    tableName: row['table_name']?.toString() ?? '',
    guestsLeft: _int(row['guests_left']),
    guests: [
      if (raw is List)
        for (final g in raw)
          if (g is Map && g['id'] != null && g['name'] != null)
            BookingGuest(id: '${g['id']}', name: '${g['name']}', ticketSent: g['ticket_sent'] == true, checkedInAt: _time(g['checked_in_at'])),
    ],
  );
}

/// "Party of 4 · table limit 6 · 2 more guests can be invited".
String allowanceLine(BookingGuests g) {
  final left = g.guestsLeft == 0 ? 'no more guests can be invited' : '${g.guestsLeft} more ${g.guestsLeft == 1 ? 'guest' : 'guests'} can be invited';
  return 'Party of ${g.partySize} · table limit ${g.maxGuests} · $left';
}

/// Who is in: "1 of 3 guests in". The holder is shown on their own line.
String guestsInLine(BookingGuests g) => g.guests.isEmpty ? 'No guests invited yet.' : '${g.guestsIn} of ${g.guests.length} ${g.guests.length == 1 ? 'guest' : 'guests'} in';

const String admissionNote =
    'The booking holder and each invited guest are admitted at the door with their own code. A reservation does not admit anyone without one.';

// ---------------------------------------------------------------------------------------------------------------------------------------
// Activity
// ---------------------------------------------------------------------------------------------------------------------------------------

class ActivityEntry {
  const ActivityEntry({required this.at, required this.kind, required this.action, required this.actor, required this.details});

  final DateTime at;

  /// 'audit' (a recorded action) or 'scan' (a door scan).
  final String kind;
  final String action;

  /// A profile name, or "Staff member". Never an e-mail address.
  final String actor;
  final Map<String, dynamic> details;
}

ActivityEntry? parseActivityEntry(Map<String, dynamic> row) {
  final at = _time(row['at']);
  final action = row['action']?.toString();
  if (at == null || action == null || action.isEmpty) return null;
  final details = row['details'];
  return ActivityEntry(
    at: at,
    kind: row['kind']?.toString() ?? 'audit',
    action: action,
    actor: (row['actor']?.toString().trim().isNotEmpty ?? false) ? row['actor'].toString().trim() : 'Staff member',
    details: details is Map ? Map<String, dynamic>.from(details) : const {},
  );
}

String _service(Object? v) => ServiceState.fromDb(v)?.label ?? 'another step';

String _method(Object? v) => switch ('$v') {
      'cash' => 'cash',
      'debit' => 'debit card',
      'credit' => 'credit card',
      'split' => 'a split payment',
      _ => 'a payment',
    };

/// What happened, in a sentence. An action this version does not know is still shown, in plain words made from its name, never hidden.
String activitySentence(ActivityEntry e) {
  final d = e.details;
  switch (e.action) {
    case 'table_booking.club_payment_recorded':
      final paid = d['amount_paid_cents'];
      return paid is num ? '${formatDollars(paid.toInt())} recorded as ${_method(d['payment_method'])}' : 'A payment was recorded';
    case 'table_booking.club_payment_manager_verified':
      return 'A payment was verified by a manager';
    case 'payment.flagged':
      return 'A payment was flagged for a second look';
    case 'payment.flag_resolved':
      final r = d['resolution'];
      return r == null ? 'A flagged payment was resolved' : 'A flagged payment was resolved (${'$r'.replaceAll('_', ' ')})';
    case 'table_booking.bottle_service_status_updated':
      return 'A bottle order moved from ${_service(d['old_status'])} to ${_service(d['new_status'])}';
    case 'booking.seated':
      return d['estimate_minutes'] is num ? 'The guest was seated. Estimate: ${_minutes(d['estimate_minutes'])}' : 'The guest was seated';
    case 'booking.estimate_set':
      final to = d['to_minutes'] ?? d['estimate_minutes'];
      return to is num ? 'The service estimate was set to ${_minutes(to)}' : 'The service estimate was changed';
    case 'booking.unseated':
      final reason = d['reason'];
      return reason == null ? 'Seating was undone' : 'Seating was undone: $reason';
    case 'booking.moved':
      final why = d['reason'];
      return why == null ? 'The booking was moved to another table' : 'The booking was moved to another table: $why';
    case 'booking.server_assigned':
      return 'The table was given to a server';
    case 'booking.server_reassigned':
      return 'The table was given to a different server';
    case 'booking.server_removed':
      return 'The table was taken off its server';
    case 'table_booking.resent':
      return 'The confirmation e-mail was sent again';
    case 'scan.ok':
      return d['guest'] == true ? 'A guest was scanned in at the door' : 'The booking holder was scanned in at the door';
    case 'scan.already_checked_in':
      return d['guest'] == true ? 'A guest\'s code was scanned again (already in)' : 'The holder\'s code was scanned again (already in)';
    case 'scan.not_paid':
      return 'A scan was refused: the booking is not paid';
    case 'scan.expired':
      return 'A scan was refused: the booking has expired';
    case 'scan.not_found':
      return 'A code that does not match was scanned';
    case 'scan.code_required':
      return 'A scan was held: the entry code is needed';
    default:
      final words = e.action.replaceAll(RegExp(r'[._]+'), ' ').trim();
      return words.isEmpty ? 'Something happened' : words[0].toUpperCase() + words.substring(1);
  }
}

String _minutes(Object? v) {
  final n = (v as num).toInt();
  if (n < 60) return '$n ${n == 1 ? 'minute' : 'minutes'}';
  final h = n ~/ 60, m = n % 60;
  return m == 0 ? '$h ${h == 1 ? 'hour' : 'hours'}' : '$h h $m min';
}
