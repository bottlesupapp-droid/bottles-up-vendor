import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../door/logic/door_rules.dart' show shouldProcessScan;
import '../../floor/logic/bookings_rules.dart' show currentNight;
import '../../ops/services/ops_rpc.dart';
import '../../ops/widgets/qr_camera_view.dart';
import '../../workspace/models/workspace.dart';
import '../logic/seating_rules.dart';
import '../providers/seating_providers.dart';
import '../widgets/seat_dialog.dart';

/// The server's Scan tab: the QR on a guest's booking, or the booking code or name typed in, checked against the tables given to this
/// person for the night. A scan finds one booking and seats it with one tap; a name can match several and then needs another detail
/// checked with the guest, so a name alone never seats the wrong table. Seating never marks anything paid or delivered.
class ServerScanScreen extends ConsumerStatefulWidget {
  const ServerScanScreen({super.key, required this.workspace, this.clock = DateTime.now, this.cameraBuilder});

  final Workspace workspace;
  final DateTime Function() clock;

  /// Replaced in tests, where there is no camera.
  final QrCameraBuilder? cameraBuilder;

  @override
  ConsumerState<ServerScanScreen> createState() => _ServerScanScreenState();
}

class _ServerScanScreenState extends ConsumerState<ServerScanScreen> {
  final _search = TextEditingController();
  bool _busy = false;
  String? _lastCode;
  DateTime? _lastAt;
  String? _problem;
  String? _message;
  List<BookingMatch> _matches = const [];

  String get _venueId => widget.workspace.venueId ?? '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _lookup(String raw, {required bool scanned}) async {
    final code = scanned ? normalizeBookingCode(raw) : raw.trim();
    final now = DateTime.now();
    if (!shouldProcessScan(code: code, busy: _busy, paused: false, lastCode: scanned ? _lastCode : null, lastAt: scanned ? _lastAt : null, now: now)) return;
    final problem = checkSearch(code);
    if (problem != null) {
      setState(() {
        _problem = problem;
        _message = null;
        _matches = const [];
      });
      return;
    }
    setState(() {
      _busy = true;
      _lastCode = code;
      _lastAt = now;
      _problem = null;
      _message = null;
    });
    List<BookingMatch> found;
    try {
      found = await ref.read(seatingServiceProvider).find(_venueId, currentNight(widget.clock()), code);
    } on OpsActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = e.message;
        _matches = const [];
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _matches = found;
      if (found.isEmpty) {
        _message = 'No booking found for you tonight. If the guest is at another server\'s table, ask your manager.';
      }
    });
    if (scanned && found.length == 1) await _open(found.first, viaScan: true);
  }

  Future<void> _open(BookingMatch m, {required bool viaScan}) async {
    final answer = await showSeatDialog(
      context,
      heading: m.customerName,
      detailLine: '${m.tableName} · ${m.guestCount} ${m.guestCount == 1 ? 'guest' : 'guests'}'
          '${m.startTime == null ? '' : ' · ${startLabel(m.startTime)}'}${m.code == null ? '' : ' · ${m.code}'}',
      manual: !viaScan,
      seated: m.seated,
      blockedNote: m.canSeat ? null : 'This table is not yours. Ask the manager.',
    );
    if (answer == null || !mounted) return;
    try {
      final outcome = await ref.read(seatingServiceProvider).seat(m.bookingId, manual: !viaScan, detail: answer.detail, estimateMinutes: answer.minutes);
      if (!mounted) return;
      setState(() {
        _matches = const [];
        _search.clear();
        _message = outcome.already
            ? '${m.customerName} was already seated. Nothing changed.'
            : '${m.customerName} is seated.${answer.minutes == null ? '' : ' Estimate: ${estimateLabel(answer.minutes!)}.'}'
                ' The guest\'s confirmation is queued.';
      });
      ref.invalidate(seatingStateProvider(m.bookingId));
      ref.invalidate(guestMessagesProvider(m.bookingId));
    } on OpsActionException catch (e) {
      if (!mounted) return;
      setState(() => _problem = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_venueId.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text('This workspace is not tied to a club, so there are no tables to scan for.', key: Key('scan-no-venue'), textAlign: TextAlign.center)),
      );
    }
    final camera = (widget.cameraBuilder ?? (c, onCode) => QrCameraView(onCode: onCode));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        Text('Scan', style: theme.textTheme.headlineSmall),
        Text('Scan the QR on the guest\'s booking to seat them.', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        SizedBox(height: 240, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: camera(context, (code) => _lookup(code, scanned: true)))),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('scan-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(labelText: 'Booking code or guest name', hintText: 'At least 3 letters'),
                onSubmitted: (v) => _lookup(v, scanned: false),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(key: const Key('scan-search-go'), onPressed: _busy ? null : () => _lookup(_search.text, scanned: false), child: const Text('Find')),
          ],
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
        if (_problem != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_problem!, key: const Key('scan-problem'), style: TextStyle(color: theme.colorScheme.error))),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, key: const Key('scan-message'))),
        for (final m in _matches)
          Card(
            key: Key('match-${m.bookingId}'),
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              title: Text(m.customerName),
              subtitle: Text('${m.tableName} · ${m.guestCount} ${m.guestCount == 1 ? 'guest' : 'guests'}'
                  '${m.startTime == null ? '' : ' · ${startLabel(m.startTime)}'}'
                  '${m.serverName == null || m.isMine ? '' : ' · ${m.serverName}\'s table'}'),
              trailing: m.seated ? const Chip(label: Text('Seated')) : const Icon(Icons.chevron_right),
              onTap: () => _open(m, viaScan: false),
            ),
          ),
      ],
    );
  }
}
