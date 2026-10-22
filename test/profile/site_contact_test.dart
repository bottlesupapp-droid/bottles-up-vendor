import 'dart:io';

import 'package:bottles_up_vendor/core/config/app_info.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/profile/logic/site_contact.dart';
import 'package:bottles_up_vendor/features/profile/providers/site_contact_provider.dart';
import 'package:bottles_up_vendor/features/profile/screens/about_screen.dart';
import 'package:bottles_up_vendor/features/profile/screens/contact_support_screen.dart';
import 'package:bottles_up_vendor/features/profile/services/site_contact_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const fullRow = {
  'contact_email': 'hello@bottlesupapp.com',
  'contact_phone': '+14169999999',
  'address': 'Toronto, ON, Canada',
  'social_instagram': 'https://www.instagram.com/bottlesupapp',
  'social_twitter': 'https://twitter.com/bottlesup_to',
  'social_facebook': 'https://facebook.com/bottlesup.toronto',
  'social_linkedin': 'https://linkedin.com/company/bottlesup-toronto',
};

void main() {
  group('how to reach BottlesUp', () {
    test('is read from the CMS row, and only what is there', () {
      final c = parseSiteContact(fullRow);
      expect([c.email, c.phone, c.address], ['hello@bottlesupapp.com', '+14169999999', 'Toronto, ON, Canada']);
      expect([for (final s in c.socials) s.name], ['Instagram', 'Facebook', 'Twitter', 'LinkedIn']);
      expect(c.isEmpty, isFalse);
      expect(c.hasEmail && c.hasPhone, isTrue);
    });

    test('nothing set is empty, never a made-up default', () {
      for (final row in <Map<String, dynamic>?>[null, {}, {'contact_email': '  ', 'contact_phone': '', 'address': null}]) {
        final c = parseSiteContact(row);
        expect(c.isEmpty, isTrue);
        expect([c.hasEmail, c.hasPhone], [false, false]);
      }
    });

    test('an e-mail that is not one, a phone with too few digits and a social page that is not a web address are left out', () {
      final c = parseSiteContact({
        'contact_email': 'not an email',
        'contact_phone': '12',
        'social_instagram': 'javascript:alert(1)',
        'social_facebook': 'facebook.com/bottlesup',
        'social_twitter': 'ftp://x.example/y',
        'social_linkedin': 'https://linkedin.com/company/x',
      });
      expect(c.email, isNull);
      expect(c.hasPhone, isFalse);
      expect([for (final s in c.socials) s.name], ['LinkedIn']);
    });

    test('a phone number is dialled as digits with a leading plus only', () {
      expect(telUri('+1 (416) 999-9999').toString(), 'tel:+14169999999');
      expect(telUri('416 999 9999').toString(), 'tel:4169999999');
      expect(telUri('+1+4'), isNull);
      expect(telUri('1234567890123456'), isNull);
    });

    test('web addresses must be http or https with a host', () {
      expect(webUri('https://example.com/x')!.host, 'example.com');
      expect(webUri('http://example.com'), isNotNull);
      for (final bad in [null, '', 'example.com', 'mailto:a@b.co', 'https://', 'javascript:1']) {
        expect(webUri(bad), isNull, reason: '$bad');
      }
    });

    test('a message is built for the person\'s own mail app, with real spaces and line breaks, and who it is from', () {
      final u = supportMailto('hello@bottlesupapp.com', category: 'Payment issue', subject: ' Refund & deposit ', message: 'Line one\nLine two', from: 'mia@club.example');
      expect(u.scheme, 'mailto');
      expect(u.path, 'hello@bottlesupapp.com');
      expect(u.toString(), contains('subject=%5BPayment%20issue%5D%20Refund%20%26%20deposit'));
      final q = Uri.splitQueryString(u.query);
      expect(q['subject'], '[Payment issue] Refund & deposit');
      expect(q['body'], 'Line one\nLine two\n\nFrom: mia@club.example');
      expect(Uri.splitQueryString(supportMailto('a@b.co', category: 'X', subject: 's', message: 'm').query)['body'], 'm');
    });

    test('a message needs a subject and enough words', () {
      expect(validateSupportMessage(subject: '', message: 'x' * 30), 'Please enter a subject.');
      expect(validateSupportMessage(subject: 's', message: 'too short'), 'Please say a little more (at least 20 characters).');
      expect(validateSupportMessage(subject: 's', message: 'x' * 20), isNull);
    });
  });

  test('the version the app states is the version of the build', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', multiLine: true).firstMatch(pubspec)!;
    expect(appVersion, m.group(1));
    expect(appBuild, int.parse(m.group(2)!));
    expect(appVersionLabel, 'Version $appVersion (build $appBuild)');
  });

  test('no screen of the app states a company, an address, a number or a promise that nobody gave', () {
    for (final path in ['lib/features/profile/screens/about_screen.dart', 'lib/features/profile/screens/contact_support_screen.dart', 'lib/features/profile/screens/profile_screen.dart']) {
      final text = File(path).readAsStringSync();
      for (final invented in ['800-BOTTLES', 'support@bottlesup.com', 'info@bottlesup.com', 'Bottles Up Inc', 'New York, USA', '24/7', 'Live Chat', 'within 24 hours', 'Support ticket submitted', 'Version 1.0.0', 'instagram.com/bottlesup\'']) {
        expect(text, isNot(contains(invented)), reason: '$path: $invented');
      }
    }
  });

  group('the screens', () {
    late List<Uri> opened;
    late bool canOpen;
    late Object? loadError;
    late Map<String, dynamic>? row;
    int loads = 0;

    Widget host(Widget screen) => ProviderScope(
          key: UniqueKey(),
          overrides: [
            siteContactServiceProvider.overrideWithValue(SiteContactService(loader: () async {
              loads++;
              final e = loadError;
              if (e != null) throw e;
              return row;
            })),
            contactLinkOpenerProvider.overrideWithValue((uri) async {
              opened.add(uri);
              return canOpen;
            }),
            currentVendorUserProvider.overrideWithValue(null),
          ],
          child: MaterialApp(theme: ThemeData.dark(), home: screen),
        );

    Future<void> show(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(screen));
      await tester.pumpAndSettle();
    }

    setUp(() {
      opened = [];
      canOpen = true;
      loadError = null;
      row = fullRow;
      loads = 0;
    });

    group('Contact Support', () {
      testWidgets('shows the e-mail and phone the team published, and nothing else about support', (tester) async {
        await show(tester, const ContactSupportScreen());
        expect(find.text('hello@bottlesupapp.com'), findsOneWidget);
        expect(find.text('+14169999999'), findsOneWidget);
        for (final promise in ['24/7', 'Live Chat', 'Coming Soon', 'within 24 hours', '800']) {
          expect(find.textContaining(promise), findsNothing, reason: promise);
        }
      });

      testWidgets('tapping the e-mail or the phone opens them', (tester) async {
        await show(tester, const ContactSupportScreen());
        await tester.tap(find.byKey(const Key('contact-email')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('contact-phone')));
        await tester.pump();
        expect(opened.map((u) => u.toString()), ['mailto:hello@bottlesupapp.com', 'tel:+14169999999']);
      });

      testWidgets('when nothing can open them, the person is told what to do instead', (tester) async {
        canOpen = false;
        await show(tester, const ContactSupportScreen());
        await tester.tap(find.byKey(const Key('contact-email')));
        await tester.pump();
        expect(find.text('No email app could be opened. You can write to hello@bottlesupapp.com yourself.'), findsOneWidget);
      });

      testWidgets('a message needs a subject and enough words before anything opens', (tester) async {
        await show(tester, const ContactSupportScreen());
        await tester.ensureVisible(find.byKey(const Key('contact-write')));
        await tester.tap(find.byKey(const Key('contact-write')));
        await tester.pump();
        expect(find.text('Please enter a subject.'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('contact-subject')), 'Deposit');
        await tester.tap(find.byKey(const Key('contact-write')));
        await tester.pump();
        expect(find.text('Please say a little more (at least 20 characters).'), findsOneWidget);
        expect(opened, isEmpty);
      });

      testWidgets('a good message opens the person\'s own mail app, ready to send, and does not claim anything was sent', (tester) async {
        await show(tester, const ContactSupportScreen());
        await tester.enterText(find.byKey(const Key('contact-subject')), 'Deposit');
        await tester.enterText(find.byKey(const Key('contact-message')), 'The deposit on my booking shows twice.');
        await tester.ensureVisible(find.byKey(const Key('contact-write')));
        await tester.tap(find.byKey(const Key('contact-write')));
        await tester.pumpAndSettle();
        final u = opened.single;
        expect([u.scheme, u.path], ['mailto', 'hello@bottlesupapp.com']);
        expect(Uri.splitQueryString(u.query)['subject'], '[General question] Deposit');
        expect(Uri.splitQueryString(u.query)['body'], 'The deposit on my booking shows twice.');
        expect(find.textContaining('submitted'), findsNothing);
        expect(find.textContaining('Nothing is sent from here'), findsOneWidget);
      });

      testWidgets('with no e-mail published there is nothing to write to, and it says so', (tester) async {
        row = {'contact_phone': '+14169999999'};
        await show(tester, const ContactSupportScreen());
        expect(find.byKey(const Key('contact-write')), findsNothing);
        expect(find.byKey(const Key('contact-email')), findsNothing);
        expect(find.byKey(const Key('contact-phone')), findsOneWidget);
      });

      testWidgets('with nothing published at all it says so, and shows no invented contact', (tester) async {
        row = null;
        await show(tester, const ContactSupportScreen());
        expect(find.byKey(const Key('contact-none')), findsOneWidget);
        expect(find.byKey(const Key('contact-write')), findsNothing);
      });

      testWidgets('contact details that cannot be loaded say so, and can be tried again', (tester) async {
        loadError = Exception('socket closed');
        await show(tester, const ContactSupportScreen());
        expect(find.textContaining('We could not load our contact details'), findsOneWidget);
        loadError = null;
        await tester.tap(find.byKey(const Key('contact-retry')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('contact-email')), findsOneWidget);
        expect(loads, 2);
      });
    });

    group('About', () {
      Widget routed() => ProviderScope(
            key: UniqueKey(),
            overrides: [
              siteContactServiceProvider.overrideWithValue(SiteContactService(loader: () async => row)),
              contactLinkOpenerProvider.overrideWithValue((uri) async {
                opened.add(uri);
                return true;
              }),
            ],
            child: MaterialApp.router(
              theme: ThemeData.dark(),
              routerConfig: GoRouter(routes: [
                GoRoute(path: '/', builder: (_, __) => const AboutScreen()),
                GoRoute(path: '/legal/terms', builder: (_, __) => const Scaffold(body: Text('terms page'))),
                GoRoute(path: '/legal/privacy', builder: (_, __) => const Scaffold(body: Text('privacy page'))),
              ]),
            ),
          );

      Future<void> showAbout(WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(routed());
        await tester.pumpAndSettle();
      }

      testWidgets('states the real version, and the contact and social pages the team published', (tester) async {
        await showAbout(tester);
        expect(find.text(appVersionLabel), findsOneWidget);
        expect(find.byKey(const Key('about-contact')), findsOneWidget);
        expect(find.text('hello@bottlesupapp.com'), findsOneWidget);
        expect(find.text('+14169999999'), findsOneWidget);
        expect(find.text('Toronto, ON, Canada'), findsOneWidget);
        for (final name in ['instagram', 'facebook', 'twitter', 'linkedin']) {
          expect(find.byKey(Key('about-social-$name')), findsOneWidget, reason: name);
        }
        for (final invented in ['Bottles Up Inc', 'New York', 'Founded', '24/7', '800-BOTTLES', 'Version 1.0.0']) {
          expect(find.textContaining(invented), findsNothing, reason: invented);
        }
      });

      testWidgets('a social page opens at the address the team gave', (tester) async {
        await showAbout(tester);
        await tester.ensureVisible(find.byKey(const Key('about-social-instagram')));
        await tester.tap(find.byKey(const Key('about-social-instagram')));
        await tester.pump();
        expect(opened.single.toString(), 'https://www.instagram.com/bottlesupapp');
      });

      testWidgets('with nothing published there is no contact card at all', (tester) async {
        row = null;
        await showAbout(tester);
        expect(find.byKey(const Key('about-contact')), findsNothing);
        expect(find.text(appVersionLabel), findsOneWidget);
      });

      testWidgets('the legal rows open the app\'s own pages', (tester) async {
        await showAbout(tester);
        await tester.ensureVisible(find.text('Terms of Service'));
        await tester.tap(find.text('Terms of Service'));
        await tester.pumpAndSettle();
        expect(find.text('terms page'), findsOneWidget);
      });
    });
  });
}
