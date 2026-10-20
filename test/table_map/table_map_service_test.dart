import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:bottles_up_vendor/features/table_map/logic/table_map_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_table_map_backend.dart';

late FakeTableMapBackend db;

const held = BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 60);

Future<int> block({String table = 't2', String slot = 's1', BlockForm form = held}) =>
    db.service.block(venueId: 'v1', night: '2026-10-19', tableTypeId: table, slotId: slot, form: form);

Future<String> refusal(Future<Object?> Function() action) async {
  try {
    await action();
  } on OpsActionException catch (e) {
    return e.message;
  }
  fail('expected a refusal');
}

void main() {
  setUp(() => db = FakeTableMapBackend());

  group('the map', () {
    test('asks for the venue and the night and reads every arrival time with every table', () async {
      final slots = await db.service.states('v1', '2026-10-19');
      expect(db.paramsOf('desk_table_states').single, {'p_venue': 'v1', 'p_night': '2026-10-19'});
      expect(slots.map((s) => s.id), ['s1', 's2']);
      expect(slots.first.tables.map((t) => t.tableName), ['Booth', 'Pair table', 'Sofa']);
      expect(slots.first.tables.first.placed, isTrue, reason: 'the booth is on floor f1');
      expect(slots.first.tables.last.placed, isFalse);
    });

    test('the counts follow the bookings, the holds and the tables taken out of use', () async {
      db.addBooking(table: 't2');
      db.addBooking(table: 't2', seated: true);
      await block(table: 't2');
      await block(table: 't3', form: const BlockForm(kind: 'unavailable', quantity: 1, reason: 'Broken leg'));
      final slots = await db.service.states('v1', '2026-10-19');
      final pair = slots.first.tables.firstWhere((t) => t.tableTypeId == 't2');
      expect([pair.booked, pair.occupied, pair.held, pair.unavailable, pair.available], [1, 1, 1, 0, 0]);
      final sofa = slots.first.tables.firstWhere((t) => t.tableTypeId == 't3');
      expect([sofa.booked, sofa.occupied, sofa.held, sofa.unavailable, sofa.available], [0, 0, 0, 1, 1]);
      expect(slots.last.tables.first.available, 1, reason: 'the other arrival time is untouched');
    });

    test('a pending checkout does not count in the fake, and a booking that is not paid is not booked', () async {
      db.addBooking(table: 't2', status: 'pending');
      final slots = await db.service.states('v1', '2026-10-19');
      expect(slots.first.tables[1].booked, 0);
    });

    test('a failed read is a load failure, never a raw error', () async {
      db.failStates = Exception('socket closed at 10.0.0.1:5432');
      await expectLater(db.service.states('v1', '2026-10-19'), throwsA(isA<OpsLoadException>()));
    });

    test('a database without the function says it is not set up on this server', () async {
      db.failAll = PostgrestException(message: 'function desk_table_states does not exist', code: '42883');
      await expectLater(db.service.states('v1', '2026-10-19'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue).having((e) => e.accessEnded, 'accessEnded', isFalse)));
    });

    test('someone who is not the club\'s manager, or is signed out, is told their access has ended', () async {
      db.role = 'server';
      await expectLater(db.service.states('v1', '2026-10-19'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      db.role = 'none';
      await expectLater(db.service.states('v1', '2026-10-19'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });
  });

  group('holds and tables out of use', () {
    test('a hold is sent with the trimmed reason and the minutes, and tells how many are left to sell', () async {
      final left = await block(form: const BlockForm(kind: 'held', quantity: 2, reason: '  VIP party ', minutes: 120));
      expect(left, 1);
      expect(db.paramsOf('desk_table_block').single, {
        'p_venue': 'v1',
        'p_night': '2026-10-19',
        'p_type': 't2',
        'p_slot': 's1',
        'p_kind': 'held',
        'p_quantity': 2,
        'p_reason': 'VIP party',
        'p_minutes': 120,
      });
    });

    test('a table taken out of use sends no minutes, even if the form held some', () async {
      await block(form: const BlockForm(kind: 'unavailable', quantity: 1, reason: 'Broken leg', minutes: 60));
      expect(db.paramsOf('desk_table_block').single['p_minutes'], isNull);
    });

    test('the blocks in force are listed with who made them and when a hold runs out', () async {
      await block();
      await block(table: 't3', form: const BlockForm(kind: 'unavailable', quantity: 1, reason: 'Broken leg'));
      final list = await db.service.blocks('v1', '2026-10-19');
      expect(list.map((b) => '${b.tableName}:${b.kind}:${b.quantity}:${b.madeBy}'), ['Pair table:held:1:Mo Manager', 'Sofa:unavailable:1:Mo Manager']);
      expect(list.first.expiresAt, isNotNull);
      expect(list.last.expiresAt, isNull);
    });

    test('a hold that has run out is no longer listed and the table is free again', () async {
      var t = DateTime(2026, 10, 19, 21);
      db.now = () => t;
      await block(table: 't1');
      expect((await db.service.states('v1', '2026-10-19')).first.tables.first.available, 0);
      t = t.add(const Duration(minutes: 61));
      expect(await db.service.blocks('v1', '2026-10-19'), isEmpty);
      expect((await db.service.states('v1', '2026-10-19')).first.tables.first.available, 1);
    });

    test('only tables that are free can be blocked: a booked table is never taken away', () async {
      db.addBooking(table: 't1');
      expect(await refusal(() => block(table: 't1')), 'Only 0 of these tables are free for that time; tables that are already booked or held cannot be blocked.');
      db.addBooking(table: 't2');
      db.addBooking(table: 't2');
      expect(await refusal(() => block(form: const BlockForm(kind: 'held', quantity: 2, reason: 'VIP party', minutes: 60))), 'Only 1 of these tables are free for that time; tables that are already booked or held cannot be blocked.');
      expect(db.blocks, isEmpty);
    });

    test('the database\'s own sentences come through for a bad reason, quantity or length', () async {
      expect(await refusal(() => block(form: const BlockForm(kind: 'held', quantity: 1, reason: 'x', minutes: 60))), 'Give a reason of 3 to 200 characters.');
      expect(await refusal(() => block(form: const BlockForm(kind: 'held', quantity: 0, reason: 'VIP party', minutes: 60))), 'How many tables?');
      expect(await refusal(() => block(form: const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 2))), 'A hold lasts between 5 minutes and 24 hours.');
      expect(await refusal(() => block(table: 'nope')), 'Table not found.');
    });

    test('two holds on the last table: the second is refused with the count it saw', () async {
      await block(table: 't1');
      expect(await refusal(() => block(table: 't1')), startsWith('Only 0 of these tables'));
      expect(db.blocks, hasLength(1));
    });

    test('someone who is not this club\'s manager is refused in the app\'s own words', () async {
      db.role = 'server';
      expect(await refusal(() => block()), 'You don\'t have access to do that.');
    });

    test('an answer without the count left is not trusted: the screen is told to look at the map', () async {
      // A reply that is not the expected object (an older function) must not look like success.
      final broken = _ReplyingBackend(null);
      await expectLater(broken.service.block(venueId: 'v1', night: '2026-10-19', tableTypeId: 't2', slotId: 's1', form: held), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('Look at the map'))));
    });

    test('a refusal is a sentence; anything else is the generic one, never a raw error', () async {
      db.failBlock = Exception('socket closed');
      final message = await refusal(() => block());
      expect(message, contains('Check your connection'));
      expect(message, isNot(contains('socket')));
    });

    test('reopening ends the block; a second tap, or a hold that already ran out, says it had ended', () async {
      await block();
      final id = db.blocks.single['id'] as String;
      expect(await db.service.release(id), isTrue);
      expect(await db.service.release(id), isFalse);
      expect(await db.service.blocks('v1', '2026-10-19'), isEmpty);
      expect((await db.service.states('v1', '2026-10-19')).first.tables[1].available, 3);
    });

    test('reopening something that is not there is refused', () async {
      expect(await refusal(() => db.service.release('nope')), 'You don\'t have access to do that.');
    });
  });

  group('moving a booking', () {
    test('the options list every table with whether the party fits and what is free', () async {
      final b = db.addBooking(table: 't2', guests: 3);
      db.addBooking(table: 't1');
      final options = await db.service.moveOptions(b['id'] as String);
      expect(db.paramsOf('desk_booking_move_options').single, {'p_booking': b['id']});
      expect(options.map((o) => '${o.name}:${o.available}:${o.fits}:${o.isCurrent}:${o.priceDifferenceCents}'), ['Booth:0:true:false:7500', 'Pair table:2:true:true:0', 'Sofa:2:true:false:null']);
    });

    test('a move sends the booking, the table and the trimmed reason, and tells from, to and the difference', () async {
      final b = db.addBooking(table: 't2', guests: 3);
      final r = await db.service.move(b['id'] as String, 't1', ' Guest asked ');
      expect(db.paramsOf('desk_move_booking').single, {'p_booking': b['id'], 'p_to_type': 't1', 'p_reason': 'Guest asked'});
      expect([r.from, r.to, r.priceDifferenceCents], ['Pair table', 'Booth', 7500]);
      expect(db.table('t1')['id'], 't1');
      expect(b['table'], 't1');
    });

    test('the move is kept in the history with who, from, to and why, newest first', () async {
      final b = db.addBooking(table: 't2', guests: 3);
      await db.service.move(b['id'] as String, 't1', 'Guest asked');
      await db.service.move(b['id'] as String, 't2', 'Back again');
      final list = await db.service.moves(b['id'] as String);
      expect(list.map((m) => '${m.from}>${m.to}:${m.reason}:${m.by}'), ['Booth>Pair table:Back again:Mo Manager', 'Pair table>Booth:Guest asked:Mo Manager']);
    });

    test('the refusals are the database\'s own sentences', () async {
      final big = db.addBooking(table: 't1', guests: 7);
      final solo = db.addBooking(table: 't1', guests: 1);
      final ok = db.addBooking(table: 't2', guests: 3);
      final pending = db.addBooking(table: 't2', guests: 2, status: 'pending');
      expect(await refusal(() => db.service.move(ok['id'] as String, 't1', 'x')), 'Give a reason of 3 to 200 characters.');
      expect(await refusal(() => db.service.move(pending['id'] as String, 't1', 'Guest asked')), 'Only a confirmed booking can be moved.');
      expect(await refusal(() => db.service.move(ok['id'] as String, 't2', 'Guest asked')), 'The booking is already at that table.');
      expect(await refusal(() => db.service.move(ok['id'] as String, 'nope', 'Guest asked')), 'Table not found.');
      expect(await refusal(() => db.service.move(big['id'] as String, 't2', 'Guest asked')), 'That table seats up to 4 guests and this booking has 7.');
      expect(await refusal(() => db.service.move(solo['id'] as String, 't2', 'Guest asked')), 'That table needs at least 2 guests and this booking has 1.');
      expect(await refusal(() => db.service.move(ok['id'] as String, 't1', 'Guest asked')), 'No tables of that type are free for that time.', reason: 'the booth is taken by the two bookings already in it');
    });

    test('the last table cannot be taken twice', () async {
      final a = db.addBooking(table: 't2', guests: 2);
      final c = db.addBooking(table: 't2', guests: 2);
      await db.service.move(a['id'] as String, 't1', 'First');
      expect(await refusal(() => db.service.move(c['id'] as String, 't1', 'Second')), 'No tables of that type are free for that time.');
      expect(c['table'], 't2');
    });

    test('an answer that is not the result is not trusted: the screen is told to look at the booking', () async {
      final broken = _ReplyingBackend('ok');
      await expectLater(broken.service.move('bk1', 't1', 'Guest asked'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('Look at the booking'))));
    });

    test('someone who is not a manager is refused', () async {
      final b = db.addBooking(table: 't2');
      db.role = 'server';
      await expectLater(db.service.moveOptions(b['id'] as String), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      expect(await refusal(() => db.service.move(b['id'] as String, 't1', 'Guest asked')), 'You don\'t have access to do that.');
    });
  });

  group('what a booking was sold under', () {
    test('the terms are read for the booking', () async {
      final b = db.addBooking(table: 't2');
      db.depositTerms = {'recipient': 'split', 'venue_pct': 60, 'purpose': 'reservation_fee'};
      final t = await db.service.bookingTerms(b['id'] as String);
      expect(db.paramsOf('desk_booking_terms').single, {'p_booking': b['id']});
      expect(t.depositCents, 2500);
      expect(t.deposit!.recipient, DepositRecipient.split);
      expect(t.includedAdmissions, 2);
      expect(t.refundPolicyLines, hasLength(2));
    });

    test('a server may read them; a role with no access is told so', () async {
      final b = db.addBooking(table: 't2');
      db.role = 'server';
      expect((await db.service.bookingTerms(b['id'] as String)).depositCents, 2500);
      db.role = 'door';
      await expectLater(db.service.bookingTerms(b['id'] as String), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });
  });

  group('placement', () {
    test('the layout lists every table with where it is and what it includes', () async {
      final list = await db.service.layout('v1');
      expect(list.map((t) => '${t.name}:${t.placed}:${t.includedAdmissions}'), ['Booth:true:null', 'Pair table:false:2', 'Sofa:false:null']);
    });

    test('placing sends the floor and the four numbers, and the table is then on that floor', () async {
      await db.service.place('v1', 't2', 'f1', const PlacedBox(x: 30.5, y: 40, w: 12, h: 10));
      expect(db.paramsOf('place_venue_table').single, {'p_venue': 'v1', 'p_type': 't2', 'p_floor': 'f1', 'p_x': 30.5, 'p_y': 40.0, 'p_w': 12.0, 'p_h': 10.0});
      final t = (await db.service.layout('v1')).firstWhere((x) => x.typeId == 't2');
      expect([t.floorId, t.box], ['f1', const PlacedBox(x: 30.5, y: 40, w: 12, h: 10)]);
    });

    test('a box outside the picture, or too small, is refused with the database\'s sentence', () async {
      expect(await refusal(() => db.service.place('v1', 't2', 'f1', const PlacedBox(x: 95, y: 10, w: 12, h: 10))), 'The table must be at least 2 percent wide and high and fully inside the floor plan.');
      expect(await refusal(() => db.service.place('v1', 't2', 'f1', const PlacedBox(x: 5, y: 10, w: 1, h: 10))), startsWith('The table must be at least 2 percent'));
      expect(await refusal(() => db.service.place('v1', 'nope', 'f1', const PlacedBox(x: 5, y: 10, w: 12, h: 10))), 'Table type not found.');
    });

    test('taking a table off the floor plan clears all five columns', () async {
      await db.service.unplace('v1', 't1');
      final t = (await db.service.layout('v1')).first;
      expect([t.placed, t.floorId, t.box], [false, null, null]);
    });

    test('included admissions: a number, 0, or nothing; never more than the table seats', () async {
      await db.service.setIncludedAdmissions('v1', 't1', 4);
      expect(db.paramsOf('set_table_included_admissions').single, {'p_venue': 'v1', 'p_type': 't1', 'p_count': 4});
      expect(db.table('t1')['included_admissions'], 4);
      await db.service.setIncludedAdmissions('v1', 't1', null);
      expect(db.table('t1')['included_admissions'], isNull);
      await db.service.setIncludedAdmissions('v1', 't1', 0);
      expect(db.table('t1')['included_admissions'], 0);
      expect(await refusal(() => db.service.setIncludedAdmissions('v1', 't1', 7)), 'A booking cannot include more admissions (7) than the table seats (6).');
      expect(await refusal(() => db.service.setIncludedAdmissions('v1', 't1', 101)), 'Included admissions must be between 0 and 100.');
      expect(db.table('t1')['included_admissions'], 0, reason: 'a refused change leaves it as it was');
    });

    test('a failed layout read is a load failure; no access is access ended', () async {
      db.failLayout = Exception('boom');
      await expectLater(db.service.layout('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
      db.failLayout = null;
      db.role = 'server';
      await expectLater(db.service.layout('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });
  });

  group('deposit terms', () {
    test('nothing chosen yet reads as no terms, with the credit switch', () async {
      db.depositIsCredit = true;
      final s = await db.service.depositSettings('v1');
      expect(db.paramsOf('venue_deposit_terms').single, {'p_venue': 'v1'});
      expect([s.terms, s.depositIsCredit], [null, true]);
    });

    test('saving sends exactly recipient, venue_pct and purpose, and the terms are then read back', () async {
      await db.service.saveDepositTerms('v1', const DepositTermsForm(recipient: DepositRecipient.split, venuePctText: '60', purpose: DepositPurpose.reservationFee));
      expect(db.paramsOf('save_venue_deposit_terms').single, {
        'p_venue': 'v1',
        'p_details': {'recipient': 'split', 'venue_pct': 60, 'purpose': 'reservation_fee'},
      });
      final s = await db.service.depositSettings('v1');
      expect([s.terms!.recipient, s.terms!.venuePct, s.terms!.purpose], [DepositRecipient.split, 60, DepositPurpose.reservationFee]);
    });

    test('a purpose that disagrees with the credit switch is refused with the database\'s sentence, and nothing changes', () async {
      db.depositIsCredit = true;
      expect(await refusal(() => db.service.saveDepositTerms('v1', const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.reservationFee))),
          'The deposit is credited toward the bottle bill at this venue, so its purpose is a minimum spend credit; ask the BottlesUp team if that should change.');
      db.depositIsCredit = false;
      expect(await refusal(() => db.service.saveDepositTerms('v1', const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.minimumSpendCredit))), contains('cannot be a minimum spend credit'));
      expect(db.depositTerms, isNull);
    });

    test('someone who is not a manager or owner is refused', () async {
      db.role = 'server';
      expect(await refusal(() => db.service.saveDepositTerms('v1', const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.admission))), 'You don\'t have access to do that.');
      await expectLater(db.service.depositSettings('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });
  });
}

/// A backend whose every answer is [reply]: how the app behaves when a function answers with something it does not expect (an older version of it).
class _ReplyingBackend extends FakeTableMapBackend {
  _ReplyingBackend(this.reply);

  final Object? reply;

  @override
  Future<dynamic> call(String function, {Map<String, dynamic>? params}) async => reply;
}
