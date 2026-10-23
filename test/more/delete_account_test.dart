import 'dart:async';

import 'package:bottles_up_vendor/features/auth/services/supabase_auth_service.dart';
import 'package:bottles_up_vendor/features/more/screens/workspace_settings_screen.dart';
import 'package:bottles_up_vendor/features/more/widgets/delete_account_section.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace ws(WorkspaceRole role, {String org = 'Club Co'}) =>
    Workspace(membershipId: 'm1', orgId: 'o1', orgName: org, orgKind: 'venue_owner', role: role, venueId: 'v1', venueName: 'Club A');

void main() {
  late int calls;
  late int deleted;
  Future<void> Function() action = () async {};

  Future<void> open(WidgetTester tester, {WorkspaceRole role = WorkspaceRole.manager, String? email = 'mia@club.example', String org = 'Club Co'}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WorkspaceSettingsScreen(
          workspace: ws(role, org: org),
          email: email,
          openLink: (_) async => true,
          deleteAccount: () async {
            calls++;
            await action();
          },
          onAccountDeleted: (_) => deleted++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> ask(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('settings-delete-account')));
    await tester.tap(find.byKey(const Key('settings-delete-account')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    calls = 0;
    deleted = 0;
    action = () async {};
  });

  testWidgets('Settings offers Delete my account, in red, and does nothing until it is confirmed', (tester) async {
    await open(tester);
    expect(find.text('Delete my account'), findsOneWidget);
    expect(find.byKey(const Key('delete-account-dialog')), findsNothing);
    expect(calls, 0);
  });

  testWidgets('the confirmation says what happens: the sign-in goes, the records stay, an owner is warned', (tester) async {
    await open(tester);
    await ask(tester);
    expect(find.byKey(const Key('delete-account-dialog')), findsOneWidget);
    final text = [for (var i = 0; i < 3; i++) tester.widget<Text>(find.byKey(Key('delete-account-warning-$i'))).data!];
    expect(text[0], allOf(contains('permanently deletes your BottlesUp sign-in (mia@club.example)'), contains('cannot get it back')));
    expect(text[1], allOf(contains('keeps its records'), contains('no longer point to your account'), contains('e-mail address')));
    expect(text[2], allOf(startsWith('If you are the owner of any business'), contains('BottlesUp assigns a new owner')));
    expect(find.byKey(const Key('delete-account-warning-3')), findsNothing);
    expect(calls, 0, reason: 'asking is not deleting');
  });

  testWidgets('an owner is told about THEIR business by name', (tester) async {
    await open(tester, role: WorkspaceRole.owner, org: 'Noir Group');
    await ask(tester);
    final last = tester.widget<Text>(find.byKey(const Key('delete-account-warning-2'))).data!;
    expect(last, allOf(startsWith('You are the owner of Noir Group.'), contains('nobody can manage it until BottlesUp assigns a new owner'), contains('Contact BottlesUp first')));
  });

  testWidgets('without an e-mail the sentence still reads', (tester) async {
    await open(tester, email: null);
    await ask(tester);
    // the session read fails in tests, so the line has no address; either way it must not print "null"
    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('permanently deletes your BottlesUp sign-in'), findsOneWidget);
  });

  testWidgets('"Keep my account" closes the dialog and deletes nothing', (tester) async {
    await open(tester);
    await ask(tester);
    await tester.tap(find.byKey(const Key('delete-account-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-account-dialog')), findsNothing);
    expect([calls, deleted], [0, 0]);
  });

  testWidgets('confirming deletes once and then takes the person away from the screen', (tester) async {
    await open(tester);
    await ask(tester);
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect([calls, deleted], [1, 1]);
    expect(find.byKey(const Key('delete-account-problem')), findsNothing);
  });

  testWidgets('while it is going through nothing can be tapped again, and it shows it is working', (tester) async {
    final gate = Completer<void>();
    action = () => gate.future;
    await open(tester);
    await ask(tester);
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // the dialog closes; the call is still waiting
    expect(calls, 1);
    expect(find.byKey(const Key('delete-account-busy')), findsOneWidget);
    expect(find.text('Deleting your account...'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byKey(const Key('settings-delete-account'))).onTap, isNull);
    await tester.tap(find.byKey(const Key('settings-delete-account')), warnIfMissed: false);
    await tester.pump();
    expect(find.byKey(const Key('delete-account-dialog')), findsNothing);
    expect(calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect([calls, deleted], [1, 1]);
  });

  testWidgets('when it does not go through the sentence is shown, the person stays, and can try again', (tester) async {
    action = () async => throw const AccountDeletionException('We could not delete your account. Check your connection and try again.');
    await open(tester);
    await ask(tester);
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('We could not delete your account. Check your connection and try again.'), findsOneWidget);
    expect(deleted, 0);
    expect(tester.widget<ListTile>(find.byKey(const Key('settings-delete-account'))).onTap, isNotNull);
    action = () async {};
    await ask(tester);
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect([calls, deleted], [2, 1]);
    expect(find.byKey(const Key('delete-account-problem')), findsNothing, reason: 'the old message goes away once it works');
  });

  testWidgets('any other failure is still a plain sentence, never the technical text', (tester) async {
    action = () async => throw Exception('PostgrestException: violates foreign key');
    await open(tester);
    await ask(tester);
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('We could not delete your account. Check your connection and try again.'), findsOneWidget);
    expect(find.textContaining('Postgrest'), findsNothing);
    expect(deleted, 0);
  });

  test('the warnings never print "null", and name the e-mail only when there is one', () {
    final w = ws(WorkspaceRole.manager);
    expect(deleteAccountWarnings(email: null, workspace: w).first, isNot(contains('(')));
    expect(deleteAccountWarnings(email: 'a@b.co', workspace: w).first, contains('(a@b.co)'));
    expect(deleteAccountWarnings(email: null, workspace: ws(WorkspaceRole.owner, org: '')).last, contains('You are the owner of this business.'));
  });

  test('the classic profile screens say the same true thing, not "all your data will be deleted"', () {
    expect(classicDeleteAccountText, allOf(contains('keeps its records'), contains('no longer point to your account'), contains('assigns a new owner')));
    expect(classicDeleteAccountText, isNot(contains('All your data')));
  });
}
