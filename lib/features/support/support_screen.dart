import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/mascot.dart';
import '../chat/chat_models.dart';
import '../chat/crisis_sheet.dart';

/// Kenya's emergency numbers, shown if the helplines can't be loaded.
const List<Helpline> emergencyHelplines = <Helpline>[
  Helpline(name: 'Emergency services', phone: '999', description: 'Police, ambulance and fire'),
  Helpline(name: 'Emergency services', phone: '112', description: 'Works from any mobile phone'),
];

/// Support: helplines with Call buttons, a guided box-breathing exercise and
/// the 5-4-3-2-1 grounding exercise. Opened from Home, Profile and insights.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.loadHelplines, this.onTalk});

  final Future<List<Helpline>> Function() loadHelplines;
  final VoidCallback? onTalk;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final Future<List<Helpline>> _lines = _load();

  Future<List<Helpline>> _load() async {
    try {
      final List<Helpline> lines = await widget.loadHelplines();
      return lines.isEmpty ? emergencyHelplines : lines;
    } catch (_) {
      return emergencyHelplines;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mq.crisisSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.favorite, color: mq.crisis, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text("You're not alone", style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Talking to someone helps. These lines are free and confidential. '
                        "If you're in danger right now, call 999 or 112.",
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Kenya helplines', style: theme.textTheme.titleMedium),
          FutureBuilder<List<Helpline>>(
            future: _lines,
            builder: (BuildContext context, AsyncSnapshot<List<Helpline>> snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                children: <Widget>[for (final Helpline l in snap.data!) HelplineRow(line: l)],
              );
            },
          ),
          const SizedBox(height: 20),
          const BoxBreathingCard(),
          const SizedBox(height: 12),
          const GroundingCard(),
          if (widget.onTalk != null) ...<Widget>[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onTalk,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Talk to Chipu'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Box breathing: in 4, hold 4, out 4, hold 4, four rounds. A circle grows as
/// you breathe in and shrinks as you breathe out.
class BoxBreathingCard extends StatefulWidget {
  const BoxBreathingCard({super.key});

  static const int rounds = 4;

  @override
  State<BoxBreathingCard> createState() => _BoxBreathingCardState();
}

class _BoxBreathingCardState extends State<BoxBreathingCard> with SingleTickerProviderStateMixin {
  late final AnimationController _box = AnimationController(vsync: this, duration: const Duration(seconds: 16))
    ..addStatusListener(_onStatus);
  int _round = 0;
  bool _running = false;
  bool _finished = false;

  static const List<String> _phases = <String>['Breathe in', 'Hold', 'Breathe out', 'Hold'];

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_running) return;
    if (_round + 1 >= BoxBreathingCard.rounds) {
      setState(() {
        _running = false;
        _finished = true;
      });
    } else {
      setState(() => _round++);
      _box.forward(from: 0);
    }
  }

  void _start() {
    setState(() {
      _round = 0;
      _running = true;
      _finished = false;
    });
    _box.forward(from: 0);
  }

  void _stop() {
    _box.stop();
    setState(() => _running = false);
  }

  @override
  void dispose() {
    _box.dispose();
    super.dispose();
  }

  /// Circle size from 0.55 (empty lungs) to 1 (full).
  double _scale(double t) {
    final double p = (t * 4) % 1;
    return switch ((t * 4).floor().clamp(0, 3)) {
      0 => 0.55 + 0.45 * Curves.easeInOut.transform(p),
      1 => 1,
      2 => 1 - 0.45 * Curves.easeInOut.transform(p),
      _ => 0.55,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Card(
      key: const Key('box-breathing'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('🌬️', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Text('Box breathing', style: theme.textTheme.titleMedium)),
                if (_running)
                  Text('Round ${_round + 1} of ${BoxBreathingCard.rounds}', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: AnimatedBuilder(
                animation: _box,
                builder: (BuildContext context, _) {
                  final double t = _box.value;
                  final int phase = (t * 4).floor().clamp(0, 3);
                  final int secondsLeft = 4 - ((t * 16).floor() % 4);
                  final double size = 170 * (_running ? _scale(t) : 0.55);
                  return Center(
                    child: Container(
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[AppPalette.mint, theme.colorScheme.primary],
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(color: AppPalette.mint.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 4),
                        ],
                      ),
                      child: _running
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(_phases[phase],
                                    style: theme.textTheme.titleSmall?.copyWith(color: Colors.white)),
                                Text('$secondsLeft',
                                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
                              ],
                            )
                          : _finished
                              ? const Mascot(pose: MascotPose.happy, size: 64)
                              : const Icon(Icons.air, color: Colors.white, size: 36),
                    ),
                  );
                },
              ),
            ),
            Text(
              _finished
                  ? 'Well done. Notice how your body feels now.'
                  : 'Breathe in for 4, hold for 4, breathe out for 4, hold for 4. Four rounds, about a minute.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('breathing-button'),
              onPressed: _running ? _stop : _start,
              child: Text(_running ? 'Stop' : (_finished ? 'Go again' : 'Start breathing')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5-4-3-2-1 grounding: tap each step when done.
class GroundingCard extends StatefulWidget {
  const GroundingCard({super.key});

  @override
  State<GroundingCard> createState() => _GroundingCardState();
}

class _GroundingCardState extends State<GroundingCard> {
  static const List<(String, String)> _steps = <(String, String)>[
    ('👀', '5 things you can see'),
    ('✋', '4 things you can touch'),
    ('👂', '3 things you can hear'),
    ('👃', '2 things you can smell'),
    ('👅', '1 thing you can taste'),
  ];
  final Set<int> _done = <int>{};

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final bool all = _done.length == _steps.length;
    return Card(
      key: const Key('grounding'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('🌿', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Text('5-4-3-2-1 grounding', style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'When worry spirals, bring yourself back to now. Name each one slowly, then tap it.',
              style: theme.textTheme.bodySmall?.copyWith(color: mq.textMuted),
            ),
            for (int i = 0; i < _steps.length; i++)
              CheckboxListTile(
                key: Key('ground-$i'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                value: _done.contains(i),
                onChanged: (bool? v) => setState(() => v == true ? _done.add(i) : _done.remove(i)),
                title: Text('${_steps[i].$1}  ${_steps[i].$2}'),
              ),
            if (all)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Well done. You are here, right now. 💚', style: theme.textTheme.titleSmall),
              ),
          ],
        ),
      ),
    );
  }
}
