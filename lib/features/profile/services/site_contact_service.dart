import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/site_contact.dart';

/// Reads how to reach BottlesUp from the public `site_content` row (readable by everyone; only a BottlesUp administrator can change it, in the CMS).
class SiteContactService {
  SiteContactService({SupabaseClient? client, Future<Map<String, dynamic>?> Function()? loader})
      : _client = client,
        _loader = loader;

  final SupabaseClient? _client;
  final Future<Map<String, dynamic>?> Function()? _loader;

  /// Throws when the row cannot be read (no connection): the screen says so with Try again. A row that is missing or empty is not an error; it is "nothing set".
  Future<SiteContact> load() async {
    final loader = _loader;
    if (loader != null) return parseSiteContact(await loader());
    final row = await (_client ?? Supabase.instance.client)
        .from('site_content')
        .select('contact_email, contact_phone, address, social_instagram, social_twitter, social_facebook, social_linkedin')
        .eq('id', 1)
        .maybeSingle();
    return parseSiteContact(row == null ? null : Map<String, dynamic>.from(row));
  }
}
