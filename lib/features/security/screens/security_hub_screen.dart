import 'package:flutter/material.dart';

import '../../workspace/models/workspace.dart';
import 'alerts_screen.dart';
import 'incidents_screen.dart';
import 'tasks_screen.dart';

/// Security for a manager (opened from More): the club's alerts, tasks and incident reports in one place.
class SecurityHubScreen extends StatelessWidget {
  const SecurityHubScreen({super.key, required this.workspace, this.clock = DateTime.now});

  final Workspace workspace;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            key: Key('security-tabs'),
            tabs: [Tab(text: 'Alerts'), Tab(text: 'Tasks'), Tab(text: 'Incidents')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                AlertsScreen(workspace: workspace, clock: clock),
                TasksScreen(workspace: workspace, clock: clock),
                IncidentsScreen(workspace: workspace, clock: clock),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
