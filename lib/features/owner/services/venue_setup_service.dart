import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/setup_forms.dart';
import 'db_errors.dart';
import 'owner_service.dart' show OwnerLoadException;

/// A save or removal was refused or failed; the message is a plain sentence for the person.
class SetupEditException implements Exception {
  const SetupEditException(this.message);

  final String message;

  @override
  String toString() => 'SetupEditException($message)';
}

/// The owner's setup editors' calls to the website's database functions (`list_/add_/save_/remove_venue_*`, defined in the website
/// repo's 20261010100000_venue_setup.sql). Each checks in the database that the signed-in person owns or manages THIS venue,
/// writes only whitelisted fields, and never reaches a row of another venue. Nothing here decides who may edit what.
class VenueSetupService {
  VenueSetupService({SupabaseClient? client, RpcCaller? rpc})
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

  List<Map<String, dynamic>> _rows(dynamic data) =>
      data is List
          ? [
            for (final r in data)
              if (r is Map) Map<String, dynamic>.from(r),
          ]
          : const [];

  Future<List<T>> _list<T>(
    String function,
    String venueId,
    T? Function(Map<String, dynamic>) parse,
  ) async {
    try {
      return _rows(
        await _rpc(function, params: {'p_venue': venueId}),
      ).map(parse).whereType<T>().toList();
    } catch (error) {
      throw OwnerLoadException(
        unavailable: isMissingFunction(error),
        accessEnded: isNoAccess(error),
      );
    }
  }

  Future<T> _act<T>(
    Future<T> Function() call, {
    String generic =
        'This could not be saved. Check your connection and try again.',
  }) async {
    try {
      return await call();
    } on SetupEditException {
      rethrow;
    } catch (error) {
      throw SetupEditException(actionMessage(error, generic: generic));
    }
  }

  // --- arrival times --------------------------------------------------------

  Future<List<ArrivalTime>> arrivalTimes(String venueId) =>
      _list('list_venue_time_slots', venueId, parseArrivalTime);

  /// One day and time. Several days are several calls (the screen reports each one's outcome).
  Future<String> addArrivalTime(
    String venueId,
    int day,
    String time,
    String label,
  ) => _act(() async {
    final id = await _rpc(
      'add_venue_time_slot',
      params: {
        'p_venue': venueId,
        'p_day': day,
        'p_start': time,
        'p_label': label.trim().isEmpty ? null : label.trim(),
      },
    );
    if (id is String && id.isNotEmpty) return id;
    throw const SetupEditException(
      'The arrival time could not be added. Try again.',
    );
  });

  Future<void> removeArrivalTime(String venueId, String slotId) => _act(
    () async => await _rpc(
      'remove_venue_time_slot',
      params: {'p_venue': venueId, 'p_slot': slotId},
    ),
    generic: 'This could not be removed. Try again.',
  );

  // --- table types ----------------------------------------------------------

  Future<List<TableTypeRow>> tableTypes(String venueId) =>
      _list('list_venue_table_types', venueId, parseTableType);

  /// typeId null adds a table type; otherwise changes that one. Only the fields in [details] change.
  Future<String> saveTableType(
    String venueId,
    String? typeId,
    Map<String, dynamic> details,
  ) => _act(() async {
    final id = await _rpc(
      'save_venue_table_type',
      params: {'p_venue': venueId, 'p_type': typeId, 'p_details': details},
    );
    if (id is String && id.isNotEmpty) return id;
    throw const SetupEditException('The table could not be saved. Try again.');
  });

  Future<void> removeTableType(String venueId, String typeId) => _act(
    () async => await _rpc(
      'remove_venue_table_type',
      params: {'p_venue': venueId, 'p_type': typeId},
    ),
    generic: 'This could not be removed. Try again.',
  );

  // --- bottles --------------------------------------------------------------

  Future<List<BottleRow>> bottles(String venueId) =>
      _list('list_venue_bottles', venueId, parseBottle);

  /// bottleId null adds a bottle; otherwise changes that one. Only the fields in [details] change.
  Future<String> saveBottle(
    String venueId,
    String? bottleId,
    Map<String, dynamic> details,
  ) => _act(() async {
    final id = await _rpc(
      'save_venue_bottle',
      params: {'p_venue': venueId, 'p_bottle': bottleId, 'p_details': details},
    );
    if (id is String && id.isNotEmpty) return id;
    throw const SetupEditException('The bottle could not be saved. Try again.');
  });

  Future<void> removeBottle(String venueId, String bottleId) => _act(
    () async => await _rpc(
      'remove_venue_bottle',
      params: {'p_venue': venueId, 'p_bottle': bottleId},
    ),
    generic: 'This could not be removed. Try again.',
  );
}
