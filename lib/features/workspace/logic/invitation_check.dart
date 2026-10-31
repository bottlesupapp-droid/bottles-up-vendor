import '../../ops/logic/ops_json.dart';
import '../../team/logic/team_rules.dart' show describeAccess, describeScope, roleLabel;

/// What a person needs when they open an invitation link, and the code that confirms a temporary one (website repo, 20261118100000_temporary_staff_links.sql). Whether a code is needed,
/// whether it is right and whether the link has expired are the database's rules. This file reads what it sends and words it.

enum PreviewOutcome {
  ok('ok'),
  invalid('invalid'),
  revoked('revoked'),
  expired('expired'),
  alreadyAccepted('already_accepted'),
  emailMismatch('email_mismatch');

  const PreviewOutcome(this.value);

  final String value;

  static PreviewOutcome? parse(String? v) {
    for (final o in values) {
      if (o.value == v) return o;
    }
    return null;
  }
}

class InvitationPreview {
  const InvitationPreview({
    required this.outcome,
    this.kind = 'permanent',
    this.needsCode = false,
    this.emailHint,
    this.role,
    this.orgName,
    this.venueName,
    this.eventTitle,
    this.shiftName,
    this.accessStartAt,
    this.accessEndAt,
    this.expiresAt,
    this.renewalRequested = false,
  });

  final PreviewOutcome outcome;

  /// 'permanent' or 'temporary'.
  final String kind;

  /// A code sent to the invited address must be typed before the link works.
  final bool needsCode;

  /// The invited address with most of it hidden ("t***@club.example").
  final String? emailHint;
  final String? role;
  final String? orgName;
  final String? venueName;
  final String? eventTitle;
  final String? shiftName;
  final DateTime? accessStartAt;
  final DateTime? accessEndAt;
  final DateTime? expiresAt;

  /// The invitee of an expired link already asked for a new one.
  final bool renewalRequested;

  bool get isTemporary => kind == 'temporary';

  InvitationPreview copyWith({bool? renewalRequested}) => InvitationPreview(
        outcome: outcome,
        kind: kind,
        needsCode: needsCode,
        emailHint: emailHint,
        role: role,
        orgName: orgName,
        venueName: venueName,
        eventTitle: eventTitle,
        shiftName: shiftName,
        accessStartAt: accessStartAt,
        accessEndAt: accessEndAt,
        expiresAt: expiresAt,
        renewalRequested: renewalRequested ?? this.renewalRequested,
      );
}

/// Null when the answer is not one the app knows, so it is treated as "no preview" rather than guessed at.
InvitationPreview? parseInvitationPreview(Map<String, dynamic> r) {
  final outcome = PreviewOutcome.parse(opsStr(r, 'outcome'));
  if (outcome == null) return null;
  return InvitationPreview(
    outcome: outcome,
    kind: opsStr(r, 'kind') ?? 'permanent',
    needsCode: opsBool(r, 'needs_code'),
    emailHint: opsStr(r, 'email_hint'),
    role: opsStr(r, 'role'),
    orgName: opsStr(r, 'org_name'),
    venueName: opsStr(r, 'venue_name'),
    eventTitle: opsStr(r, 'event_title'),
    shiftName: opsStr(r, 'shift_name'),
    accessStartAt: opsTime(r, 'access_start_at'),
    accessEndAt: opsTime(r, 'access_end_at'),
    expiresAt: opsTime(r, 'expires_at'),
    renewalRequested: opsBool(r, 'renewal_requested'),
  );
}

/// "Door staff at Club A · Friday late. Access: until Oct 10, 03:00." for the screen that asks for the code.
String previewSummary(InvitationPreview p) {
  final role = p.role == null ? 'Staff' : roleLabel(p.role!);
  final where = describeScope(p.venueName, p.eventTitle, p.shiftName);
  final org = p.orgName == null ? '' : ' for ${p.orgName}';
  final access = describeAccess(p.accessStartAt, p.accessEndAt);
  // Only the first letter is lowered, so a date keeps its capital ("until Oct 25", not "until oct 25").
  return '$role$org · $where. Access: ${access[0].toLowerCase()}${access.substring(1)}.';
}

// -------------------------------------------------------------------------------------------------------------------------------------
// The code
// -------------------------------------------------------------------------------------------------------------------------------------

enum CodeOutcome {
  ok('ok'),
  wrong('wrong'),
  malformed('malformed'),
  locked('locked'),
  codeExpired('code_expired'),
  noCode('no_code'),
  notNeeded('not_needed'),
  invalid('invalid'),
  revoked('revoked'),
  expired('expired'),
  alreadyAccepted('already_accepted'),
  emailMismatch('email_mismatch'),
  failed('failed');

  const CodeOutcome(this.value);

  final String value;

