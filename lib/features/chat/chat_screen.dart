import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot.dart';
import '../home/progress_repository.dart';
import '../mood/mood_insights.dart';
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
    this.onHelplines,
    this.onPastChats,
  });

  final ChatBackend backend;

  /// Opens the list of past chats.
  final VoidCallback? onPastChats;

  /// Saves mood check-ins made in the chat. Without it there is no picker.
  final ProgressRepository? progress;

  /// Shows a back arrow (to Home) when given.
  final VoidCallback? onBack;

  /// Called after a mood is saved from the chat (e.g. to refresh Home).
  final VoidCallback? onMoodSaved;

  /// Opens the helplines (offered after a run of hard days).
  final VoidCallback? onHelplines;

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

/// The same suggestions in Kiswahili (all close to the training phrases).
const List<String> quickRepliesSw = <String>[
  'Nina msongo wa mawazo',
  'Nina wasiwasi',
  'Nisaidie kupumua',
  'Niko poa',
];

/// Chip that asks for a mood check-in in the chat.
const String checkInChip = 'Check in my mood';
const String checkInChipSw = 'Rekodi hisia zangu';

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final List<ChatMessage> _messages = <ChatMessage>[];

  ChatMessage _firstMessage() {
    final String lang = context.lang;
    return widget.progress == null
        ? ChatMessage(
            text: tr(
                lang,
                "Hi, I'm Chipu, your MindQuest buddy. How are you feeling today? "
                    'You can also ask me for a breathing exercise.',
                'Habari, mimi ni Chipu, rafiki yako wa MindQuest. Unajisikiaje leo? '
                    'Unaweza pia kuniomba zoezi la kupumua.'),
            fromUser: false,
          )
        : ChatMessage(
            text: tr(
                lang,
                "Hi, I'm Chipu, your MindQuest buddy. How are you feeling right now?",
                'Habari, mimi ni Chipu, rafiki yako wa MindQuest. Unajisikiaje sasa hivi?'),
            fromUser: false,
            kind: ChatItemKind.moodPicker);
  }

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The greeting needs the language, which is only known here.
    if (_messages.isEmpty) _messages.add(_firstMessage());
  }

  /// Picks up the last conversation if it was recent.
  Future<void> _restore() async {
    try {
      final RestoredChat? chat = await widget.backend.restore();
      // Only if the user hasn't started typing in the meantime.
      if (chat == null || !mounted || _messages.length > 1 || _sending) return;
      final String time = clock(chat.startedAt);
      setState(() {
        _messages
          ..clear()
          ..add(ChatMessage(
              text: context.tr('Continuing your chat from $time',
                  'Unaendelea na mazungumzo ya saa $time'),
              fromUser: false,
              kind: ChatItemKind.note))
          ..addAll(chat.messages);
        _picked.clear();
      });
    } catch (_) {
      // Start fresh if the old chat can't be loaded.
    }
  }

  Future<void> _newChat() async {
    if (_sending) return;
    final bool talked = _messages.any((ChatMessage m) => m.fromUser);
    if (talked) {
      final bool? sure = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title:
              Text(context.tr('Start a new chat?', 'Anza mazungumzo mapya?')),
          content: Text(context.tr(
              'This conversation is saved. You can read it again in Past chats.',
              'Mazungumzo haya yamehifadhiwa. Unaweza kuyasoma tena kwenye Mazungumzo ya awali.')),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Cancel', 'Ghairi'))),
            TextButton(
              key: const Key('confirm-new-chat'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('New chat', 'Mazungumzo mapya')),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    setState(() {
      _messages
        ..clear()
        ..add(_firstMessage());
      _picked.clear();
    });
    try {
      await widget.backend.startNewChat();
    } catch (_) {
      // The next message starts a new chat anyway.
    }
  }

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
    final String lang = context.lang;

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
      _showError(tr(
          lang,
          "Couldn't send your message. Check your connection and try again.",
          'Imeshindikana kutuma ujumbe wako. Angalia mtandao wako kisha ujaribu tena.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static bool _isCheckIn(String chip) =>
      chip == checkInChip || chip == checkInChipSw;

  void _askMood() {
    if (_sending) return;
    setState(() {
      _messages.add(ChatMessage(
          text: context.tr(checkInChip, checkInChipSw), fromUser: true));
      _addBot(
          context.tr(
              'How are you feeling right now?', 'Unajisikiaje sasa hivi?'),
          ChatItemKind.moodPicker);
    });
  }

  Future<void> _pickMood(int index, int mood) async {
    final ProgressRepository? progress = widget.progress;
    if (progress == null || _picked.containsKey(index) || _sending) return;
    final MoodOption m = moodOptions[mood - 1];
    final String lang = context.lang;
    setState(() {
      _picked[index] = mood;
      _messages
          .add(ChatMessage(text: '${m.emoji} ${m.name(lang)}', fromUser: true));
      _sending = true;
    });
    try {
      final MoodSaved saved = await progress.logMood(mood: mood);
      List<MoodEntry> week = _week;
      Map<String, int> feelings = const <String, int>{};
      try {
        week = await progress.loadMoodHistory();
        feelings = await progress.loadChatFeelings();
      } catch (_) {
        // The graph and insight are a bonus; the check-in is already saved.
      }
      final List<MoodInsight> insights =
          buildInsights(week, chatFeelings: feelings, language: lang);
      if (!mounted) return;
      widget.onMoodSaved?.call();
      setState(() {
        _week = week;
        _addBot(moodReply(mood, lang));
        _addBot(
          saved.xpEarned > 0
              ? tr(lang, "I've added that to your graph. +${saved.xpEarned} XP",
                  'Nimeiongeza kwenye grafu yako. +${saved.xpEarned} XP')
              : tr(lang, "I've added that to your graph.",
                  'Nimeiongeza kwenye grafu yako.'),
          ChatItemKind.moodGraph,
        );
        // Share the most important thing Chipu noticed, if anything.
        if (insights.isNotEmpty) {
          final MoodInsight top = insights.first;
          if (top.needsSupport) {
            _addBot('${top.title}. ${top.body}', ChatItemKind.support);
          } else {
            _addBot(tr(lang, 'Something I noticed: ${top.body}',
                'Nimegundua jambo: ${top.body}'));
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _picked.remove(index);
        _messages.removeLast();
      });
      _showError(tr(
          lang,
          "Couldn't save your mood. Check your connection and try again.",
          'Imeshindikana kuhifadhi hisia zako. Angalia mtandao wako kisha ujaribu tena.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final List<String> chips = <String>[
      if (widget.progress != null) context.tr(checkInChip, checkInChipSw),
      ...(context.isSw ? quickRepliesSw : quickReplies),
    ];
    // Newest first, because the list is reversed. Index 0 may be "typing".
    final int extra = _sending ? 1 : 0;
    return Scaffold(
      appBar: AppBar(
        leading:
            widget.onBack == null ? null : BackButton(onPressed: widget.onBack),
        title: Row(
          children: <Widget>[
            const MascotAvatar(size: 36),
            const SizedBox(width: 10),
            // Expanded + ellipsis so big system text sizes can't overflow.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Chipu',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    context.tr('AI companion · not a therapist',
                        'Rafiki wa AI · si mtaalamu wa tiba'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: mq.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (widget.onPastChats != null)
            IconButton(
              key: const Key('past-chats'),
              tooltip: context.tr('Past chats', 'Mazungumzo ya awali'),
              onPressed: widget.onPastChats,
              icon: const Icon(Icons.history),
            ),
          IconButton(
            key: const Key('new-chat'),
            tooltip: context.tr('New chat', 'Mazungumzo mapya'),
            onPressed: _sending ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
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
                    onPick:
                        _sending ? null : (int mood) => _pickMood(index, mood),
                    week: _week,
                    onHelplines: widget.onHelplines,
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
                separatorBuilder: (BuildContext context, int i) =>
                    const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int i) => ActionChip(
                  avatar: _isCheckIn(chips[i]) ? const Text('📝') : null,
                  label: Text(chips[i]),
                  onPressed: _sending
                      ? null
                      : _isCheckIn(chips[i])
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
            context.tr(
                'I listen, suggest exercises and track your moods.\n'
                    "I'm not a therapist. If you're in danger, please call emergency services.",
                'Ninasikiliza, napendekeza mazoezi na kufuatilia hisia zako.\n'
                    'Mimi si mtaalamu wa tiba. Ukiwa hatarini, tafadhali piga simu ya dharura.'),
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
    this.onHelplines,
  });

  final ChatMessage message;
  final VoidCallback? onHelplines;
  final bool showAvatar;
  final int? picked;
  final ValueChanged<int>? onPick;
  final List<MoodEntry> week;

  @override
  Widget build(BuildContext context) {
    if (message.fromUser) return _Bubble(message: message);
    if (message.kind == ChatItemKind.note) {
      final ThemeData theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            message.text,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.extension<MindQuestColors>()!.textMuted),
          ),
        ),
      );
    }
    final Widget content = switch (message.kind) {
      ChatItemKind.text || ChatItemKind.note => _Bubble(message: message),
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
      ChatItemKind.support => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Bubble(message: message),
            if (onHelplines != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: FilledButton.tonalIcon(
                  key: const Key('chat-helplines'),
                  onPressed: onHelplines,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  icon: const Icon(Icons.phone_in_talk_outlined),
                  label: Text(
                      context.tr('See helplines', 'Ona nambari za msaada')),
                ),
              ),
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
              label: m.name(context.lang),
              child: InkWell(
                key: Key('chat-mood-${m.value}'),
                borderRadius: BorderRadius.circular(14),
                onTap: picked != null || onPick == null
                    ? null
                    : () => onPick!(m.value),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: picked == null || picked == m.value ? 1 : 0.35,
                  child: Container(
                    width: 60,
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                    decoration: BoxDecoration(
                      color: picked == m.value
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: picked == m.value
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                        width: picked == m.value ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(m.emoji, style: const TextStyle(fontSize: 22)),
                        // Shrinks a little for long names ("Vibaya sana")
                        // instead of cutting them off.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(m.name(context.lang),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 1),
                        ),
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
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
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
              Expanded(
                  child: Text(context.tr('Your week', 'Wiki yako'),
                      style: theme.textTheme.titleSmall)),
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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
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
            color: mine
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
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

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MindQuestColors mq = Theme.of(context).extension<MindQuestColors>()!;
    return Semantics(
      label: context.tr('Chipu is typing', 'Chipu anaandika'),
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
  const _Composer(
      {required this.controller, required this.sending, required this.onSend});

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
                decoration: InputDecoration(
                  hintText: context.tr('Type a message...', 'Andika ujumbe...'),
                  counterText: '',
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
              tooltip: context.tr('Send', 'Tuma'),
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
          ],
        ),
      ),
    );
  }
}
