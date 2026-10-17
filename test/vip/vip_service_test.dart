import 'package:bottles_up_vendor/features/ops/services/ops_rpc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_vip_backend.dart';

void main() {
  late FakeVipBackend db;
  setUp(() {
    db = FakeVipBackend();
    db.members.add(FakeVip('m1', 'Ada Lovelace', email: 'ada@example.com', tier: 'Gold', host: 'Mia Manager', preferences: 'still water', notes: 'allergic to nuts')
      ..perks.addAll([FakePerk('k1', 'entry', 'Priority entry', max: 1), FakePerk('k2', 'service', 'Welcome shot', max: 1), FakePerk('k3', 'discount', '10 percent off', max: 3, period: 'total')]));
  });

  Future<void> expectRefusal(Future<Object?> f, String message) =>
      expectLater(f, throwsA(isA<OpsActionException>().having((e) => e.message, 'message', message)));

  test('the list is asked for with the search and whether to include ended ones', () async {
    final list = await db.service.list('v1', search: ' ada ', includeEnded: true, night: '2026-10-09');
    expect(db.calledWith('vip_list').single, {'p_venue': 'v1', 'p_search': 'ada', 'p_include_ended': true, 'p_night': '2026-10-09'});
    expect(list.single.name, 'Ada Lovelace');
    await db.service.list('v1');
    expect(db.calledWith('vip_list').last['p_search'], isNull);
  });

  test('adding sends what was filled in and gets an id; refusals are the database\'s words', () async {
    final id = await db.service.add('v1', {'name': 'Bob Barlow', 'phone': '+1 555 0100'});
    expect(db.member(id).name, 'Bob Barlow');
    await expectRefusal(db.service.add('v1', {'name': 'Zed'}), 'Enter an email or a phone number.');
    await expectRefusal(db.service.add('v1', {'email': 'z@example.com'}), "Enter the guest's name.");
    db.role = 'server';
    await expectRefusal(db.service.add('v1', {'name': 'Zed', 'email': 'z@example.com'}), "You don't have access to do that.");
  });

  test('changing leaves out what is not mentioned and clears what is null', () async {
    await db.service.update('m1', {'tier': 'Platinum', 'host': null});
    expect(db.member('m1').tier, 'Platinum');
    expect(db.member('m1').host, isNull);
    expect(db.member('m1').preferences, 'still water');
    await expectRefusal(db.service.update('m1', {'email': null}), 'Enter an email or a phone number.');
  });

  test('a membership ends with a reason, once, and can be reinstated', () async {
    await expectRefusal(db.service.end('m1', ' '), 'Say why the membership is ending.');
    await db.service.end('m1', '  asked to leave ');
    expect(db.calledWith('vip_end').last['p_reason'], 'asked to leave');
    await expectRefusal(db.service.end('m1', 'again'), 'This membership has already ended.');
    await db.service.reinstate('m1');
    await expectRefusal(db.service.reinstate('m1'), 'This membership has not ended.');
  });

  test('perks are added with a limit and period, and ended once', () async {
    await db.service.addPerk('m1', 'service', ' Reserved booth ', maxUses: 2, period: 'total');
    expect(db.calledWith('vip_add_perk').single, {'p_member': 'm1', 'p_kind': 'service', 'p_label': 'Reserved booth', 'p_max_uses': 2, 'p_period': 'total'});
    await expectRefusal(db.service.addPerk('m1', 'free', 'Anything'), 'Choose entry, service or discount.');
    await db.service.endPerk('k1');
    await expectRefusal(db.service.endPerk('k1'), 'This perk has already ended.');
  });

  test('the invitation is queued, once at a time', () async {
    await db.service.invite('m1');
    await expectRefusal(db.service.invite('m1'), 'An invitation was queued a moment ago.');
    db.members.add(FakeVip('m2', 'Bob', phone: '+1 555 0100'));
    await expectRefusal(db.service.invite('m2'), 'This guest has no email address to invite.');
  });

  test('a lookup shows each role only what it may see', () async {
    var r = (await db.service.lookup('v1', 'ada')).single;
    expect((r.email, r.notes, r.preferences), ('ada@example.com', 'allergic to nuts', 'still water'));
    expect(r.perks.map((p) => p.label), ['Priority entry', 'Welcome shot', '10 percent off']);
    db.role = 'server';
    r = (await db.service.lookup('v1', 'ada')).single;
    expect((r.email, r.notes, r.preferences), (null, null, 'still water'));
    expect(r.perks.map((p) => p.label), ['Welcome shot']);
    db.role = 'door';
    r = (await db.service.lookup('v1', 'ada')).single;
    expect((r.email, r.notes, r.preferences), (null, null, null));
    expect(r.perks.map((p) => p.label), ['Priority entry']);
    db.role = 'security';
    await expectRefusal(db.service.lookup('v1', 'ada'), "You don't have access to do that.");
    db.role = 'server';
    await expectRefusal(db.service.lookup('v1', 'ad'), 'Type at least 3 letters of the name, or the credential code.');
  });

  test('redeeming sends the night, counts, and refuses past the limit', () async {
    final o = await db.service.redeem('k2', night: '2026-10-09', note: ' at the booth ');
    expect(db.calledWith('vip_redeem').single, {'p_perk': 'k2', 'p_night': '2026-10-09', 'p_note': 'at the booth'});
    expect((o.used, o.maxUses, o.usesLeft), (1, 1, 0));
    await expectRefusal(db.service.redeem('k2'), 'This benefit has already been used 1 of 1 tonight.');
    db.role = 'door';
    await expectRefusal(db.service.redeem('k3'), "You don't have access to do that.");
    db.member('m1').status = 'expired';
    await expectRefusal(db.service.redeem('k1'), 'This membership is not active (expired).');
  });

  test('a backend without VIP says it is not available yet; a dropped connection says to try again', () async {
    db.missing = true;
    await expectLater(db.service.list('v1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isTrue)));
    db.missing = false;
    db.offline = true;
    await expectLater(db.service.detail('m1'), throwsA(isA<OpsLoadException>().having((e) => e.unavailable, 'unavailable', isFalse)));
    await expectRefusal(db.service.lookup('v1', 'ada'), 'The search could not be done. Check your connection and try again.');
  });
}
