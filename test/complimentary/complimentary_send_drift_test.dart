import 'dart:io';

import 'package:bottles_up_vendor/features/complimentary/logic/complimentary_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_offers_backend.dart';

// The database and the edge function decide every name, state, limit and sentence about sending a link; the app must not drift from them. These read the website's files when they are checked out
// beside this app (the monorepo) and are skipped otherwise.
void main() {
  final website = Directory('../bottles-up-website-main');
  final migration = File('${website.path}/supabase/migrations/20261124100000_complimentary_send.sql');
  final logic = File('${website.path}/supabase/functions/_shared/compOffer.ts');
  final entry = File('${website.path}/supabase/functions/send-complimentary-offer/index.ts');
  const why = 'website repo is not checked out next to this app (or lacks the send migration)';
  final present = migration.existsSync() && logic.existsSync() && entry.existsSync();

  group('agrees with the website', () {
    String sql() => migration.readAsStringSync();
    String ts() => logic.readAsStringSync();

    String fn(String name) {
      final s = sql();
      final start = s.indexOf('create function public.$name(');
      expect(start, isNot(-1), reason: 'function $name is in the website\'s migration');
      return s.substring(start, s.indexOf('\n\$\$;', start));
    }

    test('the app calls the function that lists the attempts, with its own parameter', () async {
      final db = FakeOffersBackend();
      await db.service.sends('o1');
      expect(db.paramsOf('comp_offer_sends').single!.keys.toList(), ['p_offer']);
      expect(fn('comp_offer_sends'), contains('comp_offer_sends(p_offer uuid)'));
    }, skip: present ? false : why);

    test('the log has exactly the columns the app reads', () {
      final m = RegExp(r'returns table \(([\s\S]*?)\)\s*language').firstMatch(fn('comp_offer_sends'))!;
      final columns = [for (final c in m.group(1)!.split(',')) c.trim().split(RegExp(r'\s+')).first]..sort();
      expect(columns, ['created_at', 'failure', 'finished_at', 'first_send', 'id', 'mine', 'status', 'to_email']);
      final parsed = parseOfferSend({for (final c in columns) c: sendRow()[c]});
      expect(parsed, isNotNull);
    }, skip: present ? false : why);

    test('the statuses and the reasons are the ones the app words', () {
      final all = sql();
      expect(all, contains("check (status in ('pending', 'sent', 'failed'))"));
      expect(all, contains("check (failure is null or failure in ('not_configured', 'send_failed'))"));
      expect(sendLine(parseOfferSend(sendRow(status: 'failed', failure: 'not_configured'))!), contains('not set up'));
      expect(sendLine(parseOfferSend(sendRow(status: 'failed', failure: 'send_failed'))!), contains('send it again'));
    }, skip: present ? false : why);

    test('the link can be sent in the same states the database allows', () {
      final m = RegExp(r"v_state not in \(([^)]*)\)").firstMatch(fn('comp_offer_send_begin'))!;
      final states = {for (final s in m.group(1)!.split(',')) s.trim().replaceAll("'", '')};
      expect(states, {'approved', 'sent', 'awaiting_location'});
      for (final status in ['approved', 'sent', 'awaiting_location', 'location_submitted', 'accepted', 'delivered', 'expired', 'cancelled']) {
        expect(canSendLink(parseOfferRow(offerRow(status: status))!), states.contains(status), reason: status);
      }
    }, skip: present ? false : why);

    test('the function reads the offer id by the name the app sends, and answers with the keys the app reads', () {
      expect(ts(), contains('.offerId'));
      expect(ts(), contains('body: { sent: true }'));
      expect(ts(), contains('body: { sent: false, reason }'));
      expect(ts(), contains("'not_configured'"));
      expect(ts(), contains("'send_failed'"));
    }, skip: present ? false : why);

    test('the sentences the app falls back on are the function\'s own', () {
      expect(ts(), contains('You cannot send this link.'));
      expect(ts(), contains('Sign in again to send this link.'));
    }, skip: present ? false : why);

    test('the limits the function reports are the database\'s sentences', () {
      final all = sql();
      expect(all, contains('this link was sent 5 times in the last day: wait before sending it again'));
      expect(all, contains('you have sent a lot of links this hour: wait before sending another'));
      expect(ts(), contains('sent 5 times|sent a lot of links'));
    }, skip: present ? false : why);
  });
}
