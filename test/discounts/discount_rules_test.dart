import 'package:bottles_up_vendor/features/discounts/logic/discount_rules.dart';
import 'package:bottles_up_vendor/features/table_service/logic/bottle_orders_rules.dart';
import 'package:flutter_test/flutter_test.dart';

ConcessionLimits limits({GiverRole role = GiverRole.server, bool set = true, int max = 10, int? allowed = 2, int used = 0, bool stacking = false, int base = 20000, int due = 30000, int discounted = 0}) =>
    ConcessionLimits(role: role, limitsSet: set, maxPercent: max, freeBottlesAllowed: allowed, freeBottlesUsed: used, allowStacking: stacking, bottleSubtotalCents: base, balanceDueCents: due, discountedCents: discounted);

Concession concession({String kind = 'discount', String status = 'applied', int? percent = 10, int amount = 2000, String? decidedBy, String? note, String role = 'server'}) => parseConcession({
      'concession_id': 'c1',
      'kind': kind,
      'percent': kind == 'discount' ? percent : null,
      'amount_cents': amount,
      'bottle_name': kind == 'free_bottle' ? 'Patron' : null,
      'quantity': kind == 'free_bottle' ? 2 : null,
      'status': status,
      'reason': 'Regular',
      'requested_by_name': 'Sam',
      'requested_role': role,
      'decided_by_name': decidedBy,
      'decision_note': note,
      'created_at': '2026-10-19T22:00:00Z',
    })!;

DiscountForm pct(String v, {String reason = 'Regular guest'}) => DiscountForm(kind: DiscountKind.percent, valueText: v, reason: reason);
DiscountForm amt(String v, {String reason = 'Regular guest'}) => DiscountForm(kind: DiscountKind.amount, valueText: v, reason: reason);

const patron = MenuBottle(id: 'bt1', name: 'Patron', size: '750ml', priceCents: 25000, leftCount: 3);

