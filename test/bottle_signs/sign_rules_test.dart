import 'package:bottles_up_vendor/features/bottle_signs/logic/sign_rules.dart';
import 'package:bottles_up_vendor/features/bottle_signs/providers/bottle_sign_providers.dart';
import 'package:flutter_test/flutter_test.dart';

// Reading what the database sends about bottle signs, the words, and the checks on what a person types.

Map<String, dynamic> line({String? text = 'Happy Birthday', String? status = 'approved', bool canSet = true, bool review = false, String? note}) =>
    {'line_id': 'l1', 'sign_text': text, 'sign_status': status, 'review_note': note, 'can_set': canSet, 'review_required': review};

void main() {
  group('the club\'s settings', () {
    test('the mode, the approval switch and the bottles are read', () {
      final s = parseSignSettings({
        'mode': 'selected',
        'review_required': true,
        'bottles': [
          {'id': 'b1', 'name': 'Patron', 'size': '750ml', 'category': 'Tequila', 'sign_eligible': true, 'is_available': true},
          {'id': 'b2', 'name': 'Moet', 'size': null, 'category': null, 'sign_eligible': false, 'is_available': false},
        ],
      })!;
      expect(s.mode, SignMode.selected);
      expect(s.reviewRequired, isTrue);
      expect(s.bottles.map((b) => b.title), ['Patron 750ml', 'Moet']);
      expect(s.bottles.map((b) => b.signEligible), [true, false]);
      expect(s.bottles.last.isAvailable, isFalse);
    });

    test('an answer with no mode is not settings; an unknown mode is "off", never "on"', () {
      expect(parseSignSettings({'review_required': true}), isNull);
      expect(parseSignSettings({'mode': 'everything', 'bottles': []})!.mode, SignMode.off);
    });

    test('a bottle without an id is dropped, not guessed at', () {
      final s = parseSignSettings({
        'mode': 'all',
        'bottles': [
          {'name': 'No id'},
          {'id': 'b1', 'name': 'Patron'},
          'junk',
        ],
      })!;
      expect(s.bottles.map((b) => b.id), ['b1']);
    });

    test('a bottle is on the menu unless the database says it is not', () {
      final s = parseSignSettings({
        'mode': 'all',
        'bottles': [
          {'id': 'b1', 'name': 'Patron'},
          {'id': 'b2', 'name': 'Moet', 'is_available': false},
        ],
      })!;
      expect(s.bottles.map((b) => b.isAvailable), [true, false]);
      expect(s.bottles.map((b) => b.signEligible), [false, false]);
    });

    test('the lines a screen holds are one key: same lines in the same order are the same read, anything else is not', () {
      expect(LineIds(['a', 'b']), LineIds(['a', 'b']));
      expect(LineIds(['a', 'b']).hashCode, LineIds(['a', 'b']).hashCode);
      expect(LineIds(['a', 'b']) == LineIds(['b', 'a']), isFalse);
      expect(LineIds(['a', 'b']) == LineIds(['a']), isFalse);
      expect(LineIds(['a', 'b']) == LineIds(['a', 'c']), isFalse);
      expect(LineIds([]), LineIds([]));
    });

    test('every mode has a label and a sentence', () {
      expect(SignMode.values.map((m) => m.label), ['Off', 'Every bottle', 'Chosen bottles']);
      expect(SignMode.values.map((m) => m.value), ['off', 'all', 'selected']);
      for (final m in SignMode.values) {
        expect(m.explanation.isNotEmpty, isTrue);
      }
    });
  });

  group('the sign on a line', () {
    test('its words, state, reason and what the person may do', () {
      final s = parseLineSign(line(status: 'rejected', note: 'Check the spelling', review: true))!;
      expect(s.lineId, 'l1');
      expect(s.text, 'Happy Birthday');
      expect(s.status, SignStatus.rejected);
      expect(s.reviewNote, 'Check the spelling');
      expect(s.canSet, isTrue);
      expect(s.reviewRequired, isTrue);
      expect(s.hasSign, isTrue);
    });

    test('a row without a line is dropped', () {
      expect(parseLineSign({'sign_text': 'x'}), isNull);
    });

    test('a line with no sign has no state', () {
      final s = parseLineSign(line(text: null, status: null))!;
      expect(s.hasSign, isFalse);
      expect(s.status, isNull);
      expect(s.blocksService, isFalse);
    });

    test('a sign that arrives with a state the app does not know is shown as waiting, never as approved', () {
      expect(parseLineSign(line(status: 'strange'))!.status, SignStatus.pendingReview);
      expect(parseLineSign(line(status: null))!.status, SignStatus.pendingReview);
    });

    test('only with review on does a waiting or declined sign stop the order', () {
      for (final (status, review, stops) in [
        ('pending_review', true, true),
        ('rejected', true, true),
        ('approved', true, false),
        ('pending_review', false, false),
        ('rejected', false, false),
        ('approved', false, false),
      ]) {
        final s = parseLineSign(line(status: status, review: review))!;
        expect(s.blocksService, stops, reason: '$status review=$review');
        expect(s.blockMessage != null, stops, reason: '$status review=$review');
      }
    });

    test('the two reasons for stopping are told apart', () {
      expect(parseLineSign(line(status: 'pending_review', review: true))!.blockMessage, 'Waiting for a manager to approve the sign before this is prepared.');
      expect(parseLineSign(line(status: 'rejected', review: true))!.blockMessage, 'The sign was declined. Change the words so a manager can look again.');
    });

    test('the states have their words', () {
      expect(SignStatus.values.map((s) => s.label), ['Waiting for approval', 'Approved', 'Declined']);
      expect(SignStatus.parse('pending_review'), SignStatus.pendingReview);
      expect(SignStatus.parse('nonsense'), isNull);
      expect(SignStatus.parse(null), isNull);
    });
  });

  group('a sign waiting for a manager', () {
    Map<String, dynamic> pending() => {
          'line_id': 'l1', 'booking_id': 'b1', 'bottle_name': 'Patron', 'quantity': 2, 'sign_text': 'Cheers', 'set_by_name': 'Sam', 'set_at': '2026-10-09T20:30:00Z', 'guest_name': 'Ada', 'service_status': 'awaiting_prep',
        };

    test('is read with who wrote it and for whom', () {
      final p = parsePendingSign(pending())!;
      expect(p.title, '2 × Patron');
      expect(p.text, 'Cheers');
      expect(p.setByName, 'Sam');
      expect(p.guestName, 'Ada');
      expect(p.setAt, DateTime.utc(2026, 10, 9, 20, 30));
    });

    test('one bottle needs no count, a missing author is "Staff member"', () {
      final p = parsePendingSign({...pending(), 'quantity': 1, 'set_by_name': null})!;
      expect(p.title, 'Patron');
      expect(p.setByName, 'Staff member');
      expect(parsePendingSign({...pending(), 'quantity': 0})!.quantity, 1);
    });

    test('a row without a line, a booking or words is dropped', () {
      for (final k in ['line_id', 'booking_id', 'sign_text']) {
        expect(parsePendingSign({...pending(), k: null}), isNull, reason: k);
      }
    });
  });

  group('what a person types', () {
    test('nothing is fine: it removes the sign', () {
      expect(checkSignText(''), isNull);
      expect(checkSignText('   '), isNull);
    });

    test('40 characters is the most, counted after trimming', () {
      expect(checkSignText('x' * 40), isNull);
      expect(checkSignText('  ${'x' * 40}  '), isNull);
      expect(checkSignText('x' * 41), 'A sign is at most 40 characters.');
    });

    test('a sign is one line of plain text', () {
      expect(checkSignText('Happy\nBirthday'), 'A sign is one line of plain text.');
      expect(checkSignText('Happy\tBirthday'), 'A sign is one line of plain text.');
      expect(checkSignText('Joyeux anniversaire Zoë 🎉'), isNull);
    });

    test('a reason for declining is 3 to 200 characters', () {
      expect(checkDeclineReason(''), 'Say why the sign is declined (at least 3 characters).');
      expect(checkDeclineReason(' no '), 'Say why the sign is declined (at least 3 characters).');
      expect(checkDeclineReason('Typo'), isNull);
      expect(checkDeclineReason('z' * 200), isNull);
      expect(checkDeclineReason('z' * 201), 'Keep the reason to 200 characters or fewer.');
    });
  });

  group('what the person is told after setting one', () {
    test('saved, waiting for approval, removed, unchanged', () {
      expect(signSavedMessage(parseSignChange({'changed': true, 'sign_text': 'x', 'sign_status': 'approved'})), 'Sign saved.');
      expect(signSavedMessage(parseSignChange({'changed': true, 'sign_text': 'x', 'sign_status': 'pending_review'})), 'Sign saved. A manager has to approve it before this is prepared.');
      expect(signSavedMessage(parseSignChange({'changed': true, 'sign_text': null, 'sign_status': null})), 'Sign removed.');
      expect(signSavedMessage(parseSignChange({'changed': false, 'sign_text': 'x', 'sign_status': 'approved'})), 'Nothing changed.');
    });

    test('an answer that is not an object changes nothing', () {
      expect(parseSignChange(null).changed, isFalse);
      expect(parseSignChange('x').changed, isFalse);
    });
  });
}
