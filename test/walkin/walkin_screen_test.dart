import 'dart:async';

import 'package:bottles_up_vendor/features/walkin/providers/walkin_providers.dart';
import 'package:bottles_up_vendor/features/walkin/screens/walkin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_walkin_backend.dart';

late FakeWalkinBackend db;
late List<(String, String)> opened;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [walkinServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: WalkinScreen(venueId: 'v1', venueName: 'Club A', night: '2026-10-19', openTable: (context, id, title) => opened.add((id, title))),
      ),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host());
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> pick(WidgetTester tester, {String slot = 's1', String table = 't1'}) async {
  await tapKey(tester, 'walkin-slot-$slot');
  await tapKey(tester, 'walkin-table-$table');
}

Future<void> fill(WidgetTester tester, {String name = 'Ann Guest', String email = 'ann@guest.example', bool terms = true}) async {
  await enter(tester, 'walkin-name', name);
  await enter(tester, 'walkin-email', email);
  if (terms) await tapKey(tester, 'walkin-terms');
}

String confirmLabel(WidgetTester tester) => (tester.widget<FilledButton>(find.byKey(const Key('walkin-confirm'))).child! as Text).data!;

void main() {
  setUp(() {
    db = FakeWalkinBackend();
    opened = [];
  });

  testWidgets('shows the arrival times for the night and no tables until one is picked', (tester) async {
    await open(tester);
    expect(find.text('Club A'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    expect(find.text('11:00 PM · Late'), findsOneWidget);
    expect(find.byKey(const Key('walkin-table-t1')), findsNothing);
    expect(find.byKey(const Key('walkin-confirm')), findsNothing);
    expect(db.paramsOf('desk_walkin_options').single, {'p_venue': 'v1', 'p_night': '2026-10-19'});
  });

  testWidgets('a time with no free table is shown as full and cannot be picked', (tester) async {
    db.takeTable('t1', 's2');
    db.takeTable('t1', 's2', email: 'b@x.example');
    db.takeTable('t2', 's2');
    await open(tester);
    expect(find.text('11:00 PM · Late · full'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walkin-slot-s2')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('walkin-table-t1')), findsNothing);
  });

  testWidgets('picking a time lists its tables with seats, deposit and what is left; a full table cannot be picked', (tester) async {
    db.takeTable('t2', 's1');
    await open(tester);
    await tapKey(tester, 'walkin-slot-s1');
    expect(find.text('Booth 3'), findsOneWidget);
    expect(find.text('2 to 6 guests · \$100.00 deposit · 2 left'), findsOneWidget);
    expect(find.text('up to 10 guests · \$50.00 an hour (at least 2 hours) · fully booked'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walkin-table-t2')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('walkin-name')), findsNothing, reason: 'a full table starts no booking');
  });

  testWidgets('picking a table asks for the guest, the party and the terms, and the button says what is due', (tester) async {
    await open(tester);
    await pick(tester);
    expect(find.byKey(const Key('walkin-name')), findsOneWidget);
    expect(find.byKey(const Key('walkin-email')), findsOneWidget);
    expect(find.byKey(const Key('walkin-phone')), findsOneWidget);
    expect(find.textContaining('paid at the club'), findsOneWidget);
    expect(confirmLabel(tester), 'Confirm walk-in · \$100.00 due');
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('walkin-terms'))).value, isFalse);
  });

  testWidgets('the party starts inside what the table takes and cannot be pushed outside it', (tester) async {
    await open(tester);
    await pick(tester);
    expect(find.byKey(const Key('walkin-guests-value')).evaluate().isNotEmpty, isTrue);
    expect((tester.widget<Text>(find.byKey(const Key('walkin-guests-value')))).data, '2');
    expect(tester.widget<IconButton>(find.byKey(const Key('walkin-guests-less'))).onPressed, isNull, reason: 'the table needs at least 2');
    for (var i = 0; i < 10; i++) {
      final more = tester.widget<IconButton>(find.byKey(const Key('walkin-guests-more')));
      if (more.onPressed == null) break;
      await tapKey(tester, 'walkin-guests-more');
    }
    expect((tester.widget<Text>(find.byKey(const Key('walkin-guests-value')))).data, '6');
  });

  testWidgets('a table that needs a bigger party starts the count at its minimum', (tester) async {
    db.tables.first['min_guests'] = 4;
    await open(tester);
    await pick(tester);
    expect((tester.widget<Text>(find.byKey(const Key('walkin-guests-value')))).data, '4');
  });

  testWidgets('moving to a smaller table brings the count down to what it seats', (tester) async {
    db.tables.last['max_guests'] = 3;
    await open(tester);
    await pick(tester);
    for (var i = 0; i < 4; i++) {
      await tapKey(tester, 'walkin-guests-more');
    }
    expect((tester.widget<Text>(find.byKey(const Key('walkin-guests-value')))).data, '6');
    await tapKey(tester, 'walkin-table-t2');
    expect((tester.widget<Text>(find.byKey(const Key('walkin-guests-value')))).data, '3');
  });

  testWidgets('moving to an hourly table starts the hours at its minimum', (tester) async {
    db.tables.last['min_hours'] = 4;
    await open(tester);
    await pick(tester, table: 't2');
    expect((tester.widget<Text>(find.byKey(const Key('walkin-hours-value')))).data, '4');
  });

  testWidgets('confirming without ticking the terms is refused on the screen, in words, and nothing is sent', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester, terms: false);
    await tapKey(tester, 'walkin-confirm');
    expect(find.textContaining('Confirm that the guest has been told the terms'), findsOneWidget);
    expect(db.paramsOf('desk_create_walkin'), isEmpty);
  });

  testWidgets('every problem on the form is listed together and nothing is sent', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester, name: '', email: 'nope', terms: false);
    await tapKey(tester, 'walkin-confirm');
    expect(find.textContaining('Enter the guest\'s name'), findsOneWidget);
    expect(find.textContaining('valid email address'), findsOneWidget);
    expect(find.textContaining('Confirm that the guest'), findsOneWidget);
    expect(db.paramsOf('desk_create_walkin'), isEmpty);
  });

  testWidgets('a complete booking is made once, shows the code and says the deposit is DUE, not paid', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    await tapKey(tester, 'walkin-confirm');
    final sent = db.paramsOf('desk_create_walkin').single;
    expect(sent['p_table_type'], 't1');
    expect(sent['p_slot'], 's1');
    expect(sent['p_guests'], 2);
    expect(sent['p_name'], 'Ann Guest');
    expect(sent['p_email'], 'ann@guest.example');
    expect(sent['p_terms_confirmed'], true);
    expect(find.byKey(const Key('walkin-done')), findsOneWidget);
    expect(find.text('WALK1'), findsOneWidget);
    expect(find.text('Deposit due at the club: \$100.00. Nothing is recorded as paid yet.'), findsOneWidget);
    expect(find.textContaining('1 of this kind left'), findsOneWidget);
    expect(db.count('t1', 's1'), 1);
  });

  testWidgets('"Record the deposit" opens the booked table\'s page', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    await tapKey(tester, 'walkin-confirm');
    await tapKey(tester, 'walkin-record');
    expect(opened, [('bk1', 'Booth 3 · Ann Guest')]);
  });

  testWidgets('a table with no deposit says nothing is due and offers to open the table', (tester) async {
    db.tables.first['deposit_cents'] = 0;
    await open(tester);
    await pick(tester);
    expect(confirmLabel(tester), 'Confirm walk-in');
    await fill(tester);
    await tapKey(tester, 'walkin-confirm');
    expect(find.text('Nothing is due.'), findsOneWidget);
    expect(find.byKey(const Key('walkin-record')), findsNothing);
    await tapKey(tester, 'walkin-open');
    expect(opened.single.$1, 'bk1');
  });

  testWidgets('an hourly table asks for hours, prices the button by them and sends them', (tester) async {
    await open(tester);
    await pick(tester, table: 't2');
    expect(find.byKey(const Key('walkin-hours-value')), findsOneWidget);
    expect(confirmLabel(tester), 'Confirm walk-in · \$100.00 due', reason: '2 hours at \$50.00');
    expect(tester.widget<IconButton>(find.byKey(const Key('walkin-hours-less'))).onPressed, isNull, reason: 'at least 2 hours');
    await tapKey(tester, 'walkin-hours-more');
    expect(confirmLabel(tester), 'Confirm walk-in · \$150.00 due');
    await fill(tester);
    await tapKey(tester, 'walkin-confirm');
    expect(db.paramsOf('desk_create_walkin').single['p_hours'], 3);
    expect(find.text('Deposit due at the club: \$150.00. Nothing is recorded as paid yet.'), findsOneWidget);
    expect(find.textContaining('No tables of this kind are left'), findsOneWidget);
  });

  testWidgets('a flat table sends no hours', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    await tapKey(tester, 'walkin-confirm');
    expect(db.paramsOf('desk_create_walkin').single['p_hours'], isNull);
  });

  testWidgets('if someone else took the last table, the screen says so, keeps what was typed, and shows what is left now', (tester) async {
    await open(tester);
    await pick(tester, table: 't2');
    await fill(tester);
    db.takeTable('t2', 's1');
    await tapKey(tester, 'walkin-confirm');
    expect(find.text('No tables of this type are left for that time.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('walkin-name'))).controller!.text, 'Ann Guest');
    expect(tester.widget<TextField>(find.byKey(const Key('walkin-email'))).controller!.text, 'ann@guest.example');
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('walkin-terms'))).value, isFalse, reason: 'the terms are asked again');
    expect(db.paramsOf('desk_walkin_options').length, 2, reason: 'the options were read again');
    expect(find.text('up to 10 guests · \$50.00 an hour (at least 2 hours) · fully booked'), findsOneWidget);
    expect(find.byKey(const Key('walkin-done')), findsNothing);
  });

  testWidgets('a repeat of the same guest is refused in the database\'s words and keeps the form', (tester) async {
    db.takeTable('t1', 's1', email: 'ann@guest.example');
    await open(tester);
    await pick(tester);
    await fill(tester);
    await tapKey(tester, 'walkin-confirm');
    expect(find.text('This guest already has a booking for that time.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('walkin-name'))).controller!.text, 'Ann Guest');
    expect(db.count('t1', 's1'), 1);
  });

  testWidgets('a lost connection keeps what was typed, says to look on the Floor first, and a second try can succeed', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    db.failCreate = PostgrestException(message: 'connection reset', code: '08006');
    await tapKey(tester, 'walkin-confirm');
    expect(find.textContaining('look for it on the Floor before booking again'), findsOneWidget);
    expect(find.textContaining('connection reset'), findsNothing, reason: 'no raw error');
    expect(tester.widget<TextField>(find.byKey(const Key('walkin-email'))).controller!.text, 'ann@guest.example');
    db.failCreate = null;
    await tapKey(tester, 'walkin-confirm');
    expect(find.byKey(const Key('walkin-done')), findsOneWidget);
  });

  testWidgets('a second tap while the booking is being made does not make a second booking', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.ensureVisible(find.byKey(const Key('walkin-confirm')));
    await tester.tap(find.byKey(const Key('walkin-confirm')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('walkin-confirm'))).onPressed, isNull, reason: 'the button is off while it works');
    expect(confirmLabel(tester), 'Booking...');
    await tester.tap(find.byKey(const Key('walkin-confirm')), warnIfMissed: false);
    await tester.pump();
    db.hold = null;
    gate.complete();
    await tester.pumpAndSettle();
    expect(db.paramsOf('desk_create_walkin').length, 1);
    expect(db.count('t1', 's1'), 1);
    expect(find.byKey(const Key('walkin-done')), findsOneWidget);
  });

  testWidgets('two taps in the same instant, before the screen has redrawn, still make one booking', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    await tester.ensureVisible(find.byKey(const Key('walkin-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('walkin-confirm')));
    await tester.tap(find.byKey(const Key('walkin-confirm')));
    await tester.pumpAndSettle();
    expect(db.paramsOf('desk_create_walkin').length, 1);
    expect(find.byKey(const Key('walkin-done')), findsOneWidget);
  });

  testWidgets('a second tap while the first is still being answered, before any redraw, is ignored', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    await tester.ensureVisible(find.byKey(const Key('walkin-confirm')));
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.tap(find.byKey(const Key('walkin-confirm')));
    await tester.tap(find.byKey(const Key('walkin-confirm')));
    db.hold = null;
    gate.complete();
    await tester.pumpAndSettle();
    expect(db.paramsOf('desk_create_walkin').length, 1);
    expect(find.byKey(const Key('walkin-done')), findsOneWidget);
  });

  testWidgets('a club with no arrival times or tables for the night says so', (tester) async {
    db.slots.clear();
    await open(tester);
    expect(find.byKey(const Key('walkin-none')), findsOneWidget);
    expect(find.textContaining('nothing to book'), findsOneWidget);
  });

  testWidgets('if the tables cannot be loaded the screen says so with Try again, and Try again works', (tester) async {
    db.failOptions = Exception('boom');
    await open(tester);
    expect(find.text('The tables could not be loaded. Check your connection and try again.'), findsOneWidget);
    expect(find.text('boom'), findsNothing);
    db.failOptions = null;
    await tapKey(tester, 'walkin-retry');
    expect(find.byKey(const Key('walkin-form')), findsOneWidget);
  });

  testWidgets('someone who is not the club\'s manager is told their access has ended, with no Try again', (tester) async {
    db.role = 'door';
    await open(tester);
    expect(find.text('Your access has ended, or you are signed out.'), findsOneWidget);
    expect(find.byKey(const Key('walkin-retry')), findsNothing);
  });

  testWidgets('changing the table after picking one starts the terms again', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('walkin-terms'))).value, isTrue);
    await tapKey(tester, 'walkin-table-t2');
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('walkin-terms'))).value, isFalse, reason: 'the guest agreed to different terms');
  });

  testWidgets('changing the arrival time clears the table so the terms of one table are never confirmed for another', (tester) async {
    await open(tester);
    await pick(tester);
    await fill(tester);
    await tapKey(tester, 'walkin-slot-s2');
    expect(find.byKey(const Key('walkin-name')), findsNothing);
    await tapKey(tester, 'walkin-table-t1');
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('walkin-terms'))).value, isFalse);
  });
}
