import 'package:bottles_up_vendor/features/business/logic/business_status.dart';
import 'package:bottles_up_vendor/features/business/providers/business_providers.dart';
import 'package:bottles_up_vendor/features/business/services/business_service.dart';
import 'package:bottles_up_vendor/features/business/widgets/business_status_card.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> rows = [];
Object? failure;
final opened = <Uri>[];
var openResult = true;

Map<String, dynamic> biz(String state, {String org = 'o1', String kind = 'venue_owner', List<String> missing = const [], String? message}) => {
      'org_id': org, 'org_name': 'Club Co', 'org_kind': kind, 'role': 'owner', 'verification_state': state,
      'request_message': message, 'missing': missing, 'venue_count': 1, 'pending_claims': 0,
    };

Widget host({String org = 'o1'}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        businessServiceProvider.overrideWithValue(BusinessService(caller: (fn, {params}) async {
          if (failure != null) throw failure!;
          expect(fn, 'my_businesses');
          return rows;
        })),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return openResult;
        }),
      ],
      child: MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: SingleChildScrollView(child: BusinessStatusCard(orgId: org, site: 'https://site.example/')))),
    );

Future<void> open(WidgetTester tester, {String org = 'o1'}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host(org: org));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    rows = [];
    failure = null;
    opened.clear();
    openResult = true;
  });

  testWidgets('not submitted: says so, lists what is missing, and what can be done meanwhile', (tester) async {
    rows = [biz('not_submitted', missing: ['legal_name', 'venue'])];
    await open(tester);
    expect(find.byKey(const Key('business-status-card')), findsOneWidget);
    expect(find.text('Not submitted'), findsOneWidget);
    expect(find.text(VerificationState.notSubmitted.summary), findsOneWidget);
    expect(find.text('• Add your legal business name'), findsOneWidget);
    expect(find.text('• Add a venue, or ask to claim one that already exists'), findsOneWidget);
    expect(find.textContaining('Set up your venues'), findsOneWidget);
    expect(find.text('… Taking a venue live waits until the business is verified'), findsOneWidget);
  });

  testWidgets('under review: you can keep setting up; no list of things to do', (tester) async {
    rows = [biz('under_review')];
    await open(tester);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.text(VerificationState.underReview.summary), findsOneWidget);
    expect(find.textContaining('Still to do'), findsNothing);
    expect(find.text('See progress on the website'), findsOneWidget);
  });

  testWidgets('under review, nothing is asked of the business even if the database lists things still missing', (tester) async {
    rows = [biz('under_review', missing: ['legal_name'])];
    await open(tester);
    expect(find.textContaining('Still to do'), findsNothing);
    expect(find.text('• Add your legal business name'), findsNothing);
  });

  testWidgets('more information needed: shows the reviewer\'s own request', (tester) async {
    rows = [biz('more_information_needed', message: 'Please add your licence number')];
    await open(tester);
    expect(find.text('More information needed'), findsOneWidget);
    expect(find.text('From the reviewer: Please add your licence number'), findsOneWidget);
    expect(find.text('Open business details on the website'), findsOneWidget);
  });

  testWidgets('an organizer is told publishing an EVENT waits', (tester) async {
    rows = [biz('under_review', kind: 'organizer')];
    await open(tester);
    expect(find.text('… Publishing an event waits until the business is verified'), findsOneWidget);
    expect(find.textContaining('event drafts'), findsOneWidget);
  });

  testWidgets('a verified business has no card', (tester) async {
    rows = [biz('verified')];
    await open(tester);
    expect(find.byKey(const Key('business-status-card')), findsNothing);
  });

  testWidgets('another business of the same person is not mixed up', (tester) async {
    rows = [biz('under_review', org: 'o2')];
    await open(tester, org: 'o1');
    expect(find.byKey(const Key('business-status-card')), findsNothing);
    await open(tester, org: 'o2');
    expect(find.byKey(const Key('business-status-card')), findsOneWidget);
  });

  testWidgets('if the state cannot be read, nothing is said (never "verified" or "not submitted" by guess)', (tester) async {
    failure = StateError('relation "site_verifications" does not exist');
    await open(tester);
    expect(find.byKey(const Key('business-status-card')), findsNothing);
    expect(find.textContaining('relation'), findsNothing);
  });

  testWidgets('the button opens this business\'s page on the website', (tester) async {
    rows = [biz('not_submitted')];
    await open(tester);
    await tester.tap(find.byKey(const Key('business-status-open')));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://site.example/business/o1/onboarding');
  });

  testWidgets('if it cannot be opened the person is told the address', (tester) async {
    rows = [biz('not_submitted')];
    openResult = false;
    await open(tester);
    await tester.tap(find.byKey(const Key('business-status-open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open the website'), findsOneWidget);
    expect(find.textContaining('https://site.example/business/o1/onboarding'), findsOneWidget);
  });
}
