import 'package:flutter/foundation.dart';

/// The Google Cloud client ids the Google sign-in needs. They are public identifiers, not secrets. Setup steps (and what Supabase's Google provider must list) are in docs/SOCIAL_LOGIN_SETUP.md
/// of the monorepo.
class GoogleSignInConfig {
  /// The "Web application" client. Google puts its id in the token it hands back, which is what Supabase's Google provider checks; Android uses it too.
  static const String webClientId = '49598092873-vvb9c9oqi02o1e94iodqv9t5c8oeghp9.apps.googleusercontent.com';

  /// The iOS client for this app's bundle id. Empty until it is created in Google Cloud: while it is empty Google sign-in is not offered on iPhone (Apple sign-in is).
  static const String iosClientId = '';

  /// Whether the Google sign-in can work on [platform] with what is configured.
  static bool isConfiguredFor(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.iOS:
        return iosClientId.isNotEmpty && webClientId.isNotEmpty;
      case TargetPlatform.android:
        return webClientId.isNotEmpty;
      default:
        return false;
    }
  }
}
