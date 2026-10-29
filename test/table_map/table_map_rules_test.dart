import 'package:bottles_up_vendor/features/table_map/logic/table_map_rules.dart';
import 'package:flutter_test/flutter_test.dart';

TableState state({int inventory = 3, int booked = 0, int occupied = 0, int held = 0, int unavailable = 0, int? available, String? floor, PlacedBox? box}) => TableState(
      slotId: 's1',
      startTime: '21:00:00',
      tableTypeId: 't1',
      tableName: 'Booth',
      maxGuests: 6,
      floorId: floor,
      box: box,
      inventory: inventory,
      booked: booked,
      occupied: occupied,
      held: held,
      unavailable: unavailable,
      available: available ?? (inventory - booked - occupied - held - unavailable).clamp(0, 1000),
    );

TableLayout layoutRow(String id, {String? floor, PlacedBox? box}) =>
    TableLayout(typeId: id, name: 'T$id', maxGuests: 4, inventory: 1, depositCents: 0, floorId: floor, box: box);

void main() {
  group('boxes on a floor', () {
    test('a box inside the picture is kept, rounded to two decimals', () {
      expect(clampBox(const PlacedBox(x: 10.123, y: 20.456, w: 12.349, h: 10)), const PlacedBox(x: 10.12, y: 20.46, w: 12.35, h: 10));
    });

    test('a box is never smaller than 2 percent, nor bigger than the picture', () {
      expect(clampBox(const PlacedBox(x: 0, y: 0, w: 0.5, h: 1)), const PlacedBox(x: 0, y: 0, w: 2, h: 2));
      expect(clampBox(const PlacedBox(x: 0, y: 0, w: 140, h: 300)), const PlacedBox(x: 0, y: 0, w: 100, h: 100));
    });

    test('a box pushed past an edge stops at the edge, whole inside', () {
      expect(clampBox(const PlacedBox(x: 95, y: 97, w: 12, h: 10)), const PlacedBox(x: 88, y: 90, w: 12, h: 10));
      expect(clampBox(const PlacedBox(x: -5, y: -1, w: 12, h: 10)), const PlacedBox(x: 0, y: 0, w: 12, h: 10));
    });

    test('moving keeps the size and stops at the edges', () {
      const b = PlacedBox(x: 10, y: 10, w: 12, h: 10);
      expect(moveBox(b, 5, -3), const PlacedBox(x: 15, y: 7, w: 12, h: 10));
      expect(moveBox(b, -50, -50), const PlacedBox(x: 0, y: 0, w: 12, h: 10));
      expect(moveBox(b, 500, 500), const PlacedBox(x: 88, y: 90, w: 12, h: 10));
    });

    test('resizing keeps the corner, never goes under 2 percent, and stays inside the picture', () {
      const b = PlacedBox(x: 90, y: 10, w: 8, h: 10);
      expect(resizeBox(b, 5, 5), const PlacedBox(x: 90, y: 10, w: 10, h: 15), reason: 'wider than the room left pulls the box back inside');
      expect(resizeBox(b, -20, -20), const PlacedBox(x: 90, y: 10, w: 2, h: 2));
    });

    test('new tables are staggered so they do not land on each other', () {
      final seen = <PlacedBox>{for (var i = 0; i < 25; i++) defaultBox(i)};
      expect(seen.length, 25);
      for (final b in seen) {
        expect(b, clampBox(b), reason: 'every default box is already valid');
      }
    });
  });

  group('the layout rows', () {
    test('a placed table has its floor and box, an unplaced one has neither', () {
      final placed = parseLayout({'type_id': 't1', 'name': 'Booth', 'max_guests': 6, 'inventory_count': 2, 'deposit_cents': 10000, 'floor_id': 'f1', 'pos_x': '10.5', 'pos_y': 20, 'width': 12, 'height': 10, 'included_admissions': 4})!;
      expect(placed.placed, isTrue);
      expect(placed.box, const PlacedBox(x: 10.5, y: 20, w: 12, h: 10));
      expect(placed.includedAdmissions, 4);
      final loose = parseLayout({'type_id': 't2', 'name': 'Sofa', 'max_guests': 8, 'floor_id': null, 'pos_x': null})!;
      expect(loose.placed, isFalse);
      expect(loose.includedAdmissions, isNull);
    });

    test('a floor without all four numbers is not placed (the database never stores half a box)', () {
      expect(parseLayout({'type_id': 't1', 'name': 'B', 'max_guests': 2, 'floor_id': 'f1', 'pos_x': 1, 'pos_y': 2, 'width': 3})!.placed, isFalse);
    });

    test('a row without an id, a name or seats is dropped', () {
      expect(parseLayout({'name': 'B', 'max_guests': 2}), isNull);
      expect(parseLayout({'type_id': 't', 'max_guests': 2}), isNull);
      expect(parseLayout({'type_id': 't', 'name': 'B'}), isNull);
    });
  });

  group('what has to be saved after editing a floor', () {
    const box = PlacedBox(x: 10, y: 10, w: 12, h: 10);
    final layout = [
      layoutRow('a', floor: 'f1', box: box),
      layoutRow('b'),
      layoutRow('c', floor: 'f2', box: box),
    ];

    test('nothing touched, nothing saved', () {
      expect(placementChanges(floorId: 'f1', layout: layout, edited: {}), isEmpty);
    });

    test('a table put back exactly where it was needs nothing', () {
      expect(placementChanges(floorId: 'f1', layout: layout, edited: {'a': box}), isEmpty);
    });

    test('a moved table and a newly placed one are both placed on this floor', () {
      const moved = PlacedBox(x: 30, y: 30, w: 12, h: 10);
      final changes = placementChanges(floorId: 'f1', layout: layout, edited: {'a': moved, 'b': box});
      expect([for (final c in changes) '${c.typeId}:${c.action.name}'], ['a:place', 'b:place']);
      expect(changes.first.box, moved);
    });

    test('taking a table off this floor unplaces it', () {
      final changes = placementChanges(floorId: 'f1', layout: layout, edited: {'a': null});
      expect([for (final c in changes) '${c.typeId}:${c.action.name}'], ['a:unplace']);
    });

    test('taking off a table that was never placed, or that is on ANOTHER floor, changes nothing', () {
      expect(placementChanges(floorId: 'f1', layout: layout, edited: {'b': null, 'c': null}), isEmpty);
    });

    test('a table from another floor is moved here only when it is given a box here', () {
      final changes = placementChanges(floorId: 'f1', layout: layout, edited: {'c': box});
      expect([for (final c in changes) '${c.typeId}:${c.action.name}'], ['c:place'], reason: 'same numbers, but a different floor');
    });

    test('the status words say where a table is', () {
      String name(String id) => id == 'f2' ? 'Terrace' : 'x';
      expect(placementStatus(layout[0], name, 'f1'), 'On this floor');
      expect(placementStatus(layout[1], name, 'f1'), 'Not on a floor plan');
      expect(placementStatus(layout[2], name, 'f1'), 'On Terrace');
    });
  });

  group('included admissions', () {
    test('the words', () {
      expect(admissionsLine(null), 'Admissions included: not stated');
      expect(admissionsLine(0), 'Admissions included: none (the booking is not admission)');
      expect(admissionsLine(1), 'Admissions included: 1 guest');
      expect(admissionsLine(4), 'Admissions included: 4 guests');
    });

    test('empty means not stated; a number is checked against the seats', () {
      expect(validateIncludedAdmissions('', 6), isNull);
      expect(validateIncludedAdmissions('  ', 6), isNull);
      expect(validateIncludedAdmissions('0', 6), isNull);
      expect(validateIncludedAdmissions('6', 6), isNull);
      expect(validateIncludedAdmissions('7', 6), 'A booking cannot include more admissions (7) than the table seats (6).');
      expect(validateIncludedAdmissions('-1', 6), isNotNull);
      expect(validateIncludedAdmissions('2.5', 6), isNotNull);
      expect(validateIncludedAdmissions('two', 6), isNotNull);
      expect(validateIncludedAdmissions('101', 200), 'Included admissions must be between 0 and 100.');
    });

    test('what is sent: nothing for empty, the number otherwise', () {
      expect(includedAdmissionsValue(''), isNull);
      expect(includedAdmissionsValue(' 3 '), 3);
      expect(includedAdmissionsValue('0'), 0);
    });
  });

  group('the state of a table type', () {
    test('Available whenever any table is free, even when others are booked', () {
      expect(kindOf(state(booked: 1)), MapKind.available);
      expect(kindOf(state(booked: 2, held: 1, available: 0)), MapKind.booked);
    });

    test('when none is free the biggest group wins, and a tie goes to the one that needs more attention', () {
      expect(kindOf(state(inventory: 3, held: 3)), MapKind.held);
      expect(kindOf(state(inventory: 3, unavailable: 2, booked: 1)), MapKind.unavailable);
      expect(kindOf(state(inventory: 2, booked: 1, occupied: 1)), MapKind.occupied);
      expect(kindOf(state(inventory: 2, booked: 1, held: 1)), MapKind.booked);
      expect(kindOf(state(inventory: 2, held: 1, unavailable: 1)), MapKind.held);
    });

    test('a kind with no tables at all reads Unavailable, never Available', () {
      expect(kindOf(state(inventory: 0)), MapKind.unavailable);
    });

    test('the counts line lists only what is not zero', () {
      expect(countsLine(state(inventory: 4, booked: 1, held: 1, unavailable: 1)), '1 available · 1 booked · 1 held · 1 unavailable');
      expect(countsLine(state(inventory: 2, occupied: 2)), '2 occupied');
      expect(countsLine(state(inventory: 0)), 'No tables of this kind');
    });

    test('the labels are the brief\'s five states', () {
      expect([for (final k in MapKind.values) k.label], ['Available', 'Held', 'Booked', 'Occupied', 'Unavailable']);
    });
  });

  group('reading the states', () {
    Map<String, dynamic> row(String slot, String type, {String? label, Object? start = '21:00:00', Object? name = 'Booth', Object? max = 6, Map<String, dynamic> more = const {}}) => {
          'slot_id': slot,
          'start_time': start,
          'slot_label': label,
          'table_type_id': type,
          'table_name': name,
          'max_guests': max,
          'inventory': 2,
          'booked': 1,
          'occupied': 0,
          'held': 0,
          'unavailable': 0,
          'available': 1,
          ...more,
        };

    test('rows are grouped by arrival time in the order given', () {
      final slots = parseTableStates([row('s2', 't1', start: '23:30:00', label: 'Late'), row('s1', 't1'), row('s2', 't2', start: '23:30:00', label: 'Late', name: 'Sofa')]);
      expect(slots.map((s) => s.id), ['s2', 's1']);
      expect(slots.first.tables.map((t) => t.tableName), ['Booth', 'Sofa']);
      expect(slots.first.title, '11:30 PM · Late');
      expect(slots.last.title, '9:00 PM');
    });

    test('a row without a time, a table, a name or seats is dropped', () {
      expect(parseTableStates([row('s1', 't1', start: null), row('s1', 't1', name: null), row('s1', 't1', max: null), {...row('s1', 't1'), 'table_type_id': null}]), isEmpty);
    });

    test('counts are read as numbers; a missing count is zero, not a crash', () {
      final t = parseTableStates([row('s1', 't1', more: {'booked': '2', 'held': null, 'available': 0})]).single.tables.single;
      expect([t.booked, t.held, t.occupied, t.unavailable, t.available], [2, 0, 0, 0, 0]);
    });

    test('a placed table needs its floor and all four numbers', () {
      final placed = parseTableStates([row('s1', 't1', more: {'floor_id': 'f1', 'pos_x': 10, 'pos_y': 20, 'width': 12.5, 'height': 10})]).single.tables.single;
      expect(placed.placed, isTrue);
      expect(placed.box, const PlacedBox(x: 10, y: 20, w: 12.5, h: 10));
      final half = parseTableStates([row('s1', 't1', more: {'floor_id': 'f1', 'pos_x': 10})]).single.tables.single;
      expect(half.placed, isFalse);
    });
  });

  group('holds and unavailable tables', () {
    Map<String, dynamic> blockRow({String kind = 'held', Object? expires = '2026-10-19T23:30:00Z', int qty = 2}) => {
          'block_id': 'b1',
          'table_type_id': 't1',
          'table_name': 'Booth',
          'slot_id': 's1',
          'start_time': '21:00:00',
          'kind': kind,
          'quantity': qty,
          'reason': 'VIP party',
          'made_by': 'Mo',
          'expires_at': expires,
        };

    test('a hold is read with who, why and when it runs out', () {
      final b = parseBlock(blockRow())!;
      expect(b.isHold, isTrue);
      expect(b.quantity, 2);
      expect(b.madeBy, 'Mo');
      expect(b.expiresAt, isNotNull);
    });

    test('an unknown kind is dropped, so a table is never shown as out of use by a guess', () {
      expect(parseBlock(blockRow(kind: 'mystery')), isNull);
      expect(parseBlock({...blockRow(), 'quantity': null}), isNull);
    });

    test('a hold is worded with the time it ends, an unavailable table with "until reopened"', () {
      final hold = TableBlock(id: 'b', tableTypeId: 't', tableName: 'Booth', slotId: 's', startTime: '21:00:00', kind: 'held', quantity: 2, reason: 'r', madeBy: 'Mo', expiresAt: DateTime(2026, 10, 19, 22, 30));
      expect(blockLine(hold), 'Held: 2 × Booth at 9:00 PM until 10:30 PM');
      final out = TableBlock(id: 'b', tableTypeId: 't', tableName: 'Sofa', slotId: 's', startTime: '21:00:00', kind: 'unavailable', quantity: 1, reason: 'r', madeBy: 'Mo');
      expect(blockLine(out), 'Unavailable: 1 × Sofa at 9:00 PM until reopened');
      expect(blockLine(TableBlock(id: 'b', tableTypeId: 't', tableName: 'Booth', slotId: 's', startTime: '00:05:00', kind: 'held', quantity: 1, reason: 'r', madeBy: 'Mo', expiresAt: DateTime(2026, 10, 19, 0, 5))), 'Held: 1 × Booth at 12:05 AM until 12:05 AM');
    });

    test('hold lengths are all within what the database accepts, and read in plain words', () {
      for (final m in holdMinutesChoices) {
        expect(m >= 5 && m <= 1440, isTrue);
      }
      expect(holdLabel(15), '15 min');
      expect(holdLabel(60), '1 hour');
      expect(holdLabel(240), '4 hours');
      expect(holdLabel(1440), '24 hours');
    });

    test('a hold needs a reason of 3 to 200 characters, a quantity that is free, and a length', () {
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 60), 2), isEmpty);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: ' x ', minutes: 60), 2), ['Give a reason of 3 to 200 characters.']);
      expect(validateBlock(BlockForm(kind: 'held', quantity: 1, reason: 'x' * 201, minutes: 60), 2), ['Give a reason of 3 to 200 characters.']);
      expect(validateBlock(BlockForm(kind: 'held', quantity: 1, reason: 'x' * 200, minutes: 60), 2), isEmpty);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: null, reason: 'VIP party', minutes: 60), 2), ['How many tables?']);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 0, reason: 'VIP party', minutes: 60), 2), ['How many tables?']);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 3, reason: 'VIP party', minutes: 60), 2), ['Only 2 of these tables are free for that time. Tables that are already booked or held cannot be blocked.']);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 2, reason: 'VIP party', minutes: 60), 1), ['Only 1 of these tables is free for that time. Tables that are already booked or held cannot be blocked.']);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 60), 0), ['No table of this kind is free for that time, so none can be held or taken out of use.']);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: null), 2), ['A hold lasts between 5 minutes and 24 hours.']);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 4), 2), ['A hold lasts between 5 minutes and 24 hours.']);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 1441), 2), ['A hold lasts between 5 minutes and 24 hours.']);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 5), 2), isEmpty);
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 1, reason: 'VIP party', minutes: 1440), 2), isEmpty);
    });

    test('a table taken out of use has no length to check', () {
      expect(validateBlock(const BlockForm(kind: 'unavailable', quantity: 1, reason: 'Broken leg', minutes: null), 1), isEmpty);
    });

    test('problems come in the order the form reads', () {
      expect(validateBlock(const BlockForm(kind: 'held', quantity: 9, reason: '', minutes: 1), 1), hasLength(3));
    });

    test('what is said after it worked', () {
      expect(blockedMessage(const BlockForm(kind: 'held', quantity: 2, reason: 'r', minutes: 120), 'Booth', 1), '2 × Booth held for 2 hours. 1 left to sell.');
      expect(blockedMessage(const BlockForm(kind: 'unavailable', quantity: 1, reason: 'r'), 'Sofa', 0), '1 × Sofa taken out of use until you reopen it. 0 left to sell.');
      expect(blockedMessage(const BlockForm(kind: 'unavailable', quantity: 2, reason: 'r'), 'Sofa', 3), '2 × Sofa taken out of use until you reopen them. 3 left to sell.');
    });
  });

  group('moving a booking', () {
    Map<String, dynamic> option({bool fits = true, bool current = false, int available = 1, Object? diff = 7500}) => {
          'table_type_id': 't1',
          'table_name': 'Booth',
          'max_guests': 6,
          'min_guests': null,
          'available': available,
          'fits': fits,
          'is_current': current,
          'price_difference_cents': diff,
        };

    test('a table is chosen only when the party fits, one is free and it is not where the booking is', () {
      expect(parseMoveOption(option())!.canChoose, isTrue);
      expect(parseMoveOption(option(current: true))!.whyNot, 'Where the booking is now');
      expect(parseMoveOption(option(fits: false))!.whyNot, 'The party does not fit this table (up to 6 guests)');
      expect(parseMoveOption({...option(fits: false), 'min_guests': 2})!.whyNot, 'The party does not fit this table (2 to 6 guests)');
      expect(parseMoveOption(option(available: 0))!.whyNot, 'None free for that time');
      expect(parseMoveOption(option(current: true, fits: false, available: 0))!.whyNot, 'Where the booking is now', reason: 'the current table is named first');
      expect(parseMoveOption(option(fits: false, available: 0))!.whyNot, startsWith('The party does not fit'));
    });

    test('a row without an id, a name or seats is dropped; a missing "fits" is not a yes', () {
      expect(parseMoveOption({...option(), 'table_type_id': null}), isNull);
      expect(parseMoveOption({...option(), 'table_name': ''}), isNull);
      expect(parseMoveOption({...option(), 'max_guests': null}), isNull);
      expect(parseMoveOption({...option()}..remove('fits'))!.canChoose, isFalse);
    });

    test('the price difference is worded as the deposit, or not at all for an hourly table', () {
      expect(priceDifferenceLine(7500), 'Deposit \$75.00 more');
      expect(priceDifferenceLine(-2000), 'Deposit \$20.00 less');
      expect(priceDifferenceLine(0), 'Same deposit');
      expect(priceDifferenceLine(null), isNull);
    });

    test('a move needs a table and a reason of 3 to 200 characters', () {
      expect(validateMove(toTableTypeId: 't1', reason: 'Guest asked'), isEmpty);
      expect(validateMove(toTableTypeId: null, reason: 'Guest asked'), ['Choose the table to move the booking to.']);
      expect(validateMove(toTableTypeId: 't1', reason: ' x '), ['Give a reason of 3 to 200 characters.']);
      expect(validateMove(toTableTypeId: 't1', reason: 'x' * 201), ['Give a reason of 3 to 200 characters.']);
      expect(validateMove(toTableTypeId: 't1', reason: 'x' * 200), isEmpty);
      expect(validateMove(toTableTypeId: null, reason: ''), hasLength(2));
    });

    test('the result is read, and a result without ids is not trusted', () {
      final r = parseMoveResult({'move_id': 'm1', 'from': 'Pair table', 'to': 'Booth', 'price_difference_cents': 7500})!;
      expect([r.from, r.to, r.priceDifferenceCents], ['Pair table', 'Booth', 7500]);
      expect(parseMoveResult({'from': 'a', 'to': 'b'}), isNull);
      expect(parseMoveResult({'move_id': 'm', 'to': 'b'}), isNull);
    });

    test('the message says the guest\'s amounts did not change when the deposits differ', () {
      expect(moveMessage(const MoveResult(moveId: 'm', from: 'Pair', to: 'Booth')), 'Moved from Pair to Booth.');
      expect(moveMessage(const MoveResult(moveId: 'm', from: 'Pair', to: 'Booth', priceDifferenceCents: 0)), 'Moved from Pair to Booth.');
      expect(moveMessage(const MoveResult(moveId: 'm', from: 'Pair', to: 'Booth', priceDifferenceCents: 7500)),
          'Moved from Pair to Booth. The deposits differ by \$75.00 (the new table costs more). The guest\'s amounts were not changed; settle any difference with them at the club.');
      expect(moveMessage(const MoveResult(moveId: 'm', from: 'Booth', to: 'Pair', priceDifferenceCents: -7500)), contains('the new table costs less'));
    });

    test('a history entry is read, and one without a time or a table is dropped', () {
      final m = parseBookingMove({'moved_at': '2026-10-19T22:00:00Z', 'from_table': 'Pair', 'to_table': 'Booth', 'moved_by': 'Mo', 'reason': 'Guest asked', 'price_difference_cents': 7500})!;
      expect([m.from, m.to, m.by, m.reason, m.priceDifferenceCents], ['Pair', 'Booth', 'Mo', 'Guest asked', 7500]);
      expect(parseBookingMove({'moved_at': 'not a time', 'from_table': 'a', 'to_table': 'b'}), isNull);
      expect(parseBookingMove({'moved_at': '2026-10-19T22:00:00Z', 'to_table': 'b'}), isNull);
      expect(parseBookingMove({'moved_at': '2026-10-19T22:00:00Z', 'from_table': 'a', 'to_table': 'b'})!.by, 'Staff member');
    });
  });

  group('deposit terms', () {
    test('they are read, and anything outside what the database allows is not trusted', () {
      final t = parseDepositTerms({'recipient': 'split', 'venue_pct': 60, 'purpose': 'admission'})!;
      expect([t.recipient, t.venuePct, t.organizerPct, t.purpose, t.isDefault], [DepositRecipient.split, 60, 40, DepositPurpose.admission, false]);
      expect(parseDepositTerms({'recipient': 'venue', 'venue_pct': 100, 'purpose': 'reservation_fee', 'default': true})!.isDefault, isTrue);
      expect(parseDepositTerms(null), isNull);
      expect(parseDepositTerms({'recipient': 'someone', 'venue_pct': 100, 'purpose': 'admission'}), isNull);
      expect(parseDepositTerms({'recipient': 'venue', 'venue_pct': 101, 'purpose': 'admission'}), isNull);
      expect(parseDepositTerms({'recipient': 'venue', 'venue_pct': 100, 'purpose': 'tip'}), isNull);
      expect(parseDepositTerms({'recipient': 'venue', 'purpose': 'admission'}), isNull);
    });

    test('the settings carry the BottlesUp-owned credit switch; no terms is "not chosen yet"', () {
      final s = parseDepositSettings({'terms': null, 'deposit_is_credit': true})!;
      expect(s.terms, isNull);
      expect(s.depositIsCredit, isTrue);
      expect(parseDepositSettings({'terms': null}), isNull);
    });

    test('the purposes on offer follow the credit switch', () {
      expect(purposesFor(depositIsCredit: true), [DepositPurpose.minimumSpendCredit]);
      expect(purposesFor(depositIsCredit: false), [DepositPurpose.reservationFee, DepositPurpose.admission]);
    });

    test('the terms in words', () {
      expect(depositTermsLine(const DepositTerms(recipient: DepositRecipient.venue, venuePct: 100, purpose: DepositPurpose.reservationFee)), 'The venue keeps the deposit, as a reservation fee.');
      expect(depositTermsLine(const DepositTerms(recipient: DepositRecipient.organizer, venuePct: 0, purpose: DepositPurpose.admission)), 'The approved organizer receives the deposit, as admission.');
      expect(depositTermsLine(const DepositTerms(recipient: DepositRecipient.split, venuePct: 60, purpose: DepositPurpose.minimumSpendCredit)), 'The deposit is split: the venue 60%, the organizer 40%, as a credit toward the minimum spend.');
    });

    test('a form needs a recipient, a purpose the credit switch allows, and a split of 1 to 99', () {
      const ok = DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.reservationFee);
      expect(validateDepositTerms(ok, depositIsCredit: false), isEmpty);
      expect(validateDepositTerms(const DepositTermsForm(), depositIsCredit: false), hasLength(2));
      expect(validateDepositTerms(const DepositTermsForm(recipient: DepositRecipient.venue), depositIsCredit: false), ['Choose what the deposit is for.']);
      expect(validateDepositTerms(const DepositTermsForm(purpose: DepositPurpose.admission), depositIsCredit: false), ['Choose who receives the deposit: the venue, the approved organizer, or a split.']);
      expect(validateDepositTerms(ok, depositIsCredit: true).single, contains('credited toward the bottle bill'));
      expect(validateDepositTerms(const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.minimumSpendCredit), depositIsCredit: false).single, contains('not credited toward the bottle bill'));
      expect(validateDepositTerms(const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.minimumSpendCredit), depositIsCredit: true), isEmpty);
      for (final bad in ['', 'x', '0', '100', '-5', '50.5']) {
        expect(validateDepositTerms(DepositTermsForm(recipient: DepositRecipient.split, venuePctText: bad, purpose: DepositPurpose.admission), depositIsCredit: false), hasLength(1), reason: 'split of "$bad"');
      }
      for (final good in ['1', '50', '99', ' 60 ']) {
        expect(validateDepositTerms(DepositTermsForm(recipient: DepositRecipient.split, venuePctText: good, purpose: DepositPurpose.admission), depositIsCredit: false), isEmpty, reason: 'split of "$good"');
      }
      expect(validateDepositTerms(const DepositTermsForm(recipient: DepositRecipient.venue, venuePctText: 'garbage', purpose: DepositPurpose.admission), depositIsCredit: false), isEmpty, reason: 'the percentage only matters for a split');
    });

    test('the payload fixes the venue\'s share for the two single recipients', () {
      expect(depositTermsPayload(const DepositTermsForm(recipient: DepositRecipient.venue, venuePctText: '30', purpose: DepositPurpose.reservationFee)), {'recipient': 'venue', 'venue_pct': 100, 'purpose': 'reservation_fee'});
      expect(depositTermsPayload(const DepositTermsForm(recipient: DepositRecipient.organizer, venuePctText: '30', purpose: DepositPurpose.admission)), {'recipient': 'organizer', 'venue_pct': 0, 'purpose': 'admission'});
      expect(depositTermsPayload(const DepositTermsForm(recipient: DepositRecipient.split, venuePctText: ' 60 ', purpose: DepositPurpose.minimumSpendCredit)), {'recipient': 'split', 'venue_pct': 60, 'purpose': 'minimum_spend_credit'});
    });

    test('the form starts from what is saved, with the share only for a split', () {
      final empty = depositFormFrom(null);
      expect([empty.recipient, empty.purpose, empty.venuePctText], [null, null, '']);
      final split = depositFormFrom(const DepositTerms(recipient: DepositRecipient.split, venuePct: 60, purpose: DepositPurpose.admission));
      expect([split.recipient, split.venuePctText, split.purpose], [DepositRecipient.split, '60', DepositPurpose.admission]);
      expect(depositFormFrom(const DepositTerms(recipient: DepositRecipient.venue, venuePct: 100, purpose: DepositPurpose.admission)).venuePctText, '');
    });

    test('the payload keys are exactly what the database accepts', () {
      expect(depositTermsPayload(const DepositTermsForm(recipient: DepositRecipient.venue, purpose: DepositPurpose.admission)).keys.toSet(), {'recipient', 'venue_pct', 'purpose'});
    });
  });

  group('the terms a booking was sold under', () {
    test('the card reads the deposit, who gets it, the admissions and the refund policy', () {
      final t = parseBookingTerms({
        'deposit_cents': 10000,
        'deposit_terms': {'recipient': 'split', 'venue_pct': 70, 'purpose': 'reservation_fee'},
        'included_admissions': 4,
        'refund_policy_set': true,
        'refund_policy_lines': ['Full refund up to 48 hours before', '50% back up to 24 hours before'],
      })!;
      expect(bookingTermsLines(t), [
        'Deposit: \$100.00',
        'The deposit is split: the venue 70%, the organizer 30%, as a reservation fee.',
        'Admissions included: 4 guests',
        'Full refund up to 48 hours before',
        '50% back up to 24 hours before',
      ]);
    });

    test('a booking with no deposit says so and has no deposit terms line', () {
      final t = parseBookingTerms({'deposit_cents': 0, 'deposit_terms': null, 'included_admissions': null, 'refund_policy_set': false, 'refund_policy_lines': []})!;
      expect(bookingTermsLines(t), ['No deposit', 'Admissions included: not stated', 'No refund policy was set when this was booked.']);
    });

    test('a deposit with no recorded terms (an old booking) says so instead of guessing', () {
      final t = parseBookingTerms({'deposit_cents': 5000, 'deposit_terms': null, 'refund_policy_set': false, 'refund_policy_lines': null})!;
      expect(bookingTermsLines(t)[1], 'Deposit terms were not recorded for this booking.');
    });

    test('something that is not the terms is not read as them', () {
      expect(parseBookingTerms({'hello': 1}), isNull);
    });
  });
}
