import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_models.dart';

/// Crisis support (wireframe 06).
///
/// Opens over the chat as soon as a crisis message is detected. Each helpline
/// has a Call button that opens the phone dialer with the number filled in.
/// It can only be closed with "I'm safe for now", not by tapping outside or
/// swiping down, so it isn't dismissed by accident.
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
    return PopScope(
      canPop: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(Icons.favorite, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              "You're not alone",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(reply.reply, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            for (final Helpline line in reply.helplines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(line.name, style: theme.textTheme.titleMedium),
                        if (line.description != null && line.description!.isNotEmpty)
                          Text(line.description!, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => _call(context, line),
                          icon: const Icon(Icons.call),
                          label: Text('Call ${line.phone}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("I'm safe for now"),
            ),
          ],
        ),
      ),
    );
  }
}
