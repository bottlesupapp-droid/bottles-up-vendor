import 'dart:io';

import 'package:bottles_up_vendor/features/profile/logic/data_collected.dart';
import 'package:flutter_test/flutter_test.dart';

// Apple wants every app to carry a privacy manifest (PrivacyInfo.xcprivacy). This keeps the app's own in step with the Xcode project and with what the app says it collects: the list in the
// app (Settings > What this app collects, data_collected.dart) and the monorepo's docs/DATA_COLLECTED_BUSINESS_APP.md. Nothing here can run the manifest through Apple's checker (that happens
// when a build is archived and uploaded), so these only guard what can be read: that the file is in the Runner target, and what it declares.
void main() {
  final manifest = File('ios/Runner/PrivacyInfo.xcprivacy');
  final project = File('ios/Runner.xcodeproj/project.pbxproj');

  String text() => manifest.readAsStringSync();

  // What the app collects, as Apple names the kinds. Each has a line in data_collected.dart; if one is added there, add it here and in docs/DATA_COLLECTED_BUSINESS_APP.md.
  const expected = {
    'Name': 'Your account / Bookings and their guests',
    'EmailAddress': 'Your account / Bookings and their guests',
    'PhoneNumber': 'Your account / Bookings and their guests',
    'UserID': 'Your account / Who did each thing',
    'PhotosorVideos': 'Camera and photos',
    'OtherUserContent': 'What you enter about the night (chat, notes, incident reports)',
    'PurchaseHistory': 'What you enter about the night (orders, payments, refunds)',
  };

  List<String> declared() => RegExp(r'<string>NSPrivacyCollectedDataType([A-Za-z]+)</string>').allMatches(text()).map((m) => m.group(1)!).where((n) => !n.startsWith('Purpose')).toList();

  test('the manifest exists, is a property list, says the app does not track, and names no tracking domain', () {
    expect(manifest.existsSync(), isTrue);
    final t = text();
    expect(t, startsWith('<?xml'));
    expect(RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(t), isTrue);
    expect(RegExp(r'<key>NSPrivacyTrackingDomains</key>\s*<array/>').hasMatch(t), isTrue);
    expect(RegExp(r'<key>NSPrivacyCollectedDataTypeTracking</key>\s*<true/>').hasMatch(t), isFalse);
  });

  test('it declares exactly the kinds of data the app says it collects, each for the app\'s own function', () {
    expect(declared().toSet(), expected.keys.toSet());
    expect(declared().length, expected.length, reason: 'each kind once');
    final purposes = RegExp(r'<string>(NSPrivacyCollectedDataTypePurpose[A-Za-z]+)</string>').allMatches(text()).map((m) => m.group(1)!).toSet();
    expect(purposes, {'NSPrivacyCollectedDataTypePurposeAppFunctionality'}, reason: 'no analytics, no advertising, no marketing');
    expect(RegExp(r'<key>NSPrivacyCollectedDataTypeLinked</key>\s*<true/>').allMatches(text()).length, expected.length);
  });

  test('it never declares what the app says it does not collect (location, contacts, advertising, browsing)', () {
    final says = dataCollected.firstWhere((s) => s.title == 'What the app does not collect').lines.join(' ');
    expect(says, allOf(contains('location'), contains('contacts'), contains('advertising')));
    for (final never in ['Location', 'Contacts', 'DeviceID', 'AdvertisingData', 'BrowsingHistory', 'SearchHistory', 'PaymentInfo', 'CreditInfo', 'Health', 'Fitness', 'SensitiveInfo']) {
      expect(declared(), isNot(contains(never)), reason: never);
    }
  });

  test('every kind declared has something in the app\'s own list that says it, in words', () {
    final all = dataCollected.expand((s) => s.lines).join(' ').toLowerCase();
    for (final needle in ['email address', 'phone number', 'name', 'photos', 'chat messages', 'incident reports', 'payments you record']) {
      expect(all, contains(needle), reason: needle);
    }
  });

  test('the Xcode project carries the file in the Runner app target (and not in the tests), so a build bundles it', () {
    final p = project.readAsStringSync();
    final ref = RegExp(r'(\w{24}) /\* PrivacyInfo\.xcprivacy \*/ = \{isa = PBXFileReference;[^}]*path = PrivacyInfo\.xcprivacy;').firstMatch(p);
    expect(ref, isNotNull, reason: 'a file reference');
    final id = ref!.group(1)!;
    final build = RegExp('(\\w{24}) /\\* PrivacyInfo\\.xcprivacy in Resources \\*/ = \\{isa = PBXBuildFile; fileRef = $id ').firstMatch(p);
    expect(build, isNotNull, reason: 'a build file');
    final buildId = build!.group(1)!;
    // it is in the Runner group ...
    final group = RegExp(r'/\* Runner \*/ = \{\s*isa = PBXGroup;\s*children = \(([^)]*)\)').firstMatch(p)!.group(1)!;
    expect(group, contains(id));
    // ... and in the resources phase of the app target, which is the one holding the storyboards
    final phases = RegExp(r'isa = PBXResourcesBuildPhase;[\s\S]*?files = \(([^)]*)\)').allMatches(p).map((m) => m.group(1)!).toList();
    final withIt = phases.where((f) => f.contains(buildId)).toList();
    expect(withIt.length, 1);
    expect(withIt.single, contains('Main.storyboard'), reason: 'the app target, not RunnerTests');
  });
}
