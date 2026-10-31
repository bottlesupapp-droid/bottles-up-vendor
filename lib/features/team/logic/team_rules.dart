// The rules behind the Team screen (Phase 2 brief section 12): inviting people, temporary access, and what each state of a
// person or an invitation means. Pure Dart, tested without a screen. A port of the website's src/lib/team.ts: the wording is the
// website's, word for word (a test compares them when the website repo is checked out beside this app). Who may invite whom,
// and who may see whom, is decided by the database (invitable_roles, list_team, can_view_membership); nothing here grants anything.

import 'package:intl/intl.dart';

import '../../workspace/models/workspace_role.dart';

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

enum Tone { success, info, warning, neutral }

enum MemberState {
  active,
  scheduled,
  expired,
  revoked;

  static MemberState? fromDb(Object? v) {
    for (final s in values) {
      if (s.name == v) return s;
    }
    return null;
  }

  String get label => switch (this) {
        MemberState.active => 'Active',
        MemberState.scheduled => 'Starts later',
        MemberState.expired => 'Access ended',
        MemberState.revoked => 'Removed',
      };

  Tone get tone => switch (this) {
        MemberState.active => Tone.success,
        MemberState.scheduled => Tone.info,
        MemberState.expired => Tone.neutral,
        MemberState.revoked => Tone.neutral,
      };

  /// Someone whose access is, or will be, in force: they belong in the main list. Ended and removed go to history.
  bool get isCurrent => this == MemberState.active || this == MemberState.scheduled;
}

enum InvitationState {
  pending,
  accepted,
  expired,
  revoked;

  static InvitationState? fromDb(Object? v) {
    for (final s in values) {
      if (s.name == v) return s;
    }
    return null;
  }

  String get label => switch (this) {
        InvitationState.pending => 'Waiting',
        InvitationState.accepted => 'Accepted',
        InvitationState.expired => 'Expired',
        InvitationState.revoked => 'Cancelled',
      };

  Tone get tone => switch (this) {
        InvitationState.pending => Tone.info,
        InvitationState.accepted => Tone.success,
        InvitationState.expired => Tone.warning,
        InvitationState.revoked => Tone.neutral,
      };

  /// A new link can be sent for a waiting or expired invitation; a used or cancelled one is finished.
  bool get canSendNewLink => this == InvitationState.pending || this == InvitationState.expired;

  /// A waiting or expired invitation can be cancelled (an expired one is still pending in the database).
  bool get canCancel => this == InvitationState.pending || this == InvitationState.expired;
}

/// Owners and organizers are not removed from here: only the platform team can do that, and the database enforces it.
bool canRemoveMember(String role, MemberState state) {
  if (role == 'owner' || role == 'organizer') return false;
  return state != MemberState.revoked;
}

String roleLabel(String role) => WorkspaceRole.fromDb(role)?.label ?? role;

// ---------------------------------------------------------------------------
// Inviting
// ---------------------------------------------------------------------------

/// What the invite form holds. `start` and `end` are the person's own clock (what the date pickers give).
class InviteForm {
  const InviteForm({
    this.email = '',
    this.role = '',
    this.venueId = '',
    this.temporary = false,
    this.start,
    this.end,
    this.shiftId = '',
    this.validHours = defaultTemporaryLinkHours,
  });

  final String email;
  final String role;
  final String venueId;

  /// Temporary access has a start and an end; otherwise it lasts until the person is removed.
  final bool temporary;
  final DateTime? start;
  final DateTime? end;
  final String shiftId;

  /// How long a temporary person's link stays valid (hours). Only used when [temporary] is on.
  final int validHours;
}

/// Temporary access is a secure, expiring link that the person confirms with a code sent to their e-mail. The client has not settled how long such a link should live, so the
/// person inviting chooses; this is what is suggested.
const int defaultTemporaryLinkHours = 24;
const List<int> temporaryLinkHourChoices = [6, 12, 24, 48, 72, 168];

