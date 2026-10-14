import 'dart:io';

import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart';
import 'package:flutter_test/flutter_test.dart';

SetupStep step(String name, SetupStatus status, {bool required = true, String? detail}) =>
    SetupStep(step: name, status: status, required: required, detail: detail);

void main() {
  group('venues', () {
    test('a my_venues row is read, with its business', () {
      final r = parseMyVenue({'venue_id': 'v1', 'venue_name': 'Club A', 'org_id': 'o1', 'status': 'published'})!;
      expect([r.venue.id, r.venue.name, r.venue.status, r.orgId], ['v1', 'Club A', 'published', 'o1']);
      expect(r.venue.isLive, isTrue);
    });

    test('a row without an id is dropped; a missing name or status is not invented as live', () {
      expect(parseMyVenue({'venue_name': 'x'}), isNull);
      expect(parseMyVenue({'venue_id': ''}), isNull);
      final r = parseMyVenue({'venue_id': 'v'})!;
      expect([r.venue.name, r.venue.status, r.venue.isLive, r.orgId], ['Venue', 'draft', false, '']);
    });

    test('only a published venue is live', () {
      expect(isLiveStatus('published'), isTrue);
      for (final s in ['draft', 'archived', '', 'Published', ' published']) {
        expect(isLiveStatus(s), isFalse, reason: '"$s"');
      }
      expect(statusWord('published'), 'Live');
      expect(statusWord('draft'), 'Draft');
    });

    test('details can be filled in without losing what is already known', () {
      const v = OrgVenue(id: 'v', name: 'Club A', status: 'draft');
      final d = v.withDetails(slug: 'club-a', address: '1 Main St');
      expect([d.id, d.name, d.status, d.slug, d.address], ['v', 'Club A', 'draft', 'club-a', '1 Main St']);
      expect(v.withDetails().slug, isNull);
    });

    test('a new venue\'s name is checked before it is sent', () {
      expect(validateVenueName('Club A'), isNull);
      expect(validateVenueName('  Club A  '), isNull);
      expect(validateVenueName(''), 'Give the venue a name.');
      expect(validateVenueName('   '), 'Give the venue a name.');
      expect(validateVenueName('x' * 120), isNull);
      expect(validateVenueName('x' * 121), 'The name must be 120 characters or fewer.');
    });
  });

  group('the setup checklist (a port of the website\'s)', () {
    final all = [
      step('profile', SetupStatus.todo),
      step('floor_plan', SetupStatus.todo),
      step('tables', SetupStatus.todo),
      step('bottles', SetupStatus.todo),
      step('booking_rules', SetupStatus.todo),
      step('team', SetupStatus.todo, required: false),
      step('payments', SetupStatus.unavailable, required: false),
      step('notifications', SetupStatus.unavailable, required: false),
    ];

    test('a new venue is 0% ready, with the first required step as the next action', () {
      final s = summarizeSetup(all);
      expect([s.requiredTotal, s.requiredDone, s.requiredTodo, s.percent, s.ready], [5, 0, 5, 0, false]);
      expect(s.nextStep?.step, 'profile');
    });

    test('counts only required steps: optional and unavailable ones never inflate or block readiness', () {
      final done = [for (final s in all) s.required ? step(s.step, SetupStatus.done) : s];
      final s = summarizeSetup(done);
      expect([s.requiredDone, s.percent, s.ready, s.nextStep], [5, 100, true, null]);
    });

    test('rounds the percentage to a whole number', () {
      expect(summarizeSetup([step('profile', SetupStatus.done), step('floor_plan', SetupStatus.todo), step('tables', SetupStatus.todo)]).percent, 33);
      expect(summarizeSetup([step('profile', SetupStatus.done), step('floor_plan', SetupStatus.done), step('tables', SetupStatus.todo)]).percent, 67, reason: 'rounded, not cut off');
    });

    test('points at the first to-do step in the checklist order, not the order received', () {
      final shuffled = [step('booking_rules', SetupStatus.todo), step('profile', SetupStatus.done), step('tables', SetupStatus.todo), step('floor_plan', SetupStatus.done)];
      expect(summarizeSetup(shuffled).nextStep?.step, 'tables');
    });

    test('measuring nothing is not "100% ready"', () {
      final empty = summarizeSetup(const []);
      expect([empty.requiredTotal, empty.percent, empty.ready, empty.nextStep], [0, 0, false, null]);
      expect(summarizeSetup([step('payments', SetupStatus.unavailable, required: false)]).ready, isFalse);
    });

    test('steps come in the brief\'s order, and one this app does not know is kept at the end in the order it arrived', () {
      final out = orderSteps([
        step('notifications', SetupStatus.unavailable, required: false),
        step('new_thing', SetupStatus.todo),
        step('profile', SetupStatus.done),
        step('another_new', SetupStatus.todo),
        step('team', SetupStatus.todo, required: false),
      ]);
      expect(out.map((s) => s.step), ['profile', 'team', 'notifications', 'new_thing', 'another_new']);
    });

    test('every step the database reports has a label and a description; an unknown one gets a readable label', () {
      for (final s in ['profile', 'floor_plan', 'tables', 'bottles', 'booking_rules', 'payments', 'team', 'notifications']) {
        expect(stepLabel(s), isNot(s), reason: s);
        expect(stepDescription(s).length, greaterThan(5), reason: s);
      }
      expect(stepLabel('some_new_step'), 'some new step');
      expect(stepDescription('some_new_step'), '');
    });

    test('a step\'s state in words; "coming soon" is never done or pending', () {
      expect(setupStatusLabel(SetupStatus.done), 'Done');
      expect(setupStatusLabel(SetupStatus.todo), 'To do');
      expect(setupStatusLabel(SetupStatus.unavailable), 'Coming soon');
    });

    test('a venue_setup_status row is read; a state it does not know is "to do", never "done"', () {
      final s = parseSetupStep({'step': 'tables', 'status': 'todo', 'required': true, 'detail': 'add a table type'})!;
      expect([s.step, s.status, s.required, s.detail], ['tables', SetupStatus.todo, true, 'add a table type']);
      expect(parseSetupStep({'step': 'x', 'status': 'finished', 'required': true})!.status, SetupStatus.todo);
      expect(parseSetupStep({'step': 'x', 'status': null})!.status, SetupStatus.todo);
      expect(parseSetupStep({'step': 'x', 'status': 'done', 'required': 'yes'})!.required, isFalse, reason: 'only a real true makes a step required');
      expect(parseSetupStep({'status': 'done'}), isNull);
      expect(parseSetupStep({'step': '', 'status': 'done'}), isNull);
    });
  });

  group('the booking link (a port of the website\'s)', () {
    test('uses the configured site only when it is a plain https address, keeping the origin', () {
      expect(siteOrigin('https://staging.bottlesupapp.com'), 'https://staging.bottlesupapp.com');
      expect(siteOrigin('  https://www.example.com  '), 'https://www.example.com');
      expect(siteOrigin('https://www.example.com/'), 'https://www.example.com');
      expect(siteOrigin('https://www.example.com/some/path?x=1#y'), 'https://www.example.com');
    });

    test('anything else falls back to the real site, so a typo cannot reach a printed QR code', () {
      for (final bad in [null, '', '   ', 'http://www.example.com', 'ftp://www.example.com', 'javascript:alert(1)', 'not a url', 'https://user:pass@www.example.com', 'https://localhost', '//www.example.com', 'www.example.com']) {
        expect(siteOrigin(bad), defaultSiteUrl, reason: '$bad');
      }
    });

    test('the link is built from the slug, or the id when there is no clean slug', () {
      const site = 'https://www.bottlesupapp.com';
      expect(bookingLink(site, id: 'a1b2', slug: 'club-noir'), 'https://www.bottlesupapp.com/venues/club-noir');
      for (final slug in [null, '', 'bad slug/../x', '-leading-dash']) {
        expect(bookingLink(site, id: 'a1b2', slug: slug), 'https://www.bottlesupapp.com/venues/a1b2', reason: '$slug');
      }
    });

    test('there is never a double slash, and nothing in an id can change the meaning of the address', () {
      expect(bookingLink('https://www.bottlesupapp.com/', id: 'x', slug: 'club'), 'https://www.bottlesupapp.com/venues/club');
      final link = bookingLink('https://www.bottlesupapp.com', id: 'a b?c#d');
      expect(link, 'https://www.bottlesupapp.com/venues/a%20b%3Fc%23d');
      final uri = Uri.parse(link);
      expect([uri.path, uri.query, uri.fragment], ['/venues/a%20b%3Fc%23d', '', '']);
    });

    test('says whether the link works yet', () {
      expect(linkNote('published'), 'Guests can book through this link now.');
      expect(linkNote('draft'), contains('starts working when the venue goes live'));
    });

    test('this build points at the real site unless told otherwise', () {
      expect(siteUrl, defaultSiteUrl);
    });
  });

  group('failed loads', () {
    test('say what is wrong, and "not set up" wins because retrying cannot fix a missing migration', () {
      expect(ownerLoadMessage(unavailable: true, accessEnded: false), contains('not set up on this server yet'));
      expect(ownerLoadMessage(unavailable: false, accessEnded: true), contains('access has ended'));
      expect(ownerLoadMessage(unavailable: false, accessEnded: false), contains('try again'));
      expect(ownerLoadMessage(unavailable: true, accessEnded: true), contains('not set up'));
    });
  });

  // The app must call the database by the names it defines and word things as the website does. These read the website repo's
  // files when it is checked out next to this app (the monorepo); on their own they are skipped.
  group('agrees with the website', () {
    final root = Directory('../bottles-up-website-main');
    final tenancy = File('${root.path}/supabase/migrations/20261006120000_tenancy_foundation.sql');
    final onboarding = File('${root.path}/supabase/migrations/20261007100000_accounts_onboarding.sql');
    final setupTs = File('${root.path}/src/lib/venueSetup.ts');
    final linkTs = File('${root.path}/src/lib/bookingLink.ts');
    const why = 'website repo is not checked out next to this app';

    test('the three functions are the ones the database defines, with these argument names', () {
      final t = tenancy.readAsStringSync();
      expect(t, contains('create function public.my_venues()'));
      expect(t, contains('returns table (venue_id uuid, venue_name text, org_id uuid, status text)'));
      expect(t, contains('create function public.create_org_venue(p_org uuid, p_name text)'));
      final o = onboarding.readAsStringSync();
      expect(o, contains('create function public.venue_setup_status(p_venue uuid)'));
      expect(o, contains('returns table (step text, status text, required boolean, detail text)'));
    }, skip: tenancy.existsSync() && onboarding.existsSync() ? false : why);

    test('every setup step the database reports is one this app words, in the same order, with the same text', () {
      final ts = setupTs.readAsStringSync();
      final re = RegExp(r"^\s{2}(\w+): \{ label: '([^']*)', description: '([^']*)' \},$", multiLine: true);
      final web = [for (final m in re.allMatches(ts)) (m.group(1)!, m.group(2)!, m.group(3)!)];
      expect(web.length, 8);
      final steps = [for (final (key, _, _) in web) step(key, SetupStatus.todo)];
      expect(orderSteps(steps.reversed.toList()).map((s) => s.step), web.map((w) => w.$1), reason: 'same order as the website');
      for (final (key, label, description) in web) {
        expect(stepLabel(key), label, reason: key);
        expect(stepDescription(key), description, reason: key);
      }
      final sql = onboarding.readAsStringSync();
      for (final (key, _, _) in web) {
        expect(sql, contains("step := '$key'"), reason: 'the database reports $key');
      }
    }, skip: setupTs.existsSync() && onboarding.existsSync() ? false : why);

    test('the default site, the slug rule and the live/draft sentences are the website\'s', () {
      final ts = linkTs.readAsStringSync();
      expect(ts, contains("DEFAULT_SITE_URL = '$defaultSiteUrl'"));
      expect(ts, contains('/^[a-z0-9][a-z0-9-]*\$/i'));
      expect(ts, contains("'Guests can book through this link now.'"));
      expect(ts, contains("'This link starts working when the venue goes live. Until then guests who open it will see a \"not found\" page.'"));
      expect(ts, contains("status === 'published'"));
    }, skip: linkTs.existsSync() ? false : why);
  });
}