  static CodeOutcome fromDb(String? v) {
    for (final o in values) {
      if (o.value == v) return o;
    }
    return CodeOutcome.failed;
  }
}

class CodeCheck {
  const CodeCheck(this.outcome, {this.attemptsLeft});

  final CodeOutcome outcome;
  final int? attemptsLeft;
}

CodeCheck? parseCodeCheck(Map<String, dynamic> r) {
  final outcome = opsStr(r, 'outcome');
  if (outcome == null) return null;
  return CodeCheck(CodeOutcome.fromDb(outcome), attemptsLeft: r['attempts_left'] == null ? null : opsInt(r, 'attempts_left'));
}

/// What was typed must be six digits (spaces are ignored). Null when it can be sent to be checked.
String? checkCodeInput(String raw) {
  final t = raw.replaceAll(RegExp(r'\s'), '');
  return RegExp(r'^[0-9]{6}$').hasMatch(t) ? null : 'Type the 6 digits from the e-mail.';
}

String cleanCode(String raw) => raw.replaceAll(RegExp(r'\s'), '');

String codeCheckMessage(CodeCheck c) {
  switch (c.outcome) {
    case CodeOutcome.ok:
      return 'Your e-mail is confirmed.';
    case CodeOutcome.wrong:
      final n = c.attemptsLeft ?? 0;
      return n <= 0 ? 'That code is not right. Ask for a new code.' : 'That code is not right. $n ${n == 1 ? 'try' : 'tries'} left.';
    case CodeOutcome.malformed:
      return 'Type the 6 digits from the e-mail.';
    case CodeOutcome.locked:
      return 'Too many wrong codes. Ask for a new code.';
    case CodeOutcome.codeExpired:
      return 'That code has expired. Ask for a new one.';
    case CodeOutcome.noCode:
      return 'Ask for a code first.';
    case CodeOutcome.notNeeded:
      return 'This link does not need a code.';
    case CodeOutcome.invalid:
      return 'This link is not valid. Check that you opened the whole link.';
    case CodeOutcome.revoked:
      return 'This invitation was cancelled. Contact the person who sent it.';
    case CodeOutcome.expired:
      return 'This link has expired.';
    case CodeOutcome.alreadyAccepted:
      return 'You already accepted this invitation.';
    case CodeOutcome.emailMismatch:
      return 'This invitation was sent to a different email address. Sign in with the address it was sent to.';
    case CodeOutcome.failed:
      return 'The code could not be checked. Check your connection and try again.';
  }
}

/// What happened when the code was asked for.
class CodeSendResult {
  const CodeSendResult({required this.sent, required this.message, this.toHint, this.codeMayExist = false});

  /// The e-mail went out.
  final bool sent;
  final String message;
  final String? toHint;

  /// A code was sent a moment ago (the database asked to wait), so one may be typed even though no new one went out.
  final bool codeMayExist;
}

CodeSendResult codeSentResult(String? toHint) =>
    CodeSendResult(sent: true, toHint: toHint, message: 'We sent a 6-digit code to ${toHint ?? 'your e-mail address'}. It works for 10 minutes.');

CodeSendResult codeNotSent(String message, {bool codeMayExist = false}) => CodeSendResult(sent: false, message: message, codeMayExist: codeMayExist);

// -------------------------------------------------------------------------------------------------------------------------------------
// Asking for a new link
// -------------------------------------------------------------------------------------------------------------------------------------

enum RenewalOutcome {
  requested('requested'),
  alreadyRequested('already_requested'),
  notExpired('not_expired'),
  invalid('invalid'),
  revoked('revoked'),
  accepted('accepted'),
  emailMismatch('email_mismatch'),
  failed('failed');

  const RenewalOutcome(this.value);

  final String value;

  static RenewalOutcome fromDb(Object? v) {
    for (final o in values) {
      if (o.value == v) return o;
    }
    return RenewalOutcome.failed;
  }

  /// The person who invited them has been told.
  bool get told => this == RenewalOutcome.requested || this == RenewalOutcome.alreadyRequested;
}

String renewalMessage(RenewalOutcome o) => switch (o) {
      RenewalOutcome.requested => 'Done. The person who invited you has been told you need a new link. When they send it, open it to continue.',
      RenewalOutcome.alreadyRequested => 'You already asked. The person who invited you has been told; open the new link when it arrives.',
      RenewalOutcome.notExpired => 'This link has not expired yet. Try opening it again.',
      RenewalOutcome.invalid => 'This link is not valid. Check that you opened the whole link.',
      RenewalOutcome.revoked => 'This invitation was cancelled. Contact the person who sent it.',
      RenewalOutcome.accepted => 'You already accepted this invitation.',
      RenewalOutcome.emailMismatch => 'This invitation was sent to a different email address. Sign in with the address it was sent to.',
      RenewalOutcome.failed => 'That could not be sent. Check your connection and try again.',
    };
