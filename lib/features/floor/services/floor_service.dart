import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/bookings_rules.dart';

/// Loading the bookings failed. Carries what the screen needs to say, not a stack trace.
class FloorLoadException implements Exception {
  const FloorLoadException({required this.unavailable, required this.accessEnded});

  /// The backend has not been given the bookings migration yet. Nothing the manager can fix.
  final bool unavailable;

  /// The database says this person no longer manages the venue (removed, access ended, signed out).
  final bool accessEnded;

  String get message => floorLoadMessage(unavailable: unavailable, accessEnded: accessEnded);

  @override
  String toString() => 'FloorLoadException($message)';
}

String _messageOf(Object error) => error is PostgrestException ? error.message : error.toString();

bool _isMissingFunction(Object error) =>
    error is PostgrestException && (error.code == '42883' || error.code == 'PGRST202' || error.code == '42P01');

bool _isNoAccess(Object error) =>
    RegExp(r'not authori[sz]ed|not allowed|access has ended|signed out|not authenticated', caseSensitive: false)
        .hasMatch(_messageOf(error));

/// The manager's read of a venue's bookings: the website's `list_venue_bookings(p_venue, p_from, p_to)`. The database checks
/// that the signed-in person owns or manages THIS venue and decides which business night each booking belongs to, at most 93
/// nights and 1000 rows at a time. Read only: nothing here writes.
class FloorService {
  FloorService({SupabaseClient? client, RpcCaller? rpc})
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

  /// Bookings for the business nights [range] (both included). The range is checked first, so a request the database would
  /// refuse never leaves the phone.
  Future<List<BookingRow>> bookings(String venueId, NightRange range) async {
    final problem = validateRange(range);
    if (problem != null) throw ArgumentError(problem);
    try {
      final data = await _rpc('list_venue_bookings', params: {'p_venue': venueId, 'p_from': range.from, 'p_to': range.to});
      if (data is! List) return const [];
      return data.whereType<Map>().map((r) => parseBookingRow(Map<String, dynamic>.from(r))).whereType<BookingRow>().toList();
    } catch (error) {
      throw FloorLoadException(unavailable: _isMissingFunction(error), accessEnded: _isNoAccess(error));
    }
  }
}
