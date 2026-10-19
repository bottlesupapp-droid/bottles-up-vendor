// Where an organizer's event stands, and exactly what blocks publishing it (developer brief 15 Oct, section 10: "Statuses: Draft, Awaiting Venue
// Approval, Ready to Publish, Live, Ended and Cancelled. Permit draft work while approval is pending and explain exactly what blocks publishing.").
// Pure Dart. The database works the state out (website: list_org_event_states, 20261020120000_org_event_states.sql); this only words it.
// "Cancelled" is not here: events have no cancelled status in the database yet, so none is shown rather than guessed. Publishing itself is still done
// by the BottlesUp team: an organizer cannot publish.

enum EventState {
  draft('draft', 'Draft', 'Only you can see this. Finish what is listed below; the BottlesUp team publishes it when it is ready.'),
  awaitingVenueApproval('awaiting_venue_approval', 'Awaiting venue approval', 'Only you can see this. You can keep working on the draft while the club decides.'),
  readyToPublish('ready_to_publish', 'Ready to publish', 'Everything needed is in place. The BottlesUp team publishes it and sets up tickets with you.'),
  live('live', 'Live', 'Live on the website. Contact BottlesUp to change it.'),
  ended('ended', 'Ended', 'This event has finished.');

  const EventState(this.db, this.label, this.note);

  final String db;
  final String label;

  /// What the state means for the organizer, in one line.
  final String note;

  static EventState? fromDb(String? v) {
    for (final s in values) {
      if (s.db == v) return s;
    }
    return null;
  }

  /// Still a draft the organizer can change or remove (a draft, waiting on a club, or ready). Live and ended events are out of reach.
  bool get isDraftLike => this == draft || this == awaitingVenueApproval || this == readyToPublish;
}

/// What still stands between a draft and publishing.
enum PublishBlocker {
  businessVerification('business_verification', BlockerAction.verification),
  venueRequest('venue_request', BlockerAction.agreements),
  venueDeclined('venue_declined', BlockerAction.agreements),
  venueApproval('venue_approval', BlockerAction.agreements);

  const PublishBlocker(this.db, this.action);

  final String db;

  /// Where the person goes to clear it.
  final BlockerAction action;

  static PublishBlocker? fromDb(String? v) {
    for (final b in values) {
      if (b.db == v) return b;
    }
    return null;
  }
}

enum BlockerAction { verification, agreements }

class EventStateInfo {
  const EventStateInfo({required this.eventId, required this.state, required this.blockers, this.agreementStatus, this.venueName, this.unknownBlockers = 0});

  final String eventId;
  final EventState state;
  final List<PublishBlocker> blockers;

  /// Blockers this version of the app does not know. They are counted and said, never dropped silently.
  final int unknownBlockers;
  final String? agreementStatus;

  /// The club behind the connection, when there is one.
  final String? venueName;
}

EventStateInfo? parseEventState(Map<String, dynamic> row) {
  final id = row['event_id']?.toString();
  final state = EventState.fromDb(row['state']?.toString());
  if (id == null || id.isEmpty || state == null) return null;
  final raw = row['blockers'];
  final known = <PublishBlocker>[];
  var unknown = 0;
  if (raw is List) {
    for (final k in raw) {
      final b = PublishBlocker.fromDb('$k');
      if (b == null) {
        unknown++;
      } else {
        known.add(b);
      }
    }
  }
  final venue = row['venue_name']?.toString();
  return EventStateInfo(
    eventId: id,
    state: state,
    blockers: known,
    unknownBlockers: unknown,
    agreementStatus: row['agreement_status']?.toString(),
    venueName: venue == null || venue.isEmpty ? null : venue,
  );
}

Map<String, EventStateInfo> statesByEvent(List<EventStateInfo> all) => {for (final s in all) s.eventId: s};

/// What blocks publishing, in a sentence each, in the order to clear them.
List<String> blockerSentences(EventStateInfo info) => [
      for (final b in info.blockers) _sentence(b, info),
      if (info.unknownBlockers > 0) info.unknownBlockers == 1 ? 'Something else needs the BottlesUp team.' : '${info.unknownBlockers} other things need the BottlesUp team.',
    ];

String _sentence(PublishBlocker b, EventStateInfo info) {
  final club = info.venueName ?? 'the club';
  return switch (b) {
    PublishBlocker.businessVerification => 'Your business is not verified yet. Publishing waits for verification.',
    PublishBlocker.venueRequest => 'No club has been asked to host this event yet.',
    PublishBlocker.venueDeclined => info.agreementStatus == 'cancelled'
        ? 'The request to $club was cancelled. Ask a club to host this event.'
        : '$club declined. Ask another club to host this event.',
    PublishBlocker.venueApproval => 'Waiting for $club to agree the terms.',
  };
}

/// The button that goes with the first blocker the person can act on, or null.
({String label, BlockerAction action})? blockerAction(EventStateInfo info) {
  for (final b in info.blockers) {
    switch (b) {
      case PublishBlocker.venueRequest:
      case PublishBlocker.venueDeclined:
        return (label: 'Ask a club to host it', action: BlockerAction.agreements);
      case PublishBlocker.venueApproval:
        return (label: 'See the agreement', action: BlockerAction.agreements);
      case PublishBlocker.businessVerification:
        continue;
    }
  }
  return null;
}
