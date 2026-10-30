// The server's desk (Phase 2 brief, sections 12, 13 and 17): a manager gives a booking to a server, a server sees their own tables,
// and the staff deal with requests from a table (water, ice, the bill). Pure Dart, tested without a screen. The database decides
// who may do what (website repo, 20261014100000_table_servers.sql and 20261014110000_service_requests.sql); this file only knows
// the words, the shapes of the answers and which buttons make sense for a request, so the screen never offers a move the database
// would refuse. A test reads the SQL (when the website repo is checked out beside this app) and fails if the lists differ.

import '../../team/logic/team_rules.dart' show MemberState, TeamMember;

// ---------------------------------------------------------------------------
// What a table can ask for, and where a request stands
// ---------------------------------------------------------------------------

enum ServiceKind {
  assistance('assistance', 'Server assistance'),
  waterIceMixers('water_ice_mixers', 'Water, ice or mixers'),
  orderQuestion('order_question', 'Question about the order'),
  billRequest('bill_request', 'Bill request'),
  tableIssue('table_issue', 'Table issue');

  const ServiceKind(this.value, this.label);

  /// As the database stores it.
  final String value;
  final String label;

  static ServiceKind? fromDb(Object? v) {
    for (final k in values) {
      if (k.value == v) return k;
    }
    return null;
  }
}

enum RequestStatus {
  fresh('new', 'New'),
  acknowledged('acknowledged', 'Acknowledged'),
  inProgress('in_progress', 'In progress'),
  completed('completed', 'Completed'),
  escalated('escalated', 'Escalated'),
  cancelled('cancelled', 'Cancelled');

  const RequestStatus(this.value, this.label);

  final String value;
  final String label;

  /// Still needs somebody: not completed and not cancelled.
  bool get isOpen => this != completed && this != cancelled;

  static RequestStatus? fromDb(Object? v) {
    for (final s in values) {
      if (s.value == v) return s;
    }
    return null;
  }
}

/// The moves a person can make with a reason or nothing more. Handing a request to someone else (`reassign`, a manager's) needs a person instead: see [reassignParams].
enum RequestAction {
  acknowledge('acknowledge', 'Take it', needsReason: false),
  start('start', 'Start', needsReason: false),
  complete('complete', 'Done', needsReason: false),
  escalate('escalate', 'Pass to a manager', needsReason: true),
  cancel('cancel', 'Cancel request', needsReason: true);

  const RequestAction(this.value, this.label, {required this.needsReason});

  final String value;
  final String label;

  /// The database refuses these without a reason, so the screen asks for one first.
  final bool needsReason;
}

/// The longest note or reason the database accepts.
const int noteLimit = 300;

/// A sentence about what is wrong with a reason, or null when it is fine. Escalating and cancelling need one.
String? validateReason(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'Say why.';
  if (t.length > noteLimit) return 'Keep it to $noteLimit characters or fewer.';
  return null;
}

/// A sentence about what is wrong with the optional note on a new request, or null when it is fine.
String? validateNote(String text) => text.trim().length > noteLimit ? 'Keep it to $noteLimit characters or fewer.' : null;

// ---------------------------------------------------------------------------
// A request, as the database lists it
// ---------------------------------------------------------------------------

class ServiceRequestRow {
  const ServiceRequestRow({
    required this.requestId,
    required this.bookingId,
    required this.confirmationCode,
    required this.customerName,
    required this.tableName,
    required this.guestCount,
    required this.kind,
    required this.note,
    required this.status,
    required this.assignedMembershipId,
    required this.assignedToMe,
    required this.createdAt,
    required this.acknowledgedAt,
    required this.closedAt,
    required this.statusNote,
  });

  final String requestId;
  final String bookingId;
  final String? confirmationCode;
  final String customerName;
  final String tableName;
  final int guestCount;
  final ServiceKind kind;
  final String? note;
  final RequestStatus status;
  final String? assignedMembershipId;
  final bool assignedToMe;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? closedAt;

