import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;
  final double? width;
  final double height;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bu = context.bu;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.control));
    final enabled = !isLoading && onPressed != null;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: isSecondary
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                side: BorderSide(color: bu.line),
                backgroundColor: bu.panel,
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: _buildButtonContent(theme, bu.ink),
            )
          : DecoratedBox(
              // A soft orange glow under the one button that matters on a screen.
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BuRadius.control),
                boxShadow: enabled ? [BoxShadow(color: bu.orange.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 8))] : null,
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: bu.orange,
                  foregroundColor: Colors.white,
                  shape: shape,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: _buildButtonContent(theme, Colors.white),
              ),
            ),
    );
  }

  Widget _buildButtonContent(ThemeData theme, Color color) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(color)),
      );
    }

    final label = Text(text, style: theme.textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: color));
    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        label,
      ],
    );
  }
}
