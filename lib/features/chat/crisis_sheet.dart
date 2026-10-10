import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'chat_models.dart';

/// Crisis support (wireframe 06).
///
/// Opens over the chat as soon as a crisis message is detected. Each helpline
/// has a Call button that opens the phone dialer with the number filled in.
/// It can only be closed with "I'm safe, continue chatting", not by tapping
/// outside, swiping down or pressing back, so it isn't dismissed by accident.
Future<void> showCrisisSheet(BuildContext context, ChatReply reply) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => CrisisSheet(reply: reply),
  );
}

class CrisisSheet extends StatelessWidget {
  const CrisisSheet({super.key, required this.reply});

  final ChatReply reply;

  Future<void> _call(BuildContext context, Helpline line) async {
    final Uri uri = Uri(scheme: 'tel', path: line.phone.replaceAll(' ', ''));
    final bool opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please dial ${line.phone}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return PopScope(
      canPop: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mq.crisisSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.favorite, color: mq.crisis),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You don't have to go through this alone",
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(reply.reply, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final Helpline line in reply.helplines) _HelplineRow(line: line, onCall: _call),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(
                "I'm safe, continue chatting",
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelplineRow extends StatelessWidget {
  const _HelplineRow({required this.line, required this.onCall});

  final Helpline line;
  final Future<void> Function(BuildContext, Helpline) onCall;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final String details = <String>[
      line.phone,
      if (line.description != null && line.description!.isNotEmpty) line.description!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(line.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(details, style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () => onCall(context, line),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Call'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 44),
              backgroundColor: mq.crisis,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
