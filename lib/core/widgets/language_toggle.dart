import 'package:flutter/material.dart';

/// EN | SW switch used on Welcome, Onboarding and (later) Profile.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.onDark = false,
  });

  final String value;
  final ValueChanged<String> onChanged;

  /// True when drawn on the dark-green Welcome background.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color border = onDark ? Colors.white54 : scheme.outline;
    final Color selectedBg = onDark ? Colors.white : scheme.primary;
    final Color selectedFg =
        onDark ? const Color(0xFF1C2B25) : scheme.onPrimary;
    final Color idleFg = onDark ? Colors.white : scheme.onSurface;

    Widget option(String code, String label) {
      final bool selected = value == code;
      return Semantics(
        selected: selected,
        button: true,
        label: code == 'en' ? 'English' : 'Kiswahili',
        child: InkWell(
          key: Key('lang-$code'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? selectedFg : idleFg),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[option('en', 'EN'), option('sw', 'SW')],
      ),
    );
  }
}
