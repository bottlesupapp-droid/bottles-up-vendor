import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/google_sign_in_config.dart';
import '../services/social_sign_in_service.dart';

/// Which of the two sign-ins this phone can offer: Apple on iPhone, Google where it is set up (see [GoogleSignInConfig]). Apple requires an app that offers another company's sign-in on
/// iPhone to offer Sign in with Apple as well, and this is always the case here: Apple is offered whenever Google is on iPhone.
List<SocialProvider> socialProvidersFor(TargetPlatform platform) => [
      if (GoogleSignInConfig.isConfiguredFor(platform)) SocialProvider.google,
      if (platform == TargetPlatform.iOS) SocialProvider.apple,
    ];

/// "or", then "Continue with Google" and, on iPhone, "Continue with Apple" (Apple's own button, which App Review looks for). Draws nothing when the phone can offer neither. While [enabled] is
/// false (a sign-in is running) the buttons cannot be pressed. [showDivider] false leaves out the "or" line for a page that introduces the buttons with its own heading.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({super.key, required this.onPressed, this.enabled = true, this.showDivider = true});

  final void Function(SocialProvider provider) onPressed;
  final bool enabled;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final providers = socialProvidersFor(defaultTargetPlatform);
    if (providers.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDivider) ...[
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('or', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 16),
        ],
        if (providers.contains(SocialProvider.google))
          OutlinedButton.icon(
            key: const Key('social-google'),
            onPressed: enabled ? () => onPressed(SocialProvider.google) : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            icon: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
            label: const Text('Continue with Google'),
          ),
        if (providers.contains(SocialProvider.apple)) ...[
          if (providers.length > 1) const SizedBox(height: 12),
          Opacity(
            opacity: enabled ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: !enabled,
              child: SignInWithAppleButton(
                key: const Key('social-apple'),
                onPressed: () => onPressed(SocialProvider.apple),
                text: 'Continue with Apple',
                height: 48,
                style: theme.brightness == Brightness.dark ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
