import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/door_rules.dart';

/// Loading events or guests failed. Carries what the screen needs to say, not a stack trace.
class DoorLoadException implements Exception {
  const DoorLoadException({required this.unavailable, required this.accessEnded});

  /// The backend has not been given the door scanner migration yet. Nothing the person at the door can fix.
  final bool unavailable;

  /// The database says this person no longer holds a door role (shift over, removed, signed out).
  final bool accessEnded;

  String get message => doorLoadMessage(unavailable: unavailable, accessEnded: accessEnded);

  @override
  String toString() => 'DoorLoadException($message)';
}

String _messageOf(Object error) => error is PostgrestException ? error.message : error.toString();

bool _isMissingFunction(Object error) =>
    error is PostgrestException && (error.code == '42883' || error.code == 'PGRST202' || error.code == '42P01');

/// The door scanner's calls to the website's database functions (door_events, door_scan_ticket, door_verify_ticket_code,
/// door_guests). Those functions check, in the database, that the signed-in person holds a door role for the event, so
/// nothing here decides who may admit whom.
///
/// A scan must always end in something the person at the door can act on, so [scan] and [verifyCode] never throw: a failure
/// becomes a [ScanOutcome] ("your access has ended", "scan failed") instead of a stuck screen.
class DoorService {
  DoorService({SupabaseClient? client, RpcCaller? rpc})
      : _client = client,
        _rpcOverride = rpc;

  final SupabaseClient? _client;
  final RpcCaller? _rpcOverride;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<dynamic> _rpc(String function, {Map<String, dynamic>? params}) async {
    final override = _rpcOverride;
    if (override != null) return override(function, params: params);
    return await _db.rpc(function, params: params);
  }

  List<Map<String, dynamic>> _rows(dynamic data) {
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  Future<List<Map<String, dynamic>>> _load(String function, Map<String, dynamic> params) async {
    try {
      return _rows(await _rpc(function, params: params));
    } catch (error) {
      throw DoorLoadException(
        unavailable: _isMissingFunction(error),
        accessEnded: outcomeFromErrorMessage(_messageOf(error)) == DoorResult.accessEnded,
      );
    }
  }

  /// The events this door workspace can work now (running, starting soon, or just finished), with how many guests are in. The count comes from
  /// door_admission_counts where the server has it (a partly admitted group counts only the guests who came in); otherwise door_events' own figure stands.
  Future<List<DoorEvent>> events(String membershipId) async {
    final rows = await _load('door_events', {'p_membership': membershipId});
    final events = rows.map(parseDoorEvent).whereType<DoorEvent>().toList();
    if (events.isEmpty || _countsMissing) return events;
    try {
      final counts = <String, int>{
        for (final r in _rows(await _rpc('door_admission_counts', params: {'p_events': [for (final e in events) e.eventId]})))
          if (r['event_id'] is String && r['guests_admitted'] is int) r['event_id'] as String: r['guests_admitted'] as int,
      };
      return [for (final e in events) counts.containsKey(e.eventId) ? e.withAdmitted(counts[e.eventId]!) : e];
    } catch (error) {
      if (_isMissingFunction(error)) _countsMissing = true;
      return events;
    }
  }

  /// Whether the server has group admission (website 20261020170000). Null until the first scan finds out; once it is known to be missing the older scan
  /// is used straight away. The exact counts and the guest list's counts come with the same migration but are tracked on their own, so one missing function never
  /// changes how a ticket is scanned.
  bool? _groupAvailable;
  bool _countsMissing = false;
  bool _admissionsMissing = false;

  /// Scans a ticket for the selected event. A ticket for ONE guest is admitted at once. A ticket for several guests answers [DoorResult.group] and admits
  /// nobody until the person chooses how many with [admit]. On a server without group admission this is the older whole-order scan.
  Future<ScanOutcome> scan(String ticketCode, String eventId) async {
    final code = normalizeScan(ticketCode);
    if (code.isEmpty) return const ScanOutcome(DoorResult.scanError);
    if (_groupAvailable != false) {
      try {
        final rows = _rows(await _rpc('door_admit_group', params: {'p_ticket_code': code, 'p_count': null, 'p_event': eventId}));
        _groupAvailable = true;
        return parseScanOutcome(rows.isEmpty ? null : rows.first);
      } catch (error) {
        if (!_isMissingFunction(error)) return ScanOutcome(outcomeFromErrorMessage(_messageOf(error)));
        _groupAvailable = false;
      }
    }
    try {
      final rows = _rows(await _rpc('door_scan_ticket', params: {'p_ticket_code': code, 'p_event': eventId}));
      return parseScanOutcome(rows.isEmpty ? null : rows.first);
    } catch (error) {
      return ScanOutcome(outcomeFromErrorMessage(_messageOf(error)));
    }
  }

  /// Admits [count] guests of a ticket for several guests. The database refuses more than the ticket has left ([DoorResult.tooMany]) and never admits a guest
  /// twice, whatever is sent. Never throws, like [scan].
  Future<ScanOutcome> admit(String ticketCode, int count, String eventId) async {
    final code = normalizeScan(ticketCode);
    if (code.isEmpty || count < 1) return const ScanOutcome(DoorResult.scanError);
    try {
      final rows = _rows(await _rpc('door_admit_group', params: {'p_ticket_code': code, 'p_count': count, 'p_event': eventId}));
      final outcome = parseScanOutcome(rows.isEmpty ? null : rows.first);
      return outcome.admitted ? outcome.withAdmittedNow(count) : outcome;
    } catch (error) {
      return ScanOutcome(outcomeFromErrorMessage(_messageOf(error)));
    }
  }

  /// How many guests of each ticket order of the event are in (only orders admitted through group admission), by order id. Empty when the server does not
  /// have it: the list then relies on the older "checked in" time.
  Future<Map<String, int>> guestAdmissions(String eventId) async {
    if (_admissionsMissing) return const {};
    try {
      return {
        for (final r in _rows(await _rpc('door_guest_admissions', params: {'p_event': eventId})))
          if (r['order_id'] is String && r['admitted'] is int) r['order_id'] as String: r['admitted'] as int,
      };
    } catch (error) {
      if (_isMissingFunction(error)) _admissionsMissing = true;
      return const {};
    }
  }

  /// The entry code for a non-transferable ticket.
  Future<ScanOutcome> verifyCode(String ticketCode, String entryCode, String eventId) async {
    final code = normalizeScan(ticketCode);
    if (code.isEmpty) return const ScanOutcome(DoorResult.scanError);
    try {
      final rows = _rows(await _rpc('door_verify_ticket_code', params: {
        'p_ticket_code': code,
        'p_code': entryCode.trim(),
        'p_event': eventId,
      }));
      return parseScanOutcome(rows.isEmpty ? null : rows.first);
    } catch (error) {
      return ScanOutcome(outcomeFromErrorMessage(_messageOf(error)));
    }
  }

  /// Paid guests of the event matching a name or ticket code. At least two characters; the database caps the answer at 50.
  Future<List<Guest>> guests(String eventId, String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final rows = await _load('door_guests', {'p_event': eventId, 'p_query': q});
    final guests = rows.map(parseGuest).whereType<Guest>().toList();
    if (guests.isEmpty) return guests;
    final admitted = await guestAdmissions(eventId);
    if (admitted.isEmpty) return guests;
    return [for (final g in guests) admitted.containsKey(g.orderId) ? g.withAdmittedKeepingTime(admitted[g.orderId]!) : g];
  }
}
