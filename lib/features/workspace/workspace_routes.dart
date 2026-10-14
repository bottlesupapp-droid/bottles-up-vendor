import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../owner/screens/venue_detail_screen.dart';
import 'screens/workspace_section_screen.dart';
import 'widgets/workspace_shell.dart';

/// Everything that lives inside a workspace's shell: the role's tabs, and an owner's pages for one venue. One definition, used by
/// the app's router and by the tests, so a test of a route is a test of the real one.
ShellRoute workspaceShellRoute() => ShellRoute(
      builder: (context, state, child) => WorkspaceShell(
        membershipId: state.uri.pathSegments.length > 1 ? state.uri.pathSegments[1] : '',
        child: child,
      ),
      routes: [
        // An owner's page for one venue. Pushed on top of the Venues tab, so the back button returns to the list.
        GoRoute(
          path: '/w/:membershipId/venues/:venueId',
          name: 'workspaceVenue',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: VenueDetailScreen(
              membershipId: state.pathParameters['membershipId']!,
              venueId: state.pathParameters['venueId']!,
            ),
          ),
        ),
        GoRoute(
          path: '/w/:membershipId/:section',
          name: 'workspaceSection',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: WorkspaceSectionScreen(
              membershipId: state.pathParameters['membershipId']!,
              sectionId: state.pathParameters['section']!,
            ),
          ),
        ),
      ],
    );
