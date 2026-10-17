import 'package:bottles_up_vendor/features/vip/logic/vip_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading what the database sends', () {
    test('a list row, a profile and a lookup result', () {
      final m = parseVipMember({'member_id': 'm1', 'name': 'Ada', 'tier': 'Gold', 'status': 'active', 'host_name': 'Mia', 'perks': 3, 'last_visit': '2026-10-09', 'invited': true})!;
      expect(m.active, isTrue);
      expect(m.perks, 3);
      expect(m.invited, isTrue);
      final p = parseVipProfile({
        'member_id': 'm1',
        'name': 'Ada',
        'email': 'ada@example.com',
        'tier': 'Gold',
        'status': 'ended',
        'credential_code': 'ABCD1234',
        'ended_reason': 'asked to leave',
        'perks': [
          {'perk_id': 'k1', 'kind': 'entry', 'label': 'Priority entry', 'max_uses': 1, 'period': 'night', 'active': true, 'used': 1},
          {'perk_id': 'k2', 'kind': 'service', 'label': 'Welcome shot', 'active': false, 'used': 0},
          'junk',
        ],
        'visits': [
          {'night': '2026-10-09', 'perk': 'Priority entry', 'by_name': 'Dee', 'note': 'at the front'},
        ],
      })!;
      expect(p.ended, isTrue);
      expect(p.perks, hasLength(2));
      expect(p.perks.first.exhausted, isTrue);
      expect(p.perks.last.active, isFalse);
      expect(p.visits.single.byName, 'Dee');
      final l = parseVipLookup({'member_id': 'm1', 'name': 'Ada', 'status': 'active', 'perks': [], 'email': null})!;
      expect(l.email, isNull);
    });

    test('rows without an id are dropped', () {
      expect(parseVipMember({'name': 'x'}), isNull);
      expect(parseVipProfile({'name': 'x'}), isNull);
      expect(parseVipLookup({'name': 'x'}), isNull);
      expect(parseVipPerk({'label': 'x'}), isNull);
      expect(parseVipPerk('nope'), isNull);
    });
  });

  group('perks in words', () {
    test('usage reads as a sentence', () {
      const night = VipPerk(id: 'k', kind: 'entry', label: 'x', period: 'night', used: 1, maxUses: 1);
      expect(night.usage, '1 of 1 tonight');
      expect(night.exhausted, isTrue);
      const total = VipPerk(id: 'k', kind: 'discount', label: 'x', period: 'total', used: 2, maxUses: 3);
      expect(total.usage, '2 of 3 in total');
      expect(total.exhausted, isFalse);
      const none = VipPerk(id: 'k', kind: 'service', label: 'x', period: 'night', used: 9);
      expect(none.usage, 'No limit');
      expect(none.exhausted, isFalse);
    });

    test('statuses and kinds are worded', () {
      expect(vipStatusLabel('upcoming'), 'Not started yet');
      expect(vipStatusLabel('expired'), 'Expired');
      expect(perkKindLabel('discount'), 'Discount');
      expect(perkKindLabel('mystery'), 'mystery');
    });

    test('after redeeming the person is told what is left', () {
      expect(redeemMessage('Welcome shot', const RedeemOutcome(used: 1, maxUses: 3, usesLeft: 2)), 'Welcome shot recorded. 2 left.');
      expect(redeemMessage('Priority entry', const RedeemOutcome(used: 1, maxUses: 1, usesLeft: 0)), 'Priority entry recorded. No uses left.');
      expect(redeemMessage('Booth', const RedeemOutcome(used: 5)), 'Booth recorded.');
    });
  });

  group('what was typed', () {
    String? form({String name = 'Ada', String email = 'ada@example.com', String phone = '', String tier = 'Gold', DateTime? from, DateTime? until, String prefs = '', String notes = ''}) =>
        checkVipForm(name: name, email: email, phone: phone, tier: tier, validFrom: from, validUntil: until, preferences: prefs, notes: notes);

    test('a guest needs a name and a way to reach them', () {
      expect(form(), isNull);
      expect(form(name: ' '), 'Enter the guest\'s name.');
      expect(form(email: '', phone: ''), 'Enter an email or a phone number.');
      expect(form(email: '', phone: '+1 555 0100'), isNull);
      expect(form(email: 'not-an-email'), 'That does not look like an email address.');
      expect(form(email: '', phone: '123'), 'That phone number is too short.');
    });

    test('dates, tier and lengths', () {
      expect(form(from: DateTime(2026, 10, 5), until: DateTime(2026, 10, 1)), 'The end date is before the start date.');
      expect(form(from: DateTime(2026, 10, 1), until: DateTime(2026, 10, 1)), isNull);
      expect(form(tier: 'x'), 'The tier needs at least 2 characters.');
      expect(form(tier: ''), isNull);
      expect(form(prefs: 'x' * 301), 'Keep the service preferences to 300 characters or fewer.');
      expect(form(notes: 'x' * 501), 'Keep the notes to 500 characters or fewer.');
    });

    test('a perk needs a name and a sane limit', () {
      expect(checkPerkForm(label: ' ', maxText: '').error, 'Say what the perk is.');
      expect(checkPerkForm(label: 'Welcome shot', maxText: '').maxUses, isNull);
      expect(checkPerkForm(label: 'Welcome shot', maxText: '').error, isNull);
      expect(checkPerkForm(label: 'Welcome shot', maxText: '3').maxUses, 3);
      expect(checkPerkForm(label: 'Welcome shot', maxText: '0').error, isNotNull);
      expect(checkPerkForm(label: 'Welcome shot', maxText: '1001').error, isNotNull);
      expect(checkPerkForm(label: 'Welcome shot', maxText: 'many').error, isNotNull);
    });

    test('a search needs three letters', () {
      expect(checkVipSearch('ad'), 'Type at least 3 letters of the name, or the credential code.');
      expect(checkVipSearch(' ada '), isNull);
    });
  });
}
