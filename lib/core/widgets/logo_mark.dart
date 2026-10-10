import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The MindQuest brain logo on a rounded mint square.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppPalette.primary, AppPalette.mint],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text('🧠', style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
