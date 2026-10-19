import 'package:bottles_up_vendor/features/money/logic/money_rules.dart';
import 'package:bottles_up_vendor/features/money/providers/money_providers.dart';
import 'package:bottles_up_vendor/features/money/screens/owner_money_screen.dart';
import 'package:bottles_up_vendor/features/money/services/money_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> row(String id, String name, {int tables = 3, int guests = 6, int booked = 18000, int paid = 15800, int balance = 2200, int cash = 7000, int card = 6800, int short = 100, int over = 200, int flags = 1, int closed = 1}) => {
      'venue_id': id, 'venue_name': name, 'tables': tables, 'guests': guests, 'booked_cents': booked, 'paid_cents': paid, 'balance_cents': balance, 'cash_cents': cash,
      'card_cents': card, 'shortage_cents': short, 'overage_cents': over, 'flags_open': flags, 'nights_closed': closed,
    };

class FakeMoney {
  final List<Map<String, dynamic>> rows = [row('v1', 'Club A'), row('v2', 'Club B', tables: 1, guests: 2, booked: 5000, paid: 5000, balance: 0, cash: 5000, card: 0, short: 0, over: 0, flags: 0, closed: 0)];
  final List<Map<String, dynamic>> calls = [];
  bool allowed = true;
  bool offline = false;
  bool missing = false;

  MoneyService get service => MoneyService(rpc: OpsRpc(rpc: call));

  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async {
    calls.add(params!);
    if (offline) throw Exception('SocketException: connection lost');
    if (missing) throw PostgrestException(message: 'function $function does not exist', code: '42883');
    if (!allowed) throw PostgrestException(message: 'not allowed', code: 'P0001');
    return rows;
  }
}

late FakeMoney db;
const owner = Workspace(membershipId: 'w', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);
DateTime fridayNight() => DateTime(2026, 10, 9, 22, 0);

Future<void> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [moneyServiceProvider.overrideWithValue(db.service)],
    child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: OwnerMoneyScreen(workspace: owner, clock: fridayNight))),
  ));
  await tester.pumpAndSettle();
}

String t(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  setUp(() => db = FakeMoney());

  group('rules', () {
    test('ranges end on tonight and say which nights they cover', () {
      final now = fridayNight();
      expect(moneyRanges.first.resolve(now), (from: '2026-10-09', to: '2026-10-09'));
      expect(moneyRanges[1].resolve(now), (from: '2026-10-03', to: '2026-10-09'));
      expect(moneyRanges[2].resolve(now), (from: '2026-09-10', to: '2026-10-09'));
      expect(moneyRanges.first.describe(now), 'Friday Oct 9');
      expect(moneyRanges[1].describe(now), 'Sat Oct 3 to Fri Oct 9');
    });

    test('after midnight is still last night', () {
      expect(moneyRanges.first.resolve(DateTime(2026, 10, 10, 2)), (from: '2026-10-09', to: '2026-10-09'));
    });

    test('the total adds every club', () {
      final clubs = [parseVenueMoney(row('v1', 'A'))!, parseVenueMoney(row('v2', 'B', tables: 1, cash: 5000, card: 0))!];
      final t = totalOf(clubs);
      expect((t.tables, t.cashCents, t.cardCents, t.collectedCents, t.shortageCents, t.flagsOpen), (4, 12000, 6800, 18800, 200, 2));
    });

    test('differences in words', () {
      expect(differenceLine(parseVenueMoney(row('v', 'A'))!), '\$1.00 short, \$2.00 over');
      expect(differenceLine(parseVenueMoney(row('v', 'A', short: 0, over: 0))!), 'No cash differences counted.');
      expect(differenceLine(parseVenueMoney(row('v', 'A', short: 500, over: 0))!), '\$5.00 short');
    });

    test('a club with nothing is quiet; a row without an id is dropped', () {
      expect(parseVenueMoney(row('v', 'A', tables: 0, cash: 0, card: 0))!.quiet, isTrue);
      expect(parseVenueMoney({'venue_name': 'x'}), isNull);
    });
  });

  group('the Money tab', () {
    testWidgets('shows tonight for each club and the business total, with cash, card, due and differences', (tester) async {
      await open(tester);
      expect(db.calls.first, {'p_org': 'o1', 'p_from': '2026-10-09', 'p_to': '2026-10-09'});
      expect(t(tester, 'money-nights'), 'Friday Oct 9');
      expect(t(tester, 'money-v1-booked'), '\$180.00');
      expect(t(tester, 'money-v1-due'), '\$22.00');
      expect(t(tester, 'money-v1-collected'), '\$138.00');
      expect(t(tester, 'money-v1-cash'), '\$70.00');
      expect(t(tester, 'money-v1-card'), '\$68.00');
      expect(t(tester, 'money-v1-differences'), '\$1.00 short, \$2.00 over');
      expect(t(tester, 'money-v1-flags'), '1 payment is flagged.');
      expect(t(tester, 'money-v2-differences'), 'No cash differences counted.');
      expect(find.byKey(const Key('money-v2-flags')), findsNothing);
      expect(t(tester, 'money-total-collected'), '\$188.00');
      expect(t(tester, 'money-total-due'), '\$22.00');
      expect(t(tester, 'money-total-closed'), '1 night closed.');
    });

    testWidgets('a longer range asks for those nights', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('money-range-last7')));
      await tester.pumpAndSettle();
      expect(db.calls.last, {'p_org': 'o1', 'p_from': '2026-10-03', 'p_to': '2026-10-09'});
      expect(t(tester, 'money-nights'), 'Sat Oct 3 to Fri Oct 9');
    });

    testWidgets('one club has no total card; a quiet club says so', (tester) async {
      db.rows
        ..clear()
        ..add(row('v1', 'Club A', tables: 0, cash: 0, card: 0, short: 0, over: 0, flags: 0, closed: 0));
      await open(tester);
      expect(find.byKey(const Key('money-total')), findsNothing);
      expect(find.byKey(const Key('money-v1-quiet')), findsOneWidget);
    });

    testWidgets('a business with no clubs, no access, no backend and a dropped connection are said in words', (tester) async {
      db.rows.clear();
      await open(tester);
      expect(find.byKey(const Key('money-empty')), findsOneWidget);
      db.allowed = false;
      await open(tester);
      expect(find.byKey(const Key('money-error')), findsOneWidget);
      db.allowed = true;
      db.missing = true;
      await open(tester);
      expect(find.byKey(const Key('money-error')), findsOneWidget);
      expect(find.byKey(const Key('ops-retry')), findsNothing);
      db.missing = false;
      db.offline = true;
      await open(tester);
      db.offline = false;
      db.rows.add(row('v1', 'Club A'));
      await tester.tap(find.byKey(const Key('ops-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('money-v1')), findsOneWidget);
    });
  });
}
