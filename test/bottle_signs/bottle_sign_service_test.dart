import 'dart:io';

import 'package:bottles_up_vendor/features/bottle_signs/logic/sign_rules.dart';
import 'package:bottles_up_vendor/features/bottle_signs/services/bottle_sign_service.dart';
import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sign_backend.dart';

// The calls to the website's bottle sign functions (website repo, 20261116100000_bottle_signs.sql).

void main() {
  late FakeSignBackend db;
  setUp(() {
    db = FakeSignBackend();
    db.bottles['p'] = FakeSignBottle('p', 'Patron', eligible: true);
    db.bottles['g'] = FakeSignBottle('g', 'Grey Goose');
    db.lines['l1'] = FakeSignLine('l1', 'b1', 'p');
    db.lines['l2'] = FakeSignLine('l2', 'b1', 'g');
  });

  Future<void> expectRefusal(Future<Object?> f, String message) => expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));

  group('the settings', () {
    test('are asked for by club, and changed by only what is given', () async {
      final s = await db.service.settings('v1');
      expect(db.calledWith('venue_sign_settings').single, {'p_venue': 'v1'});
      expect(s.mode, SignMode.off);
      expect(s.bottles.map((b) => b.name), ['Patron', 'Grey Goose']);

      final all = await db.service.save('v1', mode: SignMode.all);
      expect(db.calledWith('save_venue_sign_settings').last, {'p_venue': 'v1', 'p_details': {'mode': 'all'}});
      expect(all.mode, SignMode.all);
      final reviewed = await db.service.save('v1', reviewRequired: true);
      expect(db.calledWith('save_venue_sign_settings').last, {'p_venue': 'v1', 'p_details': {'review_required': true}});
      expect(reviewed.mode, SignMode.all, reason: 'the mode is not touched when only the approval is changed');
      expect(reviewed.reviewRequired, isTrue);
    });

    test('a bottle is marked, and marking it again changes nothing', () async {
      expect(await db.service.setEligible('v1', 'g', true), isTrue);
      expect(db.calledWith('set_bottle_sign_eligible').last, {'p_venue': 'v1', 'p_bottle': 'g', 'p_eligible': true});
      expect(await db.service.setEligible('v1', 'g', true), isFalse);
      await expectRefusal(db.service.setEligible('v1', 'nope', true), 'That bottle is not on this club\'s menu.');
    });

    test('are not for a server, and a refusal is the database\'s sentence or "no access"', () async {
      db.role = 'server';
      await expectLater(db.service.settings('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
      await expectRefusal(db.service.save('v1', mode: SignMode.all), 'You don\'t have access to do that.');
    });
  });

  group('the signs of the lines a screen holds', () {
    test('are asked for together, with the line ids', () async {
      db.mode = 'all';
      db.lines['l1']!.text = 'Cheers';
      db.lines['l1']!.status = 'approved';
      final signs = await db.service.lineSigns(['l1', 'l2']);
      expect(db.calledWith('desk_line_signs').single, {'p_lines': ['l1', 'l2']});
      expect(signs.keys, ['l1', 'l2']);
      expect(signs['l1']!.text, 'Cheers');
      expect(signs['l2']!.hasSign, isFalse);
      expect(signs['l2']!.canSet, isTrue);
    });

    test('no lines, no call', () async {
      expect(await db.service.lineSigns([]), isEmpty);
      expect(db.calls, isEmpty);
    });

    test('more than the database answers for at once are asked for in groups of 500 and put together', () async {
      db.mode = 'all';
      for (var i = 0; i < 1200; i++) {
        db.lines['x$i'] = FakeSignLine('x$i', 'b1', 'p');
      }
      final signs = await db.service.lineSigns([for (var i = 0; i < 1200; i++) 'x$i']);
      expect(db.calledWith('desk_line_signs').map((p) => (p['p_lines'] as List).length), [500, 500, 200]);
      expect(signs.length, 1200);
    });

    test('a line the person may not see is simply not in the answer', () async {
      db.mode = 'all';
      db.role = 'server';
      db.lines['l9'] = FakeSignLine('l9', 'b9', 'p');
      final signs = await db.service.lineSigns(['l1', 'l9']);
      expect(signs.keys, ['l1']);
    });

    test('a failure is a load failure the screen can word', () async {
      db.offline = true;
      await expectLater(db.service.lineSigns(['l1']), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
      db.offline = false;
      db.missing = true;
      await expectLater(db.service.lineSigns(['l1']), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    });
  });

  group('putting a sign on, reviewing it', () {
    test('the words are trimmed and the answer says what became of them', () async {
      db.mode = 'all';
      db.review = true;
      db.role = 'server';
      final c = await db.service.setSign('l1', '  Cheers  ');
      expect(db.calledWith('desk_set_bottle_sign').single, {'p_line': 'l1', 'p_text': 'Cheers'});
      expect(c.changed, isTrue);
      expect(c.status, SignStatus.pendingReview);
      expect((await db.service.setSign('l1', 'Cheers')).changed, isFalse);
      final removed = await db.service.setSign('l1', '');
      expect(removed.changed, isTrue);
      expect(removed.text, isNull);
    });

    test('the database\'s own sentences come through', () async {
      await expectRefusal(db.service.setSign('l1', 'Cheers'), 'Signs are not switched on for this club.');
      db.mode = 'selected';
      await expectRefusal(db.service.setSign('l2', 'Cheers'), 'This bottle is not one of the club\'s sign bottles.');
      db.mode = 'all';
      await expectRefusal(db.service.setSign('l1', 'x' * 41), 'A sign is at most 40 characters.');
      db.lines['l1']!.state = 'served';
      await expectRefusal(db.service.setSign('l1', 'Cheers'), 'This item is already on its way, so its sign can no longer change.');
      db.role = 'stranger';
      await expectRefusal(db.service.setSign('l2', 'Cheers'), 'You don\'t have access to do that.');
    });

    test('a manager approves; declining needs a reason, which is trimmed', () async {
      db.mode = 'all';
      db.review = true;
      db.lines['l1']!
        ..text = 'Cheers'
        ..status = 'pending_review'
        ..setBy = 'u-other';
      expect((await db.service.review('l1', approve: true)).status, SignStatus.approved);
      expect(db.calledWith('desk_review_bottle_sign').last, {'p_line': 'l1', 'p_decision': 'approve', 'p_note': null});
      db.lines['l2']!
        ..text = 'Cheers'
        ..status = 'pending_review'
        ..setBy = 'u-other';
      await expectRefusal(db.service.review('l2', approve: false), 'Say why the sign is declined (at least 3 characters).');
      final c = await db.service.review('l2', approve: false, note: '  Check the spelling  ');
      expect(c.status, SignStatus.rejected);
      expect(db.calledWith('desk_review_bottle_sign').last, {'p_line': 'l2', 'p_decision': 'reject', 'p_note': 'Check the spelling'});
      expect(db.lines['l2']!.note, 'Check the spelling');
    });

    test('an approval never sends a note, even if one is passed', () async {
      db.lines['l1']!
        ..text = 'Cheers'
        ..status = 'pending_review'
        ..setBy = 'u-other';
      await db.service.review('l1', approve: true, note: 'ignored');
      expect(db.calledWith('desk_review_bottle_sign').last['p_note'], isNull);
    });

    test('one\'s own sign cannot be reviewed, and a reviewed one cannot be reviewed again', () async {
      db.lines['l1']!
        ..text = 'Mine'
        ..status = 'pending_review'
        ..setBy = db.me;
      await expectRefusal(db.service.review('l1', approve: true), 'Someone else has to review your sign.');
      db.lines['l1']!
        ..status = 'approved'
        ..setBy = 'u-other';
      await expectRefusal(db.service.review('l1', approve: false, note: 'Changed my mind'), 'This sign was already reviewed.');
      expect((await db.service.review('l1', approve: true)).changed, isFalse);
    });

    test('a dropped connection is a plain sentence', () async {
      db.offline = true;
      await expectRefusal(db.service.setSign('l1', 'Cheers'), 'The sign could not be saved. Check your connection and try again.');
      await expectRefusal(db.service.review('l1', approve: true), 'That could not be recorded. Check your connection and try again.');
      await expectRefusal(db.service.save('v1', mode: SignMode.all), 'That could not be saved. Check your connection and try again.');
    });
  });

  group('the queue', () {
    test('lists the signs waiting at a club for a manager only', () async {
      db.lines['l1']!
        ..text = 'Cheers'
        ..status = 'pending_review';
      final list = await db.service.pending('v1');
      expect(db.calledWith('desk_pending_sign_reviews').single, {'p_venue': 'v1'});
      expect(list.single.text, 'Cheers');
      db.role = 'server';
      await expectLater(db.service.pending('v1'), throwsA(isA<OpsLoadException>().having((e) => e.accessEnded, 'accessEnded', isTrue)));
    });
  });

  group('agrees with the website', () {
    final migration = File('../bottles-up-website-main/supabase/migrations/20261116100000_bottle_signs.sql');
    const why = 'the bottle signs migration is not in the website checkout beside this app (its branch is not merged yet)';

    test('every function, its parameters and who may call it', () async {
      final sql = migration.readAsStringSync();
      for (final fn in [
        'venue_sign_settings(p_venue uuid)',
        'save_venue_sign_settings(p_venue uuid, p_details jsonb)',
        'set_bottle_sign_eligible(p_venue uuid, p_bottle uuid, p_eligible boolean)',
        'desk_set_bottle_sign(p_line uuid, p_text text)',
        'desk_review_bottle_sign(p_line uuid, p_decision text, p_note text default null)',
        'desk_line_signs(p_lines uuid[])',
        'desk_pending_sign_reviews(p_venue uuid)',
      ]) {
        expect(sql, contains('create function public.$fn'));
      }
      expect(sql, contains('to authenticated, service_role'));
      db.mode = 'all';
      await db.service.settings('v1');
      await db.service.save('v1', mode: SignMode.all, reviewRequired: false);
      await db.service.setEligible('v1', 'g', true);
      await db.service.lineSigns(['l1']);
      await db.service.setSign('l1', 'x');
      db.lines['l2']!
        ..text = 'y'
        ..status = 'pending_review'
        ..setBy = 'u-other';
      await db.service.review('l2', approve: false, note: 'abc');
      await db.service.pending('v1');
      final keys = {for (final c in db.calls) c.function: c.params!.keys.toList()};
      expect(keys['venue_sign_settings'], ['p_venue']);
      expect(keys['save_venue_sign_settings'], ['p_venue', 'p_details']);
      expect(keys['set_bottle_sign_eligible'], ['p_venue', 'p_bottle', 'p_eligible']);
      expect(keys['desk_line_signs'], ['p_lines']);
      expect(keys['desk_set_bottle_sign'], ['p_line', 'p_text']);
      expect(keys['desk_review_bottle_sign'], ['p_line', 'p_decision', 'p_note']);
      expect(keys['desk_pending_sign_reviews'], ['p_venue']);
    }, skip: migration.existsSync() ? false : why);

    test('the sentences the app relies on, the limits and the settings fields are the database\'s', () {
      final sql = migration.readAsStringSync();
      for (final s in [
        "raise exception 'signs are not switched on for this club'",
        "raise exception 'this bottle is not one of the club''s sign bottles'",
        "raise exception 'a sign is at most 40 characters'",
        "raise exception 'a sign is one line of plain text'",
        "raise exception 'this item is already on its way, so its sign can no longer change'",
        "raise exception 'this item was cancelled'",
        "raise exception 'someone else has to review your sign'",
        "raise exception 'this sign was already reviewed'",
        "raise exception 'say why the sign is declined (at least 3 characters)'",
        "raise exception 'keep the reason to 200 characters or fewer'",
        "raise exception 'ask for at most 500 items at a time'",
        "raise exception 'that bottle is not on this club''s menu'",
        "raise exception 'the sign on this order has not been approved yet'",
        "array['mode', 'review_required']",
        "sign_mode in ('off', 'all', 'selected')",
        "sign_status in ('pending_review', 'approved', 'rejected')",
        'between 1 and 40',
      ]) {
        expect(sql, contains(s));
      }
      expect(maxSignLength, 40);
      expect(lineSignsBatch, 500);
    }, skip: migration.existsSync() ? false : why);
  });
}
