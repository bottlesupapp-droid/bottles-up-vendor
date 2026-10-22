import 'dart:io';

import 'package:bottles_up_vendor/features/owner/logic/owner_rules.dart' show defaultSiteUrl;
import 'package:bottles_up_vendor/features/team/logic/team_rules.dart' show invitationLink;
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:flutter_test/flutter_test.dart';

// An invitation link in the email opens this app, not only the website, once the site and the app vouch for each other (docs/APP_LINKS_SETUP.md in the monorepo). The app's side of that is the
// Android intent filter; these tests keep it in step with the link the app itself writes and the route the router answers.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  String? filterWith(String needle) {
    for (final m in RegExp(r'<intent-filter[\s\S]*?</intent-filter>').allMatches(manifest)) {
      if (m.group(0)!.contains(needle)) return m.group(0);
    }
    return null;
  }

  test('the app link filter is for the address the invitation emails use, and for nothing else', () {
    final filter = filterWith('BROWSABLE')!;
    final site = Uri.parse(defaultSiteUrl);
    expect(filter, contains('android:autoVerify="true"'));
    expect(filter, contains('android.intent.action.VIEW'));
    expect(filter, contains('android.intent.category.DEFAULT'));
    expect(RegExp(r'<data ([^>]*)/>').allMatches(filter).length, 1, reason: 'one address only');
    expect(filter, contains('android:scheme="${site.scheme}"'));
    expect(filter, contains('android:host="${site.host}"'));
    expect(filter, contains('android:pathPrefix="${WorkspaceRoutes.acceptInvite}"'));
  });

  test('the link the app writes into an invitation is one the filter opens', () {
    final link = Uri.parse(invitationLink(defaultSiteUrl, 'a' * 40));
    final site = Uri.parse(defaultSiteUrl);
    expect(link.scheme, site.scheme);
    expect(link.host, site.host);
    expect(link.path, startsWith(WorkspaceRoutes.acceptInvite));
    expect(link.queryParameters['token'], 'a' * 40);
  });

  test('the launcher entry is still there, and the filter did not open the app to any other address', () {
    expect(filterWith('android.intent.category.LAUNCHER'), contains('android.intent.action.MAIN'));
    expect('android:scheme='.allMatches(manifest).length, 1, reason: 'the only web address the app answers to is the invitation page');
    expect(manifest, isNot(contains('flutter_deeplinking_enabled')), reason: 'Flutter hands links to the router by default; nothing turns that off');
  });
}
