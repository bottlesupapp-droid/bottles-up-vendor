import 'dart:io';

import 'package:bottles_up_vendor/core/theme/app_theme.dart';
import 'package:bottles_up_vendor/core/theme/app_tokens.dart';
import 'package:bottles_up_vendor/features/server_desk/widgets/desk_chip.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared by the design tests of the role tabs: the design's tokens, a workspace for each role, and a way to show a screen on a phone with the app's real theme.
final bu = BuTokens.dark;

const managerWs = Workspace(membershipId: 'm-m', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.manager, venueId: 'v1', venueName: 'Club A');
const serverWs = Workspace(membershipId: 'm-s', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.server, venueId: 'v1', venueName: 'Club A');
const verifierWs = Workspace(membershipId: 'm-v', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.verifier, venueId: 'v1', venueName: 'Club A');
const securityWs = Workspace(membershipId: 'm-x', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.security, venueId: 'v1', venueName: 'Club A');
const organizerWs = Workspace(membershipId: 'm-g', orgId: 'org2', orgName: 'Night Events', orgKind: 'organizer', role: WorkspaceRole.organizer);
const ownerWs = Workspace(membershipId: 'm-o', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

/// A phone, tall enough that a whole screen is built at once, showing [screen] with the app's real theme.
Future<void> showScreen(WidgetTester tester, Widget screen, List<Override> overrides, {double width = 393, double height = 2600}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: screen)),
  ));
  await tester.pumpAndSettle();
}

Color textColor(WidgetTester tester, Finder f) => tester.widget<Text>(f).style!.color!;
Color chipColor(WidgetTester tester, String key) => tester.widget<DeskChip>(find.byKey(Key(key))).color;


/// The app's own Inter file, so text takes the room it really takes (without it the test environment draws every letter as a wide square).
Future<void> loadInter() async {
  final font = FontLoader('Inter')..addFont(File('assets/fonts/Inter.ttf').readAsBytes().then(ByteData.sublistView));
  await font.load();
}
