import 'package:supabase_flutter/supabase_flutter.dart';

import '../../owner/services/db_errors.dart';
import '../logic/business_name_rules.dart';

/// What renaming a business did, as the database answers.
class BusinessRenamed {
  const BusinessRenamed({
    required this.name,
    required this.eventsUpdated,
    this.canChangeAgainAt,
  });

  /// The name as saved (spaces tidied).
  final String name;

  /// How many events (drafts and ones that have not started) now carry the new name. Events already held keep the old one.
  final int eventsUpdated;

  /// The day a real rename is possible again; null when the database did not say.
  final DateTime? canChangeAgainAt;

  static BusinessRenamed? tryParse(dynamic rows) {
    if (rows is! List || rows.isEmpty || rows.first is! Map) return null;
    final row = Map<String, dynamic>.from(rows.first as Map);
    final name = row['new_name']?.toString();
    if (name == null || name.isEmpty) return null;
    final updated = row['events_updated'];
    final next = row['can_change_again_at']?.toString();
    return BusinessRenamed(
      name: name,
      eventsUpdated: updated is num ? updated.toInt() : 0,
      canChangeAgainAt:
          next == null ? null : DateTime.tryParse(next)?.toLocal(),
    );
  }
}

/// A rename that did not happen, with the sentence to show.
class BusinessRenameFailed implements Exception {
  const BusinessRenameFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

/// How the service calls a database function. Replaced in tests; in the app it is Supabase's own `rpc`.
typedef RenameRpc =
    Future<dynamic> Function(String function, {Map<String, dynamic>? params});

/// Renames a business through the `rename_business` database function (the only way: the apps cannot write the name directly).
class BusinessNameService {
  BusinessNameService({SupabaseClient? client, RenameRpc? rpc})
    : _client = client,
      _rpcOverride = rpc;

  final SupabaseClient? _client;
  final RenameRpc? _rpcOverride;

  Future<dynamic> _rpc(String function, Map<String, dynamic> params) async {
    final override = _rpcOverride;
    if (override != null) return override(function, params: params);
    return await (_client ?? Supabase.instance.client).rpc(
      function,
      params: params,
    );
  }

  /// Throws [BusinessRenameFailed] with a sentence for the person; never the database's own technical text.
  Future<BusinessRenamed> rename({
    required String orgId,
    required String name,
  }) async {
    final Object? rows;
    try {
      rows = await _rpc('rename_business', {
        'p_org': orgId,
        'p_name': tidyBusinessName(name),
      });
    } catch (error) {
      if (isMissingFunction(error)) {
        throw const BusinessRenameFailed(
          'Renaming a business is not available yet. Try again later.',
        );
      }
      if (isNoAccess(error)) {
        throw const BusinessRenameFailed(
          'Only the business owner can change its name.',
        );
      }
      final text = actionMessage(
        error,
        generic:
            'The name could not be changed. Check your connection and try again.',
      );
      throw BusinessRenameFailed(asSentence(text));
    }
    final done = BusinessRenamed.tryParse(rows);
    if (done == null) {
      throw const BusinessRenameFailed(
        'The name could not be changed. Check your connection and try again.',
      );
    }
    return done;
  }
}
