import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'chat_backend.dart';
import 'chat_models.dart';
import 'crisis_sheet.dart';

/// Chat (wireframe 05). Sends each message to the chat Edge Function and
/// shows the reply. A crisis reply opens the crisis support sheet (wireframe 06).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.backend});

  final ChatBackend backend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Suggested replies that match what the model understands well.
const List<String> quickReplies = <String>[
  "I'm stressed",
  "I'm feeling anxious",
  'Help me breathe',
  "I'm doing great",
];

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final List<ChatMessage> _messages = <ChatMessage>[
    const ChatMessage(
      text: "Hi, I'm MindQuest. How are you feeling today? "
          'You can also ask me for a breathing exercise.',
      fromUser: false,
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final String text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessage(text: text, fromUser: true));
      _sending = true;
      _input.clear();
    });

    try {
      final ChatReply reply = await widget.backend.send(text);
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(text: reply.reply, fromUser: false)));
      if (reply.crisis) {
        await showCrisisSheet(context, reply);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send your message. Check your connection and try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('🧠', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            const Text('Chat'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: mq.surfaceSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.info_outline, size: 14, color: mq.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'AI companion · not a therapist',
                      style: theme.textTheme.labelSmall?.copyWith(color: mq.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (BuildContext context, int i) {
                  if (_sending && i == 0) return const _TypingBubble();
                  final int index = _messages.length - 1 - (i - (_sending ? 1 : 0));
                  return _Bubble(message: _messages[index]);
                },
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: quickReplies.length,
                separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int i) => ActionChip(
                  label: Text(quickReplies[i]),
                  onPressed: _sending ? null : () => _send(quickReplies[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const Key('chat-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('chat-send'),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Send',
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final bool mine = message.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primary : mq.surfaceSoft,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: mine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final MindQuestColors mq = Theme.of(context).extension<MindQuestColors>()!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('typing'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: mq.surfaceSoft, borderRadius: BorderRadius.circular(18)),
        child: Text('•••', style: TextStyle(color: mq.textMuted, letterSpacing: 2)),
      ),
    );
  }
}