void main() {
  group('what the caller may give', () {
    test('the limits are read, with an owner\'s unlimited free bottles as no number', () {
      final l = parseConcessionLimits({
        'role': 'manager',
        'limits_set': true,
        'max_percent': 25,
        'free_bottles_allowed': 4,
        'free_bottles_used': 1,
        'allow_stacking': true,
        'bottle_subtotal_cents': 20000,
        'balance_due_cents': 15000,
        'discounted_cents': 500,
      })!;
      expect([l.role, l.limitsSet, l.maxPercent, l.freeBottlesAllowed, l.freeLeft, l.allowStacking, l.bottleSubtotalCents, l.balanceDueCents, l.discountedCents], [GiverRole.manager, true, 25, 4, 3, true, 20000, 15000, 500]);
      final owner = parseConcessionLimits({'role': 'owner', 'limits_set': true, 'max_percent': 100, 'free_bottles_allowed': null, 'free_bottles_used': 0})!;
      expect([owner.freeBottlesAllowed, owner.freeLeft, owner.isOwner], [null, null, true]);
    });

    test('something that is not the limits, or a role this app does not know, is not trusted', () {
      expect(parseConcessionLimits(null), isNull);
      expect(parseConcessionLimits({'role': 'visitor'}), isNull);
      expect(parseConcessionLimits({'limits_set': true}), isNull);
      expect(parseConcessionLimits('server'), isNull);
    });

    test('what is left tonight never goes below zero', () {
      expect(limits(allowed: 2, used: 5).freeLeft, 0);
    });

    test('the sentence says what the person may do, who decides the rest, and when nothing is set', () {
      expect(limitsLine(limits(role: GiverRole.server, max: 10, allowed: 2, used: 1)), 'You may give a discount up to 10% on your own, and 2 free bottles tonight (1 left). Anything more waits for a manager.');
      expect(limitsLine(limits(role: GiverRole.manager, max: 25, allowed: 1, used: 0)), 'You may give a discount up to 25% on your own, and 1 free bottle tonight (1 left). Anything more waits for the owner.');
      expect(limitsLine(limits(set: false)), 'The owner has not set discount limits for this club yet, so nothing can be given.');
      expect(limitsLine(limits(role: GiverRole.owner, set: true, allowed: null)), 'You are the owner: you can give any discount or free bottle.');
      expect(limitsLine(limits(role: GiverRole.owner, set: false, allowed: null)), 'You are the owner: you can give any discount or free bottle.', reason: 'an owner needs no limit');
    });
  });

  group('what has been given', () {
    test('a discount and a free bottle are read and worded', () {
      expect(concessionLine(concession(percent: 10, amount: 2000)), '10% discount: \$20.00 off');
      expect(concessionLine(concession(percent: null, amount: 1500)), '\$15.00 discount');
      expect(concessionLine(concession(kind: 'free_bottle', amount: 50000)), '2 × Patron free');
    });

    test('a row without an id, a known kind or status, an amount or a time is dropped', () {
      final base = {'concession_id': 'a', 'kind': 'discount', 'status': 'applied', 'amount_cents': 100, 'created_at': '2026-10-19T22:00:00Z'};
      expect(parseConcession(base), isNotNull);
      for (final k in ['concession_id', 'amount_cents', 'created_at']) {
        expect(parseConcession({...base}..remove(k)), isNull, reason: k);
      }
      expect(parseConcession({...base, 'kind': 'gift'}), isNull);
      expect(parseConcession({...base, 'status': 'maybe'}), isNull);
      expect(parseConcession({...base, 'created_at': 'later'}), isNull);
    });

    test('who asked and who approved reads as a sentence for each state', () {
      expect(concessionWho(concession()), 'Asked by Sam (server), within their own limit');
      expect(concessionWho(concession(decidedBy: 'Mo')), 'Asked by Sam (server), approved by Mo');
      expect(concessionWho(concession(status: 'pending')), 'Asked by Sam (server), waiting for approval');
      expect(concessionWho(concession(status: 'declined', decidedBy: 'Mo', note: 'Too much')), 'Asked by Sam (server), declined by Mo: Too much');
      expect(concessionWho(concession(status: 'declined')), 'Asked by Sam (server), declined');
      expect(concessionWho(concession(status: 'voided', note: 'Mistake')), 'Asked by Sam (server), taken back: Mistake');
    });

    test('only an applied one can be taken back', () {
      expect([for (final s in ConcessionStatus.values) concession(status: s.db).canTakeBack], [true, false, false, false]);
    });

    test('the statuses read as the brief words', () {
      expect([for (final s in ConcessionStatus.values) s.label], ['Applied', 'Waiting for approval', 'Declined', 'Taken back']);
    });
  });

  group('giving a discount', () {
    test('a sensible percent or amount is fine', () {
      expect(validateDiscount(pct('10'), limits(), const []), isEmpty);
      expect(validateDiscount(pct('100'), limits(role: GiverRole.owner, allowed: null), const []), isEmpty);
      expect(validateDiscount(amt('50.00'), limits(), const []), isEmpty);
      expect(validateDiscount(amt('\$200'), limits(), const []), isEmpty, reason: 'exactly the bottles');
    });

    test('a percent is a whole number from 1 to 100', () {
      for (final bad in ['', 'x', '0', '101', '-5', '5.5', '1e1']) {
        expect(validateDiscount(pct(bad), limits(), const []), ['A percent discount is between 1 and 100.'], reason: '"$bad"');
      }
    });

    test('a percent that comes to less than a cent is refused', () {
      expect(validateDiscount(pct('1'), limits(base: 99), const []), ['That discount is less than one cent.']);
      expect(validateDiscount(pct('1'), limits(base: 100), const []), isEmpty);
    });

    test('an amount needs to be a real amount, and not more than the table\'s bottles', () {
      for (final bad in ['', 'x', '0', '0.00', '-1', '1.234']) {
        expect(validateDiscount(amt(bad), limits(), const []), ['How much is the discount? Enter an amount above \$0.00.'], reason: '"$bad"');
      }
      expect(validateDiscount(amt('200.01'), limits(), const []), ['A discount cannot be more than the table\'s bottles (\$200.00).']);
    });

    test('a table with no bottles has nothing to discount', () {
      expect(validateDiscount(pct('10'), limits(base: 0), const []), ['There are no bottles on this table to discount.']);
    });

    test('it can never be more than the table still owes', () {
      expect(validateDiscount(amt('50.00'), limits(due: 4999), const []), ['A discount of \$50.00 is more than this table still owes (\$49.99).']);
      expect(validateDiscount(amt('50.00'), limits(due: 5000), const []), isEmpty);
      expect(validateDiscount(pct('50'), limits(base: 20000, due: 9999), const []), ['A discount of \$100.00 is more than this table still owes (\$99.99).']);
    });

    test('discounts do not combine unless the owner allows it; declined and taken-back ones do not count', () {
      const msg = 'This table already has a discount: discounts do not combine at this club.';
      expect(validateDiscount(pct('10'), limits(), [concession()]), [msg]);
      expect(validateDiscount(pct('10'), limits(), [concession(status: 'pending')]), [msg]);
      expect(validateDiscount(pct('10'), limits(), [concession(status: 'declined')]), isEmpty);
      expect(validateDiscount(pct('10'), limits(), [concession(status: 'voided')]), isEmpty);
      expect(validateDiscount(pct('10'), limits(), [concession(kind: 'free_bottle')]), isEmpty, reason: 'a free bottle is not a discount');
      expect(validateDiscount(pct('10'), limits(stacking: true), [concession()]), isEmpty);
    });

    test('a reason of 3 to 300 characters is needed', () {
      expect(validateDiscount(pct('10', reason: 'ab'), limits(), const []), ['Give a reason of 3 to 300 characters.']);
      expect(validateDiscount(pct('10', reason: 'x' * 301), limits(), const []), ['Give a reason of 3 to 300 characters.']);
      expect(validateDiscount(pct('10', reason: 'x' * 300), limits(), const []), isEmpty);
    });

    test('until the owner has set limits nothing can be given, except by the owner', () {
      expect(validateDiscount(pct('10'), limits(set: false), const []), ['The owner has not set discount limits for this club yet, so nothing can be given.']);
      expect(validateDiscount(pct('10'), limits(role: GiverRole.owner, set: false, allowed: null), const []), isEmpty);
    });

    test('the amounts are worked out the way the database works them out', () {
      expect(discountCents(pct('15'), 20001), 3000, reason: 'a percent is rounded down to the cent');
      expect(discountCents(amt('12.34'), 99999), 1234);
      expect(discountCents(pct('x'), 20000), isNull);
      expect(discountCents(pct('0'), 20000), isNull);
      expect(discountPercentOf(3000, 20001), 15, reason: '29.99/200.01 rounds up to 15');
      expect(discountPercentOf(3001, 20000), 16);
      expect(discountPercentOf(1, 0), 0);
    });

    test('the payload is what desk_request_discount takes', () {
      expect(discountParams('b1', pct(' 15 ', reason: ' Regular '), 20000), {'p_booking': 'b1', 'p_kind': 'percent', 'p_value': 15, 'p_reason': 'Regular'});
      expect(discountParams('b1', amt('\$12.50'), 20000), {'p_booking': 'b1', 'p_kind': 'amount', 'p_value': 1250, 'p_reason': 'Regular guest'});
    });

    test('before it is sent, the screen says whether it will be applied or wait', () {
      expect(discountPreview(limits(max: 10), 2000), '\$20.00 off (10% of the bottles): applied at once.');
      expect(discountPreview(limits(max: 10), 2001), '\$20.01 off (11% of the bottles) is above your limit of 10%: it waits for a manager to approve.');
      expect(discountPreview(limits(role: GiverRole.manager, max: 25), 6000), contains('waits for the owner'));
      expect(discountPreview(limits(role: GiverRole.owner, max: 100, allowed: null), 20000), '\$200.00 off (100% of the bottles): applied at once.');
    });

    test('the answer is read, and anything else is not trusted', () {
      final r = parseConcessionResult({'id': 'c1', 'status': 'applied', 'amount_cents': 2000, 'percent': 10})!;
      expect([r.id, r.applied, r.amountCents, r.percent], ['c1', true, 2000, 10]);
      expect(parseConcessionResult({'id': 'c1', 'status': 'pending', 'amount_cents': 2000})!.applied, isFalse);
      expect(parseConcessionResult({'id': 'c1', 'status': 'declined'}), isNull);
      expect(parseConcessionResult({'status': 'applied'}), isNull);
      expect(parseConcessionResult('ok'), isNull);
    });

    test('what is said afterwards', () {
      final applied = parseConcessionResult({'id': 'c1', 'status': 'applied', 'amount_cents': 2000})!;
      final waits = parseConcessionResult({'id': 'c1', 'status': 'pending', 'amount_cents': 2000})!;
      expect(discountGivenMessage(applied, limits()), 'Discount applied: \$20.00 off. The table now owes less.');
      expect(discountGivenMessage(waits, limits()), 'Waiting for approval: \$20.00 off. A manager will decide.');
      expect(discountGivenMessage(waits, limits(role: GiverRole.manager)), 'Waiting for approval: \$20.00 off. The owner will decide.');
    });
  });

  group('giving a free bottle', () {
    test('a bottle, a number and a reason', () {
      expect(validateFreeBottle(const FreeBottleForm(bottle: patron, quantity: 2, reason: 'Birthday'), limits()), isEmpty);
      expect(validateFreeBottle(const FreeBottleForm(quantity: 1, reason: 'Birthday'), limits()), ['Choose the bottle.']);
      expect(validateFreeBottle(const FreeBottleForm(bottle: patron, quantity: 0, reason: 'Birthday'), limits()), ['How many bottles? Between 1 and 100.']);
      expect(validateFreeBottle(const FreeBottleForm(bottle: MenuBottle(id: 'x', name: 'Vodka', priceCents: 100), quantity: 101, reason: 'Birthday'), limits()), ['How many bottles? Between 1 and 100.']);
      expect(validateFreeBottle(const FreeBottleForm(bottle: patron, reason: 'no'), limits()), ['Give a reason of 3 to 300 characters.']);
    });

    test('more than are left in stock is refused, and a sold-out bottle cannot be given', () {
      expect(validateFreeBottle(const FreeBottleForm(bottle: patron, quantity: 4, reason: 'Birthday'), limits()), ['Only 3 of Patron 750ml are left.']);
      const one = MenuBottle(id: 'x', name: 'Last One', priceCents: 100, leftCount: 1);
      expect(validateFreeBottle(const FreeBottleForm(bottle: one, quantity: 2, reason: 'Birthday'), limits()), ['Only 1 of Last One is left.']);
      const none = MenuBottle(id: 'y', name: 'Gone', priceCents: 100, leftCount: 0);
      expect(validateFreeBottle(const FreeBottleForm(bottle: none, quantity: 1, reason: 'Birthday'), limits()), ['Gone is sold out.']);
    });

    test('until the owner has set limits nothing can be given, except by the owner', () {
      expect(validateFreeBottle(const FreeBottleForm(bottle: patron, reason: 'Birthday'), limits(set: false)), ['The owner has not set limits for free bottles at this club yet, so nothing can be given.']);
      expect(validateFreeBottle(const FreeBottleForm(bottle: patron, reason: 'Birthday'), limits(role: GiverRole.owner, set: false, allowed: null)), isEmpty);
    });

    test('the payload is what desk_request_free_bottle takes', () {
      expect(freeBottleParams('b1', const FreeBottleForm(bottle: patron, quantity: 2, reason: ' Birthday ')), {'p_booking': 'b1', 'p_bottle': 'bt1', 'p_quantity': 2, 'p_reason': 'Birthday'});
    });

    test('before it is sent, the screen says whether it is within the allowance for the night', () {
      expect(freeBottlePreview(limits(allowed: 2, used: 0), 2), 'Within your allowance tonight (2 left): applied at once.');
      expect(freeBottlePreview(limits(allowed: 2, used: 1), 2), 'More than your allowance tonight (1 left): it waits for a manager to approve.');
      expect(freeBottlePreview(limits(allowed: 0, used: 0), 1), 'More than your allowance tonight (0 left): it waits for a manager to approve.');
      expect(freeBottlePreview(limits(role: GiverRole.owner, allowed: null), 50), 'Applied at once.');
      expect(freeBottlePreview(limits(role: GiverRole.manager, allowed: 1, used: 1), 1), contains('waits for the owner'));
    });

    test('what is said afterwards', () {
      final applied = parseConcessionResult({'id': 'c1', 'status': 'applied', 'value_cents': 50000})!;
      final waits = parseConcessionResult({'id': 'c1', 'status': 'pending', 'value_cents': 50000})!;
      expect(freeBottleGivenMessage(applied, limits(), 'Patron 750ml', 2), '2 × Patron 750ml added at no charge. It is served like any other order and counts against stock, not sales.');
      expect(freeBottleGivenMessage(waits, limits(), 'Patron 750ml', 2), 'Waiting for approval: 2 × Patron 750ml. A manager will decide.');
    });
  });

  group('what waits for approval', () {
    Map<String, dynamic> row({bool canDecide = true, String kind = 'discount'}) => {
          'concession_id': 'c1',
          'booking_id': 'b1',
          'confirmation_code': 'AB12CD',
          'guest_name': 'Ada',
          'table_name': 'VIP booth',
          'kind': kind,
          'percent': kind == 'discount' ? 25 : null,
          'amount_cents': 5000,
          'bottle_name': kind == 'free_bottle' ? 'Patron' : null,
          'quantity': kind == 'free_bottle' ? 2 : null,
          'reason': 'Regular',
          'requested_by_name': 'Sam',
          'requested_role': 'server',
          'created_at': '2026-10-19T22:00:00Z',
          'can_decide': canDecide,
        };

    test('a waiting request is read, with whether the caller may decide it', () {
      final p = parsePending(row())!;
      expect([p.title, p.guestName, p.tableName, p.code, p.requestedBy, p.requestedRole, p.canDecide], ['25% discount: \$50.00 off', 'Ada', 'VIP booth', 'AB12CD', 'Sam', 'server', true]);
      expect(parsePending(row(kind: 'free_bottle'))!.title, '2 × Patron free');
      expect(parsePending(row(canDecide: false))!.canDecide, isFalse);
      expect(cannotDecideWhy(parsePending(row())!), isNull);
      expect(cannotDecideWhy(parsePending(row(canDecide: false))!), contains('your own'));
    });

    test('a row without what it needs is dropped; a missing can_decide is a no', () {
      expect(parsePending({...row()}..remove('concession_id')), isNull);
      expect(parsePending({...row()}..remove('booking_id')), isNull);
      expect(parsePending({...row(), 'kind': 'gift'}), isNull);
      expect(parsePending({...row()}..remove('can_decide'))!.canDecide, isFalse);
    });

    test('declining needs a reason the person can be told; approving needs nothing', () {
      expect(validateConcessionDecision(approve: true, note: ''), isNull);
      expect(validateConcessionDecision(approve: false, note: ''), 'Say why it is declined, so the person can be told.');
      expect(validateConcessionDecision(approve: false, note: 'no'), 'Say why it is declined, so the person can be told.');
      expect(validateConcessionDecision(approve: false, note: 'Too generous'), isNull);
      expect(validateConcessionDecision(approve: true, note: 'x' * 301), 'The note can be up to 300 characters.');
    });

    test('the payload is what desk_decide_concession takes', () {
      expect(decisionParams('c1', true, ' Fine '), {'p_id': 'c1', 'p_approve': true, 'p_note': 'Fine'});
      expect(decisionParams('c1', true, ''), {'p_id': 'c1', 'p_approve': true, 'p_note': null});
      expect(decisionParams('c1', false, 'Too much'), {'p_id': 'c1', 'p_approve': false, 'p_note': 'Too much'});
    });

    test('taking something back needs a reason', () {
      expect(validateTakeBackNote('Given by mistake'), isNull);
      expect(validateTakeBackNote(' no '), 'Say why it is taken back.');
      expect(validateTakeBackNote('x' * 301), 'The note can be up to 300 characters.');
    });
  });

  group('the limits', () {
    DiscountLimits saved({bool has = true}) => parseDiscountLimits({
          'has_limits': has,
          'server_max_percent': 10,
          'manager_max_percent': 25,
          'server_free_bottles_per_night': 2,
          'manager_free_bottles_per_night': 6,
          'allow_stacking': false,
        })!;

    test('they are read, and an answer that is not the limits is not trusted', () {
      final l = saved();
      expect([l.hasLimits, l.serverMaxPercent, l.managerMaxPercent, l.serverFreeBottles, l.managerFreeBottles, l.allowStacking], [true, 10, 25, 2, 6, false]);
      expect(parseDiscountLimits({'hello': 1}), isNull);
    });

    test('a form starts from what is saved, or from zeros', () {
      final f = limitsFormFrom(saved());
      expect([f.serverPercent, f.managerPercent, f.serverBottles, f.managerBottles, f.allowStacking], ['10', '25', '2', '6', false]);
      final none = limitsFormFrom(null);
      expect([none.serverPercent, none.managerPercent, none.serverBottles, none.managerBottles], ['0', '0', '0', '0']);
    });

    test('every limit is a whole number in its range', () {
      expect(validateLimits(const LimitsForm(serverPercent: '10', managerPercent: '25', serverBottles: '2', managerBottles: '6')), isEmpty);
      expect(validateLimits(const LimitsForm(serverPercent: '100', managerPercent: '100', serverBottles: '100', managerBottles: '500')), isEmpty);
      for (final bad in ['', 'x', '-1', '1.5', '101']) {
        expect(validateLimits(LimitsForm(serverPercent: bad)), ['A server\'s discount limit is a whole number from 0 to 100.'], reason: 'server percent "$bad"');
        expect(validateLimits(LimitsForm(managerPercent: bad)), ['A manager\'s discount limit is a whole number from 0 to 100.'], reason: 'manager percent "$bad"');
      }
      expect(validateLimits(const LimitsForm(serverBottles: '101')), ['A server\'s free bottles a night is a whole number from 0 to 100.']);
      expect(validateLimits(const LimitsForm(managerBottles: '501')), ['The managers\' free bottles a night is a whole number from 0 to 500.']);
    });

    test('a server is never allowed more than a manager', () {
      expect(validateLimits(const LimitsForm(serverPercent: '30', managerPercent: '25')), ['A server cannot be allowed a bigger discount than a manager.']);
      expect(validateLimits(const LimitsForm(serverBottles: '5', managerBottles: '4')), ['A server cannot be allowed more free bottles a night than the managers\' pool.']);
      expect(validateLimits(const LimitsForm(serverPercent: '25', managerPercent: '25', serverBottles: '4', managerBottles: '4')), isEmpty);
    });

    test('the payload sends all five keys every time', () {
      expect(limitsPayload(const LimitsForm(serverPercent: ' 10 ', managerPercent: '25', serverBottles: '2', managerBottles: '6', allowStacking: true)), {
        'server_max_percent': 10,
        'manager_max_percent': 25,
        'server_free_bottles_per_night': 2,
        'manager_free_bottles_per_night': 6,
        'allow_stacking': true,
      });
    });

    test('Save is wanted only when something changed, and always for a club with no limits yet', () {
      expect(limitsChanged(saved(), limitsFormFrom(saved())), isFalse);
      expect(limitsChanged(saved(), const LimitsForm(serverPercent: '11', managerPercent: '25', serverBottles: '2', managerBottles: '6')), isTrue);
      expect(limitsChanged(saved(), const LimitsForm(serverPercent: '10', managerPercent: '25', serverBottles: '2', managerBottles: '6', allowStacking: true)), isTrue);
      expect(limitsChanged(saved(has: false), limitsFormFrom(saved(has: false))), isTrue);
      expect(limitsChanged(null, const LimitsForm()), isTrue);
    });

    test('the limits in words, and what no limits means', () {
      expect(limitsWords(saved()), [
        'A server may give up to 10% off and 2 free bottles a night.',
        'A manager may give up to 25% off, and the managers share 6 free bottles a night.',
        'Only one discount may be on a table.',
        'Anything above a limit waits for a manager or the owner to approve.',
      ]);
      expect(limitsWords(saved(has: false)), ['No limits are set, so servers and managers cannot give discounts or free bottles of their own. The owner can.']);
      final one = parseDiscountLimits({'has_limits': true, 'server_max_percent': 5, 'manager_max_percent': 5, 'server_free_bottles_per_night': 1, 'manager_free_bottles_per_night': 1, 'allow_stacking': true})!;
      expect(limitsWords(one)[0], 'A server may give up to 5% off and 1 free bottle a night.');
      expect(limitsWords(one)[2], 'More than one discount may be on a table.');
    });
  });
}
