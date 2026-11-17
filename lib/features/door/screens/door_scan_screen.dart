import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../logic/door_rules.dart';
import '../providers/door_providers.dart';
import '../services/door_service.dart';
import '../widgets/door_event_bar.dart';
import '../widgets/door_message.dart';
import '../widgets/scan_result_panel.dart';

/// Builds the camera view. [onCode] must be called with every code the camera reads. Replaced in tests, where there is no camera.
typedef CameraBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

/// Scan (door role): the QR on a ticket, or the code typed in, checked against the selected event by the database.
///
/// Manual entry always sits under the camera, because a camera can be denied, dirty or missing; if it cannot start the
/// screen says why and carries on. The camera keeps running while an answer shows (the screen only stops acting on it), and
/// the same ticket held up again within five seconds is not counted twice.
class DoorScanScreen extends ConsumerStatefulWidget {
  const DoorScanScreen({super.key, required this.membershipId, this.cameraBuilder});

  final String membershipId;
  final CameraBuilder? cameraBuilder;

  @override
  ConsumerState<DoorScanScreen> createState() => _DoorScanScreenState();
}

class _DoorScanScreenState extends ConsumerState<DoorScanScreen> {
  MobileScannerController? _controller;
  final _manual = TextEditingController();

  bool _busy = false;
  bool _verifying = false;
  bool _admitting = false;
  ScanOutcome? _outcome;

  /// Exit mode (only offered while the event tracks exits): a scan records one guest leaving instead of admitting one.
  bool _exitMode = false;
  ExitOutcome? _exitOutcome;
  String? _ticket;
  String? _lastCode;
  DateTime? _lastAt;

  @override
  void dispose() {
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
  }

  Widget _defaultCamera(BuildContext context, ValueChanged<String> onCode) {
    final controller = _controller ??= MobileScannerController(formats: const [BarcodeFormat.qrCode]);
    return MobileScanner(
      controller: controller,
      onDetect: (capture) {
        for (final b in capture.barcodes) {
          final value = b.rawValue;
          if (value != null) {
            onCode(value);
            break;
          }
        }
      },
      errorBuilder: (context, error) {
        final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
        return _CameraProblem(
          text: denied
              ? 'Camera access is off. Allow it in Settings, or type the code below.'
              : 'The camera could not start. Type the code below.',
        );
      },
    );
  }

