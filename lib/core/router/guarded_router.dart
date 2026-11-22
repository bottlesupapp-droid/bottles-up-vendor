import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A [GoRouter] that opens a page once however many times it was tapped.
///
/// A page takes a moment to slide in, and while it does the row that opened it is still on screen and still tappable. A second tap used to push the same page again (two copies on top of
/// each other: the back button then shows the same page, and anything the page does happens twice). Here, asking for the SAME place again within [window] of the last time is ignored.
/// Asking for a different place is never held back, and neither is asking for the same place after [window] (someone who goes back and taps again).
///
/// `push` and `pushReplacement` are the two calls every other way of navigating goes through (`pushNamed` and `pushReplacementNamed` call them), so guarding those covers `context.push`,
/// `context.pushNamed` and the rest without touching the screens. `go` is not guarded: going to the place you are already at changes nothing.
class GuardedGoRouter extends GoRouter {
  GuardedGoRouter({
    required List<RouteBase> routes,
    required GoRouterRedirect redirect,
    GoRouterWidgetBuilder? errorBuilder,
    Listenable? refreshListenable,
    String? initialLocation,
    List<NavigatorObserver>? observers,
    bool debugLogDiagnostics = false,
    GlobalKey<NavigatorState>? navigatorKey,
    this.window = const Duration(milliseconds: 600),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super.routingConfig(
         routingConfig: ValueNotifier<RoutingConfig>(RoutingConfig(routes: routes, redirect: redirect)),
         errorBuilder: errorBuilder,
         refreshListenable: refreshListenable,
         initialLocation: initialLocation,
         observers: observers,
         debugLogDiagnostics: debugLogDiagnostics,
         navigatorKey: navigatorKey,
       );

  /// How long asking for the same place again is treated as the same tap.
  final Duration window;
  final DateTime Function() _now;

  String? _lastKey;
  DateTime? _lastAt;

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
    if (_isRepeat('push:$location')) return Future<T?>.value(null);
    return super.push<T>(location, extra: extra);
  }

  @override
  Future<T?> pushReplacement<T extends Object?>(String location, {Object? extra}) {
    if (_isRepeat('replace:$location')) return Future<T?>.value(null);
    return super.pushReplacement<T>(location, extra: extra);
  }
}
