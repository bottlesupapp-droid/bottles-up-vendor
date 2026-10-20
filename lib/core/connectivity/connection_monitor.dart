import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// "Connection lost" (developer brief 15 Oct, section 33: "Show disconnected or pending-sync status"). A small check that the phone can reach the server, so the person is
// told they are offline BEFORE they type a long form, not after a save fails. It never decides what can or cannot be done: every screen still shows its own plain failure
// message and keeps what was typed, and the database stays the only judge of access. The rule is pure Dart and tested without a phone.

/// Answers true when the server could be reached (any HTTP answer counts, even an error status: the network works), false when nothing came back.
typedef ConnectionProbe = Future<bool> Function();

/// How many checks in a row must fail before the person is told they are offline. One failed check is often just a slow moment.
const int failuresBeforeOffline = 2;

/// How often the connection is checked while the app is in front.
const Duration connectionCheckEvery = Duration(seconds: 15);

/// How long one check may take before it counts as a failure.
const Duration probeTimeout = Duration(seconds: 5);

class NetworkStatus {
  const NetworkStatus({required this.online, this.failures = 0, this.checking = false});

  /// Whether the person should be told they are online. Starts true: nothing is said until two checks have failed.
  final bool online;

  /// Failed checks in a row.
  final int failures;
  final bool checking;

  NetworkStatus copy({bool? online, int? failures, bool? checking}) => NetworkStatus(online: online ?? this.online, failures: failures ?? this.failures, checking: checking ?? this.checking);
}

/// The state after one more check. A success is online at once; a failure only turns into "offline" after [failuresBeforeOffline] in a row.
NetworkStatus afterCheck(NetworkStatus s, {required bool reachable}) {
  if (reachable) return s.copy(online: true, failures: 0);
  final failures = s.failures + 1;
  return s.copy(failures: failures, online: failures < failuresBeforeOffline);
}

class ConnectionMonitor extends StateNotifier<NetworkStatus> with WidgetsBindingObserver {
  ConnectionMonitor(this._probe, {Duration every = connectionCheckEvery, bool autoStart = true}) : super(const NetworkStatus(online: true)) {
    if (autoStart) {
      _timer = Timer.periodic(every, (_) => check());
      WidgetsBinding.instance.addObserver(this);
    }
  }

  final ConnectionProbe _probe;
  Timer? _timer;

  /// One check now. A second call while one is running is ignored.
  Future<void> check() async {
    if (state.checking) return;
    state = state.copy(checking: true);
    bool reachable;
    try {
      reachable = await _probe();
    } catch (_) {
      reachable = false;
    }
    if (!mounted) return;
    state = afterCheck(state.copy(checking: false), reachable: reachable);
  }

  @override
  // ignore: avoid_renaming_method_parameters (the notifier already has a field called state)
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Back in front after a while away: look again straight away rather than waiting for the next tick.
    if (lifecycle == AppLifecycleState.resumed) check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Whether the monitor runs at all. Off by default so tests and previews never start a timer or touch the network; the app turns it on in main.dart.
final connectionMonitorEnabledProvider = Provider<bool>((ref) => false);

/// The real check: a HEAD request to the project's own address. Any answer at all means the network works.
ConnectionProbe httpProbe(String baseUrl) => () async {
      final client = HttpClient()..connectionTimeout = probeTimeout;
      try {
        final request = await client.headUrl(Uri.parse(baseUrl)).timeout(probeTimeout);
        final response = await request.close().timeout(probeTimeout);
        await response.drain<void>();
        return true;
      } catch (_) {
        return false;
      } finally {
        client.close(force: true);
      }
    };

final connectionProbeProvider = Provider<ConnectionProbe>((ref) => () async => true);

final connectionMonitorProvider = StateNotifierProvider<ConnectionMonitor, NetworkStatus>((ref) {
  final enabled = ref.watch(connectionMonitorEnabledProvider);
  return ConnectionMonitor(ref.watch(connectionProbeProvider), autoStart: enabled);
});
