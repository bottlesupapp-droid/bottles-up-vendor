import 'package:bottles_up_vendor/features/discounts/logic/discount_rules.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/table_service/logic/bottle_orders_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_discount_backend.dart';

late FakeDiscountBackend db;

const set10 = {'server_max_percent': 10, 'manager_max_percent': 25, 'server_free_bottles_per_night': 2, 'manager_free_bottles_per_night': 4, 'allow_stacking': false};

Future<String> refusal(Future<Object?> Function() action) async {
  try {
    await action();
  } on OpsActionException catch (e) {
    return e.message;
  }
  fail('expected a refusal');
}

DiscountForm pct(String v, {String reason = 'Regular guest'}) => DiscountForm(kind: DiscountKind.percent, valueText: v, reason: reason);
DiscountForm amt(String v, {String reason = 'Regular guest'}) => DiscountForm(kind: DiscountKind.amount, valueText: v, reason: reason);

Future<ConcessionResult> discount(DiscountForm f, {String booking = 'b1'}) async {
  final l = await db.service.limits(booking);
  final existing = await db.service.given(booking);
  return db.service.giveDiscount(booking, f, l, existing);
}

Future<ConcessionResult> free({int quantity = 1, String bottle = 'bt1', String booking = 'b1', String reason = 'Birthday'}) async {
  final l = await db.service.limits(booking);
  final menu = await db.service.menu(booking);
  return db.service.giveFreeBottle(booking, FreeBottleForm(bottle: menu.firstWhere((m) => m.id == bottle), quantity: quantity, reason: reason), l);
}

