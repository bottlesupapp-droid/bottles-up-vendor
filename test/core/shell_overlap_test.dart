
import 'package:bottles_up_vendor/core/ui/glass_kit.dart';
import 'package:bottles_up_vendor/features/workspace/logic/workspace_routing.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace.dart';
import 'package:bottles_up_vendor/features/workspace/models/workspace_role.dart';
import 'package:bottles_up_vendor/features/workspace/providers/workspace_providers.dart';
import 'package:bottles_up_vendor/features/workspace/widgets/workspace_shell.dart';
import 'package:bottles_up_vendor/shared/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The floating bottom bar used to sit on top of the page it frames: the last line of a long list, the "Delete Account" button, an "Add Venue" button could all end up underneath it. These put a long page
// and a button inside each of the two frames, on a phone with a home-indicator strip (34 points), and check with real positions that nothing the person has to read or press is under the bar.
const _ws = Workspace(membershipId: 'm1', orgId: 'o1', orgName: 'Club Co', orgKind: 'venue_owner', role: WorkspaceRole.owner);

/// A page like the app's own: a Scaffold of its own, a list with its own padding (so it adds nothing for the bar by itself), and an extended button.
class _LongPage extends StatelessWidget {
  const _LongPage({this.fab = true});

  final bool fab;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < 40; i++) ListTile(title: Text('Row $i')),
            const Text('THE LAST LINE', key: Key('last-line')),
          ],
        ),
        floatingActionButton: fab ? FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add Venue')) : null,
      );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);
}

Future<void> _mainShell(WidgetTester tester, Widget page) async {
  _phone(tester);
  final router = GoRouter(initialLocation: '/clubs', routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [GoRoute(path: '/clubs', builder: (_, __) => page)],
    ),
  ]);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _workspaceShell(WidgetTester tester, Widget page) async {
  _phone(tester);
  final router = GoRouter(initialLocation: '/w/m1/home', routes: [
    ShellRoute(
      builder: (context, state, child) => WorkspaceShell(membershipId: 'm1', child: child),
      routes: [GoRoute(path: '/w/:membershipId/:section', builder: (_, __) => page)],
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [workspaceSnapshotProvider.overrideWith((ref) async => WorkspaceSnapshot.ready(const [_ws]))],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

double _barTop(WidgetTester tester) => tester.getRect(find.byType(GlassBottomNavBar)).top;

Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -20000));
  await tester.pumpAndSettle();
}

void main() {
  final frames = <String, Future<void> Function(WidgetTester, Widget)>{
    'the classic frame (Dashboard, Events, Analytics, Venues, More)': _mainShell,
    'the workspace frame (every role)': _workspaceShell,
  };

  frames.forEach((name, open) {
    group(name, () {
      testWidgets('the bar is at the bottom of the screen, above the home-indicator strip', (tester) async {
        await open(tester, const _LongPage());
        final bar = tester.getRect(find.byType(GlassBottomNavBar));
        expect(bar.bottom, closeTo(852, 0.5));
        expect(tester.getRect(find.byType(GlassBottomNavBar)).top, lessThan(852 - 34));
      });

      testWidgets('at the end of a long page the last line is fully above the bar', (tester) async {
        await open(tester, const _LongPage(fab: false));
        await _scrollToEnd(tester);
        final last = tester.getRect(find.byKey(const Key('last-line')));
        expect(last.bottom, lessThanOrEqualTo(_barTop(tester)), reason: 'the last line is under the bar');
      });

      testWidgets('a floating "Add" button sits above the bar, never over it', (tester) async {
        await open(tester, const _LongPage());
        final fab = tester.getRect(find.byType(FloatingActionButton));
        expect(fab.bottom, lessThanOrEqualTo(_barTop(tester)), reason: 'the button overlaps the bar');
        expect(tester.getRect(find.text('Row 0')).top, greaterThan(0));
      });

      testWidgets('the button can be pressed: nothing covers its centre', (tester) async {
        var pressed = 0;
        await open(
          tester,
          Scaffold(
            body: const SizedBox.expand(),
            floatingActionButton: FloatingActionButton.extended(onPressed: () => pressed++, label: const Text('Add Venue')),
          ),
        );
        await tester.tap(find.text('Add Venue'));
        expect(pressed, 1);
      });

      testWidgets('a page that is shorter than the screen is not pushed off or squeezed by the bar', (tester) async {
        await open(tester, const Scaffold(body: Center(child: Text('Short page'))));
        final text = tester.getRect(find.text('Short page'));
        expect(text.bottom, lessThan(_barTop(tester)));
      });
    });
  });
}
