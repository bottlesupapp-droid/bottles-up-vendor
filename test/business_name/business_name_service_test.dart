import 'package:bottles_up_vendor/features/business_name/services/business_name_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<Map<String, dynamic>> calls;
  late List<String> functions;

  BusinessNameService serviceAnswering(Future<dynamic> Function() answer) {
    return BusinessNameService(
      rpc: (function, {params}) {
        functions.add(function);
        calls.add(params ?? {});
        return answer();
      },
    );
  }

  setUp(() {
    calls = [];
    functions = [];
  });

  test(
    'asks the database to rename, with the business and the tidied name',
    () async {
      final service = serviceAnswering(
        () async => [
          {
            'new_name': 'Club Co Toronto',
            'events_updated': 2,
            'can_change_again_at': '2026-12-27T10:00:00+00:00',
          },
        ],
      );
      final done = await service.rename(
        orgId: 'o1',
        name: '  Club   Co Toronto ',
      );

      expect(functions, ['rename_business']);
      expect(calls.single, {'p_org': 'o1', 'p_name': 'Club Co Toronto'});
      expect(done.name, 'Club Co Toronto');
      expect(done.eventsUpdated, 2);
      expect(
        done.canChangeAgainAt!.isAtSameMomentAs(DateTime.utc(2026, 12, 27, 10)),
        isTrue,
      );
    },
  );

  test('a missing date or count is fine', () async {
    final done = await serviceAnswering(
      () async => [
        {
          'new_name': 'Club Co Toronto',
          'events_updated': null,
          'can_change_again_at': null,
        },
      ],
    ).rename(orgId: 'o1', name: 'Club Co Toronto');
    expect(done.eventsUpdated, 0);
    expect(done.canChangeAgainAt, isNull);
  });

  test('an answer with no name is a failure, not a silent success', () async {
    for (final answer in <dynamic>[
      null,
      [],
      [<String, dynamic>{}],
      'ok',
      [1],
    ]) {
      await expectLater(
        serviceAnswering(
          () async => answer,
        ).rename(orgId: 'o1', name: 'Club Co Toronto'),
        throwsA(
          isA<BusinessRenameFailed>().having(
            (e) => e.message,
            'message',
            contains('could not be changed'),
          ),
        ),
        reason: '$answer',
      );
    }
  });

  group('a refusal comes back as a sentence for the person', () {
    Future<String> refusedWith(Object error) async {
      try {
        await serviceAnswering(
          () async => throw error,
        ).rename(orgId: 'o1', name: 'Club Co Toronto');
      } on BusinessRenameFailed catch (e) {
        return e.message;
      }
      return 'NOT REFUSED';
    }

    test('the database\'s own plain sentences are shown, as sentences', () async {
      expect(
        await refusedWith(
          const PostgrestException(
            message:
                'another business already uses that name. Choose a different one',
            code: 'P0001',
          ),
        ),
        'Another business already uses that name. Choose a different one.',
      );
      expect(
        await refusedWith(
          const PostgrestException(
            message:
                'the name was changed on 3 November 2026. It can be changed again from 3 December 2026',
            code: 'P0001',
          ),
        ),
        'The name was changed on 3 November 2026. It can be changed again from 3 December 2026.',
      );
    });

    test('"not allowed" says who may change it', () async {
      expect(
        await refusedWith(
          const PostgrestException(message: 'not allowed', code: 'P0001'),
        ),
        'Only the business owner can change its name.',
      );
    });

    test(
      'a database without the function says it is not available yet',
      () async {
        for (final code in ['42883', 'PGRST202']) {
          expect(
            await refusedWith(
              PostgrestException(
                message: 'function public.rename_business does not exist',
                code: code,
              ),
            ),
            contains('not available yet'),
            reason: code,
          );
        }
      },
    );

    test('anything technical is never shown', () async {
      final shown = await refusedWith(
        const PostgrestException(
          message:
              'duplicate key value violates unique constraint "site_organizations_pkey"',
          code: '23505',
        ),
      );
      expect(
        shown,
        'The name could not be changed. Check your connection and try again.',
      );
      expect(
        await refusedWith(Exception('SocketException: Failed host lookup')),
        'The name could not be changed. Check your connection and try again.',
      );
    });
  });
}
