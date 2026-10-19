import 'package:bottles_up_vendor/core/crash/crash_reporting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  group('runWithCrashReporting', () {
    test('this test build has no SENTRY_DSN, so crash reporting is off', () {
      expect(crashReportingEnabled, isFalse);
      expect(sentryDsn, isEmpty);
    });

    test('with no address the app just runs, once, and Sentry is never started', () async {
      var ran = 0;
      var started = 0;
      await runWithCrashReporting(
        appRunner: () async => ran++,
        initSentry: (_, __) async => started++,
      );
      expect(ran, 1);
      expect(started, 0);
    });

    test('with an address Sentry is started with the app inside it', () async {
      var ran = 0;
      FlutterOptionsConfiguration? config;
      AppRunner? runner;
      await runWithCrashReporting(
        appRunner: () async => ran++,
        dsn: 'https://key@example.test/1',
        environment: 'staging',
        initSentry: (c, r) async {
          config = c;
          runner = r;
        },
      );
      expect(config, isNotNull);
      expect(runner, isNotNull);
      expect(ran, 0, reason: 'the app is run by Sentry, inside its handlers');
      await runner!();
      expect(ran, 1);
      final options = SentryFlutterOptions();
      await config!(options);
      expect(options.dsn, 'https://key@example.test/1');
      expect(options.environment, 'staging');
    });
  });

  group('what is sent', () {
    SentryFlutterOptions configured() {
      final o = SentryFlutterOptions();
      configureSentry(o, dsn: 'https://key@example.test/1', environment: 'production');
      return o;
    }

    test('errors only, nothing personal, no screenshots, no breadcrumbs', () {
      final o = configured();
      expect(o.sendDefaultPii, isFalse);
      expect(o.attachScreenshot, isFalse);
      // ignore: experimental_member_use
      expect(o.attachViewHierarchy, isFalse);
      expect(o.tracesSampleRate, 0);
      expect(o.maxBreadcrumbs, 0);
      expect(o.beforeSend, isNotNull);
    });

    test('an event loses its user details, request and breadcrumbs before it is sent', () async {
      final event = SentryEvent(
        user: SentryUser(id: 'u1', email: 'a@x.test', ipAddress: '1.2.3.4'),
        request: SentryRequest(url: 'https://x.test/rest/v1/vendors?email=eq.a@x.test'),
        breadcrumbs: [Breadcrumb(message: 'GET /rest/v1/vendors?email=eq.a@x.test')],
        message: SentryMessage('boom'),
      );
      final scrubbed = await scrubEvent(event, Hint());
      expect(scrubbed, isNotNull);
      expect(scrubbed!.user?.id, anonymousUserId);
      expect(scrubbed.user?.email, isNull);
      expect(scrubbed.user?.ipAddress, isNull);
      expect(scrubbed.request?.url, isNull);
      expect(scrubbed.request?.queryString, isNull);
      expect(scrubbed.breadcrumbs, isEmpty);
      expect(scrubbed.message?.formatted, 'boom', reason: 'the error itself is kept');
    });
  });
}
