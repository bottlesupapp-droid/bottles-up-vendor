import 'dart:io';

import 'package:bottles_up_vendor/core/config/password_reset_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pieces of the password-reset flow that live outside Dart: the scheme the website's page opens the app on, and the address the app asks Supabase to use.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  String read(String path) => File(path).readAsStringSync();

  test('the app asks Supabase for the website address that tells the email this is BottlesUp Business', () {
    expect(passwordResetRedirect, 'https://www.bottlesupapp.com/reset-password?app=business');
    final uri = Uri.parse(passwordResetRedirect);
    expect([uri.scheme, uri.host, uri.path, uri.queryParameters], ['https', 'www.bottlesupapp.com', '/reset-password', {'app': 'business'}]);
  });

  test('the request for the email passes that address', () {
    expect(read('lib/features/auth/services/supabase_auth_service.dart'), contains('resetPasswordForEmail(email, redirectTo: passwordResetRedirect)'));
    expect(read('lib/features/auth/services/password_recovery_service.dart'), contains('resetPasswordForEmail(email, redirectTo: passwordResetRedirect)'));
  });

  test('Android opens the app on the business scheme, for the website\'s page', () {
    expect(businessAppScheme, 'bottlesupbusiness');
    final live = manifest.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    final filters = RegExp(r'<intent-filter[^>]*>[\s\S]*?</intent-filter>').allMatches(live).map((m) => m.group(0)!).toList();
    final ours = filters.where((f) => f.contains('android:scheme="bottlesupbusiness"')).toList();
    expect(ours, hasLength(1));
    expect(ours.single, contains('android:host="app"'));
    expect(ours.single, contains('android.intent.action.VIEW'));
    expect(ours.single, contains('android.intent.category.BROWSABLE'));
    expect(ours.single, isNot(contains('autoVerify')), reason: 'verification is for web addresses; this is the app\'s own scheme');
  });

  test('adding it did not touch the invitation link: it is still a verified web address', () {
    final live = manifest.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    expect(live, contains('android:scheme="https" android:host="www.bottlesupapp.com" android:pathPrefix="/accept-invite"'));
    expect(live, contains('android:autoVerify="true"'));
  });

  test('iOS has the scheme, next to the Google sign-in one', () {
    expect(RegExp(r'<key>CFBundleURLSchemes</key>\s*<array>\s*<string>bottlesupbusiness</string>\s*</array>').hasMatch(plist), isTrue);
    expect(plist, contains('com.googleusercontent.apps.49598092873-0ubqrl5je9vkl68sjohn2an7l2pgeki9'));
  });

  test('the link package is a direct dependency, because the app now imports it', () {
    expect(read('pubspec.yaml'), contains('  app_links: '));
    expect(read('lib/features/auth/services/recovery_link_listener.dart'), contains("import 'package:app_links/app_links.dart';"));
  });

  test('the app wraps itself in the link listener', () {
    expect(read('lib/main.dart'), contains('RecoveryLinkListener(child:'));
  });
}
