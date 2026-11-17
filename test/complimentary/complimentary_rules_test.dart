import 'dart:io';

import 'package:bottles_up_vendor/features/complimentary/logic/complimentary_rules.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_offers_backend.dart';

// Complimentary bottle offers (website 20261123100000; brief section 20). Rules: what each state says, how a row is read (never guessed), what was typed is checked the way the database checks it.
// Calls: each sends exactly what the function takes. And the app agrees with the migration by name.

({OfferDraft? draft, String? error}) form({
  String? bottle = 'p1',
  String qty = '2',
  String email = 'gina@x.example',
  String name = '',
  String reason = 'Birthday table',
  String sign = '',
  int hours = 24,
}) => checkOfferForm(bottleId: bottle, quantityText: qty, email: email, name: name, reason: reason, sign: sign, expiresHours: hours);

void main() {
  final website = Platform.environment['WEBSITE_REPO'] ?? '../bottles-up-website-main';
  final sql = File('$website/supabase/migrations/20261123100000_complimentary_offers.sql');

  group('What a state says', () {
    test('every state of the brief has its words; "Approved" says the link has not been sent', () {
      expect(offerStatusInfo('approved').label, 'Approved');
      expect(offerStatusInfo('approved').note, contains('has not been sent'));
      expect(offerStatusInfo('sent').label, 'Sent');
      expect(offerStatusInfo('awaiting_location').label, 'Awaiting location');
      expect(offerStatusInfo('location_submitted').label, 'Location submitted');
      expect(offerStatusInfo('accepted').label, 'Accepted for service');
      expect(offerStatusInfo('delivered').label, 'Delivered');
      expect(offerStatusInfo('expired').label, 'Expired');
      expect(offerStatusInfo('cancelled').label, 'Cancelled');
      expect(offerStatusInfo('whatever').label, 'Unknown');
      expect(offerStatusInfo(null).label, 'Unknown');
    });

    test('the tone says how much attention it wants', () {
      expect(offerStatusInfo('approved').tone, OfferTone.attention);
      expect(offerStatusInfo('location_submitted').tone, OfferTone.attention);
      expect(offerStatusInfo('accepted').tone, OfferTone.good);
      expect(offerStatusInfo('delivered').tone, OfferTone.good);
      expect(offerStatusInfo('expired').tone, OfferTone.bad);
      expect(offerStatusInfo('cancelled').tone, OfferTone.neutral);
    });

    test('what became of the free bottle is said, and nothing is invented for an unknown one', () {
      expect(concessionNote('applied'), 'Free bottle applied');
      expect(concessionNote('pending'), 'Free bottle waiting for approval (over the club\'s limit)');
      expect(concessionNote('declined'), 'Free bottle declined');
      expect(concessionNote('voided'), 'Free bottle taken back');
      expect(concessionNote(null), isNull);
      expect(concessionNote('x'), isNull);
    });
  });

  group('Reading what the database sends', () {
    test('a row is read as it is, with the steps the database says are open', () {
      final o = parseOfferRow(offerRow(status: 'location_submitted', location: 'Booth 1', setBy: 'recipient'))!;
      expect(
        [o.id, o.status, o.quantity, o.valueCents, o.reason, o.sign, o.locationName, o.locationSetBy],
        ['o1', 'location_submitted', 2, 50000, 'Birthday table', 'Happy Birthday', 'Booth 1', 'recipient'],
      );
      expect(o.item, '2 × Patron · 750ml');
      expect(o.recipient, 'Gina · gina@x.example');
      expect(o.actions, ['accept', 'set_location', 'cancel']);
      expect([o.can('accept'), o.can('mark_delivered')], [true, false]);
    });

    test('with no name the address is the recipient, with no size the item has none', () {
      final o = parseOfferRow(offerRow(name: null, size: null, quantity: 1))!;
      expect(o.recipient, 'gina@x.example');
      expect(o.item, '1 × Patron');
    });

    test('a row without an id or a status is dropped, and what is missing is plain, never a crash', () {
      expect(parseOfferRow({'status': 'approved'}), isNull);
      expect(parseOfferRow({'offer_id': 'o9'}), isNull);
      final o = parseOfferRow({'offer_id': 'o9', 'status': 'approved', 'actions': 'nope'})!;
      expect([o.bottleName, o.quantity, o.actions], ['Bottle', 0, <String>[]]);
    });

    test('tables, bookings and the answer to accepting are read', () {
      expect(parseOfferTable(tableRow('t1', 'Booth 1', floor: 'Main floor'))!.label, 'Booth 1 · Main floor');
      expect(parseOfferTable(tableRow('t2', 'Booth 2'))!.label, 'Booth 2');
      expect(parseOfferTable({'name': 'x'}), isNull);
      final b = parseOfferBooking(bookingRow('b1', 'Ada Evening', 'ADA-EVENING', guests: 1))!;
      expect(b.label, 'Ada Evening · Booth 1 · 1 guest · ADA-EVENING');
      expect(parseOfferBooking(bookingRow('b2', 'Zed', 'Z', guests: 4))!.label, contains('4 guests'));
      expect(parseOfferBooking({'guest_name': 'x'}), isNull);
      expect(parseAcceptOutcome({'concession_status': 'pending'})!.pending, isTrue);
      expect(parseAcceptOutcome({'concession_status': 'applied'})!.pending, isFalse);
      expect(parseAcceptOutcome({'offer_id': 'o1'})!.pending, isFalse, reason: 'an answer that says nothing about the free bottle is not "waiting"');
      expect(parseAcceptOutcome('nope'), isNull);
    });
  });

  group('What was typed', () {
    test('a complete form becomes a draft, tidied', () {
      final d = form(bottle: 'p1', qty: ' 3 ', email: ' gina@x.example ', name: ' Gina ', reason: ' Birthday table ', sign: ' Happy Birthday ', hours: 72).draft!;
      expect([d.bottleId, d.quantity, d.email, d.name, d.reason, d.sign, d.expiresHours], ['p1', 3, 'gina@x.example', 'Gina', 'Birthday table', 'Happy Birthday', 72]);
      final bare = form().draft!;
      expect([bare.name, bare.sign, bare.expiresHours], [null, null, 24]);
    });

    test('the bottle and the number of bottles are checked', () {
      expect(form(bottle: null).error, 'Choose the bottle.');
      expect(form(bottle: '').error, 'Choose the bottle.');
      expect(form(qty: '0').error, 'Choose from 1 to 12 bottles.');
      expect(form(qty: '13').error, 'Choose from 1 to 12 bottles.');
      expect(form(qty: 'two').error, 'Choose from 1 to 12 bottles.');
      expect(form(qty: '12').error, isNull);
      expect(form(qty: '1').error, isNull);
    });

    test('the e-mail has to look like one, and a long name, reason or sign is refused', () {
      for (final bad in ['', '  ', 'gina', 'gina@x', 'gi na@x.example', '@x.example', 'a' * 250 + '@x.example']) {
        expect(form(email: bad).error, 'Enter the e-mail address the link is for.', reason: bad);
      }
      expect(form(name: 'n' * 61).error, 'Keep the name to 60 characters or fewer.');
      expect(form(name: 'n' * 60).error, isNull);
      expect(form(reason: 'ab').error, 'Say why, in at least 3 characters. It is kept with the offer.');
      expect(form(reason: 'r' * 301).error, 'Keep the reason to 300 characters or fewer.');
      expect(form(reason: 'r' * 300).error, isNull);
      expect(form(sign: 's' * 41).error, 'Keep the sign to 40 characters, on one line.');
      expect(form(sign: 's' * 40).error, isNull);
      expect(form(sign: 'two\nlines').error, 'Keep the sign to 40 characters, on one line.');
    });

    test('the link lasts from 1 hour to 7 days, and the choices offered are inside that', () {
      expect(form(hours: 0).error, 'The link can last from 1 hour to 7 days.');
      expect(form(hours: 169).error, 'The link can last from 1 hour to 7 days.');
      expect(form(hours: 168).error, isNull);
      expect(form(hours: 1).error, isNull);
      expect(expiryChoices.every((c) => c.hours >= 1 && c.hours <= 168), isTrue);
      expect(expiryChoices.map((c) => c.hours), contains(defaultExpiryHours));
    });

    test('a reason to cancel is 3 to 300 characters', () {
      expect(checkCancelReason('x'), 'Say why, in at least 3 characters.');
      expect(checkCancelReason('Not coming'), isNull);
      expect(checkCancelReason('x' * 301), 'Keep it to 300 characters or fewer.');
      expect(checkCancelReason('x' * 300), isNull);
    });

    test('the note says nothing is sent yet', () {
      expect(claimNote, contains('nothing is sent from here'));
      expect(claimNote, contains('ordinary free bottle'));
    });
  });

  group('The service', () {
    late FakeOffersBackend db;
    setUp(() => db = FakeOffersBackend());

    test('the list, the tables and the bookings ask for the club, and for the offer and the night', () async {
      db.offers = [offerRow(), offerRow(id: 'o2', status: 'accepted')];
      expect((await db.service.list('v1')).map((o) => o.id), ['o1', 'o2']);
      expect(db.paramsOf('comp_offers_list').single, {'p_venue': 'v1'});
      expect((await db.service.tables('v1')).length, 2);
      expect(db.paramsOf('comp_offer_tables').single, {'p_venue': 'v1'});
      expect((await db.service.bookings('o1', '2026-10-09')).single.guestName, 'Ada Evening');
      expect(db.paramsOf('comp_offer_bookings').single, {'p_offer': 'o1', 'p_night': '2026-10-09'});
    });

    test('making an offer sends exactly what the function takes', () async {
      final d = form(name: 'Gina', sign: 'Happy Birthday', hours: 72).draft!;
      expect(await db.service.create('v1', d, eventId: 'e1'), 'o-new');
      expect(db.paramsOf('comp_offer_create').single, {
        'p_venue': 'v1',
        'p_bottle': 'p1',
        'p_quantity': 2,
        'p_email': 'gina@x.example',
        'p_name': 'Gina',
        'p_reason': 'Birthday table',
        'p_sign': 'Happy Birthday',
        'p_event': 'e1',
        'p_expires_hours': 72,
      });
      await db.service.create('v1', form().draft!);
      expect(db.paramsOf('comp_offer_create').last, containsPair('p_name', null));
      expect(db.paramsOf('comp_offer_create').last, containsPair('p_event', null));
    });

    test('each step sends the offer and what it needs', () async {
      await db.service.setLocation('o1', 't1');
      expect(db.paramsOf('comp_offer_set_location').single, {'p_offer': 'o1', 'p_table': 't1'});
      final out = await db.service.accept('o1', 'b1');
      expect(out.pending, isFalse);
      expect(db.paramsOf('comp_offer_accept').single, {'p_offer': 'o1', 'p_booking': 'b1'});
      await db.service.markDelivered('o1');
      expect(db.paramsOf('comp_offer_mark_delivered').single, {'p_offer': 'o1'});
      await db.service.cancel('o1', ' Not coming ');
      expect(db.paramsOf('comp_offer_cancel').single, {'p_offer': 'o1', 'p_reason': 'Not coming'});
    });

    test('accepting says when the free bottle is waiting for the owner', () async {
      db.handlers['comp_offer_accept'] = (_) => {'status': 'accepted', 'concession_status': 'pending'};
      expect((await db.service.accept('o1', 'b1')).pending, isTrue);
    });

    test('a refusal is the database\'s own sentence, a lost connection says to look first, a server without the migration is "not set up"', () async {
      db.handlers['comp_offer_accept'] = (_) => throw refuse('that booking is for a different table than the one chosen');
      await expectLater(db.service.accept('o1', 'b1'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', 'That booking is for a different table than the one chosen.')));
      db.handlers.clear();
      db.offline = true;
      await expectLater(db.service.cancel('o1', 'Not coming'), throwsA(isA<OpsActionException>().having((e) => e.message, 'message', contains('look at the offer before trying again'))));
      await expectLater(db.service.list('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', false)));
      db.offline = false;
      db.missing = true;
      await expectLater(db.service.list('v1'), throwsA(isA<OpsLoadException>().having((e) => e.message, 'message', 'The offers are not set up on this server yet.')));
    });
  });

  group('agrees with the website', () {
    late String text;
    setUpAll(() {
      if (sql.existsSync()) text = sql.readAsStringSync();
    });

    test('every function the service calls is defined, with every argument it sends', () {
      final calls = {
        'comp_offers_list': ['p_venue'],
        'comp_offer_tables': ['p_venue'],
        'comp_offer_bookings': ['p_offer', 'p_night'],
        'comp_offer_create': ['p_venue', 'p_bottle', 'p_quantity', 'p_email', 'p_name', 'p_reason', 'p_sign', 'p_event', 'p_expires_hours'],
        'comp_offer_set_location': ['p_offer', 'p_table'],
        'comp_offer_accept': ['p_offer', 'p_booking'],
        'comp_offer_mark_delivered': ['p_offer'],
        'comp_offer_cancel': ['p_offer', 'p_reason'],
      };
      for (final e in calls.entries) {
        final start = text.indexOf('create function public.${e.key}(');
        expect(start, greaterThanOrEqualTo(0), reason: e.key);
        final sig = text.substring(start, text.indexOf('returns', start));
        for (final a in e.value) {
          expect(sig, contains(a), reason: '${e.key} takes $a');
        }
      }
    });

    test('every column of the list, the tables and the bookings, and every state and step, is one the migration writes', () {
      for (final k in [...offerRow().keys, ...tableRow('t', 'n').keys, ...bookingRow('b', 'g', 'c').keys]) {
        expect(text, contains(k), reason: k);
      }
      for (final s in ['approved', 'sent', 'awaiting_location', 'location_submitted', 'accepted', 'delivered', 'expired', 'cancelled']) {
        expect(text, contains("'$s'"), reason: s);
        expect(offerStatusInfo(s).label, isNot('Unknown'), reason: s);
      }
      for (final a in ['set_location', 'accept', 'mark_delivered', 'cancel']) {
        expect(text, contains("'$a'"), reason: a);
      }
      expect(text, contains("'concession_status'"));
    });

    test('the limits the app checks are the limits the database has', () {
      expect(text, contains('p_quantity < 1 or p_quantity > 12'));
      expect(text, contains('p_expires_hours < 1 or p_expires_hours > 168'));
      expect(text, contains('char_length(v_reason) < 3 or char_length(v_reason) > 300'));
      expect(text, contains('char_length(v_sign) > 40'));
      expect(text, contains('char_length(v_name) > 60'));
      expect(text, contains('char_length(v_email) > 254'));
    });
  }, skip: sql.existsSync() ? false : 'website repo is not checked out next to this app');
}
