import 'dart:io';

import 'package:bottles_up_vendor/core/ui/bu_coming_soon.dart';
import 'package:bottles_up_vendor/features/auth/providers/supabase_auth_provider.dart';
import 'package:bottles_up_vendor/features/profile/screens/business_details_screen.dart';
import 'package:bottles_up_vendor/features/profile/screens/edit_profile_screen.dart';
import 'package:bottles_up_vendor/features/profile/screens/help_center_screen.dart';
import 'package:bottles_up_vendor/features/profile/screens/notifications_screen.dart';
import 'package:bottles_up_vendor/features/profile/screens/security_screen.dart';
import 'package:bottles_up_vendor/features/venues/providers/venues_provider.dart';
import 'package:bottles_up_vendor/shared/models/user_model.dart';
import 'package:bottles_up_vendor/shared/models/venue_model.dart';
import 'package:bottles_up_vendor/shared/widgets/classic_top_bar.dart' show classicRoleLabel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'classic_detail_screens_test.dart' show pumpPage, shot, venue;

// The account pages behind More > Settings, rebuilt in the design's look from what the account really has. What the app cannot do yet says "Coming soon"; nothing is invented
// (no made-up opening hours, no "saved" for a save that saves nothing, no fee or notification the app does not have).
VendorUser user({String? businessName = 'Bottles Up Vendor', String? phone = '+1 416 555 0100', String email = 'owner@bottlesup.test', String? logoUrl}) =>
    VendorUser(id: 'u1', email: email, phone: phone, businessName: businessName, logoUrl: logoUrl, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1), role: 'venue_owner');

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(File('assets/fonts/Inter.ttf').readAsBytes().then(ByteData.sublistView));
    await font.load();
  });

  group('Business details', () {
    Future<void> open(WidgetTester tester, {VendorUser? who, List<Venue> venues = const []}) => pumpPage(
      tester,
      () => const BusinessDetailsScreen(),
      overrides: [currentVendorUserProvider.overrideWithValue(who ?? user()), myVenuesProvider.overrideWith((ref) async => venues)],
      stubs: ['/profile/edit', '/clubs/create', '/clubs/c1'],
    );

    testWidgets('shows what the account has: business name, email and phone, and its role', (tester) async {
      await open(tester, venues: [venue()]);
      expect(find.byKey(const Key('business-name-title')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('business-name-title'))).data, 'Bottles Up Vendor');
      expect(find.text('owner@bottlesup.test'), findsOneWidget);
      expect(find.text('+1 416 555 0100'), findsOneWidget);
      expect(find.text(classicRoleLabel('venue_owner')), findsOneWidget);
      await shot(tester, 'business');
    });

    testWidgets('invents nothing: no made-up opening hours, and a missing phone says "Not added yet"', (tester) async {
      await open(tester, who: user(phone: null));
      expect(find.text('9:00 AM - 5:00 PM'), findsNothing);
      expect(find.text('Closed'), findsNothing);
      expect(find.text('Coming Soon'), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('business-phone')), matching: find.text('Not added yet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('business-phone')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /profile/edit'), findsOneWidget);
    });

    testWidgets('opening hours are Coming soon, and say what they will do', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.byKey(const Key('business-hours-soon')));
      await tester.tap(find.byKey(const Key('business-hours-soon')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coming-soon-close')), findsOneWidget);
      expect(find.text('Opening hours'), findsWidgets);
    });

    testWidgets('the venues are listed with their address and open their page; none says how to add one', (tester) async {
      await open(tester, venues: [venue()]);
      expect(find.text('XnO Lounge'), findsOneWidget);
      expect(find.textContaining('1800 Davenport Road'), findsOneWidget);
      await tester.ensureVisible(find.text('XnO Lounge'));
      await tester.tap(find.text('XnO Lounge'));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /clubs/c1'), findsOneWidget);

      await open(tester);
      expect(find.byKey(const Key('business-no-venues')), findsOneWidget);
    });

    testWidgets('Edit business details opens Edit profile', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.byKey(const Key('business-edit')));
      await tester.tap(find.byKey(const Key('business-edit')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /profile/edit'), findsOneWidget);
    });
  });

  group('Notifications', () {
    testWidgets('says plainly that nothing is sent or saved; every switch is off-limits; there is no Save button', (tester) async {
      await pumpPage(tester, () => const NotificationsScreen());
      expect(find.byKey(const Key('notifications-soon')), findsOneWidget);
      expect(find.text('Notifications are on their way'), findsOneWidget);
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, 8);
      expect(switches.every((s) => s.onChanged == null), isTrue, reason: 'nothing can be changed, so nothing can be "saved"');
      expect(find.text('Save Preferences'), findsNothing);
      expect(find.textContaining('preferences saved'), findsNothing);
      expect(find.text('Nothing here is saved or sent.'), findsOneWidget);
      await shot(tester, 'notifications');
    });
  });

  group('Security', () {
    Future<void> open(WidgetTester tester) => pumpPage(tester, () => const SecurityScreen());

    testWidgets('password, two-step sign-in, login activity and devices are Coming soon rows; there is no fake switch', (tester) async {
      await open(tester);
      for (final k in ['security-password', 'security-2fa', 'security-activity', 'security-devices']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.byType(BuComingSoonPill), findsNWidgets(4));
      expect(find.byType(Switch), findsNothing, reason: 'the two-step switch used to be fixed at off whatever the account had');
      await tester.tap(find.byKey(const Key('security-2fa')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coming-soon-close')), findsOneWidget);
      await shot(tester, 'security');
    });

    testWidgets('Delete Account still asks first, and Cancel leaves everything as it was', (tester) async {
      await open(tester);
      await tester.ensureVisible(find.byKey(const Key('security-delete')));
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Account?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Account?'), findsNothing);
      expect(find.byKey(const Key('security-delete')), findsOneWidget);
    });
  });

  group('Help Center', () {
    testWidgets('promises nothing the app cannot keep: no fee, no push notification, no tab that moved', (tester) async {
      final all = helpFaqs.map((f) => '${f.question} ${f.answer}').join(' ').toLowerCase();
      expect(all.contains('10%'), isFalse, reason: 'the fee schedule is an open client decision');
      expect(all.contains('push notification'), isFalse);
      expect(all.contains('bottom navigation'), isFalse);
      expect(all.contains('profile tab'), isFalse);
      expect(all.contains('three dots'), isFalse);
      expect(helpFaqs.length, 12);
    });

    testWidgets('groups the questions, opens an answer, and filters by a word', (tester) async {
      await pumpPage(tester, () => const HelpCenterScreen(), stubs: ['/support/contact']);
      expect(find.text('GETTING STARTED'), findsOneWidget);
      expect(find.text('How do I create my first event?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('faq-0')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Create event'), findsOneWidget);
      await shot(tester, 'help');

      await tester.enterText(find.byKey(const Key('help-search')), 'inventory');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-contact')), findsNothing, reason: 'a search shows only answers');
      expect(find.text('How do I see my stock?'), findsOneWidget);
      expect(find.text('How do I create my first event?'), findsNothing);

      await tester.enterText(find.byKey(const Key('help-search')), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-none')), findsOneWidget);
    });

    testWidgets('Contact Support opens the contact page (it used a Navigator route the app does not have)', (tester) async {
      await pumpPage(tester, () => const HelpCenterScreen(), stubs: ['/support/contact']);
      await tester.tap(find.byKey(const Key('help-contact')));
      await tester.pumpAndSettle();
      expect(find.text('WENT TO /support/contact'), findsOneWidget);
    });
  });

  group('Edit profile', () {
    Future<void> open(WidgetTester tester, {VendorUser? who}) => pumpPage(tester, () => const EditProfileScreen(), overrides: [currentVendorUserProvider.overrideWithValue(who ?? user())]);

    testWidgets('shows the business name and phone to change, and the email locked', (tester) async {
      await open(tester);
      expect(tester.widget<TextFormField>(find.byKey(const Key('profile-business-name'))).controller!.text, 'Bottles Up Vendor');
      expect(tester.widget<TextFormField>(find.byKey(const Key('profile-phone'))).controller!.text, '+1 416 555 0100');
      expect(tester.widget<TextFormField>(find.byKey(const Key('profile-email'))).enabled, isFalse);
      expect(find.text('Full Name'), findsNothing, reason: 'that field was checked but never saved anywhere');
      expect(find.byKey(const Key('profile-photo-change')), findsOneWidget);
      await shot(tester, 'edit_profile');
    });

    testWidgets('Save asks for the business name and the phone before it saves anything', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('profile-business-name')), '');
      await tester.enterText(find.byKey(const Key('profile-phone')), '');
      await tester.ensureVisible(find.byKey(const Key('profile-save')));
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter your business name'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
    });

    testWidgets('with no photo the business\'s initials stand in for it', (tester) async {
      await open(tester);
      expect(find.text('BU'), findsOneWidget);
    });
  });
}
