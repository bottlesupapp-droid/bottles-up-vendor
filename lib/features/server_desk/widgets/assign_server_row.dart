import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../logic/server_desk_rules.dart';

/// What the manager chose in the picker: a server to give the table to, or nobody (take the server off).
class ServerChoice {
  const ServerChoice(this.membershipId);

  /// Null means "no server".
  final String? membershipId;
}

/// Shows the servers of the club and lets the manager pick one, or take the server off. Returns null if they back out.
typedef ServerPicker = Future<ServerChoice?> Function(BuildContext context, List<ServerOption> options, String? currentMembershipId);

Future<ServerChoice?> showServerPicker(BuildContext context, List<ServerOption> options, String? currentMembershipId) {
  return showModalBottomSheet<ServerChoice>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Who serves this table?', style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (options.isEmpty)
                const Text('There are no servers on the team yet. Invite one from the Team tab.', key: Key('picker-empty')),
              for (final o in options)
                ListTile(
                  key: Key('pick-${o.membershipId}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.label),
                  subtitle: o.starts ? const Text('Starts later') : null,
                  trailing: o.membershipId == currentMembershipId ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(sheet).pop(ServerChoice(o.membershipId)),
                ),
              if (currentMembershipId != null)
                ListTile(
                  key: const Key('pick-none'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Take the server off this table'),
                  onTap: () => Navigator.of(sheet).pop(const ServerChoice(null)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The "Server" line under a confirmed booking on the manager's list: who has the table, and a way to change it.
class AssignServerRow extends StatelessWidget {
  const AssignServerRow({
    super.key,
    required this.bookingId,
    required this.label,
    required this.unavailable,
    required this.canChange,
    required this.busy,
    required this.onChange,
  });

  final String bookingId;

  /// Who has it ("Sam"), or null when nobody does.
  final String? label;

  /// The person who has it can no longer serve it: shown in amber.
  final bool unavailable;

  /// False while the team is still loading or could not be loaded: there is nobody to choose from yet.
  final bool canChange;
  final bool busy;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = unavailable ? const Color(0xFFFFB300) : null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Ionicons.person_outline, size: 16, color: warn),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label == null ? 'No server yet' : 'Server: $label',
              key: Key('server-$bookingId'),
              style: theme.textTheme.bodyMedium?.copyWith(color: warn),
            ),
          ),
          TextButton(
            key: Key('assign-$bookingId'),
            onPressed: (busy || !canChange) ? null : onChange,
            child: Text(label == null ? 'Give to a server' : 'Change'),
          ),
        ],
      ),
    );
  }
}