  /// Why it was escalated or cancelled, or a remark on completion.
  final String? statusNote;
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int _int(Object? v) => v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : 0);
DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// One `list_service_requests` row. A row with no id, an unknown kind or status, or no creation time is dropped rather than
/// guessed at: showing an unknown status as if it were New would hide that it needs attention elsewhere.
ServiceRequestRow? parseServiceRequestRow(Map<String, dynamic> r) {
  final id = r['request_id'];
  final booking = r['booking_id'];
  final kind = ServiceKind.fromDb(r['kind']);
  final status = RequestStatus.fromDb(r['status']);
  final created = _time(r['created_at']);
  if (id is! String || id.isEmpty || booking is! String || booking.isEmpty || kind == null || status == null || created == null) return null;
  return ServiceRequestRow(
    requestId: id,
    bookingId: booking,
    confirmationCode: _text(r['confirmation_code']),
    customerName: _text(r['customer_name']) ?? '',
    tableName: _text(r['table_name']) ?? '',
    guestCount: _int(r['guest_count']),
    kind: kind,
    note: _text(r['note']),
    status: status,
    assignedMembershipId: _text(r['assigned_membership_id']),
    assignedToMe: r['assigned_to_me'] == true,
    createdAt: created,
    acknowledgedAt: _time(r['acknowledged_at']),
    closedAt: _time(r['closed_at']),
    statusNote: _text(r['status_note']),
  );
}

/// The buttons that make sense for a request, the most likely first. These are the moves the database accepts for this person:
///  * a server can act on a request that is theirs (or that nobody has) and cannot touch one passed to a manager;
///  * a manager or owner can act on any open request, and can take over one that was passed up.
/// The database checks all of it again; this keeps the screen from offering what would be refused.
List<RequestAction> availableActions(ServiceRequestRow r, {required bool manager}) {
  if (!r.status.isOpen) return const [];
  if (!manager) {
    // Somebody else's request is not offered. (The database does not list those to a server, so this is a second line.)
    if (r.assignedMembershipId != null && !r.assignedToMe) return const [];
    switch (r.status) {
      case RequestStatus.fresh:
        return const [RequestAction.acknowledge, RequestAction.complete, RequestAction.escalate, RequestAction.cancel];
      case RequestStatus.acknowledged:
        return const [RequestAction.start, RequestAction.complete, RequestAction.escalate, RequestAction.cancel];
      case RequestStatus.inProgress:
        return const [RequestAction.complete, RequestAction.escalate, RequestAction.cancel];
      default:
        return const [];
    }
  }
  switch (r.status) {
    case RequestStatus.fresh:
      return const [RequestAction.acknowledge, RequestAction.complete, RequestAction.cancel];
    case RequestStatus.acknowledged:
      return const [RequestAction.start, RequestAction.complete, RequestAction.cancel];
    case RequestStatus.inProgress:
      return const [RequestAction.complete, RequestAction.cancel];
    case RequestStatus.escalated:
      return const [RequestAction.acknowledge, RequestAction.complete, RequestAction.cancel];
    default:
      return const [];
  }
}

/// Who has it, in words a server can use: "You", "A colleague" or "Nobody yet". A server is not told a colleague's name or email.
String holderLabel(ServiceRequestRow r) {
  if (r.assignedToMe) return 'You';
  if (r.assignedMembershipId != null) return 'A colleague';
  return 'Nobody yet';
}

/// A manager (or the owner) can hand any OPEN request to a server of the club, including one that was passed up to them. The database checks it again:
/// only a manager, only a person who is staff at this club and still has access.
bool canHandOver(ServiceRequestRow r, {required bool manager}) => manager && r.status.isOpen;

/// Who has it, for a manager, who is told names: "You", the person's name or e-mail when the team list knows them, otherwise as [holderLabel].
String holderLabelFor(ServiceRequestRow r, Iterable<TeamMember> team) {
  if (r.assignedToMe) return 'You';
  final id = r.assignedMembershipId;
  if (id != null) {
    for (final m in team) {
      if (m.membershipId == id) return _personLabel(m);
    }
  }
  return holderLabel(r);
}

/// How long a request has been waiting: "just now", "5 min", "1 h 20 min", "3 days".
String waitingLabel(DateTime since, DateTime now) {
  final d = now.difference(since);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) {
    final m = d.inMinutes % 60;
    return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
  }
  final days = d.inDays;
  return '$days ${days == 1 ? 'day' : 'days'}';
}

/// The open requests of each booking, for showing under a table.
Map<String, List<ServiceRequestRow>> openByBooking(Iterable<ServiceRequestRow> rows) {
  final out = <String, List<ServiceRequestRow>>{};
  for (final r in rows) {
    if (r.status.isOpen) out.putIfAbsent(r.bookingId, () => []).add(r);
  }
  return out;
}

// ---------------------------------------------------------------------------
// A server's tables
// ---------------------------------------------------------------------------

class AssignedTable {
  const AssignedTable({
    required this.bookingId,
    required this.venueId,
    required this.venueName,
    required this.nightDate,
    required this.startTime,
    required this.slotLabel,
    required this.tableName,
    required this.guestCount,
    required this.customerName,
    required this.confirmationCode,
    required this.checkedInAt,
  });

  final String bookingId;
  final String venueId;
  final String venueName;

  /// The business night this booking belongs to.
  final String nightDate;

