import 'package:supabase_flutter/supabase_flutter.dart';

import '../../owner/services/db_errors.dart';
import '../../server_desk/logic/server_desk_rules.dart' show deskLoadMessage;
import '../../team/services/team_service.dart' show sentence;
import '../../workspace/services/workspace_service.dart' show RpcCaller;

/// Loading something failed. Carries what the screen needs to say, not a stack trace.
class OpsLoadException implements Exception {
  const OpsLoadException({required this.unavailable, required this.accessEnded, required this.what});

  /// The backend has not been given the migration yet. Nothing the person can fix.
  final bool unavailable;

  /// The database says this person no longer has access (removed, access ended, signed out).
  final bool accessEnded;

  /// What was being loaded, in the plural: "handovers", "messages".
  final String what;

  String get message => deskLoadMessage(unavailable: unavailable, accessEnded: accessEnded, what: what);

  @override
  String toString() => 'OpsLoadException($message)';
}

/// An action was refused or failed; the message is a plain sentence.
class OpsActionException implements Exception {
  const OpsActionException(this.message);

  final String message;

  @override
  String toString() => 'OpsActionException($message)';
}

/// The failure a screen shows for [error] while loading [what]. A screen never shows a raw error or a blank.
OpsLoadException opsLoadFailureFor(Object error, String what) =>
    error is OpsLoadException ? error : OpsLoadException(unavailable: false, accessEnded: false, what: what);

/// A call to one of the website's edge functions, returning what it answered. Throws a `FunctionException` when it answers with an error status.
typedef EdgeInvoker = Future<dynamic> Function(String name, Map<String, dynamic> body);

/// The calls to the website's database functions, with one way of failing: a list that cannot be read becomes an [OpsLoadException], an
/// action that is refused becomes an [OpsActionException] carrying the database's own sentence. The database decides who may do what;
/// nothing built on this decides anything about access.
class OpsRpc {
  OpsRpc({SupabaseClient? client, RpcCaller? rpc, EdgeInvoker? invoker})
      : _client = client,
        _rpcOverride = rpc,
        _invokerOverride = invoker;

  final SupabaseClient? _client;
  final RpcCaller? _rpcOverride;
  final EdgeInvoker? _invokerOverride;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<dynamic> call(String function, [Map<String, dynamic>? params]) async {
    final override = _rpcOverride;
    if (override != null) return override(function, params: params);
    return await _db.rpc(function, params: params);
  }

  /// An edge function, called as the signed-in person. What it answered is returned as it came; a refusal is a `FunctionException` for the caller to read.
  Future<dynamic> invoke(String name, Map<String, dynamic> body) async {
    final override = _invokerOverride;
    if (override != null) return override(name, body);
    final response = await _db.functions.invoke(name, body: body);
    return response.data;
  }

  static List<Map<String, dynamic>> rows(dynamic data) => data is List
      ? [
          for (final r in data)
            if (r is Map) Map<String, dynamic>.from(r),
        ]
      : const [];

  /// A list the function returns as a set of rows. Rows the parser cannot use are dropped.
  Future<List<T>> list<T>(String function, Map<String, dynamic> params, T? Function(Map<String, dynamic>) parse, String what) async {
    try {
      return rows(await call(function, params)).map(parse).whereType<T>().toList();
    } catch (error) {
      throw OpsLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error), what: what);
    }
  }

  /// One row (or one json object) the function returns.
  Future<T> one<T>(String function, Map<String, dynamic> params, T? Function(Map<String, dynamic>) parse, String what) async {
    try {
      final data = await call(function, params);
      final map = data is List ? (data.isNotEmpty && data.first is Map ? data.first as Map : null) : (data is Map ? data : null);
      final parsed = map == null ? null : parse(Map<String, dynamic>.from(map));
      if (parsed == null) throw StateError('no row');
      return parsed;
    } catch (error) {
      throw OpsLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error), what: what);
    }
  }

  /// Something the person asked to be done. A refusal is the database's own sentence.
  Future<T> act<T>(Future<T> Function() action, {String generic = 'This could not be done. Check your connection and try again.'}) async {
    try {
      return await action();
    } on OpsActionException {
      rethrow;
    } catch (error) {
      throw OpsActionException(sentence(actionMessage(error, generic: generic)));
    }
  }
}
