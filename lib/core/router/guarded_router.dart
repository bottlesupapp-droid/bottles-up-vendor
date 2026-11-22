import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A [GoRouter] that opens a page once however many times it was tapped.
///
/// A page takes a moment to appear (it slides in, and a heavy one takes a moment to build first), and while that happens the row that opened it is still on screen and still tappable.
/// A second tap used to push the same page again: two copies on top of each other, so the back button shows the same page again and anything the page does happens twice.
/// Two rules stop that, and neither touches a screen:
///   1. A page is never pushed on top of itself: asking for the exact place you are already on is ignored, however long ago it opened (a slow page can take longer than any timer).
///   2. Asking for the SAME place again within [window] of the last time is ignored, as a safety net for the moment before the first push has shown up in [routerDelegate].
/// Asking for a different place is never held back, and neither is asking for the same place after going back to the page that has the row.
///
/// `push` and `pushReplacement` are the two calls every other way of navigating goes through (`pushNamed` and `pushReplacementNamed` call them), so guarding those covers `context.push`,
/// `context.pushNamed` and the rest. `go` is not guarded: going to the place you are already at changes nothing. `pushReplacement` only gets rule 2: replacing a page with itself is how a
/// page reloads, so rule 1 does not apply to it.
class GuardedGoRouter extends GoRouter {
  GuardedGoRouter({
    required List<RouteBase> routes,
    required GoRouterRedirect redirect,
    super.errorBuilder,
    super.refreshListenable,
    super.initialLocation,
    super.observers,
    super.debugLogDiagnostics,
    super.navigatorKey,
    this.window = const Duration(milliseconds: 600),
    DateTime Function()? now,
  }) : _now = now ?? (() => clock.now()),
       super.routingConfig(routingConfig: ValueNotifier<RoutingConfig>(RoutingConfig(routes: routes, redirect: redirect)));

  /// How long asking for the same place again is treated as the same tap.
  final Duration window;
  final DateTime Function() _now;

  String? _lastKey;
  DateTime? _lastAt;

  /// The place the stack shows on top. A page that was pushed does not change the configuration's own `uri` (that stays the address underneath), so for one the place is the pushed
  /// match's own.
  Uri _topLocation() {
    final configuration = routerDelegate.currentConfiguration;
    final top = configuration.lastOrNull;
    return top is ImperativeRouteMatch ? top.matches.uri : configuration.uri;
  }

  /// True when [location] is the place the stack is already showing on top (same path, same query).
  bool _isOnTop(String location) {
    final wanted = Uri.tryParse(location);
    if (wanted == null) return false;
    final here = _topLocation();
    if (wanted.path != here.path) return false;
    final a = wanted.queryParametersAll;
    final b = here.queryParametersAll;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      final other = b[key];
      final mine = a[key]!;
      if (other == null || other.length != mine.length) return false;
      for (var i = 0; i < mine.length; i++) {
        if (mine[i] != other[i]) return false;
      }
    }
    return true;
  }

  /// True when [key] is the place that was just asked for (so this request is the repeat); otherwise remembers it as the latest.
  bool _isRepeat(String key) {
    final now = _now();
    final lastAt = _lastAt;
    if (_lastKey == key && lastAt != null) {
      final since = now.difference(lastAt);
      // A clock that moved backwards (a negative gap) is not a repeat: never hold someone back for longer than the window.
      if (!since.isNegative && since < window) return true;
    }
    _lastKey = key;
    _lastAt = now;
    return false;
  }

  @override
  Future<T?> push<T extends Object?>(String location, {Object? extra}) {
    if (_isOnTop(location) || _isRepeat('push:$location')) return Future<T?>.value(null);
    return super.push<T>(location, extra: extra);
  }

  @override
  Future<T?> pushReplacement<T extends Object?>(String location, {Object? extra}) {
    if (_isRepeat('replace:$location')) return Future<T?>.value(null);
    return super.pushReplacement<T>(location, extra: extra);
  }
}
