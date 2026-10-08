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

  /// The events this door workspace can work now (running, starting soon, or just finished), with how many guests are in.
  Future<List<DoorEvent>> events(String membershipId) async {
    final rows = await _load('door_events', {'p_membership': membershipId});
    return rows.map(parseDoorEvent).whereType<DoorEvent>().toList();
  }

  /// Admits a ticket for the selected event.
  Future<ScanOutcome> scan(String ticketCode, String eventId) async {
    final code = normalizeScan(ticketCode);
    if (code.isEmpty) return const ScanOutcome(DoorResult.scanError);
    try {
      final rows = _rows(await _rpc('door_scan_ticket', params: {'p_ticket_code': code, 'p_event': eventId}));
      return parseScanOutcome(rows.isEmpty ? null : rows.first);
    } catch (error) {
      return ScanOutcome(outcomeFromErrorMessage(_messageOf(error)));
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
    return rows.map(parseGuest).whereType<Guest>().toList();
  }
}
