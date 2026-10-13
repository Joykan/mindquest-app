import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';

/// Poses of Chipu, the MindQuest mascot: a little sprout (from "chipukizi",
/// Kiswahili for sprout). Our own design; sources in docs/design/mascot.
enum MascotPose { idle, happy, wave }

/// The full mascot.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.pose = MascotPose.idle, this.size = 96});

  final MascotPose pose;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String file = switch (pose) {
      MascotPose.idle => 'mascot',
      MascotPose.happy => 'mascot_happy',
      MascotPose.wave => 'mascot_wave',
    };
    return Semantics(
      label: context.tr(
          'Chipu, the MindQuest mascot', 'Chipu, mhusika wa MindQuest'),
      image: true,
      child: Image.asset('assets/images/$file.png', width: size, height: size),
    );
  }
}

/// The mascot's face in a circle, shown beside the bot's messages.
class MascotAvatar extends StatelessWidget {
  const MascotAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: mq.surfaceSoft,
          border: Border.all(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset('assets/images/mascot_face.png', fit: BoxFit.cover),
      ),
    );
  }
}
