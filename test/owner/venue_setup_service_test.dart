import 'package:bottles_up_vendor/features/owner/logic/setup_forms.dart';
import 'package:bottles_up_vendor/features/owner/services/db_errors.dart';
import 'package:bottles_up_vendor/features/owner/services/owner_service.dart';
import 'package:bottles_up_vendor/features/owner/services/venue_setup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_setup_backend.dart';

Matcher refusal(String message) => throwsA(isA<SetupEditException>().having((e) => e.message, 'message', message));

void main() {
  late FakeSetupBackend db;
  setUp(() => db = FakeSetupBackend());

  group('error wording', () {
    test('the database\'s own sentence is shown for a refusal, anything else gets the generic one', () {
      expect(actionMessage(const PostgrestException(message: 'that arrival time is already added', code: 'P0001')), 'that arrival time is already added');
      expect(actionMessage(const PostgrestException(message: '  padded  ', code: 'P0001')), 'padded');
      expect(actionMessage(const PostgrestException(message: '', code: 'P0001')), startsWith('This could not be saved'));
      expect(actionMessage(const PostgrestException(message: 'duplicate key value violates unique constraint', code: '23505')), startsWith('This could not be saved'));
      expect(actionMessage(Exception('socket closed')), startsWith('This could not be saved'));
      expect(actionMessage(Exception('socket closed'), generic: 'Try again.'), 'Try again.');
    });

    test('losing access is said in the person\'s words, not the database\'s', () {
      for (final m in ['not allowed', 'not authenticated', 'Not Authorized', 'your access has ended', 'you are signed out']) {
        expect(actionMessage(PostgrestException(message: m, code: 'P0001')), "You don't have access to do that.", reason: m);
      }
    });

    test('a missing function means the migration is not applied', () {
      for (final code in ['42883', 'PGRST202', '42P01']) {
        expect(isMissingFunction(PostgrestException(message: 'x', code: code)), isTrue, reason: code);
      }
      expect(isMissingFunction(const PostgrestException(message: 'x', code: 'P0001')), isFalse);
      expect(isMissingFunction(Exception('x')), isFalse);
    });
  });

  group('arrival times', () {
    test('lists the venue\'s times, dropping rows it cannot read', () async {
      db.slots.addAll([slotRow('s1', 5, '21:00:00', label: 'Late'), {'day_of_week': 5, 'start_time': '22:00:00'}, slotRow('s2', 6, '22:00:00')]);
      final list = await db.service.arrivalTimes('v1');
      expect(list.map((t) => t.slotId), ['s1', 's2']);
      expect(db.paramsOf('list_venue_time_slots'), [
        {'p_venue': 'v1'},
      ]);
    });

    test('adding sends the venue, day, time and a trimmed note; a blank note is none', () async {
      expect(await db.service.addArrivalTime('v1', 5, '21:00', '  Early  '), isNotEmpty);
      await db.service.addArrivalTime('v1', 6, '21:00', '   ');
      expect(db.paramsOf('add_venue_time_slot'), [
        {'p_venue': 'v1', 'p_day': 5, 'p_start': '21:00', 'p_label': 'Early'},
        {'p_venue': 'v1', 'p_day': 6, 'p_start': '21:00', 'p_label': null},
      ]);
    });

    test('a refusal arrives as the database\'s sentence', () async {
      await db.service.addArrivalTime('v1', 5, '21:00', '');
      await expectLater(db.service.addArrivalTime('v1', 5, '21:00', ''), refusal('that arrival time is already added'));
    });

    test('an answer that is not an id is a failure, not a success', () async {
      for (final answer in [null, '', 7]) {
        final odd = VenueSetupService(rpc: (f, {params}) async => answer);
        await expectLater(odd.addArrivalTime('v1', 5, '21:00', ''), refusal('The arrival time could not be added. Try again.'), reason: '$answer');
      }
    });

    test('removing sends the venue and the slot; a time with bookings is refused in the database\'s words', () async {
      db.slots.addAll([slotRow('s1', 5, '21:00:00'), slotRow('s2', 6, '21:00:00', bookings: 2)]);
      await db.service.removeArrivalTime('v1', 's1');
      expect(db.slots.map((s) => s['slot_id']), ['s2']);
      expect(db.paramsOf('remove_venue_time_slot'), [
        {'p_venue': 'v1', 'p_slot': 's1'},
      ]);
      await expectLater(db.service.removeArrivalTime('v1', 's2'), refusal('this arrival time has bookings, so it cannot be removed'));
      expect(db.slots, hasLength(1));
    });

    test('a dropped connection while removing says so plainly', () async {
      db.failAll = Exception('socket closed');
      await expectLater(db.service.removeArrivalTime('v1', 's1'), refusal('This could not be removed. Try again.'));
    });
  });

  group('table types', () {
    test('lists the venue\'s tables', () async {
      db.tables.addAll([tableRowJson('t1', 'VIP booth', bookings: 2), {'name': 'no id', 'max_guests': 4}]);
      final list = await db.service.tableTypes('v1');
      expect(list.map((t) => [t.typeId, t.name, t.bookingCount]), [
        ['t1', 'VIP booth', 2],
      ]);
    });

    test('adding sends no row id and exactly the form\'s fields, then it is in the list', () async {
      final form = TableTypeForm(name: 'Booth', maxGuests: '6', inventoryCount: '2', minSpend: '1500', deposit: '500');
      final id = await db.service.saveTableType('v1', null, tableTypePayload(form));
      final call = db.paramsOf('save_venue_table_type').single!;
      expect([call['p_venue'], call['p_type']], ['v1', null]);
      expect((call['p_details'] as Map).keys.toSet(), tableTypePayload(form).keys.toSet());
      final saved = (await db.service.tableTypes('v1')).single;
      expect([saved.typeId, saved.name, saved.minSpendCents, saved.depositCents, saved.inventoryCount], [id, 'Booth', 150000, 50000, 2]);
    });

    test('changing a table keeps its photo (the form sends the address back as it was); replacing it sends the new one; clearing it sends none', () async {
      db.tables.add(tableRowJson('t1', 'VIP booth'));
      final form = tableTypeFormFrom((await db.service.tableTypes('v1')).single);
      await db.service.saveTableType('v1', 't1', tableTypePayload(form.copyWith(name: 'Renamed')));
      expect(db.tables.single['name'], 'Renamed');
      expect(db.tables.single['image_url'], 'https://img.example/t1.jpg');
      expect((db.paramsOf('save_venue_table_type').single!['p_details'] as Map)['image_url'], 'https://img.example/t1.jpg');
      await db.service.saveTableType('v1', 't1', tableTypePayload(form.copyWith(imageUrl: 'https://img.example/new.jpg')));
      expect(db.tables.single['image_url'], 'https://img.example/new.jpg');
      await db.service.saveTableType('v1', 't1', tableTypePayload(form.copyWith(imageUrl: '')));
      expect(db.tables.single['image_url'], isNull);
    });

    test('a table that is not this venue\'s is refused in the database\'s words', () async {
      await expectLater(db.service.saveTableType('v1', 'nope', {'name': 'x'}), refusal('table type not found'));
    });

    test('a field the database does not know is refused (this is what the drift guard protects)', () async {
      await expectLater(db.service.saveTableType('v1', null, {'name': 'x', 'colour': 'red'}), refusal('unknown field: colour'));
    });

    test('a table with bookings cannot be removed, and the sentence says what to do instead', () async {
      db.tables.addAll([tableRowJson('t1', 'VIP', bookings: 1), tableRowJson('t2', 'Floor')]);
      await expectLater(db.service.removeTableType('v1', 't1'), refusal('this table type has bookings, so it cannot be removed. Lower the number of tables or rename it instead'));
      await db.service.removeTableType('v1', 't2');
      expect(db.tables.map((t) => t['type_id']), ['t1']);
    });

    test('an answer that is not an id is a failure', () async {
      final odd = VenueSetupService(rpc: (f, {params}) async => null);
      await expectLater(odd.saveTableType('v1', null, {}), refusal('The table could not be saved. Try again.'));
    });
  });

  group('bottles', () {
    test('adding then changing one field sends only that field', () async {
      final id = await db.service.saveBottle('v1', null, bottlePayload(const BottleForm(name: 'Grey Goose', price: '195')));
      await db.service.saveBottle('v1', id, {'is_sold_out': true});
      expect(db.paramsOf('save_venue_bottle').last, {'p_venue': 'v1', 'p_bottle': id, 'p_details': {'is_sold_out': true}});
      final b = (await db.service.bottles('v1')).single;
      expect([b.name, b.priceCents, b.isSoldOut, b.isAvailable], ['Grey Goose', 19500, true, true]);
    });

    test('changing a bottle leaves its photo alone', () async {
      db.bottles.add(bottleRowJson('b1', 'Vodka'));
      final form = bottleFormFrom((await db.service.bottles('v1')).single);
      await db.service.saveBottle('v1', 'b1', bottlePayload(form.copyWith(price: '200')));
      expect(db.bottles.single['price_cents'], 20000);
      expect(db.bottles.single['image_url'], 'https://img.example/b1.jpg');
      await db.service.saveBottle('v1', 'b1', bottlePayload(form.copyWith(imageUrl: 'https://img.example/new.jpg')));
      expect(db.bottles.single['image_url'], 'https://img.example/new.jpg');
      await db.service.saveBottle('v1', 'b1', bottlePayload(form.copyWith(imageUrl: '')));
      expect(db.bottles.single['image_url'], isNull);
    });

    test('a bottle that is not this venue\'s is refused in the database\'s words, and removing works', () async {
      await expectLater(db.service.saveBottle('v1', 'nope', {'name': 'x'}), refusal('bottle not found'));
      db.bottles.add(bottleRowJson('b1', 'Vodka'));
      await db.service.removeBottle('v1', 'b1');
      expect(db.bottles, isEmpty);
      await expectLater(db.service.removeBottle('v1', 'b1'), refusal('bottle not found'));
    });

    test('losing access mid-edit is said in the person\'s words', () async {
      db.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
      await expectLater(db.service.saveBottle('v1', null, {'name': 'x'}), refusal("You don't have access to do that."));
    });
  });

  group('loading failures say what is wrong', () {
    Matcher failure({bool unavailable = false, bool accessEnded = false}) => throwsA(isA<OwnerLoadException>()
        .having((e) => e.unavailable, 'unavailable', unavailable)
        .having((e) => e.accessEnded, 'accessEnded', accessEnded));

    test('for each list', () async {
      final lists = <Future<Object?> Function()>[
        () => db.service.arrivalTimes('v1'),
        () => db.service.tableTypes('v1'),
        () => db.service.bottles('v1'),
      ];
      for (final load in lists) {
        db.failAll = const PostgrestException(message: 'no function', code: '42883');
        await expectLater(load(), failure(unavailable: true));
        db.failAll = const PostgrestException(message: 'not allowed', code: 'P0001');
        await expectLater(load(), failure(accessEnded: true));
        db.failAll = Exception('socket closed');
        await expectLater(load(), failure());
      }
    });

    test('a non-list answer is an empty list, never a crash', () async {
      final odd = VenueSetupService(rpc: (f, {params}) async => 'nonsense');
      expect(await odd.bottles('v1'), isEmpty);
      expect(await odd.tableTypes('v1'), isEmpty);
      expect(await odd.arrivalTimes('v1'), isEmpty);
    });
  });
}
