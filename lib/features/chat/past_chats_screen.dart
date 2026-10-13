import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot.dart';
import 'chat_backend.dart';
import 'chat_models.dart';

/// "Tue 13 Oct · 10:23" / "Jnn 13 Okt · 10:23".
String chatDate(DateTime d, [String language = 'en']) =>
    '${shortDay(language, d.weekday)} ${shortDate(language, d)} · ${clock(d)}';

/// Past chats: recent conversations, newest first. Tap one to read it.
class PastChatsScreen extends StatelessWidget {
  const PastChatsScreen(
      {super.key, required this.backend, required this.onOpen});

  final ChatBackend backend;
  final ValueChanged<ChatSessionSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Scaffold(
      appBar: AppBar(
          title: Text(context.tr('Past chats', 'Mazungumzo ya awali'))),
      body: FutureBuilder<List<ChatSessionSummary>>(
        future: backend.loadPastChats(),
        builder: (BuildContext context,
            AsyncSnapshot<List<ChatSessionSummary>> snap) {
          if (snap.hasError) {
            return Center(
                child: Text(context.tr(
                    "Couldn't load your chats. Check your connection.",
                    'Imeshindikana kupakia mazungumzo yako. Angalia mtandao wako.')));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<ChatSessionSummary> chats = snap.data!;
          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Mascot(size: 96),
                    const SizedBox(height: 12),
                    Text(
                        context.tr('No chats yet. Say hi to Chipu!',
                            'Bado hakuna mazungumzo. Msalimie Chipu!'),
                        style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: chats.length + 1,
            separatorBuilder: (BuildContext context, int i) =>
                const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int i) {
              if (i == chats.length) {
                return Text(
                  context.tr('Only you can see your chats.',
                      'Ni wewe tu unayeweza kuona mazungumzo yako.'),
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
                );
              }
              final ChatSessionSummary c = chats[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: Key('past-chat-${c.id}'),
                  leading: const MascotAvatar(size: 40),
                  title: Text(
                    c.preview.isEmpty
                        ? context.tr('Chat with Chipu', 'Mazungumzo na Chipu')
                        : c.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Text(context.tr(
                      '${chatDate(c.startedAt)} · ${c.messageCount} messages'
                          '${c.open ? ' · current' : ''}',
                      '${chatDate(c.startedAt, 'sw')} · jumbe ${c.messageCount}'
                          '${c.open ? ' · ya sasa' : ''}')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpen(c),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// One past conversation, read-only.
class ChatTranscriptScreen extends StatelessWidget {
  const ChatTranscriptScreen(
      {super.key, required this.backend, required this.chat});

  final ChatBackend backend;
  final ChatSessionSummary chat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Scaffold(
      appBar: AppBar(title: Text(chatDate(chat.startedAt, context.lang))),
      body: FutureBuilder<List<ChatMessage>>(
        future: backend.loadTranscript(chat.id),
        builder: (BuildContext context, AsyncSnapshot<List<ChatMessage>> snap) {
          if (snap.hasError) {
            return Center(
                child: Text(context.tr("Couldn't load this chat.",
                    'Imeshindikana kupakia mazungumzo haya.')));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              for (final ChatMessage m in snap.data!)
                Align(
                  alignment:
                      m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: m.fromUser
                          ? theme.colorScheme.primary
                          : mq.surfaceSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      m.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: m.fromUser
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
