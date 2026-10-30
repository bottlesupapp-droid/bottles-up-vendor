import 'dart:io';

import 'package:bottles_up_vendor/core/config/google_sign_in_config.dart';
import 'package:bottles_up_vendor/features/auth/services/social_sign_in_service.dart';
import 'package:bottles_up_vendor/features/auth/widgets/social_sign_in_buttons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _suffix = '.apps.googleusercontent.com';

/// The scheme Google returns to after its sign-in sheet: the client id written backwards.
String _reversed(String clientId) => 'com.googleusercontent.apps.${clientId.substring(0, clientId.length - _suffix.length)}';

void main() {
  group('Google sign-in on iPhone', () {
    test('the iOS client is set, belongs to the same Google project as the web client, and is not the web client', () {
      expect(GoogleSignInConfig.iosClientId, endsWith(_suffix));
      expect(GoogleSignInConfig.iosClientId.split('-').first, GoogleSignInConfig.webClientId.split('-').first);
      expect(GoogleSignInConfig.iosClientId, isNot(GoogleSignInConfig.webClientId));
    });

    test('so Google is offered on iPhone, with Apple under it', () {
      expect(GoogleSignInConfig.isConfiguredFor(TargetPlatform.iOS), isTrue);
      expect(socialProvidersFor(TargetPlatform.iOS), [SocialProvider.google, SocialProvider.apple]);
    });

    test('Info.plist has the iOS client\'s reversed id as a URL scheme (without it the sign-in sheet cannot come back to the app)', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>CFBundleURLTypes</key>'));
      expect(plist, contains('<string>${_reversed(GoogleSignInConfig.iosClientId)}</string>'));
    });

    test('and only that one Google scheme is registered', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(RegExp(r'<string>com\.googleusercontent\.apps\.[^<]+</string>').allMatches(plist).length, 1);
    });
  });
}
