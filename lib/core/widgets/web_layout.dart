import 'package:flutter/material.dart';

/// Screens at least this wide (laptops, tablets in landscape, the web) get
/// a side menu instead of the bottom tabs.
const double wideBreakpoint = 840;

/// Text and cards are kept to this width on big screens, so lines stay easy
/// to read.
const double readableWidth = 720;

bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideBreakpoint;

/// On a big screen, centres [child] and keeps it to [readableWidth]. On a
/// phone it changes nothing.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isWideScreen(context)) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: child,
        ),
      ),
    );
  }
}
