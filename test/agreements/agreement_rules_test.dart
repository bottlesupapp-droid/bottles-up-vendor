import 'package:bottles_up_vendor/features/agreements/logic/agreement_rules.dart';
import 'package:flutter_test/flutter_test.dart';

AgreementRow row({String status = 'negotiating', int version = 2, String? waiting, String side = 'venue', String? reason}) => AgreementRow(
      id: 'a',
      eventTitle: 'Night One',
      venueName: 'Club A',
      organizerName: 'Night Events',
      status: status,
      currentVersion: version,
      side: side,
      waitingOn: waiting,
      closedReason: reason,
    );

void main() {
  group('the sample calculation (the same vectors as the database test)', () {
    const above = {'bar_percent': 10, 'threshold_cents': 500000, 'formula': 'above_threshold'};
    const all = {'bar_percent': 10, 'threshold_cents': 500000, 'formula': 'all_once_reached'};

    test('a percentage of sales ABOVE the threshold', () {
      expect(sampleShareCents(above, 800000), 30000);
      expect(sampleShareCents(above, 400000), 0);
      expect(sampleShareCents(above, 500000), 0);
    });

    test('a percentage of ALL sales once the threshold is reached', () {
      expect(sampleShareCents(all, 800000), 80000);
      expect(sampleShareCents(all, 499999), 0);
      expect(sampleShareCents(all, 500000), 50000);
    });

    test('no share, no sales and odd cents', () {
      expect(sampleShareCents({'formula': 'above_threshold'}, 800000), 0);
      expect(sampleShareCents({'bar_percent': 0, 'formula': 'above_threshold'}, 800000), 0);
      expect(sampleShareCents(above, -5), 0);
      expect(sampleShareCents({'bar_percent': 12.5, 'threshold_cents': 0, 'formula': 'above_threshold'}, 1001), 125);
      expect(sampleShareCents({'bar_percent': 10, 'threshold_cents': 0}, 1000), 0, reason: 'no formula, no share');
    });

    test('the sentence', () {
      expect(sampleSentence(above, 800000), 'On \$8,000.00 of bar sales the organizer\'s share would be \$300.00.');
      expect(sampleSentence({'capacity': 100}, 800000), isNull);
    });
  });

  group('the terms in words', () {
    test('lines come in the form\'s order with money, percentages and choices worded', () {
      final lines = termsLines({'capacity': 400, 'bar_percent': 12.5, 'threshold_cents': 500000, 'ticket_ownership': 'shared', 'formula': 'all_once_reached', 'rooms': 'Main room', 'unknown_key': 'x'});
      expect(lines.map((l) => l.key), ['rooms', 'capacity', 'ticket_ownership', 'bar_percent', 'threshold_cents', 'formula']);
      expect(lines.firstWhere((l) => l.key == 'threshold_cents').value, '\$5,000.00');
      expect(lines.firstWhere((l) => l.key == 'bar_percent').value, '12.5%');
      expect(lines.firstWhere((l) => l.key == 'ticket_ownership').value, 'Shared');
      expect(lines.firstWhere((l) => l.key == 'formula').value, 'A percentage of ALL sales once the threshold is reached');
      expect(termValueLabel('bar_percent', 10), '10%');
    });

    test('changes between versions are told as sentences', () {
      final changes = termsChanges(
        {'capacity': 400, 'rooms': 'Main room', 'admissions': 'Door list', 'threshold_cents': 500000},
        {'capacity': 350, 'rooms': 'Main room', 'cancellation': '48 hours', 'threshold_cents': 600000},
      );
      expect(changes, ['Capacity: 400 → 350', 'Threshold: \$5,000.00 → \$6,000.00', 'Removed: Admissions', 'Added: If the event is cancelled = 48 hours']);
      expect(termsChanges({'capacity': 1}, {'capacity': 1}), isEmpty);
    });
  });

  group('what was typed', () {
    test('plain terms are built, trimmed, typed and kept apart from the empty ones', () {
      final r = buildTerms({'starts': ' 21:00 ', 'capacity': '400', 'rooms': 'Main room', 'bar_percent': '', 'responsibilities': 'Club: bar. Organizer: promotion.'});
      expect(r.error, isNull);
      expect(r.terms, {'starts': '21:00', 'capacity': 400, 'rooms': 'Main room', 'responsibilities': 'Club: bar. Organizer: promotion.'});
    });

    test('mistakes are said in words', () {
      expect(buildTerms({}).error, 'Fill in at least one term.');
      expect(buildTerms({'starts': '9pm'}).error, 'Doors open must be a time like 21:00.');
      expect(buildTerms({'capacity': '0'}).error, 'Capacity must be a whole number from 1.');
      expect(buildTerms({'complimentary_allowance': '-1'}).error, isNotNull);
      expect(buildTerms({'bar_percent': '101'}).error, 'The share must be a number from 0 to 100.');
      expect(buildTerms({'bar_percent': '10.123'}).error, 'The share can have at most two decimals.');
      expect(buildTerms({'threshold_cents': 'lots'}).error, 'Threshold must be an amount like 5000 or 5000.00.');
      expect(buildTerms({'rooms': 'x' * 301}).error, 'Rooms: keep it to 300 characters or fewer.');
      expect(buildTerms({'responsibilities': 'x' * 501}).error, 'Who is responsible for what: keep it to 500 characters or fewer.');
    });

    test('a share of bar sales cannot be proposed without the terms that make it clear', () {
      final base = {'bar_percent': '10'};
      expect(buildTerms(base).error, 'A share of bar sales needs a threshold (0 if it applies from the first sale).');
      expect(buildTerms({...base, 'threshold_cents': '0'}).error, 'Say whether the share is of sales ABOVE the threshold or of ALL sales once it is reached.');
      expect(buildTerms({...base, 'threshold_cents': '0', 'formula': 'above_threshold'}).error, 'Say which revenue counts towards the share.');
      expect(buildTerms({...base, 'threshold_cents': '0', 'formula': 'above_threshold', 'eligible_revenue': 'bar'}).error, 'Say how refunds are treated.');
      expect(buildTerms({...base, 'threshold_cents': '0', 'formula': 'above_threshold', 'eligible_revenue': 'bar', 'refunds': 'deducted'}).error, 'Say how taxes, tips and fees are treated.');
      final ok = buildTerms({...base, 'threshold_cents': '5,000.50', 'formula': 'above_threshold', 'eligible_revenue': 'bar', 'refunds': 'deducted', 'taxes_tips_fees': 'excluded'});
      expect(ok.error, isNull);
      expect(ok.terms!['threshold_cents'], 500050);
      expect(ok.terms!['bar_percent'], 10);
    });

    test('a share of nothing needs none of that', () {
      expect(buildTerms({'bar_percent': '0', 'capacity': '300'}).error, isNull);
    });

    test('money is read as dollars and cents', () {
      expect(parseMoneyToCents('5000'), 500000);
      expect(parseMoneyToCents('\$5,000.5'), 500050);
      expect(parseMoneyToCents('12.34'), 1234);
      expect(parseMoneyToCents('12.345'), isNull);
      expect(parseMoneyToCents('-5'), isNull);
      expect(parseMoneyToCents(''), isNull);
    });

    test('notes, reasons and messages', () {
      expect(checkAgreementNote(' '), 'Write the note first.');
      expect(checkAgreementNote('x' * 1001), 'Keep a note to 1000 characters or fewer.');
      expect(checkAgreementNote('hello'), isNull);
      expect(checkCloseReason('no'), 'Say why.');
      expect(checkCloseReason('We are closed'), isNull);
      expect(checkRequestMessage('x' * 501), 'Keep the message to 500 characters or fewer.');
    });
  });

  group('who has to act', () {
    test('a request waits on the club; a proposal on the side that has not accepted; a closed one says why', () {
      expect(waitingLine(row(status: 'requested', version: 0, waiting: 'venue')), 'Waiting for you to review the request');
      expect(waitingLine(row(status: 'requested', version: 0, waiting: 'venue', side: 'organizer')), 'Waiting for the club to respond');
      expect(waitingLine(row(waiting: 'venue')), 'Waiting for you to review version 2');
      expect(waitingLine(row(waiting: 'organizer')), 'Waiting for the organizer to accept version 2');
      expect(waitingLine(row(status: 'active')), 'Agreed. Nothing waiting.');
      expect(waitingLine(row(status: 'declined', reason: 'closed that night')), 'Declined: closed that night');
      expect(row(waiting: 'venue').waitingOnMe, isTrue);
      expect(row(waiting: 'organizer').waitingOnMe, isFalse);
      expect(row(status: 'cancelled').closed, isTrue);
    });

    test('statuses read as words', () {
      expect(agreementStatusLabel('changes_pending'), 'Active, change proposed');
      expect(agreementStatusLabel('negotiating'), 'Being agreed');
    });
  });

  test('a detail is read with versions newest first, acceptances and notes', () {
    final d = parseAgreementDetail({
      'agreement_id': 'a1',
      'status': 'changes_pending',
      'side': 'venue',
      'event_title': 'Night One',
      'venue_name': 'Club A',
      'organizer_name': 'Night Events',
      'current_version': 4,
      'active_version': 3,
      'can_accept': true,
      'versions': [
        {'version': 4, 'terms': {'capacity': 350}, 'proposed_by_side': 'organizer', 'organizer_accepted_at': '2026-10-09T20:00:00Z', 'organizer_accepted_by_name': 'Olive', 'is_active': false},
        {'version': 3, 'terms': {'capacity': 400}, 'proposed_by_side': 'venue', 'organizer_accepted_at': '2026-10-09T19:00:00Z', 'venue_accepted_at': '2026-10-09T18:00:00Z', 'is_active': true},
      ],
      'notes': [
        {'side': 'venue', 'version': 2, 'body': 'Can we move the threshold?', 'author_name': 'Mia', 'is_mine': true, 'created_at': '2026-10-09T17:00:00Z'},
      ],
    })!;
    expect(d.latest!.version, 4);
    expect(d.previous!.version, 3);
    expect(d.active!.version, 3);
    expect(d.latest!.organizerAccepted, isTrue);
    expect(d.latest!.venueAccepted, isFalse);
    expect(d.previous!.bothAccepted, isTrue);
    expect(d.notes.single.isMine, isTrue);
    expect(parseAgreementDetail({'status': 'x'}), isNull);
    expect(parseAgreementRow({'event_title': 'x'}), isNull);
  });
}
