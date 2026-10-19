import 'package:intl/intl.dart';

import '../../ops/logic/ops_json.dart';

/// Seating a guest (the server's Scan tab, and a table's page). Who may seat which table, that it happens once, and that the message to
/// the guest is only ever queued are the database's rules; this file reads what it sends and checks what a person typed.

class BookingMatch {
  const BookingMatch({
    required this.bookingId,
    required this.code,
    required this.customerName,
    required this.tableName,
    required this.guestCount,
    required this.startTime,
    required this.seated,
    required this.isMine,
    required this.canSeat,
    this.serverName,
  });

  final String bookingId;
  final String? code;
  final String customerName;
  final String tableName;
  final int guestCount;

  /// "21:00:00".
  final String? startTime;
  final bool seated;
  final String? serverName;
  final bool isMine;
  final bool canSeat;
}

BookingMatch? parseBookingMatch(Map<String, dynamic> r) {
  final id = opsStr(r, 'booking_id');
  if (id == null) return null;
  return BookingMatch(
    bookingId: id,
    code: opsStr(r, 'confirmation_code'),
    customerName: opsStr(r, 'customer_name') ?? 'Guest',
    tableName: opsStr(r, 'table_name') ?? 'Table',
    guestCount: opsInt(r, 'guest_count'),
    startTime: opsStr(r, 'start_time'),
    seated: opsBool(r, 'seated'),
    serverName: opsStr(r, 'server_name'),
    isMine: opsBool(r, 'is_mine'),
    canSeat: opsBool(r, 'can_seat'),
  );
}

class SeatingState {
  const SeatingState({required this.seated, this.seatedAt, this.method, this.estimateMinutes, this.seatedByName, this.confirmation});

  final bool seated;
  final DateTime? seatedAt;
  final String? method;
  final int? estimateMinutes;
  final String? seatedByName;
  final String? confirmation;
}

SeatingState? parseSeatingState(Map<String, dynamic> r) => SeatingState(
      seated: opsBool(r, 'seated'),
      seatedAt: opsTime(r, 'seated_at'),
      method: opsStr(r, 'method'),
      estimateMinutes: r['estimate_minutes'] == null ? null : opsInt(r, 'estimate_minutes'),
      seatedByName: opsStr(r, 'seated_by_name'),
      confirmation: opsStr(r, 'confirmation'),
    );

class SeatOutcome {
  const SeatOutcome({required this.already, this.estimateMinutes});

  /// The guest was seated before this tap: nothing changed and nothing was sent.
  final bool already;
  final int? estimateMinutes;
}

SeatOutcome parseSeatOutcome(Object? data) {
  final m = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  return SeatOutcome(already: opsBool(m, 'already'), estimateMinutes: m['estimate_minutes'] == null ? null : opsInt(m, 'estimate_minutes'));
}

class GuestMessage {
  const GuestMessage({required this.kind, required this.status, this.createdAt, this.sentAt, this.lastError});

  final String kind;
  final String status;
  final DateTime? createdAt;
  final DateTime? sentAt;
  final String? lastError;

  String get kindLabel => switch (kind) {
        'seated_ack' => 'Arrival confirmation',
        'estimate_updated' => 'Service estimate update',
        _ => kind,
      };

  /// What the guest has actually had. "Queued" is never worded as delivered.
  String get statusLabel => switch (status) {
        'sent' => 'Sent',
        'failed' => 'Failed${lastError == null ? '' : ': $lastError'}',
        _ => 'Queued, not sent yet',
      };
}

GuestMessage? parseGuestMessage(Map<String, dynamic> r) {
  final kind = opsStr(r, 'kind');
  if (kind == null) return null;
  return GuestMessage(
    kind: kind,
    status: opsStr(r, 'status') ?? 'queued',
    createdAt: opsTime(r, 'created_at'),
    sentAt: opsTime(r, 'sent_at'),
    lastError: opsStr(r, 'last_error'),
  );
}

// ---------------------------------------------------------------------------
// What a person types or scans
// ---------------------------------------------------------------------------
/// The booking code in what the camera read. The booking's QR carries its confirmation code; a link that ends in the code is accepted too.
String normalizeBookingCode(String scanned) {
  var t = scanned.trim();
  final q = Uri.tryParse(t)?.queryParameters['code'];
  if (q != null && q.trim().isNotEmpty) {
    t = q.trim();
  } else if (t.contains('/')) {
    t = t.split('/').where((s) => s.isNotEmpty).lastOrNull ?? t;
  }
  return t.length > 60 ? t.substring(0, 60) : t;
}

/// The search box: a booking code or at least 3 letters of a name.
String? checkSearch(String text) {
  final t = text.trim();
  if (t.length < 3) return 'Type at least 3 letters of the name, or the booking code.';
  if (t.length > 60) return 'That is too long to be a name or a booking code.';
  return null;
}

const int minEstimate = 1;
const int maxEstimate = 480;

/// An estimate in minutes: empty means none. Returns the minutes (or null for none) or what is wrong.
({int? minutes, String? error}) checkEstimate(String text) {
  final t = text.trim();
  if (t.isEmpty) return (minutes: null, error: null);
  final n = int.tryParse(t);
  if (n == null || n < minEstimate || n > maxEstimate) {
    return (minutes: null, error: 'Enter the estimate in minutes, between $minEstimate and $maxEstimate.');
  }
  return (minutes: n, error: null);
}

/// What was checked with the guest when a booking is found by name, not by its code.
String? checkManualDetail(String text) {
  final t = text.trim();
  if (t.length < 3) return 'Say what you checked with the guest, for example the email or the last digits of their phone.';
  if (t.length > 300) return 'Keep it to 300 characters or fewer.';
  return null;
}

String estimateLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "9:42 PM" for a moment, in the phone's own time.
String clockLabel(DateTime t) => DateFormat('h:mm a').format(t.toLocal());

/// "9:00 PM" from the database's "21:00:00".
String startLabel(String? time) {
  if (time == null || time.length < 5) return '';
  final h = int.tryParse(time.substring(0, 2));
  final m = int.tryParse(time.substring(3, 5));
  if (h == null || m == null) return '';
  return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
}
