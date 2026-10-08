import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  ScanOutcome? _outcome;
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
      paused: _outcome != null,
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
    final outcome = await ref.read(doorServiceProvider).scan(code, event.eventId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
      _ticket = code;
    });
    _afterAnswer(outcome);
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
    _afterAnswer(outcome);
  }

  void _afterAnswer(ScanOutcome outcome) {
    // A short vibration confirms the answer without looking at the screen.
    HapticFeedback.mediumImpact();
    // Someone was admitted: the count of guests in must be read again, not guessed.
    if (outcome.admitted) ref.invalidate(doorEventsProvider(widget.membershipId));
  }

  void _next() {
    setState(() {
      _outcome = null;
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        DoorEventBar(
          events: events,
          selected: event,
          onSelect: (id) {
            ref.read(selectedDoorEventProvider(widget.membershipId).notifier).state = id;
            // An answer belongs to the event it was checked against.
            _next();
          },
        ),
        const SizedBox(height: 16),
        if (_outcome != null) ...[
          ScanResultPanel(outcome: _outcome!, verifying: _verifying, onVerify: (c) => _verify(c, event), onNext: _next),
          const SizedBox(height: 16),
        ],
        if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(key: Key('checking'))),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(key: const Key('camera-area'), height: 260, child: camera),
        ),
        const SizedBox(height: 16),
        Text('Or type the ticket code', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('manual-code-field'),
                controller: _manual,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'Ticket code', border: OutlineInputBorder()),
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
