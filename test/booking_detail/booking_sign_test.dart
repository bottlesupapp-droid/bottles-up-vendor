import 'dart:io';

import 'package:bottles_up_vendor/features/booking_detail/providers/booking_detail_providers.dart';
import 'package:bottles_up_vendor/features/booking_detail/services/booking_detail_service.dart';
import 'package:bottles_up_vendor/features/booking_detail/widgets/booking_sign_card.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// The guest's bottle sign, read by the manager and the table's own server (website repo, 20261114100000_booking_sign_text.sql).

final List<(String, Map<String, dynamic>?)> calls = [];
Object? answer;
Object? failure;

BookingDetailService service() => BookingDetailService(caller: (fn, {params}) async {
      calls.add((fn, params));
      if (failure != null) throw failure!;
      return answer;
    });

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [bookingDetailServiceProvider.overrideWithValue(service())],
      child: MaterialApp(theme: ThemeData.dark(), home: const Scaffold(body: SingleChildScrollView(child: BookingSignCard(bookingId: 'b1')))),
    );

Future<void> open(WidgetTester tester) async {
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    calls.clear();
    answer = null;
    failure = null;
  });

  group('the service', () {
    test('asks for that booking\'s sign, by name', () async {
      answer = 'Happy Birthday';
      expect(await service().sign('b1'), 'Happy Birthday');
      expect(calls.single.$1, 'desk_booking_sign');
      expect(calls.single.$2, {'p_booking': 'b1'});
    });

    test('trims it, and no sign, an empty one or spaces are all "none"', () async {
      answer = '  Happy Birthday  ';
      expect(await service().sign('b1'), 'Happy Birthday');
      for (final none in [null, '', '   ', 7]) {
        answer = none;
        expect(await service().sign('b1'), isNull, reason: '$none');
      }
    });

    test('a database without the function says so, with nothing to retry', () async {
      failure = PostgrestException(message: 'Could not find the function public.desk_booking_sign', code: 'PGRST202');
      try {
        await service().sign('b1');
        fail('should have been refused');
      } on OpsLoadException catch (e) {
        expect([e.unavailable, e.accessEnded], [true, false]);
      }
    });

    test('someone who may not read it is told their access has ended', () async {
      failure = PostgrestException(message: 'not allowed', code: 'P0001');
      try {
        await service().sign('b1');
        fail('should have been refused');
      } on OpsLoadException catch (e) {
        expect([e.unavailable, e.accessEnded], [false, true]);
      }
    });

    test('a dropped connection is a plain failure that can be tried again', () async {
      failure = Exception('SocketException: Failed host lookup');
      try {
        await service().sign('b1');
        fail('should have been refused');
      } on OpsLoadException catch (e) {
        expect([e.unavailable, e.accessEnded], [false, false]);
        expect(e.message, isNot(contains('Socket')));
      }
    });
  });

  group('the card', () {
    testWidgets('shows the sign the guest asked for', (tester) async {
      answer = 'Happy Birthday';
      await open(tester);
      expect(find.byKey(const Key('sign-card')), findsOneWidget);
      expect(find.text('Sign for the bottles'), findsOneWidget);
      expect(find.byKey(const Key('sign-text')), findsOneWidget);
      expect(find.text('Happy Birthday'), findsOneWidget);
    });

    testWidgets('shows nothing at all when there is no sign', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('sign-card')), findsNothing);
      expect(find.byKey(const Key('sign-error-card')), findsNothing);
      expect(find.text('Sign for the bottles'), findsNothing);
    });

    testWidgets('shows nothing on a server that does not have the function yet', (tester) async {
      failure = PostgrestException(message: 'Could not find the function public.desk_booking_sign', code: 'PGRST202');
      await open(tester);
      expect(find.byKey(const Key('sign-card')), findsNothing);
      expect(find.byKey(const Key('sign-error-card')), findsNothing);
    });

    testWidgets('a read that fails says so and can be tried again: a sign the guest asked for must not go missing quietly', (tester) async {
      failure = Exception('SocketException: Failed host lookup');
      await open(tester);
      expect(find.byKey(const Key('sign-error')), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      failure = null;
      answer = 'Happy Birthday';
      await tester.tap(find.byKey(const Key('sign-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Happy Birthday'), findsOneWidget);
      expect(find.byKey(const Key('sign-error')), findsNothing);
    });

    testWidgets('someone whose access has ended gets the words and no retry', (tester) async {
      failure = PostgrestException(message: 'not allowed', code: 'P0001');
      await open(tester);
      expect(find.byKey(const Key('sign-error')), findsOneWidget);
      expect(find.byKey(const Key('sign-retry')), findsNothing);
    });
  });

  group('agrees with the website', () {
    final migration = File('../bottles-up-website-main/supabase/migrations/20261114100000_booking_sign_text.sql');
    const why = 'the sign migration is not in the website checkout beside this app (its branch is not merged yet)';

    test('the function and its one parameter are the database\'s', () async {
      final sql = migration.readAsStringSync();
      expect(sql, contains('create function public.desk_booking_sign(p_booking uuid)'));
      answer = 'x';
      await service().sign('b1');
      expect(calls.single.$2!.keys.toList(), ['p_booking']);
      expect(sql, contains("raise exception 'not allowed'"));
      expect(sql, contains('grant execute on function public.desk_booking_sign(uuid) to authenticated'));
    }, skip: migration.existsSync() ? false : why);
  });
}
