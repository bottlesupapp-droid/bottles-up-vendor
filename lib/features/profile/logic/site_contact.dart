// How to reach BottlesUp, as the BottlesUp team has set it in the CMS (the website's Content page, table `site_content`, one public row): the contact e-mail and phone, the address and the
// social pages. The app shows exactly these and nothing it makes up; a value the team has not filled in is simply not shown. Pure Dart, tested without a screen.

String? _text(Object? v) {
  final s = v is String ? v.trim() : null;
  return s == null || s.isEmpty ? null : s;
}

class SocialLink {
  const SocialLink(this.name, this.url);

  final String name;
  final Uri url;
}

class SiteContact {
  const SiteContact({this.email, this.phone, this.address, this.socials = const []});

  final String? email;
  final String? phone;
  final String? address;
  final List<SocialLink> socials;

  bool get hasEmail => email != null;
  bool get hasPhone => phone != null && telUri(phone!) != null;
  bool get isEmpty => email == null && phone == null && address == null && socials.isEmpty;
}

/// An absolute web address, or null (an app never opens something it cannot tell is a web page: no `javascript:`, no bare words).
Uri? webUri(String? value) {
  final s = _text(value);
  if (s == null) return null;
  final u = Uri.tryParse(s);
  if (u == null || !u.hasScheme || (u.scheme != 'https' && u.scheme != 'http') || u.host.isEmpty) return null;
  return u;
}

final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// One `site_content` row. Null or an empty row is "nothing set".
SiteContact parseSiteContact(Map<String, dynamic>? row) {
  if (row == null) return const SiteContact();
  final email = _text(row['contact_email']);
  final socials = <SocialLink>[
    for (final (name, key) in const [('Instagram', 'social_instagram'), ('Facebook', 'social_facebook'), ('Twitter', 'social_twitter'), ('LinkedIn', 'social_linkedin')])
      if (webUri(row[key] as String?) case final url?) SocialLink(name, url),
  ];
  return SiteContact(
    email: email != null && _emailShape.hasMatch(email) ? email : null,
    phone: _text(row['contact_phone']),
    address: _text(row['address']),
    socials: socials,
  );
}

/// `tel:` for a phone number: digits and a leading plus only (spaces, dashes and brackets are dropped). Null when there are not enough digits to be a number.
Uri? telUri(String phone) {
  final kept = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final digits = kept.replaceAll('+', '');
  if (digits.length < 7 || digits.length > 15) return null;
  return Uri(scheme: 'tel', path: kept.startsWith('+') ? '+$digits' : digits);
}

/// A message to BottlesUp, ready in the person's own mail app. Nothing is sent from here: the person reads it and presses send.
Uri supportMailto(String to, {required String category, required String subject, required String message, String? from}) {
  final body = StringBuffer(message.trim());
  if (from != null && from.trim().isNotEmpty) body.write('\n\nFrom: ${from.trim()}');
  return Uri(
    scheme: 'mailto',
    path: to,
    // Uri.query would turn spaces into plus signs, which mail apps show literally: build the encoded query by hand.
    query: 'subject=${Uri.encodeComponent('[$category] ${subject.trim()}')}&body=${Uri.encodeComponent(body.toString())}',
  );
}

/// The first thing wrong with a message about to be written, or null.
String? validateSupportMessage({required String subject, required String message}) {
  if (subject.trim().isEmpty) return 'Please enter a subject.';
  if (message.trim().length < 20) return 'Please say a little more (at least 20 characters).';
  return null;
}
