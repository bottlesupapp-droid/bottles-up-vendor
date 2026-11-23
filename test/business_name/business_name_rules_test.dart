import 'package:bottles_up_vendor/features/business_name/logic/business_name_rules.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter_test/flutter_test.dart';

Workspace ws(WorkspaceRole role) => Workspace(
  membershipId: 'm1',
  orgId: 'o1',
  orgName: 'Club Co',
  orgKind: 'venue_owner',
  role: role,
);

void main() {
  group('who may rename', () {
    test('the owner and the event organizer may, nobody else', () {
      expect(canRenameBusiness(ws(WorkspaceRole.owner)), isTrue);
      expect(canRenameBusiness(ws(WorkspaceRole.organizer)), isTrue);
      for (final role in WorkspaceRole.values.where(
        (r) => r != WorkspaceRole.owner && r != WorkspaceRole.organizer,
      )) {
        expect(canRenameBusiness(ws(role)), isFalse, reason: role.name);
      }
    });
  });

  group('tidying', () {
    test('spaces at the ends go and runs of spaces become one', () {
      expect(tidyBusinessName('   Club   Co   Toronto '), 'Club Co Toronto');
      expect(tidyBusinessName('Club Co'), 'Club Co');
      expect(tidyBusinessName('   '), '');
    });
  });

  group('what is wrong with a name', () {
    String? problem(String raw, [String current = 'Club Co']) =>
        businessNameProblem(raw, current: current);

    test('a good name has no problem', () {
      expect(problem('Club Co Toronto'), isNull);
      expect(
        problem('club co'),
        isNull,
        reason:
            'capitals only is a real, allowed change (the database decides about the 30 days)',
      );
    });

    test(
      'empty, blank and one letter are too short; two letters are enough',
      () {
        for (final raw in ['', '    ', ' A ']) {
          expect(
            problem(raw),
            'The business name must be at least 2 characters.',
            reason: '"$raw"',
          );
        }
        expect(problem('Ab'), isNull);
      },
    );

    test('80 characters fit and 81 do not (counted after tidying)', () {
      expect(problem('x' * 80), isNull);
      expect(
        problem('x' * 81),
        'The business name can be at most 80 characters.',
      );
      expect(
        problem('  ${'x' * 80}  '),
        isNull,
        reason: 'the spaces around it do not count',
      );
      expect(
        problem('${'x' * 40}      ${'y' * 40}'),
        'The business name can be at most 80 characters.',
        reason: 'the spaces between are one space, so this is 81',
      );
    });

    test(
      'control characters are refused, before they could be tidied away',
      () {
        expect(
          problem('Club\tCo Two'),
          'The business name has characters that are not allowed.',
        );
        expect(
          problem('Club\nCo Two'),
          'The business name has characters that are not allowed.',
        );
        expect(
          problem('Club\u0000Co'),
          'The business name has characters that are not allowed.',
        );
      },
    );

    test('the same name is not a change, even with extra spaces', () {
      expect(problem('Club Co'), 'That is already the name of this business.');
      expect(
        problem('  Club   Co '),
        'That is already the name of this business.',
      );
    });
  });

  group('the database\'s sentences', () {
    test('start with a capital and end with a full stop', () {
      expect(
        asSentence(
          'another business already uses that name. Choose a different one',
        ),
        'Another business already uses that name. Choose a different one.',
      );
      expect(asSentence('Already fine.'), 'Already fine.');
      expect(asSentence('  what?  '), 'What?');
      expect(asSentence(''), '');
    });
  });

  test('the limits are the ones the person is told about', () {
    expect(businessNameMin, 2);
    expect(businessNameMax, 80);
    expect(businessNameGapDays, 30);
  });
}
