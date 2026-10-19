import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Brief 15 Oct, section 1: the app is called BottlesUp Business (the customer app stays BottlesUp). Where a person can read it, the old names
/// "Vendor", "Bottles Up Vendor" and "BottlesUp Vendor" must not come back. Code and comments may still say vendor (the database does).
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('the phone shows BottlesUp Business under the icon, on Android and iOS', () {
    expect(read('android/app/src/main/AndroidManifest.xml'), contains('android:label="BottlesUp Business"'));
    final plist = read('ios/Runner/Info.plist');
    expect(RegExp(r'<key>CFBundleDisplayName</key>\s*<string>BottlesUp Business</string>').hasMatch(plist), isTrue);
    expect(RegExp(r'<key>CFBundleName</key>\s*<string>BottlesUp Business</string>').hasMatch(plist), isTrue);
  });

  test('the old product names appear in no text a person reads in the app, the web page or the package description', () {
    final offenders = <String>[];
    final old = RegExp(r'Bottles ?Up Vendor');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      var n = 0;
      for (final line in f.readAsLinesSync()) {
        n++;
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue; // comments are not shown to anyone
        if (old.hasMatch(line)) offenders.add('${f.path}:$n');
      }
    }
    expect(offenders, isEmpty, reason: 'rename these to BottlesUp Business: $offenders');
    expect(old.hasMatch(read('web/delete_account.html')), isFalse);
    expect(old.hasMatch(read('pubspec.yaml')), isFalse);
  });

  test('the screens that introduce the app use the new name', () {
    expect(read('lib/main.dart'), contains("title: 'BottlesUp Business'"));
    expect(read('lib/core/startup/startup_error_app.dart'), contains("title: 'BottlesUp Business'"));
    expect(read('lib/features/profile/screens/about_screen.dart'), contains("applicationName: 'BottlesUp Business'"));
    expect(read('lib/features/profile/screens/terms_of_service_screen.dart'), contains('Welcome to BottlesUp Business'));
  });

  test('the customer app keeps its own name (this app does not rename it)', () {
    // The customer app lives next to this one; if it is checked out, its display name is still BottlesUp.
    final plist = File('../bottles-up-user/ios/Runner/Info.plist');
    if (!plist.existsSync()) return;
    expect(plist.readAsStringSync(), isNot(contains('BottlesUp Business')));
  });
}
