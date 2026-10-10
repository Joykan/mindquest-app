import 'package:flutter/material.dart';

import '../../core/widgets/mascot.dart';
import 'badges.dart';

/// Celebrates newly earned badges, with a happy Chipu.
Future<void> showNewBadges(BuildContext context, List<RewardBadge> badges, String language) {
  final ThemeData theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      key: const Key('new-badge-dialog'),
      icon: const Mascot(pose: MascotPose.happy, size: 96),
      title: Text(badges.length == 1 ? 'New badge!' : 'New badges!', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final RewardBadge b in badges)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: <Widget>[
                  Text(b.emoji, style: const TextStyle(fontSize: 40)),
                  Text(b.displayName(language), style: theme.textTheme.titleMedium),
                  Text(b.description, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nice!')),
      ],
    ),
  );
}
