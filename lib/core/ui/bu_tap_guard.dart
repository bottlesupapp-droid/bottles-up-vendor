import 'package:flutter/material.dart';

/// "One tap, once." Lets a tap through, then holds back further taps on the same thing for [window].
///
/// Used where a tap starts something that takes a moment (opening a page, loading a list): the person sees nothing change for a beat, taps again, and the thing used to start twice.
/// One guard belongs to one tappable thing, so tapping two different rows quickly is never held back.
class BuTapGuard {
  BuTapGuard({this.window = const Duration(milliseconds: 500), DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Duration window;
  final DateTime Function() _now;
  DateTime? _last;

  /// True for the first tap and again once [window] has passed since the last tap that was let through.
  bool take() {
    final now = _now();
    final last = _last;
    if (last != null) {
      final since = now.difference(last);
      // A clock that moved backwards (a negative gap) never holds someone back.
      if (!since.isNegative && since < window) return false;
    }
    _last = now;
    return true;
  }
}

/// An [InkWell] that lets one tap through per [BuTapGuard.window]. With no [onTap] it is not tappable at all (no ripple, no tap), exactly like a plain [InkWell].
class BuGuardedInkWell extends StatefulWidget {
  const BuGuardedInkWell({super.key, required this.onTap, required this.child, this.borderRadius, this.guard});

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  /// For tests: a guard with its own clock. Normally each tappable makes its own.
  final BuTapGuard? guard;

  @override
  State<BuGuardedInkWell> createState() => _BuGuardedInkWellState();
}

class _BuGuardedInkWellState extends State<BuGuardedInkWell> {
  late final BuTapGuard _guard = widget.guard ?? BuTapGuard();

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onTap;
    return InkWell(
      borderRadius: widget.borderRadius,
      onTap:
          onTap == null
              ? null
              : () {
                if (_guard.take()) onTap();
              },
      child: widget.child,
    );
  }
}
