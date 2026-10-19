import 'package:supabase_flutter/supabase_flutter.dart';

import '../../owner/services/db_errors.dart';
import '../../workspace/services/workspace_service.dart' show RpcCaller;
import '../logic/event_states.dart';
import '../logic/organizer_events_rules.dart';

/// Loading the events failed. Carries what the screen needs to say, not a stack trace.
class OrganizerEventsLoadException implements Exception {
  const OrganizerEventsLoadException({required this.unavailable, required this.accessEnded});

  /// The backend has not been given the organizer events migration yet. Nothing the person can fix.
  final bool unavailable;

  /// The database says this person no longer has access (removed, access ended, signed out).
  final bool accessEnded;

  String get message {
    if (unavailable) return 'Events are not set up on this server yet.';
    if (accessEnded) return 'Your access has ended, or you are signed out.';
    return 'Your events could not be loaded. Check your connection and try again.';
  }

  @override
  String toString() => 'OrganizerEventsLoadException($message)';
}

/// A save or removal was refused or failed; the message is a plain sentence for the person.
class OrganizerEventsActionException implements Exception {
  const OrganizerEventsActionException(this.message);

  final String message;

  @override
  String toString() => 'OrganizerEventsActionException($message)';
}

/// The organizer's calls to the website's `list_org_events`, `save_org_event` and `remove_org_event` (website repo,
/// 20261013100000_organizer_events.sql). Each checks in the database that the signed-in person is an organizer of THIS business,
/// looks the event up inside it, and writes only whitelisted fields; a draft is all an organizer can create, and a published event
/// is out of reach. Nothing here decides who may do what.
class OrganizerEventsService {
  OrganizerEventsService({SupabaseClient? client, RpcCaller? rpc})
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

  /// Where each of the business's events stands and what blocks publishing it. A failure here is a [OrganizerEventsLoadException]; the events
  /// themselves still load without it.
  Future<List<EventStateInfo>> states(String orgId) async {
    try {
      final data = await _rpc('list_org_event_states', params: {'p_org': orgId});
      return [
        if (data is List)
          for (final r in data)
            if (r is Map) ...[
              if (parseEventState(Map<String, dynamic>.from(r)) case final info?) info,
            ],
      ];
    } catch (error) {
      throw OrganizerEventsLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error));
    }
  }

  Future<T> _act<T>(Future<T> Function() call, String generic) async {
    try {
      return await call();
    } on OrganizerEventsActionException {
      rethrow;
    } catch (error) {
      throw OrganizerEventsActionException(sentence(actionMessage(error, generic: generic)));
    }
  }

  Future<List<OrgEvent>> events(String orgId) async {
    try {
      final data = await _rpc('list_org_events', params: {'p_org': orgId});
      if (data is! List) return const [];
      return [
        for (final r in data)
          if (r is Map) ...[if (parseOrgEvent(Map<String, dynamic>.from(r)) case final e?) e],
      ];
    } catch (error) {
      throw OrganizerEventsLoadException(unavailable: isMissingFunction(error), accessEnded: isNoAccess(error));
    }
  }

  /// eventId null adds a draft; otherwise changes that draft. Only the fields in [details] change.
  Future<String> save(String orgId, String? eventId, Map<String, dynamic> details) => _act(() async {
        final id = await _rpc('save_org_event', params: {'p_org': orgId, 'p_event': eventId, 'p_details': details});
        if (id is String && id.isNotEmpty) return id;
        throw const OrganizerEventsActionException('The event could not be saved. Try again.');
      }, 'This could not be saved. Check your connection and try again.');

  Future<void> remove(String orgId, String eventId) => _act(
        () async => await _rpc('remove_org_event', params: {'p_org': orgId, 'p_event': eventId}),
        'This could not be removed. Try again.',
      );
}

class SubmitResult {
  const SubmitResult({required this.ok, this.problems = const []});

  final bool ok;

  /// What is wrong, in plain words, for the form to show. Empty when it was saved.
  final List<String> problems;
}

/// The form's Save: every problem is said before anything is sent; a refusal from the database comes back as a sentence for the form
/// to show (so nothing typed is lost); nothing else ever throws at the screen.
Future<SubmitResult> submitEventForm(EventForm form, String orgId, String? eventId, OrganizerEventsService service) async {
  final problems = validateEventForm(form);
  if (problems.isNotEmpty) return SubmitResult(ok: false, problems: problems);
  try {
    await service.save(orgId, eventId, eventPayload(form));
    return const SubmitResult(ok: true);
  } on OrganizerEventsActionException catch (e) {
    return SubmitResult(ok: false, problems: [e.message]);
  }
}
