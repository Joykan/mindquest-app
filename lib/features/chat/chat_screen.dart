import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot.dart';
import '../home/progress_repository.dart';
import '../mood/mood_week_graph.dart';
import '../mood/moods.dart';
import 'chat_backend.dart';
import 'chat_models.dart';
import 'crisis_sheet.dart';

/// Chat (wireframe 05). Sends each message to the chat Edge Function and
/// shows the reply. A crisis reply opens the crisis support sheet (wireframe 06).
/// With a [progress] repository the bot also asks for a mood check-in in the
/// chat and draws the week's moods.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.backend,
    this.progress,
    this.onBack,
    this.onMoodSaved,
  });

  final ChatBackend backend;

  /// Saves mood check-ins made in the chat. Without it there is no picker.
  final ProgressRepository? progress;

  /// Shows a back arrow (to Home) when given.
  final VoidCallback? onBack;

  /// Called after a mood is saved from the chat (e.g. to refresh Home).
  final VoidCallback? onMoodSaved;

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

/// Chip that asks for a mood check-in in the chat.
const String checkInChip = 'Check in my mood';

const String _greeting = "Hi, I'm MindQuest. How are you feeling right now?";

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  late final List<ChatMessage> _messages = <ChatMessage>[
    widget.progress == null
        ? const ChatMessage(
            text: "Hi, I'm MindQuest. How are you feeling today? "
                'You can also ask me for a breathing exercise.',
            fromUser: false,
          )
        : const ChatMessage(text: _greeting, fromUser: false, kind: ChatItemKind.moodPicker),
  ];

  /// Mood picked in each picker (by its index in [_messages]).
  final Map<int, int> _picked = <int, int>{};
  List<MoodEntry> _week = <MoodEntry>[];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _addBot(String text, [ChatItemKind kind = ChatItemKind.text]) =>
      _messages.add(ChatMessage(text: text, fromUser: false, kind: kind));

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
      setState(() {
        _addBot(reply.reply);
        _sending = false;
      });
      if (reply.crisis) {
        await showCrisisSheet(context, reply);
      }
    } catch (_) {
      if (!mounted) return;
      _showError("Couldn't send your message. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _askMood() {
    if (_sending) return;
    setState(() {
      _messages.add(const ChatMessage(text: checkInChip, fromUser: true));
      _addBot('How are you feeling right now?', ChatItemKind.moodPicker);
    });
  }

  Future<void> _pickMood(int index, int mood) async {
    final ProgressRepository? progress = widget.progress;
    if (progress == null || _picked.containsKey(index) || _sending) return;
    final MoodOption m = moodOptions[mood - 1];
    setState(() {
      _picked[index] = mood;
      _messages.add(ChatMessage(text: '${m.emoji} ${m.label}', fromUser: true));
      _sending = true;
    });
    try {
      final MoodSaved saved = await progress.logMood(mood: mood);
      List<MoodEntry> week = _week;
      try {
        week = await progress.loadMoodHistory(days: 7);
      } catch (_) {
        // The graph is a bonus; the check-in is already saved.
      }
      if (!mounted) return;
      widget.onMoodSaved?.call();
      setState(() {
        _week = week;
        _addBot(_moodReply(mood));
        _addBot(
          saved.xpEarned > 0
              ? "I've added that to your graph. +${saved.xpEarned} XP"
              : "I've added that to your graph.",
          ChatItemKind.moodGraph,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _picked.remove(index);
        _messages.removeLast();
      });
      _showError("Couldn't save your mood. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _moodReply(int mood) => switch (mood) {
        5 => "That's wonderful! I'm so glad to hear it.",
        4 => "I'm glad to hear that!",
        3 => 'Thanks for checking in. Want to tell me more about your day?',
        _ => "I'm sorry it's a hard day. I'm here. Tell me what's going on, "
            'or try a breathing exercise with me.',
      };

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final List<String> chips = <String>[
      if (widget.progress != null) checkInChip,
      ...quickReplies,
    ];
    // Newest first, because the list is reversed. Index 0 may be "typing".
    final int extra = _sending ? 1 : 0;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null ? null : BackButton(onPressed: widget.onBack),
        title: Row(
          children: <Widget>[
            const MascotAvatar(size: 36),
            const SizedBox(width: 10),
            // Expanded + ellipsis so big system text sizes can't overflow.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Chat', maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    'AI companion · not a therapist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: mq.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                itemCount: _messages.length + extra + 1,
                itemBuilder: (BuildContext context, int i) {
                  if (_sending && i == 0) return const _TypingBubble();
                  final int index = _messages.length - 1 - (i - extra);
                  if (index < 0) return const _ChatIntro();
                  final ChatMessage m = _messages[index];
                  // The mascot sits beside the last bot item in a run.
                  final bool lastInRun = index == _messages.length - 1
                      ? !_sending
                      : _messages[index + 1].fromUser;
                  return _ChatItem(
                    message: m,
                    showAvatar: !m.fromUser && lastInRun,
                    picked: _picked[index],
                    onPick: _sending ? null : (int mood) => _pickMood(index, mood),
                    week: _week,
                  );
                },
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chips.length,
                separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int i) => ActionChip(
                  avatar: chips[i] == checkInChip ? const Text('📝') : null,
                  label: Text(chips[i]),
                  onPressed: _sending
                      ? null
                      : chips[i] == checkInChip
                          ? _askMood
                          : () => _send(chips[i]),
                ),
              ),
            ),
            _Composer(controller: _input, sending: _sending, onSend: _send),
          ],
        ),
      ),
    );
  }
}

