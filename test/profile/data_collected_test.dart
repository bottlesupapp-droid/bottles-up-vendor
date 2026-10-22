import 'package:bottles_up_vendor/features/more/screens/workspace_settings_screen.dart';
import 'package:bottles_up_vendor/features/profile/logic/data_collected.dart';
import 'package:bottles_up_vendor/features/profile/screens/privacy_policy_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<Uri> opened = [];
bool opens = true;

Widget host(Widget home) => ProviderScope(
      overrides: [
        privacyLinkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return opens;
        }),
        siteUrlProvider.overrideWithValue('https://site.example'),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: home),
    );

void main() {
  setUp(() {
    opened = [];
    opens = true;
  });

  group('the text', () {
    String all() => [for (final s in dataCollected) ...[s.title, ...s.lines]].join('\n');

    test('no placeholder or invented policy wording is left: no made-up address, phone, analytics provider, cloud or retention period', () {
      for (final w in forbiddenPlaceholderWords) {
        expect(all().toLowerCase(), isNot(contains(w.toLowerCase())), reason: w);
      }
    });

    test('it says what is collected and what is not, and does not promise anything the app does not decide', () {
      expect(dataCollected.map((s) => s.title), contains('What the app does not collect'));
      expect(dataCollected.map((s) => s.title), contains('Crash reports'));
      expect(all(), contains('BottlesUp\'s privacy policy'));
      for (final promise in ['encrypt', 'delete your', 'we never', 'guarantee', 'years']) {
        expect(all().toLowerCase(), isNot(contains(promise)), reason: promise);
      }
    });

    test('every section has a title and at least one line', () {
      for (final s in dataCollected) {
        expect(s.title.trim(), isNotEmpty);
        expect(s.lines, isNotEmpty, reason: s.title);
        for (final l in s.lines) {
          expect(l.trim(), isNotEmpty);
        }
      }
    });
  });

  testWidgets('the screen lists every section and says it is not the legal policy', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const PrivacyPolicyScreen()));
    expect(find.text('What this app collects'), findsOneWidget);
    expect(find.textContaining('It is not the legal privacy policy'), findsOneWidget);
    for (final s in dataCollected) {
      expect(find.byKey(Key('data-${s.title}')), findsOneWidget, reason: s.title);
      expect(find.text(s.lines.first), findsOneWidget, reason: s.title);
    }
  });

  testWidgets('the full policy opens on the website, at the address the app is pointed at', (tester) async {
    await tester.pumpWidget(host(const PrivacyPolicyScreen()));
    await tester.tap(find.byKey(const Key('open-full-policy')));
    await tester.pump();
    expect(opened.single.toString(), 'https://site.example/privacy-policy');
  });

  testWidgets('if it cannot be opened the person is told, in a sentence', (tester) async {
    opens = false;
    await tester.pumpWidget(host(const PrivacyPolicyScreen()));
    await tester.tap(find.byKey(const Key('open-full-policy')));
    await tester.pump();
    expect(find.text('The privacy policy could not be opened. Check your connection and try again.'), findsOneWidget);
  });

  testWidgets('workspace settings offer it next to the privacy policy', (tester) async {
    const ws = Workspace(membershipId: 'w', orgId: 'o', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(Scaffold(body: WorkspaceSettingsScreen(workspace: ws, email: 'a@b.example'))));
    expect(find.byKey(const Key('settings-privacy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-collected')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('data-collected')), findsOneWidget);
  });
}