void main() {
  setUp(() {
    db = FakeDiscountBackend()..role = 'server';
    db.limits = Map.of(set10);
    db.addBooking('b1');
  });

  group('what the caller may give', () {
    test('a server reads their own limits and the table\'s money', () async {
      final l = await db.service.limits('b1');
      expect(db.paramsOf('desk_concession_limits').single, {'p_booking': 'b1'});
      expect([l.role, l.limitsSet, l.maxPercent, l.freeBottlesAllowed, l.freeBottlesUsed, l.bottleSubtotalCents, l.balanceDueCents], [GiverRole.server, true, 10, 2, 0, 20000, 30000]);
    });

    test('a manager has the manager\'s limits, and the owner none', () async {
      db.role = 'manager';
      expect((await db.service.limits('b1')).maxPercent, 25);
      db.role = 'owner';
      final o = await db.service.limits('b1');
      expect([o.role, o.maxPercent, o.freeBottlesAllowed], [GiverRole.owner, 100, null]);
    });

    test('with no limits set a server has nothing to give, and the owner is not held back', () async {
      db.limits = null;
      expect((await db.service.limits('b1')).limitsSet, isFalse);
      db.role = 'owner';
      expect((await db.service.limits('b1')).limitsSet, isTrue);
    });

    test('a server who was not given the table, a verifier and a signed-out person are told their access has ended', () async {
      db.bookings['b1']!.assignedToMe = false;
      await expectLater(db.service.limits('b1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      db.role = 'verifier';
      await expectLater(db.service.limits('b1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      db.role = 'none';
      await expectLater(db.service.limits('b1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });

    test('a failed read is a load failure; a missing function says it is not set up', () async {
      db.failAll = Exception('boom');
      await expectLater(db.service.limits('b1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
      db.failAll = PostgrestException(message: 'function desk_concession_limits does not exist', code: '42883');
      await expectLater(db.service.limits('b1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    });
  });

  group('a discount', () {
    test('within the server\'s limit it is applied at once, and the table owes less', () async {
      final r = await discount(pct('10'));
      expect(db.paramsOf('desk_request_discount').single, {'p_booking': 'b1', 'p_kind': 'percent', 'p_value': 10, 'p_reason': 'Regular guest'});
      expect([r.applied, r.amountCents, r.percent], [true, 2000, 10]);
      final l = await db.service.limits('b1');
      expect([l.balanceDueCents, l.discountedCents], [28000, 2000]);
      final given = await db.service.given('b1');
      expect([given.single.status, given.single.requestedRole, given.single.decidedBy], [ConcessionStatus.applied, 'server', null]);
    });

    test('above the server\'s limit it waits, and the table is untouched', () async {
      final r = await discount(pct('15'));
      expect([r.applied, r.amountCents, r.percent], [false, 3000, 15]);
      final l = await db.service.limits('b1');
      expect([l.balanceDueCents, l.discountedCents], [30000, 0]);
      expect((await db.service.given('b1')).single.status, ConcessionStatus.pending);
    });

    test('an amount is worked out as a share of the bottles, so a big amount waits too', () async {
      expect((await discount(amt('20.00'))).applied, isTrue, reason: '10% of the bottles');
      db.concessions.clear();
      db.bookings['b1']!.discount = 0;
      db.bookings['b1']!.total = 30000;
      expect((await discount(amt('20.01'))).applied, isFalse, reason: 'just over 10%');
    });

    test('a manager has a higher limit, and the owner has none', () async {
      db.role = 'manager';
      expect((await discount(pct('25'))).applied, isTrue);
      db.concessions.clear();
      expect((await discount(pct('26'))).applied, isFalse);
      db.concessions.clear();
      db.role = 'owner';
      expect((await discount(pct('100'))).applied, isTrue);
    });

    test('only one discount a table unless the owner allows more', () async {
      await discount(pct('5'));
      final l = await db.service.limits('b1');
      expect(await refusal(() => db.service.giveDiscount('b1', pct('5'), l, const [])), 'This table already has a discount: discounts do not combine at this club.', reason: 'the database refuses what the app was not shown');
      db.limits = {...set10, 'allow_stacking': true};
      expect((await discount(pct('5'))).applied, isTrue);
    });

    test('the app\'s own checks stop what it can see is wrong, before anything is sent', () async {
      expect(await refusal(() => discount(pct('0'))), 'A percent discount is between 1 and 100.');
      expect(await refusal(() => discount(pct('10', reason: 'x'))), 'Give a reason of 3 to 300 characters.');
      expect(await refusal(() => discount(amt('500'))), 'A discount cannot be more than the table\'s bottles (\$200.00).');
      expect(db.paramsOf('desk_request_discount'), isEmpty);
    });

    test('the database still refuses what the app let through, in its own sentences', () async {
      final l = await db.service.limits('b1');
      db.bookings['b1']!.paid = 29000; // the table was paid in the meantime: only $10.00 is still owed
      expect(await refusal(() => db.service.giveDiscount('b1', pct('10'), l, const [])), 'A discount of 20.00 is more than this table still owes (10.00).');
      db.bookings['b1']!.reconciled = true;
      expect(await refusal(() => db.service.giveDiscount('b1', pct('10'), l, const [])), 'This table has already been closed out.');
      db.bookings['b1']!.reconciled = false;
      db.bookings['b1']!.status = 'cancelled';
      expect(await refusal(() => db.service.giveDiscount('b1', pct('10'), l, const [])), 'Only a confirmed booking can have a discount or a free bottle.');
    });

    test('with the limits not set, the database says so', () async {
      final l = await db.service.limits('b1');
      db.limits = null;
      expect(await refusal(() => db.service.giveDiscount('b1', pct('10'), ConcessionLimits(role: l.role, limitsSet: true, maxPercent: 10, freeBottlesAllowed: 2, freeBottlesUsed: 0, allowStacking: false, bottleSubtotalCents: 20000, balanceDueCents: 30000, discountedCents: 0), const [])),
          'Discounts are not set up for this club yet: the owner sets the limits first.');
    });

    test('a server who is not given the table is refused', () async {
      final l = await db.service.limits('b1');
      db.bookings['b1']!.assignedToMe = false;
      expect(await refusal(() => db.service.giveDiscount('b1', pct('5'), l, const [])), 'You don\'t have access to do that.');
    });

    test('an answer that is not the result is not trusted: the screen is told to look at the table', () async {
      final l = await db.service.limits('b1');
      final broken = _Replying('ok');
      expect(await refusal(() => broken.service.giveDiscount('b1', pct('5'), l, const [])), contains('Look at the table before trying again'));
    });

    test('a failure in transit is the generic sentence, never a raw error', () async {
      final l = await db.service.limits('b1');
      db.beforeCall = (f) {
        if (f == 'desk_request_discount') throw Exception('socket closed at 10.0.0.1');
      };
      final message = await refusal(() => db.service.giveDiscount('b1', pct('5'), l, const []));
      expect(message, contains('Check your connection'));
      expect(message, isNot(contains('socket')));
    });
  });

  group('a free bottle', () {
    test('within the server\'s allowance for the night it is applied at once', () async {
      final r = await free(quantity: 2);
      expect(db.paramsOf('desk_request_free_bottle').single, {'p_booking': 'b1', 'p_bottle': 'bt1', 'p_quantity': 2, 'p_reason': 'Birthday'});
      expect([r.applied, r.valueCents], [true, 50000]);
      final l = await db.service.limits('b1');
      expect([l.freeBottlesUsed, l.freeLeft], [2, 0]);
    });

    test('past the allowance it waits, and uses none of it', () async {
      await free(quantity: 2);
      final r = await free(bottle: 'bt2');
      expect(r.applied, isFalse);
      expect((await db.service.limits('b1')).freeBottlesUsed, 2);
    });

    test('a manager draws on the managers\' pool; a server\'s allowance is their own', () async {
      db.role = 'manager';
      expect((await free(quantity: 4)).applied, isTrue);
      expect((await free(bottle: 'bt2')).applied, isFalse, reason: 'the pool of 4 is used up');
      db.role = 'server';
      expect((await free(bottle: 'bt2')).applied, isTrue, reason: 'the server\'s own allowance is untouched by the manager\'s pool');
    });

    test('the owner is never held back', () async {
      db.role = 'owner';
      db.limits = null;
      expect((await free(quantity: 5, bottle: 'bt2')).applied, isTrue);
    });

    test('the menu is the club\'s bottles on sale, with how many are left', () async {
      final menu = await db.service.menu('b1');
      expect(db.paramsOf('desk_bottle_menu').single, {'p_booking': 'b1'});
      expect(menu.map((m) => '${m.title}:${m.leftCount}'), ['Patron 750ml:6', 'Grey Goose:null', 'Last One:1']);
    });

    test('the app stops what it can see is wrong; the database still counts stock', () async {
      expect(await refusal(() => free(quantity: 7)), 'Only 6 of Patron 750ml are left.');
      final l = await db.service.limits('b1');
      db.menu.first['left_count'] = 1;
      expect(await refusal(() => db.service.giveFreeBottle('b1', const FreeBottleForm(bottle: MenuBottle(id: 'bt1', name: 'Patron', priceCents: 25000), quantity: 2, reason: 'Birthday'), l)), 'Only 1 of that bottle are left.');
    });

    test('an answer that is not the result is not trusted', () async {
      final l = await db.service.limits('b1');
      final broken = _Replying(null);
      expect(await refusal(() => broken.service.giveFreeBottle('b1', const FreeBottleForm(bottle: MenuBottle(id: 'bt1', name: 'Patron', priceCents: 25000), reason: 'Birthday'), l)), contains('Look at the table before trying again'));
    });
  });

  group('what waits for approval', () {
    test('the manager sees the waiting requests, with whether they may decide each', () async {
      db.role = 'manager';
      db.addConcession('b1', amount: 4000, percent: 20);
      db.addConcession('b1', by: 'u-me', amount: 4000, percent: 20);
      db.addConcession('b1', amount: 10000, percent: 50);
      final list = await db.service.pending('v1');
      expect(db.paramsOf('desk_pending_concessions').single, {'p_venue': 'v1'});
      expect(list.map((p) => '${p.title}:${p.canDecide}'), ['20% discount: \$40.00 off:true', '20% discount: \$40.00 off:false', '50% discount: \$100.00 off:false']);
    });

    test('the owner may decide anything except their own', () async {
      db.role = 'owner';
      db.addConcession('b1', amount: 10000, percent: 50);
      db.addConcession('b1', by: 'u-me', amount: 10000, percent: 50);
      expect((await db.service.pending('v1')).map((p) => p.canDecide), [true, false]);
    });

    test('a server cannot see them', () async {
      await expectLater(db.service.pending('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });

    test('approving applies it to the table; declining needs a reason', () async {
      db.role = 'manager';
      final c = db.addConcession('b1', amount: 4000, percent: 20);
      expect(await db.service.decide(c.id, true, ' Fine '), 'applied');
      expect(db.paramsOf('desk_decide_concession').single, {'p_id': c.id, 'p_approve': true, 'p_note': 'Fine'});
      expect((await db.service.limits('b1')).discountedCents, 4000);
      final d = db.addConcession('b1', amount: 1000, percent: 5);
      expect(await refusal(() => db.service.decide(d.id, false, '')), 'Say why it is declined, so the person can be told.');
      expect(db.paramsOf('desk_decide_concession'), hasLength(1), reason: 'the second was not sent');
      expect(await db.service.decide(d.id, false, 'Too generous'), 'declined');
    });

    test('nobody approves their own request', () async {
      db.role = 'manager';
      final c = db.addConcession('b1', by: 'u-me', byRole: 'manager', amount: 4000, percent: 20);
      expect(await refusal(() => db.service.decide(c.id, true, '')), 'You cannot approve your own request: another manager or the owner decides.');
      expect(c.status, 'pending');
    });

    test('a manager cannot approve above the manager\'s limit, nor past the managers\' pool; the owner can', () async {
      db.role = 'manager';
      final big = db.addConcession('b1', amount: 10000, percent: 50);
      expect(await refusal(() => db.service.decide(big.id, true, '')), 'This is more than a manager may approve: the owner decides.');
      final bottles = db.addConcession('b1', kind: 'free_bottle', quantity: 5);
      expect(await refusal(() => db.service.decide(bottles.id, true, '')), 'This is more than the managers\' free bottles for the night: the owner decides.');
      db.role = 'owner';
      expect(await db.service.decide(big.id, true, ''), 'applied');
      expect(await db.service.decide(bottles.id, true, ''), 'applied');
    });

    test('a request that was decided a moment ago', () async {
      db.role = 'manager';
      final c = db.addConcession('b1', amount: 4000, percent: 20);
      await db.service.decide(c.id, true, '');
      expect(await refusal(() => db.service.decide(c.id, true, '')), 'This request has already been decided.');
    });

    test('a discount cannot be approved if another one was applied in the meantime', () async {
      db.role = 'manager';
      final a = db.addConcession('b1', amount: 4000, percent: 20);
      final b = db.addConcession('b1', amount: 2000, percent: 10);
      await db.service.decide(a.id, true, '');
      expect(await refusal(() => db.service.decide(b.id, true, '')), 'This table already has a discount: discounts do not combine at this club.');
    });

    test('an answer that is not applied or declined is not trusted', () async {
      final broken = _Replying('maybe');
      expect(await refusal(() => broken.service.decide('c1', true, '')), contains('Look at the request before trying again'));
    });
  });

  group('taking something back', () {
    test('a discount stops counting and the table owes the amount again', () async {
      db.role = 'manager';
      final c = db.addConcession('b1', amount: 4000, percent: 20, status: 'applied');
      db.bookings['b1']!.discount = 4000;
      db.bookings['b1']!.total = 26000;
      await db.service.takeBack(c.id, ' Mistake ');
      expect(db.paramsOf('desk_void_concession').single, {'p_id': c.id, 'p_note': 'Mistake'});
      final l = await db.service.limits('b1');
      expect([l.discountedCents, l.balanceDueCents], [0, 30000]);
      expect(c.status, 'voided');
    });

    test('a bottle that was served cannot be', () async {
      db.role = 'manager';
      final c = db.addConcession('b1', kind: 'free_bottle', status: 'applied');
      db.served.add(c.id);
      expect(await refusal(() => db.service.takeBack(c.id, 'Mistake')), 'That bottle has already been served, so it cannot be taken back.');
      expect(c.status, 'applied');
    });

    test('a reason is needed, a repeat changes nothing, and only an applied one can be taken back', () async {
      db.role = 'manager';
      final c = db.addConcession('b1', amount: 4000, percent: 20, status: 'applied');
      db.bookings['b1']!.discount = 4000;
      expect(await refusal(() => db.service.takeBack(c.id, 'x')), 'Say why it is taken back.');
      await db.service.takeBack(c.id, 'Mistake');
      await db.service.takeBack(c.id, 'Mistake');
      expect(db.bookings['b1']!.discount, 0, reason: 'taken back once');
      final p = db.addConcession('b1', status: 'pending');
      expect(await refusal(() => db.service.takeBack(p.id, 'Mistake')), 'Only something that has been applied can be taken back.');
    });

    test('a server cannot', () async {
      final c = db.addConcession('b1', status: 'applied');
      expect(await refusal(() => db.service.takeBack(c.id, 'Mistake')), 'You don\'t have access to do that.');
    });
  });

  group('the limits', () {
    test('a club that never set them reads as no limits', () async {
      db.role = 'owner';
      db.limits = null;
      final l = await db.service.venueLimits('v1');
      expect(db.paramsOf('venue_discount_limits').single, {'p_venue': 'v1'});
      expect([l.hasLimits, l.serverMaxPercent], [false, 0]);
    });

    test('the owner saves all five and reads them back', () async {
      db.role = 'owner';
      db.limits = null;
      await db.service.saveLimits('v1', const LimitsForm(serverPercent: '10', managerPercent: '25', serverBottles: '2', managerBottles: '6', allowStacking: true));
      expect(db.paramsOf('save_venue_discount_limits').single, {
        'p_venue': 'v1',
        'p_details': {'server_max_percent': 10, 'manager_max_percent': 25, 'server_free_bottles_per_night': 2, 'manager_free_bottles_per_night': 6, 'allow_stacking': true},
      });
      final l = await db.service.venueLimits('v1');
      expect([l.hasLimits, l.serverMaxPercent, l.managerMaxPercent, l.serverFreeBottles, l.managerFreeBottles, l.allowStacking], [true, 10, 25, 2, 6, true]);
    });

    test('a manager reads them but cannot change them', () async {
      db.role = 'manager';
      expect((await db.service.venueLimits('v1')).hasLimits, isTrue);
      expect(await refusal(() => db.service.saveLimits('v1', const LimitsForm())), 'You don\'t have access to do that.');
    });

    test('a server cannot even read them', () async {
      await expectLater(db.service.venueLimits('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });

    test('limits the app can see are wrong are not sent', () async {
      db.role = 'owner';
      expect(await refusal(() => db.service.saveLimits('v1', const LimitsForm(serverPercent: '30', managerPercent: '25'))), 'A server cannot be allowed a bigger discount than a manager.');
      expect(db.paramsOf('save_venue_discount_limits'), isEmpty);
    });
  });
}

/// A backend whose every answer is [reply]: how the app behaves when a function answers with something it does not expect.
class _Replying extends FakeDiscountBackend {
  _Replying(this.reply);

  final Object? reply;

  @override
  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async => reply;
}
