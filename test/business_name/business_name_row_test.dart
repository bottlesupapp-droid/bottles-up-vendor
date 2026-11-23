import 'dart:async';

import 'package:bottles_up_vendor/features/business_name/services/business_name_service.dart';
import 'package:bottles_up_vendor/features/more/screens/workspace_settings_screen.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace ws(WorkspaceRole role, {String name = 'Club Co'}) => Workspace(
  membershipId: 'm1',
  orgId: 'o1',
  orgName: name,
  orgKind: role == WorkspaceRole.organizer ? 'organizer' : 'venue_owner',
  role: role,
);

void main() {
  late List<String> asked;
  late List<BusinessRenamed> renamed;
  Future<BusinessRenamed> Function(String name) answer =
      (n) async => BusinessRenamed(name: n, eventsUpdated: 0);

  Future<BusinessRenamed> fakeRename(String name) {
    asked.add(name);
    return answer(name);
  }

  setUp(() {
    asked = [];
    renamed = [];
    answer = (n) async => BusinessRenamed(name: n, eventsUpdated: 0);
  });

  Future<void> open(
    WidgetTester tester, {
    WorkspaceRole role = WorkspaceRole.owner,
    String name = 'Club Co',
    bool canRename = true,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceSettingsScreen(
            workspace: ws(role, name: name),
            email: 'owner@club.example',
            renameBusiness: canRename ? fakeRename : null,
            onBusinessRenamed: renamed.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('business-name-field')), text);
    await tester.pump();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-business-name')));
    await tester.pumpAndSettle();
  }

  bool continueEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.byKey(const Key('business-name-continue')))
          .onPressed !=
      null;

  group('the row', () {
    testWidgets('the owner sees the business name and can change it', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const Key('business-name-text')), findsOneWidget);
      expect(find.text('Club Co'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('settings-business-name')))
            .onTap,
        isNotNull,
      );
    });

    testWidgets('an event organizer may change theirs too', (tester) async {
      await open(tester, role: WorkspaceRole.organizer);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets(
      'everybody else sees the name and who can change it, and nothing to tap',
      (tester) async {
        for (final role in WorkspaceRole.values.where(
          (r) => r != WorkspaceRole.owner && r != WorkspaceRole.organizer,
        )) {
          await open(tester, role: role);
          expect(find.text('Club Co'), findsOneWidget, reason: role.name);
          expect(find.text('Change'), findsNothing, reason: role.name);
          expect(
            find.textContaining('Only the business owner can change it'),
            findsOneWidget,
            reason: role.name,
          );
          expect(
            tester
                .widget<ListTile>(
                  find.byKey(const Key('settings-business-name')),
                )
                .onTap,
            isNull,
            reason: role.name,
          );
        }
      },
    );

    testWidgets(
      'a build that cannot rename shows it read only, even to the owner',
      (tester) async {
        await open(tester, canRename: false);
        expect(find.text('Change'), findsNothing);
        expect(
          tester
              .widget<ListTile>(find.byKey(const Key('settings-business-name')))
              .onTap,
          isNull,
        );
      },
    );

    testWidgets('a business with no name says so', (tester) async {
      await open(tester, name: '');
      expect(find.text('Your business'), findsOneWidget);
    });
  });

  group('the box for the new name', () {
    testWidgets(
      'opens with the current name, the rules, and Continue off (nothing has changed)',
      (tester) async {
        await open(tester);
        await openSheet(tester);

        expect(
          tester
              .widget<TextField>(find.byKey(const Key('business-name-field')))
              .controller!
              .text,
          'Club Co',
        );
        expect(find.byKey(const Key('business-name-rules')), findsOneWidget);
        expect(find.textContaining('once every 30 days'), findsOneWidget);
        expect(continueEnabled(tester), isFalse);
        expect(asked, isEmpty);
      },
    );

    testWidgets(
      'a good new name turns Continue on, and a problem is said as it is typed',
      (tester) async {
        await open(tester);
        await openSheet(tester);

        await type(tester, 'Club Co Toronto');
        expect(continueEnabled(tester), isTrue);
        expect(find.textContaining('must be at least'), findsNothing);

        await type(tester, 'A');
        expect(continueEnabled(tester), isFalse);
        expect(
          find.text('The business name must be at least 2 characters.'),
          findsOneWidget,
        );

        await type(tester, 'x' * 81);
        expect(continueEnabled(tester), isFalse);
        expect(
          find.text('The business name can be at most 80 characters.'),
          findsOneWidget,
        );

        await type(
          tester,
          '   club   co   '.replaceAll('club   co', 'Club Co'),
        );
        expect(
          continueEnabled(tester),
          isFalse,
          reason: 'only spaces were added: it is the same name',
        );
        expect(
          find.text('That is already the name of this business.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Cancel closes it and asks nothing', (tester) async {
      await open(tester);
      await openSheet(tester);
      await type(tester, 'Club Co Toronto');
      await tester.tap(find.byKey(const Key('business-name-sheet-cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('business-name-field')), findsNothing);
      expect(asked, isEmpty);
      expect(
        renamed,
        isEmpty,
        reason: 'nothing was renamed, so nothing is refreshed',
      );
      expect(find.text('Club Co'), findsOneWidget);
      expect(find.byKey(const Key('business-name-done')), findsNothing);
    });
  });

  group('the confirmation', () {
    Future<void> toConfirm(WidgetTester tester, String newName) async {
      await open(tester);
      await openSheet(tester);
      await type(tester, newName);
      await tester.tap(find.byKey(const Key('business-name-continue')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Continue asks "Change the business name?", saying from what to what and what happens, and has not asked the database yet',
      (tester) async {
        await toConfirm(tester, '  Club   Co Toronto ');

        expect(
          find.byKey(const Key('business-name-confirm-dialog')),
          findsOneWidget,
        );
        expect(find.text('Change the business name?'), findsOneWidget);
        expect(
          find.textContaining('From "Club Co" to "Club Co Toronto"'),
          findsOneWidget,
          reason: 'the tidied name is what is confirmed',
        );
        expect(find.textContaining('upcoming events'), findsOneWidget);
        expect(
          find.textContaining('already started or finished keep the old name'),
          findsOneWidget,
        );
        expect(find.textContaining('again for 30 days'), findsOneWidget);
        expect(asked, isEmpty);
      },
    );

    testWidgets(
      'Cancel at the confirmation changes nothing and asks nothing; the box is still there',
      (tester) async {
        await toConfirm(tester, 'Club Co Toronto');
        await tester.tap(find.byKey(const Key('business-name-cancel')));
        await tester.pumpAndSettle();

        expect(asked, isEmpty);
        expect(
          find.byKey(const Key('business-name-confirm-dialog')),
          findsNothing,
        );
        expect(find.byKey(const Key('business-name-field')), findsOneWidget);
        expect(renamed, isEmpty);
      },
    );

    testWidgets(
      'Change name asks the database once with the tidied name, closes, shows the new name at once, and says what happened',
      (tester) async {
        answer = (n) async => BusinessRenamed(name: n, eventsUpdated: 3);
        await toConfirm(tester, '  Club   Co Toronto ');
        await tester.tap(find.byKey(const Key('business-name-confirm')));
        await tester.pumpAndSettle();

        expect(asked, ['Club Co Toronto']);
        expect(
          find.byKey(const Key('business-name-field')),
          findsNothing,
          reason: 'the box closed',
        );
        expect(
          find.text('Club Co Toronto'),
          findsOneWidget,
          reason: 'the row shows the new name without reopening',
        );
        expect(find.text('Club Co'), findsNothing);
        expect(
          find.textContaining('The business is now called Club Co Toronto.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('3 upcoming events show it'),
          findsOneWidget,
        );
        expect(renamed.single.name, 'Club Co Toronto');
      },
    );

    testWidgets(
      'one upcoming event says "event shows", none says nothing about events',
      (tester) async {
        answer = (n) async => BusinessRenamed(name: n, eventsUpdated: 1);
        await toConfirm(tester, 'Club Co Toronto');
        await tester.tap(find.byKey(const Key('business-name-confirm')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('1 upcoming event shows it'),
          findsOneWidget,
        );
      },
    );

    testWidgets('with no upcoming events the message does not mention events', (
      tester,
    ) async {
      await toConfirm(tester, 'Club Co Toronto');
      await tester.tap(find.byKey(const Key('business-name-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The business is now called Club Co Toronto.'),
        findsOneWidget,
      );
      expect(find.textContaining('upcoming event'), findsNothing);
    });

    testWidgets(
      'while it is being saved the box cannot be used again, and a second tap does not send a second request',
      (tester) async {
        final done = Completer<BusinessRenamed>();
        answer = (n) => done.future;
        await toConfirm(tester, 'Club Co Toronto');
        await tester.tap(find.byKey(const Key('business-name-confirm')));
        await tester.pump();

        expect(asked.length, 1);
        expect(continueEnabled(tester), isFalse);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('business-name-field')))
              .enabled,
          isFalse,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('business-name-sheet-cancel')),
              )
              .onPressed,
          isNull,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('business-name-continue')),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(asked.length, 1, reason: 'a second tap sent a second request');

        done.complete(
          const BusinessRenamed(name: 'Club Co Toronto', eventsUpdated: 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Club Co Toronto'), findsOneWidget);
      },
    );
  });

  group('when the database refuses', () {
    Future<void> tryRename(WidgetTester tester, String newName) async {
      await open(tester);
      await openSheet(tester);
      await type(tester, newName);
      await tester.tap(find.byKey(const Key('business-name-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('business-name-confirm')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'its sentence is shown in the box, the name is unchanged, the box stays open with what was typed, and nothing is refreshed',
      (tester) async {
        answer =
            (n) async =>
                throw const BusinessRenameFailed(
                  'The name was changed on 3 November 2026. It can be changed again from 3 December 2026.',
                );
        await tryRename(tester, 'Club Co Toronto');

        expect(
          find.text(
            'The name was changed on 3 November 2026. It can be changed again from 3 December 2026.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('business-name-field')))
              .controller!
              .text,
          'Club Co Toronto',
        );
        expect(renamed, isEmpty);
        await tester.tap(find.byKey(const Key('business-name-sheet-cancel')));
        await tester.pumpAndSettle();
        expect(find.text('Club Co'), findsOneWidget);
        expect(find.byKey(const Key('business-name-done')), findsNothing);
      },
    );

    testWidgets(
      'the refusal goes away as soon as the person edits, and they can try again',
      (tester) async {
        var first = true;
        answer = (n) async {
          if (first) {
            first = false;
            throw const BusinessRenameFailed(
              'Another business already uses that name. Choose a different one.',
            );
          }
          return BusinessRenamed(name: n, eventsUpdated: 0);
        };
        await tryRename(tester, 'Taken Name');
        expect(
          find.textContaining('Another business already uses that name'),
          findsOneWidget,
        );

        await type(tester, 'Free Name');
        expect(
          find.textContaining('Another business already uses that name'),
          findsNothing,
        );
        await tester.tap(find.byKey(const Key('business-name-continue')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('business-name-confirm')));
        await tester.pumpAndSettle();

        expect(asked, ['Taken Name', 'Free Name']);
        expect(find.text('Free Name'), findsOneWidget);
      },
    );

    testWidgets('an unexpected error is a plain sentence, never the error text', (
      tester,
    ) async {
      answer =
          (n) async =>
              throw StateError(
                'boom: relation "site_organizations" does not exist',
              );
      await tryRename(tester, 'Club Co Toronto');

      expect(
        find.text(
          'The name could not be changed. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('boom'), findsNothing);
      expect(find.textContaining('site_organizations'), findsNothing);
    });
  });
}
