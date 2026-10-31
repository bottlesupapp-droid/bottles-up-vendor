import 'package:bottles_up_vendor/features/booking_detail/providers/booking_detail_providers.dart';
import 'package:bottles_up_vendor/features/bottle_signs/providers/bottle_sign_providers.dart';
import 'package:bottles_up_vendor/features/table_service/providers/table_service_providers.dart';
import 'package:bottles_up_vendor/features/table_service/screens/table_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../table_service/fake_table_backend.dart';
import 'fake_sign_backend.dart';

// The sign on the bottle orders of one table (the table's own page, Orders tab).

late FakeTableBackend orders;
late FakeSignBackend signs;

DateTime friday9pm() => DateTime(2026, 10, 9, 21);

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      tableServiceServiceProvider.overrideWithValue(orders.service),
      bottleSignServiceProvider.overrideWithValue(signs.service),
      bookingSignProvider.overrideWith((ref, bookingId) async => 'Happy Birthday'),
    ],
    child: MaterialApp(theme: ThemeData.dark(), home: TableDetailScreen(bookingId: 'b1', title: 'VIP booth · Ada Lovelace', clock: friday9pm)),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(Tab, 'Orders'));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    orders = FakeTableBackend()..role = 'manager';
    orders.now = DateTime(2026, 10, 9, 21);
    orders.addBooking('b1', name: 'Ada Lovelace', code: 'AB12CD', total: 10000, paid: 6000, guests: 4);
    orders.assignments['b1'] = 'm-me';
    orders.addLine('b1', 'Patron', lineId: 'l1', minutesAgo: 40);
    orders.addLine('b1', 'Grey Goose', lineId: 'l2', state: 'preparing', minutesAgo: 25, qty: 2);
    signs = FakeSignBackend(role: 'manager')
      ..mode = 'all'
      ..review = true;
    signs.bottles['p'] = FakeSignBottle('p', 'Patron');
    signs.lines['l1'] = FakeSignLine('l1', 'b1', 'p');
    signs.lines['l2'] = FakeSignLine('l2', 'b1', 'p', state: 'preparing', quantity: 2);
  });

  testWidgets('the table\'s orders show their signs and a way to add one, and the guest\'s own request is offered', (tester) async {
    signs.lines['l2']!
      ..text = 'Cheers'
      ..status = 'approved';
    await open(tester);
    expect(find.text('Sign: “Cheers”'), findsOneWidget);
    expect(signs.calledWith('desk_line_signs').single['p_lines'], ['l1', 'l2']);
    await tapKey(tester, 'sign-edit-l1');
    expect(find.byKey(const Key('sign-suggestion')), findsOneWidget);
    await tapKey(tester, 'sign-use-suggestion');
    await tapKey(tester, 'sign-save');
    expect(signs.calledWith('desk_set_bottle_sign').single, {'p_line': 'l1', 'p_text': 'Happy Birthday'});
    expect(find.text('Sign: “Happy Birthday”'), findsOneWidget);
    expect(find.text('Approved'), findsWidgets, reason: 'a manager\'s own sign needs no approval');
  });

  testWidgets('a waiting sign is approved from the table, and the order is not offered on until then', (tester) async {
    signs.lines['l2']!
      ..text = 'Cheers'
      ..status = 'pending_review'
      ..setBy = 'u-sam';
    await open(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('move-l2'))).onPressed, isNull);
    await tapKey(tester, 'sign-approve-l2');
    expect(tester.widget<FilledButton>(find.byKey(const Key('move-l2'))).onPressed, isNotNull);
  });

  testWidgets('part of a ready line is not handed over while its sign waits, and is once it is approved', (tester) async {
    orders.addLine('b1', 'Moet', lineId: 'l3', qty: 5, state: 'ready');
    signs.lines['l3'] = FakeSignLine('l3', 'b1', 'p', state: 'ready', quantity: 5)
      ..text = 'Cheers'
      ..status = 'pending_review'
      ..setBy = 'u-sam';
    await open(tester);
    expect(find.byKey(const Key('deliver-part-l3')), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('deliver-part-l3'))).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.byKey(const Key('move-l3'))).onPressed, isNull);
    await tapKey(tester, 'sign-approve-l3');
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('deliver-part-l3'))).onPressed, isNotNull);
    expect(tester.widget<FilledButton>(find.byKey(const Key('move-l3'))).onPressed, isNotNull);
  });

  testWidgets('the signs not loading is said on the table\'s page too', (tester) async {
    signs.offline = true;
    await open(tester);
    expect(find.byKey(const Key('signs-notice')), findsOneWidget);
    expect(find.byKey(const Key('order-l1')), findsOneWidget);
  });
}
