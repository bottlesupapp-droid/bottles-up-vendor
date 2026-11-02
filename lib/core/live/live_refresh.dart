import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Whether screens look again by themselves at all. Off by default so tests and previews never start a timer; the app turns it on in main.dart (like the connection monitor).
final liveRefreshEnabledProvider = Provider<bool>((ref) => false);

/// How often a visible screen looks again. The brief asks for live floor status, order progress, payments, admission counts and requests; a short look every few seconds while the screen is in front is
/// how this app gets there (the tables are closed to realtime; every read is a database function).
final liveRefreshIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 20));

/// "Updated 7:15:04 PM", or what is true when the last look failed.
String liveStatusText({required DateTime? updated, required bool failed}) {
  final time = updated == null ? null : DateFormat('h:mm:ss a').format(updated);
  if (failed) return time == null ? "Couldn't refresh. Trying again." : "Couldn't refresh. Showing what was current at $time.";
  return time == null ? 'Updating…' : 'Updated $time';
}

/// Puts a one-line "Updated 7:15:04 PM" above a screen and looks again every [liveRefreshIntervalProvider] while the screen is the one in front and the app is open: it pauses when the app goes to the
/// background or another page covers it, and looks straight away when the app comes back. The screen keeps showing what it has while it looks (give its list `keepWhileReloading`), and if a look
/// fails the line says so and keeps the time of the last good one: nothing is shown as current that is not.
///
/// [refresh] invalidates the screen's providers. [watching] are the same providers, only so the line knows when data arrived and when a look failed.
class LiveRefresh extends ConsumerStatefulWidget {
  const LiveRefresh({super.key, required this.refresh, required this.watching, required this.child, this.clock = DateTime.now});

  final void Function(WidgetRef ref) refresh;
  final List<ProviderListenable<AsyncValue<Object?>>> watching;
  final Widget child;
  final DateTime Function() clock;

  @override
  ConsumerState<LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends ConsumerState<LiveRefresh> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _updated;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (!ref.read(liveRefreshEnabledProvider)) return;
    _timer = Timer.periodic(ref.read(liveRefreshIntervalProvider), (_) => _look());
  }

  /// One look now: skipped while the screen is covered by another page, or while the last look is still running.
  void _look() {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return;
    if (widget.watching.any((p) => ref.read(p).isLoading)) return;
    widget.refresh(ref);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
      _look();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onValue(AsyncValue<Object?> next) {
    if (next.isLoading) return;
    final failed = next.hasError;
    final updated = next.hasValue && !failed ? widget.clock() : _updated;
    if (failed == _failed && updated == _updated) return;
    // A provider can settle while the screen is being built: say so a moment later, not in the middle of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _failed = failed;
        _updated = updated;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    for (final p in widget.watching) {
      ref.listen<AsyncValue<Object?>>(p, (_, next) => _onValue(next));
    }
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: _failed ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
          child: Row(
            children: [
              Expanded(child: Text(liveStatusText(updated: _updated, failed: _failed), key: const Key('live-status'), style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                key: const Key('live-refresh'),
                tooltip: 'Refresh now',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: () => widget.refresh(ref),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