/// The roles temporary access is for (the database refuses a manager).
const Set<String> temporaryRoles = {'server', 'door', 'security', 'verifier'};

/// "6 hours", "1 day", "7 days".
String linkValidityLabel(int hours) {
  if (hours % 24 == 0) {
    final days = hours ~/ 24;
    return days == 1 ? '1 day' : '$days days';
  }
  return hours == 1 ? '1 hour' : '$hours hours';
}

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());

/// Plain-language problems with the form; an empty list means it can be sent.
List<String> validateInvite(InviteForm f, {required DateTime now}) {
  final problems = <String>[];
  if (!isValidEmail(f.email)) problems.add('Enter the email address of the person you are inviting.');
  if (f.venueId.isEmpty) problems.add('Choose the club they will work at.');
  if (f.role.isEmpty) problems.add('Choose a role.');
  if (f.temporary) {
    if (f.role.isNotEmpty && !temporaryRoles.contains(f.role)) problems.add('Temporary access is for servers, door staff, security and verifiers.');
    if (f.validHours < 1 || f.validHours > 168) problems.add('The link must stay valid for between 1 hour and 7 days.');
    final start = f.start;
    final end = f.end;
    if (start == null || end == null) {
      problems.add('Temporary access needs a start and an end.');
    } else if (!end.isAfter(start)) {
      problems.add('The end must be after the start.');
    } else if (!end.isAfter(now)) {
      problems.add('The end is already in the past.');
    }
  }
  return problems;
}

/// What is sent to invite_member. An event is never part of it from this screen (event staff are invited from an organizer's
/// event), and ongoing access sends no window at all.
class InvitePayload {
  const InvitePayload({
    required this.email,
    required this.role,
    required this.venueId,
    this.shiftId,
    this.accessStartAt,
    this.accessEndAt,
    this.temporary = false,
    this.validHours,
  });

  final String email;
  final String role;
  final String venueId;
  final String? shiftId;
  final DateTime? accessStartAt;
  final DateTime? accessEndAt;

  /// A secure temporary link (invite_temporary_staff) instead of an ordinary invitation (invite_member).
  final bool temporary;

  /// How long the link is valid, for a temporary invitation.
  final int? validHours;
}

InvitePayload buildInvitePayload(InviteForm f) => InvitePayload(
      email: f.email.trim().toLowerCase(),
      role: f.role,
      venueId: f.venueId,
      shiftId: f.shiftId.isEmpty ? null : f.shiftId,
      accessStartAt: f.temporary ? f.start : null,
      accessEndAt: f.temporary ? f.end : null,
      temporary: f.temporary,
      validHours: f.temporary ? f.validHours : null,
    );

/// The parameters of `invite_member`, as the database names them.
Map<String, dynamic> inviteParams(String orgId, InvitePayload p) => {
      'p_org': orgId,
      'p_email': p.email,
      'p_role': p.role,
      'p_venue': p.venueId,
      'p_event': null,
      'p_shift': p.shiftId,
      'p_access_start': p.accessStartAt?.toUtc().toIso8601String(),
      'p_access_end': p.accessEndAt?.toUtc().toIso8601String(),
    };

/// The parameters of `invite_temporary_staff`, as the database names them.
Map<String, dynamic> inviteTemporaryParams(String orgId, InvitePayload p) => {
      ...inviteParams(orgId, p),
      'p_valid_hours': p.validHours ?? defaultTemporaryLinkHours,
    };

// ---------------------------------------------------------------------------
// The link and how to send it
// ---------------------------------------------------------------------------

String invitationLink(String origin, String token) =>
    '${origin.replaceAll(RegExp(r'/+$'), '')}/accept-invite?token=${Uri.encodeComponent(token)}';

