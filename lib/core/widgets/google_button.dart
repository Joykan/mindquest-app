import 'package:flutter/material.dart';

import '../l10n/tr.dart';

/// "Continue with Google" button, used on Welcome, Sign in and Save progress.
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.label,
    this.onDark = false,
  });

  final VoidCallback? onPressed;
  /// Defaults to "Continue with Google".
  final String? label;

  /// True on the dark Welcome background.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      key: const Key('google'),
      onPressed: onPressed,
      icon: const Icon(Icons.g_mobiledata, size: 30),
      label: Text(label ??
          context.tr('Continue with Google', 'Endelea na Google')),
      style: OutlinedButton.styleFrom(
        backgroundColor: onDark ? Colors.white : scheme.surface,
        foregroundColor: onDark ? const Color(0xFF1C2B25) : scheme.onSurface,
        side: BorderSide(color: onDark ? Colors.white : scheme.outline, width: 1.5),
      ),
    );
  }
}
