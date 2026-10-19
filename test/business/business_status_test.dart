import 'dart:io';

import 'package:bottles_up_vendor/features/business/logic/business_status.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row({String state = 'under_review', String org = 'o1', String kind = 'venue_owner', Object? missing, String? message}) => {
      'org_id': org,
      'org_name': 'Club Co',
      'org_kind': kind,
      'role': 'owner',
      'verification_state': state,
      'request_message': message,
      'missing': missing ?? <String>[],
      'venue_count': 2,
      'pending_claims': 1,
    };

void main() {
  group('reading what the database says', () {
    test('every state the database knows', () {
      for (final s in VerificationState.values) {
        expect(parseBusinessStatus(row(state: s.db))!.state, s);
      }
    });

    test('a state this app does not know is not shown as anything else', () {
      expect(parseBusinessStatus(row(state: 'suspended')), isNull);
      expect(parseBusinessStatus(row(state: '')), isNull);
    });

    test('a row without an id is dropped', () {
      expect(parseBusinessStatus({...row(), 'org_id': null}), isNull);
      expect(parseBusinessStatus({...row(), 'org_id': ''}), isNull);
    });

    test('the fields come through, counts as numbers or text, a blank reviewer message as none', () {
      final b = parseBusinessStatus({...row(state: 'more_information_needed', missing: ['address', 'venue'], message: '  Please add your licence number  '), 'venue_count': '3'})!;
      expect(b.name, 'Club Co');
      expect(b.kind, 'venue_owner');
      expect(b.requestMessage, 'Please add your licence number');
      expect(b.missing, ['address', 'venue']);
      expect(b.venueCount, 3);
      expect(b.pendingClaims, 1);
      expect(parseBusinessStatus(row(message: '   '))!.requestMessage, isNull);
      expect(parseBusinessStatus(row(missing: 'not a list'))!.missing, isEmpty);
    });

    test('statusFor picks the business of the workspace and nothing else', () {
      final a = parseBusinessStatus(row(org: 'o1'))!;
      final b = parseBusinessStatus(row(org: 'o2'))!;
      expect(statusFor([a, b], 'o2'), b);
      expect(statusFor([a, b], 'o3'), isNull);
      expect(statusFor(const [], 'o1'), isNull);
    });
  });

  group('what it says', () {
    test('only a verified business is cleared, and nobody is stopped from drafting', () {
      expect([for (final s in VerificationState.values) s.cleared], [false, false, false, true]);
      expect(VerificationState.values.every((s) => s.canDraft), isTrue);
    });

    test('the card is shown until the business is verified, and never for a business we know nothing about', () {
      expect(showsStatusCard(null), isFalse);
      expect(showsStatusCard(parseBusinessStatus(row(state: 'verified'))), isFalse);
      for (final s in ['not_submitted', 'under_review', 'more_information_needed']) {
        expect(showsStatusCard(parseBusinessStatus(row(state: s))), isTrue, reason: s);
      }
    });

    test('what a venue owner and an organizer can do now, and what waits', () {
      final owner = whatYouCanDo(parseBusinessStatus(row())!);
      expect(owner.can.first, contains('Set up your venues'));
      expect(owner.waits, ['Taking a venue live']);
      final organizer = whatYouCanDo(parseBusinessStatus(row(kind: 'organizer'))!);
      expect(organizer.can.first, contains('event drafts'));
      expect(organizer.waits, ['Publishing an event']);
      expect(whatYouCanDo(parseBusinessStatus(row(state: 'verified'))!).waits, isEmpty);
    });

    test('missing keys become the website\'s messages, and an unknown key is shown, not hidden', () {
      expect(describeMissing(['legal_name', 'venue']), ['Add your legal business name', 'Add a venue, or ask to claim one that already exists']);
      expect(describeMissing(['tax_number']), ['Complete: tax number']);
    });
  });

  group('the same words as the website (checked when the website is beside this app)', () {
    final file = File('../bottles-up-website-main/src/lib/verification.ts');

    test('state labels and summaries', () {
      if (!file.existsSync()) return;
      final ts = file.readAsStringSync();
      for (final s in VerificationState.values) {
        expect(ts, contains("label: '${s.label}'"), reason: s.db);
        expect(ts, contains("summary: '${s.summary}'"), reason: s.db);
        expect(ts, contains("'${s.db}'"), reason: s.db);
      }
    });

    test('the messages for what is missing', () {
      if (!file.existsSync()) return;
      final ts = file.readAsStringSync();
      for (final e in missingMessages.entries) {
        expect(ts, contains(e.value), reason: e.key);
        expect(ts, contains('${e.key}:'), reason: e.key);
      }
    });

    test('the states are the database\'s own constraint', () {
      final sql = File('../bottles-up-website-main/supabase/migrations/20261007100000_accounts_onboarding.sql');
      if (!sql.existsSync()) return;
      final text = sql.readAsStringSync();
      for (final s in VerificationState.values) {
        expect(text, contains("'${s.db}'"), reason: s.db);
      }
    });
  });
}
