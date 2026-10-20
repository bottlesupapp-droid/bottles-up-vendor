import 'dart:async';

import 'package:bottles_up_vendor/features/refunds/providers/refund_providers.dart';
import 'package:bottles_up_vendor/features/refunds/screens/refund_policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_refund_backend.dart';

late FakeRefundBackend db;

Widget host() => ProviderScope(
      key: UniqueKey(),
      overrides: [refundServiceProvider.overrideWithValue(db.service)],
      child: MaterialApp(theme: ThemeData.dark(), home: const RefundPolicyScreen(venueId: 'v1')),
    );

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3600);
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

String field(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
bool saveEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('policy-save'))).onPressed != null;
List<String> preview(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.descendant(of: find.byKey(const Key('policy-preview')), matching: find.byType(Text)))) t.data!.replaceFirst('• ', ''),
    ];

void main() {
  setUp(() => db = FakeRefundBackend());

  testWidgets('a venue with no policy is offered two rules to start from, says so, and can save them', (tester) async {
    await open(tester);
    expect(find.textContaining('You have not set a refund policy yet'), findsOneWidget);
    expect([field(tester, 'rule-0-hours'), field(tester, 'rule-0-percent'), field(tester, 'rule-1-hours'), field(tester, 'rule-1-percent')], ['48', '100', '24', '50']);
    expect(saveEnabled(tester), isTrue);
    expect(preview(tester).first, 'Cancel at least 2 days before you arrive: the whole deposit is refunded.');
    expect(db.stored, isNull, reason: 'nothing is saved until Save');
    await tapKey(tester, 'policy-save');
    expect(db.paramsOf('save_venue_refund_policy').single['p_details'], {
      'tiers': [
        {'hours': 48, 'percent': 100},
        {'hours': 24, 'percent': 50},
      ],
      'no_refund_after_check_in': true,
      'note': null,
    });
    expect(find.textContaining('Saved. Bookings made from now on carry this policy'), findsOneWidget);
    expect(saveEnabled(tester), isFalse, reason: 'it now matches what is saved');
  });

  testWidgets('a saved policy is shown as it is, with nothing to save until something changes', (tester) async {
    db.stored = {
      'tiers': [
        {'hours': 72, 'percent': 100},
        {'hours': 12, 'percent': 25},
      ],
      'no_refund_after_check_in': false,
      'note': 'Message us first.',
    };
    await open(tester);
    expect(find.textContaining('Guests read this before they pay'), findsOneWidget);
    expect([field(tester, 'rule-0-hours'), field(tester, 'rule-0-percent'), field(tester, 'rule-1-hours'), field(tester, 'rule-1-percent')], ['72', '100', '12', '25']);
    expect(field(tester, 'policy-note'), 'Message us first.');
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('policy-after-arrival'))).value, isFalse);
    expect(saveEnabled(tester), isFalse);
    expect(preview(tester), [
      'Cancel at least 3 days before you arrive: the whole deposit is refunded.',
      'Cancel at least 12 hours before you arrive: 25% of the deposit is refunded.',
      'Later than that: no refund.',
      'Message us first.',
    ]);
  });

  testWidgets('editing a rule changes what guests will read, at once, and wakes the Save button', (tester) async {
    await open(tester);
    await tapKey(tester, 'rule-add');
    await enter(tester, 'rule-2-hours', '2');
    await enter(tester, 'rule-2-percent', '10');
    expect(preview(tester), contains('Cancel at least 2 hours before you arrive: 10% of the deposit is refunded.'));
    await tapKey(tester, 'policy-after-arrival');
    expect(preview(tester), isNot(contains('Once the guests have arrived there is no refund.')));
  });

  testWidgets('rules can be removed, and removing them all says the deposit is not refundable', (tester) async {
    await open(tester);
    await tapKey(tester, 'rule-0-remove');
    expect(field(tester, 'rule-0-hours'), '24');
    await tapKey(tester, 'rule-clear');
    expect(find.byKey(const Key('policy-no-rules')), findsOneWidget);
    expect(preview(tester).first, 'The deposit is not refundable.');
    await tapKey(tester, 'policy-save');
    expect(db.paramsOf('save_venue_refund_policy').single['p_details'], {'tiers': [], 'no_refund_after_check_in': true, 'note': null});
    expect(db.stored!['tiers'], isEmpty);
  });

  testWidgets('no more than six rules can be added', (tester) async {
    await open(tester);
    for (var i = 0; i < 4; i++) {
      await tapKey(tester, 'rule-add');
    }
    expect(find.byKey(const Key('rule-5-hours')), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('rule-add'))).onPressed, isNull);
    expect(find.byKey(const Key('rule-limit')), findsOneWidget);
  });

  testWidgets('what is wrong is said before anything is sent, naming the rule', (tester) async {
    await open(tester);
    await enter(tester, 'rule-1-percent', '150');
    await tapKey(tester, 'policy-save');
    expect(find.text('Rule 2: give the percent refunded as a whole number from 0 to 100.'), findsOneWidget);
    expect(db.paramsOf('save_venue_refund_policy'), isEmpty);
    expect(find.byKey(const Key('policy-preview-none')), findsOneWidget, reason: 'while a rule is wrong there is nothing to preview');
  });

  testWidgets('more notice getting less back is refused with the reason', (tester) async {
    await open(tester);
    await enter(tester, 'rule-0-percent', '20');
    await tapKey(tester, 'policy-save');
    expect(find.text('Giving more notice cannot get less back: a rule with fewer hours cannot refund a larger percent.'), findsOneWidget);
    expect(db.stored, isNull);
  });

  testWidgets('the note is cleared by emptying it', (tester) async {
    db.stored = {'tiers': [], 'no_refund_after_check_in': true, 'note': 'Old note'};
    await open(tester);
    await enter(tester, 'policy-note', '');
    await tapKey(tester, 'policy-save');
    expect(db.paramsOf('save_venue_refund_policy').single['p_details']['note'], isNull);
    expect(db.stored!['note'], isNull);
  });

  testWidgets('the database refusing is shown and everything typed stays', (tester) async {
    await open(tester);
    await enter(tester, 'policy-note', 'Message us first.');
    db.beforeCall = (f) {
      if (f == 'save_venue_refund_policy') throw PostgrestException(message: 'the note must be 300 characters or fewer', code: 'P0001');
    };
    await tapKey(tester, 'policy-save');
    expect(find.text('The note must be 300 characters or fewer.'), findsOneWidget);
    expect(field(tester, 'policy-note'), 'Message us first.');
    expect(field(tester, 'rule-0-hours'), '48');
  });

  testWidgets('a connection failure keeps everything and says what to do', (tester) async {
    await open(tester);
    db.beforeCall = (f) {
      if (f == 'save_venue_refund_policy') throw Exception('socket closed');
    };
    await tapKey(tester, 'policy-save');
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.textContaining('socket'), findsNothing);
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('a second tap on Save while the first is going saves once', (tester) async {
    await open(tester);
    final gate = Completer<void>();
    db.hold = gate.future;
    await tester.ensureVisible(find.byKey(const Key('policy-save')));
    await tester.tap(find.byKey(const Key('policy-save')));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);
    gate.complete();
    db.hold = null;
    await tester.pumpAndSettle();
    expect(db.paramsOf('save_venue_refund_policy'), hasLength(1));
  });

  testWidgets('a failed read says so with Try again; someone without access gets no retry', (tester) async {
    db.beforeCall = (f) => throw Exception('boom');
    await open(tester);
    expect(find.byKey(const Key('policy-error')), findsOneWidget);
    db.beforeCall = null;
    await tapKey(tester, 'policy-retry');
    expect(find.byKey(const Key('refund-policy')), findsOneWidget);
    db.role = 'server';
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('policy-error')), findsOneWidget);
    expect(find.byKey(const Key('policy-retry')), findsNothing);
  });
}
