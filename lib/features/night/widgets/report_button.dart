import 'package:flutter/material.dart';

import '../screens/report_screen.dart';

/// Opens the nightly report for a club, for the night shown. What it contains depends on the person's role; the database decides.
class ReportButton extends StatelessWidget {
  const ReportButton({super.key, required this.venueId, this.venueName, this.emailOrgId, this.night, this.clock = DateTime.now, this.label = 'Nightly report'});

  final String venueId;
  final String? venueName;

  /// The business of this club, when the person may e-mail the report from its page (the owner and the manager).
  final String? emailOrgId;
  final String? night;
  final DateTime Function() clock;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('report-open'),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Report')),
          body: SafeArea(child: ReportScreen(venueId: venueId, venueName: venueName, emailOrgId: emailOrgId, initialNight: night, clock: clock)),
        ),
      )),
      icon: const Icon(Icons.description_outlined, size: 18),
      label: Text(label),
    );
  }
}
