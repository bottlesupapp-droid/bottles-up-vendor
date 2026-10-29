/// The version this app says it is. Kept equal to `version:` in pubspec.yaml by a test (test/profile/site_contact_test.dart), so a screen never states a version the build does not have.
const String appVersion = '1.3.1';
const int appBuild = 9;

/// "Version 1.3.1 (build 9)".
String get appVersionLabel => 'Version $appVersion (build $appBuild)';