/// A `mailto:` link, for when the server could not send the email. It opens the person's own mail app with the message ready, so
/// an invitation is never stuck just because outgoing mail is not configured.
Uri mailtoLink(String to, String businessName, String roleName, String link) {
  // Names are typed by users: collapse any line break so a name cannot add a mail header once decoded.
  final business = businessName.replaceAll(RegExp(r'\s+'), ' ').trim();
  final role = roleName.replaceAll(RegExp(r'\s+'), ' ').trim();
  final subject = 'You are invited to join $business on BottlesUp';
  final body = 'You have been invited to join $business on BottlesUp as $role.\n\nAccept the invitation here:\n$link\n\nSign in or create an account with $to to accept.';
  return Uri.parse('mailto:${Uri.encodeComponent(to)}?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
}

/// `reason` says why a send failed.
class EmailOutcome {
  const EmailOutcome({required this.sent, this.reason});

  final bool sent;
  final String? reason;
}

class OutcomeMessage {
  const OutcomeMessage(this.tone, this.text);

  final Tone tone;
  final String text;
}

/// What the `send-team-invitation` function answered: `{sent: true}`, or `{sent: false, reason}`. Anything else is a failed send.
EmailOutcome emailOutcomeFromResponse(Object? data) {
  if (data is Map && data['sent'] == true) return const EmailOutcome(sent: true);
  final reason = data is Map ? data['reason'] : null;
  return EmailOutcome(sent: false, reason: reason is String ? reason : 'send_failed');
}

/// The function answered with an error status: 429 means this link was emailed too recently.
EmailOutcome emailOutcomeFromStatus(int? status) => EmailOutcome(sent: false, reason: status == 429 ? 'rate_limited' : 'send_failed');

/// What to tell the person after trying to email the link. The link itself is always shown as well.
OutcomeMessage emailOutcomeMessage(EmailOutcome outcome, String to) {
  if (outcome.sent) return OutcomeMessage(Tone.success, 'We emailed the invitation to $to.');
  switch (outcome.reason) {
    case 'not_configured':
      return const OutcomeMessage(Tone.warning, 'Email is not set up yet, so nothing was sent. Copy the link below and send it yourself.');
    case 'rate_limited':
      return const OutcomeMessage(Tone.warning, 'This invitation was emailed recently. Copy the link below if you need to send it again.');
    default:
      return const OutcomeMessage(Tone.warning, 'We could not send the email. Copy the link below and send it yourself.');
  }
}

// ---------------------------------------------------------------------------
// Wording
// ---------------------------------------------------------------------------

String _fmt(DateTime t) => DateFormat('MMM d, h:mm a', 'en_US').format(t.toLocal());

/// "Ongoing", "Oct 10, 9:00 PM to Oct 11, 3:00 AM", "From ...", "Until ...".
String describeAccess(DateTime? start, DateTime? end) {
  if (start == null && end == null) return 'Ongoing';
  if (start != null && end != null) return '${_fmt(start)} to ${_fmt(end)}';
  if (start != null) return 'From ${_fmt(start)}';
  return 'Until ${_fmt(end!)}';
}

/// One moment in the same words the access windows use.
String describeAccessTime(DateTime at) => _fmt(at);

/// A person's name, or their email when they have no profile name yet.
String displayName(String? name, String? email) {
  final n = name?.trim();
  if (n != null && n.isNotEmpty) return n;
  return email ?? 'Unknown';
}

/// Where someone works: the club, and the event if they are scoped to one.
String describeScope(String? venueName, String? eventTitle, String? shiftName) {
  final parts = [venueName, eventTitle, shiftName].whereType<String>().toList();
  return parts.isEmpty ? 'Whole business' : parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Reading what the database returns
// ---------------------------------------------------------------------------

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

class TeamMember {
  const TeamMember({
    required this.membershipId,
    required this.userId,
    required this.role,
    required this.state,
    this.email,
    this.name,
    this.venueId,
    this.venueName,
    this.eventId,
    this.eventTitle,
    this.shiftId,
    this.shiftName,
    this.accessStartAt,
    this.accessEndAt,
  });

  final String membershipId;
  final String userId;
  final String? email;
  final String? name;
  final String role;
  final String? venueId;
  final String? venueName;
  final String? eventId;
  final String? eventTitle;
  final String? shiftId;
  final String? shiftName;
  final DateTime? accessStartAt;
  final DateTime? accessEndAt;
  final MemberState state;
}

class TeamInvitation {
  const TeamInvitation({
    required this.invitationId,
    required this.email,
    required this.role,
    required this.state,
    this.venueId,
    this.venueName,
    this.eventId,
    this.eventTitle,
    this.shiftId,
    this.shiftName,
    this.accessStartAt,
    this.accessEndAt,
    this.expiresAt,
    this.emailsSent = 0,
    this.isTemporary = false,
    this.identityConfirmed = false,
    this.renewalRequestedAt,
    this.renewalNote,
  });

  final String invitationId;
  final String email;
  final String role;
  final String? venueId;
  final String? venueName;
  final String? eventId;
  final String? eventTitle;
  final String? shiftId;
  final String? shiftName;
  final DateTime? accessStartAt;
  final DateTime? accessEndAt;
  final InvitationState state;
  final DateTime? expiresAt;
  final int emailsSent;

  /// A secure temporary link that needs a code sent to the invited address.
  final bool isTemporary;

  /// The invitee has typed the code (it holds for 30 minutes).
  final bool identityConfirmed;

  /// The invitee of an expired link asked for a new one.
  final DateTime? renewalRequestedAt;
  final String? renewalNote;

  bool get renewalRequested => renewalRequestedAt != null;

  TeamInvitation withExtras(InvitationExtras? x) => x == null
      ? this
      : TeamInvitation(
          invitationId: invitationId,
          email: email,
          role: role,
          state: state,
          venueId: venueId,
          venueName: venueName,
          eventId: eventId,
          eventTitle: eventTitle,
          shiftId: shiftId,
          shiftName: shiftName,
          accessStartAt: accessStartAt,
          accessEndAt: accessEndAt,
          expiresAt: expiresAt,
          emailsSent: emailsSent,
          isTemporary: x.isTemporary,
          identityConfirmed: x.identityConfirmed,
          renewalRequestedAt: x.renewalRequestedAt,
          renewalNote: x.renewalNote,
        );
}

/// What list_invitation_extras says about one waiting invitation.
class InvitationExtras {
  const InvitationExtras({required this.invitationId, required this.isTemporary, required this.identityConfirmed, this.renewalRequestedAt, this.renewalNote});

  final String invitationId;
  final bool isTemporary;
  final bool identityConfirmed;
  final DateTime? renewalRequestedAt;
  final String? renewalNote;
}

InvitationExtras? parseInvitationExtras(Map<String, dynamic> r) {
  final id = r['invitation_id'];
  if (id is! String) return null;
  return InvitationExtras(
    invitationId: id,
    isTemporary: r['kind'] == 'temporary',
    identityConfirmed: r['identity_verified'] == true,
    renewalRequestedAt: _time(r['renewal_requested_at']),
    renewalNote: _str(r['renewal_note']),
  );
}

class Shift {
  const Shift({required this.shiftId, required this.name, required this.startsAt, required this.endsAt, this.eventTitle});

  final String shiftId;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? eventTitle;
}

/// One list_team() row. A row whose state this code does not know is dropped: it is better to omit a person than to mislabel them.
TeamMember? parseTeamMember(Map<String, dynamic> r) {
  final id = r['membership_id'];
  final user = r['user_id'];
  final role = r['role'];
  final state = MemberState.fromDb(r['state']);
  if (id is! String || user is! String || role is! String || state == null) return null;
  return TeamMember(
    membershipId: id,
    userId: user,
    email: _str(r['email']),
    name: _str(r['name']),
    role: role,
    venueId: _str(r['venue_id']),
    venueName: _str(r['venue_name']),
    eventId: _str(r['event_id']),
    eventTitle: _str(r['event_title']),
    shiftId: _str(r['shift_id']),
    shiftName: _str(r['shift_name']),
    accessStartAt: _time(r['access_start_at']),
    accessEndAt: _time(r['access_end_at']),
    state: state,
  );
}

TeamInvitation? parseTeamInvitation(Map<String, dynamic> r) {
  final id = r['invitation_id'];
  final email = r['email'];
  final role = r['role'];
  final state = InvitationState.fromDb(r['state']);
  if (id is! String || email is! String || role is! String || state == null) return null;
  final sent = r['emails_sent'];
  return TeamInvitation(
    invitationId: id,
    email: email,
    role: role,
    venueId: _str(r['venue_id']),
    venueName: _str(r['venue_name']),
    eventId: _str(r['event_id']),
    eventTitle: _str(r['event_title']),
    shiftId: _str(r['shift_id']),
    shiftName: _str(r['shift_name']),
    accessStartAt: _time(r['access_start_at']),
    accessEndAt: _time(r['access_end_at']),
    state: state,
    expiresAt: _time(r['expires_at']),
    emailsSent: sent is int ? sent : 0,
  );
}

Shift? parseShift(Map<String, dynamic> r) {
  final id = r['shift_id'];
  final starts = _time(r['starts_at']);
  final ends = _time(r['ends_at']);
  if (id is! String || starts == null || ends == null) return null;
  return Shift(shiftId: id, name: _str(r['name']) ?? 'Shift', startsAt: starts, endsAt: ends, eventTitle: _str(r['event_title']));
}

/// The main list and the history, each in the order the database gave them.
({List<TeamMember> current, List<TeamMember> history}) splitTeam(List<TeamMember> members) => (
      current: [for (final m in members) if (m.state.isCurrent) m],
      history: [for (final m in members) if (!m.state.isCurrent) m],
    );

/// Whether a member's role can be changed to another club role from the app. Owners and organizers are a platform matter, and an event
/// role (door) has nothing to change to. The database still decides who may do it.
bool canChangeRole(String role, MemberState state, {required String? venueId}) {
  if (venueId == null || state == MemberState.revoked) return false;
  return const {'manager', 'server', 'door', 'security', 'verifier'}.contains(role);
}

/// The roles to offer when changing [current]: the ones this person may appoint at the club, without the one already held.
List<String> rolesToChangeTo(List<String> invitable, String current) => [for (final r in invitable) if (r != current) r];

/// What a shift form holds. [start] and [end] are the person's own clock; if the end is not after the start it means the next day, so a
/// shift can run past midnight without anyone doing date arithmetic.
String? checkShiftForm({required String name, required DateTime? start, required DateTime? end}) {
  final n = name.trim();
  if (n.isEmpty) return 'Name the shift, for example "Friday night".';
  if (n.length > 80) return 'Keep the name to 80 characters or fewer.';
  if (start == null) return 'Choose when the shift starts.';
  if (end == null) return 'Choose when the shift ends.';
  if (!end.isAfter(start)) return 'The shift has to end after it starts.';
  if (end.difference(start) > const Duration(hours: 24)) return 'A shift can be at most 24 hours long.';
  return null;
}

/// "Fri 9 Oct 21:00 to 03:00": a shift's time in words.
String describeShift(DateTime start, DateTime end) {
  final s = start.toLocal();
  final e = end.toLocal();
  final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
  final day = DateFormat('EEE d MMM').format(s);
  final from = DateFormat('HH:mm').format(s);
  final to = DateFormat('HH:mm').format(e);
  return sameDay ? '$day $from to $to' : '$day $from to ${DateFormat('EEE d MMM').format(e)} $to';
}