  Future<void> _process(String raw, DoorEvent event, {bool manual = false}) async {
    final code = normalizeScan(raw);
    final now = DateTime.now();
    if (!shouldProcessScan(
      code: code,
      busy: _busy,
      paused: _outcome != null || _exitOutcome != null,
      // Typing a code is deliberate: only a camera that keeps seeing the same ticket needs the cooldown.
      lastCode: manual ? null : _lastCode,
      lastAt: manual ? null : _lastAt,
      now: now,
    )) {
      return;
    }
    setState(() {
      _busy = true;
      _lastCode = code;
      _lastAt = now;
    });
    if (_exitMode && (ref.read(doorOccupancyProvider(event.eventId)).valueOrNull?.tracking ?? false)) {
      await _recordExit(code, event);
      return;
    }
    final outcome = await ref.read(doorServiceProvider).scan(code, event.eventId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
      _ticket = code;
    });
    _afterAnswer(outcome, event.eventId);
  }

  /// One guest of the ticket leaves. The count inside is read again afterwards, never guessed.
  Future<void> _recordExit(String code, DoorEvent event) async {
    final exit = await ref.read(doorServiceProvider).recordExit(code, event.eventId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _exitOutcome = exit;
      _ticket = code;
    });
    HapticFeedback.mediumImpact();
    ref.invalidate(doorOccupancyProvider(event.eventId));
  }

  /// Another guest of the same ticket is leaving.
  Future<void> _anotherExit(DoorEvent event) async {
    final ticket = _ticket;
    if (ticket == null || _busy) return;
    setState(() => _busy = true);
    await _recordExit(ticket, event);
  }

  Future<void> _verify(String entryCode, DoorEvent event) async {
    final ticket = _ticket;
    if (ticket == null || _verifying) return;
    setState(() => _verifying = true);
    final outcome = await ref.read(doorServiceProvider).verifyCode(ticket, entryCode, event.eventId);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _outcome = outcome;
    });
    _afterAnswer(outcome, event.eventId);
  }

  /// A group ticket: [count] of its guests are coming in now.
  Future<void> _admit(int count, DoorEvent event) async {
    final ticket = _ticket;
    if (ticket == null || _admitting) return;
    setState(() => _admitting = true);
    final outcome = await ref.read(doorServiceProvider).admit(ticket, count, event.eventId);
    if (!mounted) return;
    setState(() {
      _admitting = false;
      _outcome = outcome;
    });
    _afterAnswer(outcome, event.eventId);
  }

  /// More of a partly admitted group are at the door: the same ticket is asked about again, which answers how many are left.
  Future<void> _more(DoorEvent event) async {
    final ticket = _ticket;
    if (ticket == null || _admitting) return;
    setState(() => _admitting = true);
    final outcome = await ref.read(doorServiceProvider).scan(ticket, event.eventId);
    if (!mounted) return;
    setState(() {
      _admitting = false;
      _outcome = outcome;
    });
    _afterAnswer(outcome, event.eventId);
  }

  void _afterAnswer(ScanOutcome outcome, String eventId) {
    // A short vibration confirms the answer without looking at the screen.
    HapticFeedback.mediumImpact();
    // Someone was admitted: the count of guests in must be read again, not guessed.
    if (outcome.admitted) {
      ref.invalidate(doorEventsProvider(widget.membershipId));
      ref.invalidate(doorOccupancyProvider(eventId));
    }
  }

  void _next() {
    setState(() {
      _outcome = null;
      _exitOutcome = null;
      _ticket = null;
      _manual.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(doorEventsProvider(widget.membershipId));
    return events.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => DoorMessage(
        text: error is DoorLoadException ? error.message : doorLoadMessage(unavailable: false, accessEnded: false),
        onRetry: error is DoorLoadException && error.unavailable ? null : () => ref.invalidate(doorEventsProvider(widget.membershipId)),
      ),
      data: (list) {
        final event = resolveEvent(list, ref.watch(selectedDoorEventProvider(widget.membershipId)));
        if (event == null) {
          return DoorMessage(
            text: 'No event to scan for right now. An event appears here while it is running, from a day before it starts, and for three hours after it ends.',
            onRetry: () => ref.invalidate(doorEventsProvider(widget.membershipId)),
          );
        }
        return _body(list, event);
      },
    );
  }

  Widget _body(List<DoorEvent> events, DoorEvent event) {
    final theme = Theme.of(context);
    final camera = (widget.cameraBuilder ?? _defaultCamera)(context, (code) => _process(code, event));
    final occupancy = ref.watch(doorOccupancyProvider(event.eventId)).valueOrNull;
    final tracking = occupancy?.tracking ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.l, BuSpace.page, BuSpace.xl),
      children: [
        const BuPageHeader(eyebrow: 'Door', title: 'Scan'),
        const SizedBox(height: BuSpace.l),
        DoorEventBar(
          events: events,
          selected: event,
          occupancy: occupancy,
          onSelect: (id) {
            ref.read(selectedDoorEventProvider(widget.membershipId).notifier).state = id;
            // An answer belongs to the event it was checked against.
            _next();
          },
        ),
        const SizedBox(height: BuSpace.l),
        if (tracking) ...[
          SegmentedButton<bool>(
            key: const Key('door-mode'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Entry'), icon: Icon(Icons.login)),
              ButtonSegment(value: true, label: Text('Exit'), icon: Icon(Icons.logout)),
            ],
            selected: {_exitMode},
            onSelectionChanged: (s) {
              setState(() => _exitMode = s.first);
              _next();
            },
          ),
          const SizedBox(height: BuSpace.l),
        ],
        if (_exitOutcome != null) ...[
          _ExitPanel(outcome: _exitOutcome!, busy: _busy, onAnother: () => _anotherExit(event), onNext: _next),
          const SizedBox(height: BuSpace.l),
        ],
        if (_outcome != null) ...[
          ScanResultPanel(
            outcome: _outcome!,
            verifying: _verifying,
            onVerify: (c) => _verify(c, event),
            onNext: _next,
            admitting: _admitting,
            onAdmit: (n) => _admit(n, event),
            onMore: () => _more(event),
          ),
          const SizedBox(height: BuSpace.l),
        ],
        if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(key: Key('checking'))),
        ClipRRect(
          borderRadius: BorderRadius.circular(BuRadius.card),
          child: SizedBox(key: const Key('camera-area'), height: 260, child: camera),
        ),
        const SizedBox(height: BuSpace.xl),
        Text(_exitMode && tracking ? 'Or type the ticket code of the guest leaving' : 'Or type the ticket code', style: theme.textTheme.titleSmall),
        const SizedBox(height: BuSpace.s),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('manual-code-field'),
                controller: _manual,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'Ticket code'),
                onSubmitted: (v) => _process(v, event, manual: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('manual-check'),
              onPressed: _busy ? null : () => _process(_manual.text, event, manual: true),
              child: const Text('Check'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('camera-problem'),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      color: context.bu.panel2,
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}

/// The answer to recording an exit: what happened, and what to do next.
class _ExitPanel extends StatelessWidget {
  const _ExitPanel({required this.outcome, required this.busy, required this.onAnother, required this.onNext});

  final ExitOutcome outcome;
  final bool busy;
  final VoidCallback onAnother;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bu = context.bu;
    final copy = exitCopy(outcome);
    final color = switch (copy.tone) {
      Tone.ok => bu.green,
      Tone.warn => bu.amber,
      Tone.error => bu.red,
    };
    return BuCard(
      key: const Key('exit-panel'),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.label, key: const Key('exit-label'), style: theme.textTheme.headlineSmall?.copyWith(color: color)),
          if (outcome.customerName != null) Text(outcome.customerName!, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(copy.hint, key: const Key('exit-hint'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: BuSpace.m),
          Row(
            children: [
              if (outcome.recorded && (outcome.inside ?? 0) > 0) ...[
                Expanded(child: OutlinedButton(key: const Key('exit-another'), onPressed: busy ? null : onAnother, child: const Text('Another guest leaves'))),
                const SizedBox(width: 8),
              ],
              Expanded(child: FilledButton(key: const Key('exit-next'), onPressed: onNext, child: const Text('Scan next'))),
            ],
          ),
        ],
      ),
    );
  }
}
