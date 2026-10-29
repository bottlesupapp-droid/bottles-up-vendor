import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/site_contact.dart';
import '../services/site_contact_service.dart';

final siteContactServiceProvider = Provider<SiteContactService>((ref) => SiteContactService());

/// How to reach BottlesUp, read again each time the screen opens (the team can change it in the CMS at any time).
final siteContactProvider = FutureProvider.autoDispose<SiteContact>((ref) => ref.watch(siteContactServiceProvider).load());
