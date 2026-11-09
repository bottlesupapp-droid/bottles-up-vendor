import 'package:flutter/foundation.dart';

/// Sample screens: layouts for parts of the Business app design that are not built yet (a DJ / Artist role, an Ambassador role, an Event
/// Lead role, and several tools inside the roles that exist). They show made-up names and numbers, save nothing and send nothing.
///
/// They are for looking at, not for people running a night, so by default they exist only in debug builds. Build with
/// `--dart-define=BU_PREVIEWS=true` to see them in a release or profile build (for example to show the client on a phone); the
/// same switch with `false` turns them off in a debug build.
const bool kPreviewsEnabled = bool.fromEnvironment('BU_PREVIEWS', defaultValue: kDebugMode);

/// Where the sample screens live in the router. `/preview` is the list, `/preview/{id}` one screen.
abstract final class PreviewRoutes {
  static const String gallery = '/preview';
  static const String prefix = '/preview/';

  static String screen(String id) => '$prefix$id';
}