/// The mascot waving at the top of the conversation.
class _ChatIntro extends StatelessWidget {
  const _ChatIntro();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: <Widget>[
          const Mascot(pose: MascotPose.wave, size: 120),
          const SizedBox(height: 4),
          Text(
            'I listen, suggest exercises and track your moods.\n'
            "I'm not a therapist. If you're in danger, please call emergency services.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ChatItem extends StatelessWidget {
  const _ChatItem({
    required this.message,
    required this.showAvatar,
    required this.picked,
    required this.onPick,
    required this.week,
  });

  final ChatMessage message;
  final bool showAvatar;
  final int? picked;
  final ValueChanged<int>? onPick;
  final List<MoodEntry> week;

  @override
  Widget build(BuildContext context) {
    if (message.fromUser) return _Bubble(message: message);
    final Widget content = switch (message.kind) {
      ChatItemKind.text => _Bubble(message: message),
      ChatItemKind.moodPicker => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Bubble(message: message),
            _MoodFaces(picked: picked, onPick: onPick),
          ],
        ),
      ChatItemKind.moodGraph => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Bubble(message: message),
            _GraphCard(week: week),
          ],
        ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        SizedBox(
          width: 36,
          child: showAvatar ? const MascotAvatar(size: 32) : null,
        ),
        const SizedBox(width: 6),
        Expanded(child: content),
      ],
    );
  }
}

class _MoodFaces extends StatelessWidget {
  const _MoodFaces({required this.picked, required this.onPick});

  final int? picked;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final MoodOption m in moodOptions)
            Semantics(
              button: true,
              selected: picked == m.value,
              label: m.label,
              child: InkWell(
                key: Key('chat-mood-${m.value}'),
                borderRadius: BorderRadius.circular(14),
                onTap: picked != null || onPick == null ? null : () => onPick!(m.value),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: picked == null || picked == m.value ? 1 : 0.35,
                  child: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: picked == m.value
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: picked == m.value ? theme.colorScheme.primary : theme.colorScheme.outline,
                        width: picked == m.value ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(m.emoji, style: const TextStyle(fontSize: 22)),
                        Text(m.label,
                            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GraphCard extends StatelessWidget {
  const _GraphCard({required this.week});

  final List<MoodEntry> week;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool happy = week.isNotEmpty && week.first.mood >= 4;
    return Container(
      key: const Key('chat-mood-graph'),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
      margin: const EdgeInsets.only(top: 2, bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text('Your week', style: theme.textTheme.titleSmall)),
              if (happy) const Mascot(pose: MascotPose.happy, size: 34),
            ],
          ),
          const SizedBox(height: 6),
          MoodWeekGraph(entries: week, height: 120),
        ],
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
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primary : mq.surfaceSoft,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(mine ? 22 : 6),
            bottomRight: Radius.circular(mine ? 6 : 22),
          ),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.35,
            color: mine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The mascot with a "typing" bubble, while waiting for a reply.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _dots =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MindQuestColors mq = Theme.of(context).extension<MindQuestColors>()!;
    return Semantics(
      label: 'MindQuest is typing',
      child: Row(
        key: const Key('typing'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const SizedBox(width: 36, child: MascotAvatar(size: 32)),
          const SizedBox(width: 6),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: mq.surfaceSoft,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: AnimatedBuilder(
              animation: _dots,
              builder: (BuildContext context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < 3; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mq.textMuted.withValues(
                          // Each dot brightens in turn.
                          alpha: ((_dots.value * 3 - i) % 3) < 1 ? 0.9 : 0.35,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill-shaped message box with a round send button inside it.
class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outline, width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('chat-input'),
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  counterText: '',
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              key: const Key('chat-send'),
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.arrow_upward_rounded),
              tooltip: 'Send',
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
          ],
        ),
      ),
    );
  }
}
