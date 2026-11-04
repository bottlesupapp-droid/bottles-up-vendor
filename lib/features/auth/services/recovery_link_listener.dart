import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../logic/password_recovery_logic.dart';

/// Where links that open the app come from. A test hands the listener a fake one.
abstract class RecoveryLinkSource {
  /// The link that started the app, if it was started by one.
  Future<Uri?> initialLink();

  /// Links that arrive while the app is already running.
  Stream<Uri> get links;
}

class AppLinksSource implements RecoveryLinkSource {
  AppLinks? _appLinks;
  AppLinks get _links => _appLinks ??= AppLinks();

  @override
  Future<Uri?> initialLink() async {
    try {
      return await _links.getInitialLink();
    } catch (_) {
      // No link plugin (a test, or a platform without one): the app simply has no link to open.
      return null;
    }
  }

  @override
  Stream<Uri> get links => _links.uriLinkStream;
}

final recoveryLinkSourceProvider = Provider<RecoveryLinkSource>((ref) => AppLinksSource());

/// Sits around the whole app and sends a password-reset link (the website's /reset-password page opens the app on `bottlesupbusiness://app/reset-password`)
/// to the new-password screen. The system may also hand the same link to the router by itself; the reset flow spends the token once however often it arrives.
class RecoveryLinkListener extends ConsumerStatefulWidget {
  const RecoveryLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RecoveryLinkListener> createState() => _RecoveryLinkListenerState();
}

class _RecoveryLinkListenerState extends ConsumerState<RecoveryLinkListener> {
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    final source = ref.read(recoveryLinkSourceProvider);
    _subscription = source.links.listen(_open, onError: (Object _) {});
    unawaited(source.initialLink().then((uri) {
      if (uri != null) _open(uri);
    }));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _open(Uri uri) {
    final location = recoveryLocationFor(uri);
    if (location == null || !mounted) return;
    debugPrint('Password reset link received: ${redactLink(uri.toString())}');
    ref.read(routerProvider).go(location);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
