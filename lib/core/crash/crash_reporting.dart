import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash reporting (Sentry). Off unless the build is given the project's address (its DSN):
///
///   flutter build ... --dart-define=SENTRY_DSN=YOUR_DSN_FROM_THE_SENTRY_PROJECT_SETTINGS
///
/// With no `SENTRY_DSN` nothing is initialised and nothing leaves the phone. It reports crashes and uncaught errors only: no
/// performance traces, no screenshots, no breadcrumbs (they would record the addresses the app calls, and those can carry emails), and
/// no personal details (`sendDefaultPii` stays false, and [scrubEvent] removes the user and request again before sending).
const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
const String sentryEnvironment = String.fromEnvironment('SENTRY_ENV', defaultValue: 'production');

bool get crashReportingEnabled => sentryDsn.isNotEmpty;

/// Runs [appRunner], with crash reporting around it when [dsn] is set. [initSentry] is only for tests.
Future<void> runWithCrashReporting({
  required Future<void> Function() appRunner,
  String dsn = sentryDsn,
  String environment = sentryEnvironment,
  Future<void> Function(FlutterOptionsConfiguration, AppRunner?)? initSentry,
}) async {
  if (dsn.isEmpty) {
    await appRunner();
    return;
  }
  await (initSentry ?? SentryFlutter.init)(
    (options) => configureSentry(options, dsn: dsn, environment: environment),
    appRunner,
  );
}

/// The options we send with, kept apart so a test can look at every one of them.
void configureSentry(SentryFlutterOptions options, {required String dsn, required String environment}) {
  options
    ..dsn = dsn
    ..environment = environment
    ..sendDefaultPii = false
    ..attachScreenshot = false
    // ignore: experimental_member_use
    ..attachViewHierarchy = false
    ..tracesSampleRate = 0
    ..maxBreadcrumbs = 0
    ..beforeSend = scrubEvent;
}

/// The one user every event is sent as.
const String anonymousUserId = 'anonymous';

/// Last look at an event before it leaves the phone: whatever the SDK collected about the person, the request or the trail of
/// breadcrumbs is replaced. (copyWith cannot set a field to null, so the user and request are replaced by empty ones.)
FutureOr<SentryEvent?> scrubEvent(SentryEvent event, Hint hint) {
  return event.copyWith(user: SentryUser(id: anonymousUserId), request: SentryRequest(), breadcrumbs: const []);
}
