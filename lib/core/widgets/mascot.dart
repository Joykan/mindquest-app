import 'package:flutter/material.dart';

import '../../features/gamification/outfits.dart';
import '../l10n/tr.dart';
import '../theme/app_colors.dart';

/// Poses of Chipu, the MindQuest mascot: a little sprout (from "chipukizi",
/// Kiswahili for sprout). Our own design; sources in docs/design/mascot.
enum MascotPose { idle, happy, wave }

/// The full mascot, wearing the user's outfit (see outfits.dart).
class Mascot extends StatelessWidget {
  const Mascot({
    super.key,
    this.pose = MascotPose.idle,
    this.size = 96,
    this.outfit,
    this.followScope = true,
  });

  final MascotPose pose;
  final double size;

  /// Shows this outfit instead of the user's (e.g. in the wardrobe).
  final String? outfit;

  /// When false and [outfit] is null, Chipu wears nothing.
  final bool followScope;

  @override
  Widget build(BuildContext context) {
    final String file = switch (pose) {
      MascotPose.idle => 'mascot',
      MascotPose.happy => 'mascot_happy',
      MascotPose.wave => 'mascot_wave',
    };
    final Outfit? o =
        outfitById(outfit ?? (followScope ? OutfitScope.of(context) : null));
    final Widget base =
        Image.asset('assets/images/$file.png', width: size, height: size);
    return Semantics(
      label: o == null
          ? context.tr(
              'Chipu, the MindQuest mascot', 'Chipu, mhusika wa MindQuest')
          : context.tr('Chipu, wearing the ${o.en.toLowerCase()}',
              'Chipu, amevaa ${o.sw.toLowerCase()}'),
      image: true,
      child: o == null
          ? base
          : SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: <Widget>[
                  if (o.backAsset != null)
                    Image.asset(o.backAsset!, width: size, height: size),
                  base,
                  if (o.frontAsset != null)
                    Image.asset(o.frontAsset!, width: size, height: size),
                ],
              ),
            ),
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
        child: Builder(builder: (BuildContext context) {
          final String? face = outfitById(OutfitScope.of(context))?.faceAsset;
          const Widget plain = Image(
              image: AssetImage('assets/images/mascot_face.png'),
              fit: BoxFit.cover);
          if (face == null) return plain;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[plain, Image.asset(face, fit: BoxFit.cover)],
          );
        }),
      ),
    );
  }
}
