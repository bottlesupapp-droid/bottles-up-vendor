import 'package:bottles_up_vendor/features/chat/providers/chat_providers.dart';
import 'package:bottles_up_vendor/features/chat/screens/chat_screen.dart';
import 'package:bottles_up_vendor/features/more/logic/more_entries.dart';
import 'package:bottles_up_vendor/features/more/screens/more_screen.dart';
import 'package:bottles_up_vendor/features/more/screens/workspace_settings_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/fake_chat_backend.dart';

Workspace ws(WorkspaceRole role) => Workspace(
      membershipId: 'w',
      orgId: 'o',
      orgName: 'Club Co',
      orgKind: 'venue_owner',
      role: role,
      venueId: 'v1',
      venueName: 'Club A',
    );

/// Every More entry that opens something, as role/entry. Add to this when one is built.
const Set<String> builtMore = {
  'owner/organizer-door', 'manager/organizer-door', 'organizer/team',
  'owner/team', 'owner/chat', 'owner/settings', 'owner/inventory', 'owner/vip', 'owner/money',
  'door/settings', 'security/settings', 'security/incidents',
  'manager/chat', 'manager/settings', 'manager/security', 'manager/inventory', 'manager/vip',
  'organizer/settings', 'organizer/agreements', 'owner/agreements', 'manager/agreements',
};

void main() {
  test('only the owner, the manager, the organizer, the door and security have a More hub', () {
    for (final role in WorkspaceRole.values) {
      final has = const {WorkspaceRole.owner, WorkspaceRole.manager, WorkspaceRole.organizer, WorkspaceRole.door, WorkspaceRole.security}.contains(role);
      expect(moreEntriesFor(role).isNotEmpty, has, reason: role.name);
    }
  });

  test('exactly these entries open something; every other one says it is not available', () {
    final actual = <String>{};
    for (final role in WorkspaceRole.values) {
      for (final e in moreEntriesFor(role)) {
        if (moreDestinationFor(ws(role), e.id) != null) actual.add('${role.name}/${e.id}');
      }
    }
    expect(actual, builtMore);
  });

  test('entry ids are unique within a role, and each has a label and words', () {
    for (final role in WorkspaceRole.values) {
      final ids = moreEntriesFor(role).map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: role.name);
      for (final e in moreEntriesFor(role)) {
        expect(e.label.isNotEmpty && e.subtitle.isNotEmpty, isTrue);
      }
    }
  });

  testWidgets('the hub lists the entries; a built one opens its page, a missing one is plainly not available', (tester) async {
    final db = FakeChatBackend();
    db.conversations.add(FakeConversation('c1', 'venue', 'Club A', venueId: 'v1'));
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [chatServiceProvider.overrideWithValue(db.service), chatPollIntervalProvider.overrideWithValue(const Duration(hours: 1))],
      child: MaterialApp(home: Scaffold(body: MoreScreen(workspace: ws(WorkspaceRole.manager)))),
    ));
    for (final e in moreEntriesFor(WorkspaceRole.manager)) {
      expect(find.byKey(Key('more-${e.id}')), findsOneWidget, reason: e.id);
    }
    expect(find.descendant(of: find.byKey(const Key('more-discounts')), matching: find.textContaining('Not available yet.')), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const Key('more-discounts'))).onTap, isNull);
    expect(find.descendant(of: find.byKey(const Key('more-chat')), matching: find.textContaining('Not available yet')), findsNothing);
    await tester.tap(find.byKey(const Key('more-chat')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Chat')), findsOneWidget);
    expect(find.byKey(const Key('chat-row-c1')), findsOneWidget);
  });

  testWidgets('the door\'s More lists shift summary, promo codes and settings; the first two are plainly not available yet', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MoreScreen(workspace: ws(WorkspaceRole.door)))));
    for (final id in ['shift-summary', 'promo-codes', 'settings']) {
      expect(find.byKey(Key('more-$id')), findsOneWidget, reason: id);
    }
    expect(find.descendant(of: find.byKey(const Key('more-shift-summary')), matching: find.textContaining('Not available yet.')), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const Key('more-promo-codes'))).onTap, isNull);
    expect(tester.widget<ListTile>(find.byKey(const Key('more-settings'))).onTap, isNotNull);
  });

  test('Payments and earnings is the owner\'s, Incidents is security\'s, and nobody else gets either', () {
    expect(moreDestinationFor(ws(WorkspaceRole.owner), 'money'), isNotNull);
    expect(moreDestinationFor(ws(WorkspaceRole.manager), 'money'), isNull);
    expect(moreDestinationFor(ws(WorkspaceRole.security), 'incidents'), isNotNull);
    expect(moreDestinationFor(ws(WorkspaceRole.door), 'incidents'), isNull);
    expect(moreDestinationFor(ws(WorkspaceRole.manager), 'incidents'), isNull);
  });

  group('Settings', () {
    Future<void> openSettings(WidgetTester tester, {OpenLink? open, String? email = 'mia@club.example'}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WorkspaceSettingsScreen(workspace: ws(WorkspaceRole.manager), email: email, openLink: open ?? (_) async => true, site: 'https://bottlesup.example/'),
        ),
      ));
    }

    testWidgets('says who is signed in, and in which role and where', (tester) async {
      await openSettings(tester);
      expect(find.text('mia@club.example'), findsOneWidget);
      expect(find.text('${WorkspaceRole.manager.label} · Club A'), findsOneWidget);
      expect(find.byKey(const Key('settings-account-note')), findsOneWidget);
    });

    testWidgets('the privacy policy opens the website page', (tester) async {
      Uri? opened;
      await openSettings(tester, open: (u) async {
        opened = u;
        return true;
      });
      await tester.tap(find.byKey(const Key('settings-privacy')));
      await tester.pumpAndSettle();
      expect(opened.toString(), 'https://bottlesup.example/privacy-policy');
    });

    testWidgets('if it cannot be opened the person is told', (tester) async {
      await openSettings(tester, open: (_) async => false);
      await tester.tap(find.byKey(const Key('settings-privacy')));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be opened'), findsOneWidget);
    });

    testWidgets('without a session email it still renders', (tester) async {
      await openSettings(tester, email: null);
      expect(find.byKey(const Key('settings-account')), findsOneWidget);
    });
  });
}
