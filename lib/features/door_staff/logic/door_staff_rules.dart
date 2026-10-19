// Organizer-provided door staff (developer brief 15 Oct, "Latest decisions" and section 25). Pure Dart, tested without a screen. The database decides
// (website: organizer_event_door_status, venue_door_permissions, set_organizer_door_staff, venue_event_door_staff, revoke_event_door_access and the rule
// inside invite_member, 20261020130000_organizer_door_staff.sql); this words it. An organizer may invite door staff for an event only when it has no club,
// or the club's approved agreement allows it. The club switches the permission on and off and can take anyone's access away.

enum EventDoorState {
  ownEvent('own_event'),
  allowed('allowed'),
  notAllowed('not_allowed'),
  awaitingApproval('awaiting_approval');

  const EventDoorState(this.db);

  final String db;

  static EventDoorState? fromDb(String? v) {
    for (final s in values) {
      if (s.db == v) return s;
    }
    return null;
  }

  /// Whether the organizer may invite door staff for the event right now.
  bool get canInvite => this == ownEvent || this == allowed;
}

class EventDoorStatus {
  const EventDoorStatus({required this.eventId, required this.title, required this.state, this.clubName});

  final String eventId;
  final String title;
  final EventDoorState state;
  final String? clubName;
}

EventDoorStatus? parseEventDoorStatus(Map<String, dynamic> row) {
  final id = row['event_id']?.toString();
  final title = row['event_title']?.toString();
  final state = EventDoorState.fromDb(row['state']?.toString());
  if (id == null || id.isEmpty || title == null || state == null) return null;
  final club = row['club_name']?.toString();
  return EventDoorStatus(eventId: id, title: title, state: state, clubName: club == null || club.isEmpty ? null : club);
}

/// Where the organizer stands on this event, in words.
String doorStateSentence(EventDoorStatus s) {
  final club = s.clubName ?? 'the club';
  return switch (s.state) {
    EventDoorState.ownEvent => 'No club is hosting this event, so you can invite door staff yourself.',
    EventDoorState.allowed => '$club allows you to invite door staff for this event.',
    EventDoorState.notAllowed => '$club has not allowed door staff for this event. Ask $club to allow it.',
    EventDoorState.awaitingApproval => 'Waiting for $club to agree the event terms. Door staff can be invited once it has, if it allows them.',
  };
}

String doorStateLabel(EventDoorState s) => switch (s) {
      EventDoorState.ownEvent => 'Your own event',
      EventDoorState.allowed => 'Allowed',
      EventDoorState.notAllowed => 'Not allowed yet',
      EventDoorState.awaitingApproval => 'Awaiting the club',
    };

// ---------------------------------------------------------------------------------------------------------------------------------------
// The club's side
// ---------------------------------------------------------------------------------------------------------------------------------------

class DoorPermission {
  const DoorPermission({
    required this.agreementId,
    required this.eventId,
    required this.eventTitle,
    required this.organizerName,
    required this.approved,
    required this.allowed,
    this.eventStart,
  });

  final String agreementId;
  final String eventId;
  final String eventTitle;
  final String organizerName;
  final DateTime? eventStart;

  /// The agreement's terms are agreed (the permission only counts once they are).
  final bool approved;

  /// The club allows the organizer's door staff on this event.
  final bool allowed;
}

DoorPermission? parseDoorPermission(Map<String, dynamic> row) {
  final id = row['agreement_id']?.toString();
  final event = row['event_id']?.toString();
  if (id == null || id.isEmpty || event == null || event.isEmpty) return null;
  return DoorPermission(
    agreementId: id,
    eventId: event,
    eventTitle: row['event_title']?.toString() ?? 'Event',
    organizerName: row['organizer_name']?.toString() ?? 'An organizer',
    eventStart: DateTime.tryParse('${row['event_start']}')?.toLocal(),
    approved: row['approved'] == true,
    allowed: row['door_staff_allowed'] == true,
  );
}

/// One of the organizer's door staff at the club's events: a person with access, or an invitation still waiting.
class ClubDoorStaff {
  const ClubDoorStaff({
    required this.eventTitle,
    required this.organizerName,
    required this.person,
    required this.state,
    this.membershipId,
    this.invitationId,
    this.accessEndAt,
  });

  final String? membershipId;
  final String? invitationId;
  final String eventTitle;
  final String organizerName;

  /// A name, or the e-mail address when they have no profile name.
  final String person;
  final String state;
  final DateTime? accessEndAt;

  bool get isInvitation => invitationId != null;

  /// Access that can still be taken away: someone in (active or scheduled) or an invitation not yet used.
  bool get canRevoke => state == 'active' || state == 'scheduled' || state == 'invited' || state == 'invitation_expired';
}

ClubDoorStaff? parseClubDoorStaff(Map<String, dynamic> row) {
  final member = row['membership_id']?.toString();
  final invite = row['invitation_id']?.toString();
  final person = row['person']?.toString();
  if ((member == null && invite == null) || person == null || person.isEmpty) return null;
  return ClubDoorStaff(
    membershipId: member,
    invitationId: invite,
    eventTitle: row['event_title']?.toString() ?? 'Event',
    organizerName: row['organizer_name']?.toString() ?? 'An organizer',
    person: person,
    state: row['state']?.toString() ?? 'active',
    accessEndAt: DateTime.tryParse('${row['access_end_at']}')?.toLocal(),
  );
}

String clubStaffStateLabel(String state) => switch (state) {
      'active' => 'Has access',
      'scheduled' => 'Access not started yet',
      'expired' => 'Access ended',
      'revoked' => 'Removed',
      'invited' => 'Invited, not accepted yet',
      'invitation_expired' => 'Invitation expired',
      _ => state.replaceAll('_', ' '),
    };

const String doorStaffLimits = 'Door staff can scan and admit guests for the event. They cannot change prices, issue refunds or reach banking.';

String permissionSentence(DoorPermission p) => !p.approved
    ? 'The terms are not agreed yet. The permission counts once they are.'
    : p.allowed
        ? '${p.organizerName} may invite door staff for this event.'
        : '${p.organizerName} may not invite door staff for this event.';
