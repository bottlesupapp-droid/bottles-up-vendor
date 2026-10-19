import 'package:supabase_flutter/supabase_flutter.dart';

import '../../floor/logic/bookings_rules.dart' show NightRange, validateRange, parseNight;
import '../../owner/services/db_errors.dart';
import '../../team/services/team_service.dart' show sentence;
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/server_desk_rules.dart';

/// Loading something for the server's desk failed. Carries what the screen needs to say, not a stack trace.
class ServerDeskLoadException implements Exception {
  const ServerDeskLoadException({required this.unavailable, required this.accessEnded, required this.what});

  /// The backend has not been given the migration yet. Nothing the person can fix.
  final bool unavailable;

  /// The database says this person no longer has access (removed, access ended, signed out).
  final bool accessEnded;

  /// What was being loaded, in the plural: "tables", "requests".
  final String what;

  String get message => deskLoadMessage(unavailable: unavailable, accessEnded: accessEnded, what: what);

  @override
  String toString() => 'ServerDeskLoadException($message)';
}

/// A request, a move on a request, or giving a table to a server was refused or failed; the message is a plain sentence.
class ServerDeskActionException implements Exception {
  const ServerDeskActionException(this.message);

  final String message;

  @override
  String toString() => 'ServerDeskActionException($message)';
}

/// The server desk's calls to the website's database functions: `my_assigned_tables`, `list_service_requests`,
/// `create_service_request`, `update_service_request`, `list_venue_booking_servers`, `assign_booking_server` and
/// `unassign_booking_server` (website repo, 20261014100000_table_servers.sql and 20261014110000_service_requests.sql). The
/// database checks who may do what (a server sees only their own tables and requests, only a manager of that club gives a table
/// out); nothing here decides that.
class ServerDeskService {
  ServerDeskService({SupabaseClient? client, RpcCaller? rpc})
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

  List<Map<String, dynamic>> _rows(dynamic data) => data is List
      ? [
          for (final r in data)
            if (r is Map) Map<String, dynamic>.from(r),
        ]
      : const [];

  Future<List<T>> _list<T>(String function, Map<String, dynamic> params, T? Function(Map<String, dynamic>) parse, String what) async {
    try {
      return _rows(await _rpc(function, params: params)).map(parse).whereType<T>().toList();
    } catch (error) {
      throw ServerDeskLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error), what: what);
    }
  }

  Future<T> _act<T>(Future<T> Function() call, {String generic = 'This could not be done. Check your connection and try again.'}) async {
    try {
      return await call();
    } on ServerDeskActionException {
      rethrow;
    } catch (error) {
      throw ServerDeskActionException(sentence(actionMessage(error, generic: generic)));
    }
  }

  /// The tables given to the signed-in server for one business night (yyyy-mm-dd). The night is checked first, so a request the
  /// database would refuse never leaves the phone.
  Future<List<AssignedTable>> myTables(String night) {
    if (parseNight(night) == null) throw ArgumentError('not a night: $night');
    return _list('my_assigned_tables', {'p_night': night}, parseAssignedTable, 'tables');
  }

  /// The requests of a club that this person may see. [includeClosed] adds those finished in the last 24 hours.
  Future<List<ServiceRequestRow>> requests(String venueId, {bool includeClosed = false}) =>
      _list('list_service_requests', {'p_venue': venueId, 'p_include_closed': includeClosed}, parseServiceRequestRow, 'requests');

  /// Asks for something for a table. Asking again for the same thing while it is open returns the same request, so a double tap is
  /// harmless. Returns the request's id.
  Future<String> ask(String bookingId, ServiceKind kind, {String? note}) {
    final problem = note == null ? null : validateNote(note);
    if (problem != null) return Future.error(ServerDeskActionException(problem));
    return _act(() async {
      final id = await _rpc('create_service_request', params: askParams(bookingId, kind, note));
      if (id is String && id.isNotEmpty) return id;
      throw const ServerDeskActionException('The request could not be made.');
    }, generic: 'The request could not be made. Check your connection and try again.');
  }

  /// Moves a request along. Escalating and cancelling need a reason, which is checked before anything is sent.
  Future<void> act(String requestId, RequestAction action, {String? note}) {
    if (action.needsReason) {
      final problem = validateReason(note ?? '');
      if (problem != null) return Future.error(ServerDeskActionException(problem));
    } else if (note != null && validateNote(note) != null) {
      return Future.error(ServerDeskActionException(validateNote(note)!));
    }
    return _act(
      () async => await _rpc('update_service_request', params: actParams(requestId, action, note)),
      generic: 'That could not be done. Check your connection and try again.',
    );
  }

  /// Who has which booking, for the club's nights [range] (both included).
  Future<List<BookingServer>> bookingServers(String venueId, NightRange range) {
    final problem = validateRange(range);
    if (problem != null) throw ArgumentError(problem);
    return _list('list_venue_booking_servers', {'p_venue': venueId, 'p_from': range.from, 'p_to': range.to}, parseBookingServer, 'servers');
  }

  Future<void> assignServer(String bookingId, String membershipId) => _act(
        () async => await _rpc('assign_booking_server', params: {'p_booking': bookingId, 'p_membership': membershipId}),
        generic: 'The table could not be given to this server. Check your connection and try again.',
      );

  Future<void> unassignServer(String bookingId) => _act(
        () async => await _rpc('unassign_booking_server', params: {'p_booking': bookingId}),
        generic: 'The server could not be taken off this table. Check your connection and try again.',
      );
}