  /// "21:00:00".
  final String startTime;
  final String? slotLabel;
  final String tableName;
  final int guestCount;
  final String customerName;
  final String? confirmationCode;
  final DateTime? checkedInAt;

  bool get arrived => checkedInAt != null;
}

/// One `my_assigned_tables` row. The answer carries no email or phone for the guest; a row without an id, a club or a night is dropped.
AssignedTable? parseAssignedTable(Map<String, dynamic> r) {
  final id = r['booking_id'];
  final venue = r['venue_id'];
  final night = r['night_date'];
  if (id is! String || id.isEmpty || venue is! String || venue.isEmpty || night is! String || night.isEmpty) return null;
  return AssignedTable(
    bookingId: id,
    venueId: venue,
    venueName: _text(r['venue_name']) ?? '',
    nightDate: night,
    startTime: _text(r['start_time']) ?? '',
    slotLabel: _text(r['slot_label']),
    tableName: _text(r['table_name']) ?? '',
    guestCount: _int(r['guest_count']),
    customerName: _text(r['customer_name']) ?? '',
    confirmationCode: _text(r['confirmation_code']),
    checkedInAt: _time(r['checked_in_at']),
  );
}

// ---------------------------------------------------------------------------
// Who has which booking (the manager's side)
// ---------------------------------------------------------------------------

class BookingServer {
  const BookingServer({required this.bookingId, required this.membershipId, required this.userId, required this.available});

  final String bookingId;
  final String membershipId;
  final String userId;

  /// False once the server's access was taken away or ended, so the table is nobody's in practice.
  final bool available;
}

/// One `list_venue_booking_servers` row.
BookingServer? parseBookingServer(Map<String, dynamic> r) {
  final booking = r['booking_id'];
  final membership = r['membership_id'];
  if (booking is! String || booking.isEmpty || membership is! String || membership.isEmpty) return null;
  return BookingServer(
    bookingId: booking,
    membershipId: membership,
    userId: _text(r['user_id']) ?? '',
    available: r['server_available'] == true,
  );
}

/// A person a booking can be given to.
class ServerOption {
  const ServerOption({required this.membershipId, required this.label, required this.starts});

  final String membershipId;

  /// The person's name, or their email when they have not given one.
  final String label;

  /// True for a server whose access starts later: they can be given tonight's tables ahead of time.
  final bool starts;
}

String _personLabel(TeamMember m) => _text(m.name) ?? _text(m.email) ?? 'A server';

/// The servers of this club who can be given a booking: active now, or starting later. Revoked and expired people are left out
/// (the database would refuse them). Sorted by name so the list does not move between loads.
List<ServerOption> serverOptions(Iterable<TeamMember> team, String venueId) {
  final out = [
    for (final m in team)
      if (m.role == 'server' && m.venueId == venueId && (m.state == MemberState.active || m.state == MemberState.scheduled))
        ServerOption(membershipId: m.membershipId, label: _personLabel(m), starts: m.state == MemberState.scheduled),
  ];
  out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return out;
}

/// Who has a booking, for the manager's card: the person's name, with a note when they can no longer serve it. A person who is not
/// in the team list at all (removed since) is "A server who no longer has access".
String assignedServerLabel(BookingServer a, Iterable<TeamMember> team) {
  for (final m in team) {
    if (m.membershipId != a.membershipId) continue;
    final name = _personLabel(m);
    return a.available ? name : '$name (access ended)';
  }
  return 'A server who no longer has access';
}

// ---------------------------------------------------------------------------
// What is sent
// ---------------------------------------------------------------------------

/// Arguments of `create_service_request`. A blank note is sent as none.
Map<String, dynamic> askParams(String bookingId, ServiceKind kind, String? note) => {
      'p_booking': bookingId,
      'p_kind': kind.value,
      'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    };

/// Arguments of `update_service_request`.
/// Handing a request to a person. The database puts it back to New, so the new person has to take it themselves.
Map<String, dynamic> reassignParams(String requestId, String membershipId) => {
      'p_request': requestId,
      'p_action': 'reassign',
      'p_assignee': membershipId,
    };

Map<String, dynamic> actParams(String requestId, RequestAction action, String? note) => {
      'p_request': requestId,
      'p_action': action.value,
      'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    };

// ---------------------------------------------------------------------------
// Wording for a failed load
// ---------------------------------------------------------------------------

String deskLoadMessage({required bool unavailable, required bool accessEnded, required String what}) {
  if (unavailable) return '${_capital(what)} are not set up on this server yet.';
  if (accessEnded) return 'Your access has ended, or you are signed out.';
  return '${_capital(what)} could not be loaded. Check your connection and try again.';
}

String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
