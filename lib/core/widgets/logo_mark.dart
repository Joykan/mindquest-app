import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The MindQuest logo: the brain on a green gradient tile (same as the app
/// icon). The brain is an image, so it looks the same on every phone.
/// Brain graphic: Twemoji, CC-BY 4.0.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MindQuest logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppPalette.primary, AppPalette.mint],
          ),
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Image.asset('assets/images/brain.png', fit: BoxFit.contain),
      ),
    );
  }
}
