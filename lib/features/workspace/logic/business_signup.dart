// Business accounts (a venue owner or an event organizer) are created on the website, not in this app: the
// website makes the organization and the first workspace in one step. These helpers are the app's side of that.

/// The website page where a business account is created. [site] is the site's origin (`siteUrl`, the same
/// address the booking links use).
Uri businessSignupUri(String site) => Uri.parse('${site.replaceAll(RegExp(r'/+$'), '')}/signup/business');

final RegExp _bareToken = RegExp(r'^[A-Za-z0-9_-]{32,128}$');

/// The invitation token inside what a person pasted: the whole link from the invitation email
/// (`https://.../accept-invite?token=...`) or the token on its own. Null when it is neither.
///
/// Only the shape is checked here. The database decides whether the token is real, still valid and for this email,
/// and the invitation screen says which of those it is.
String? invitationTokenFrom(String pasted) {
  final text = pasted.trim();
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasQuery) {
    final token = uri.queryParameters['token']?.trim();
    if (token != null && _bareToken.hasMatch(token)) return token;
    return null;
  }
  return _bareToken.hasMatch(text) ? text : null;
}
