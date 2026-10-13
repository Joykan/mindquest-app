import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_colors.dart';
import 'reminders.dart';

String _clock(TimeOfDay t) =>
    clock(DateTime(2000, 1, 1, t.hour, t.minute));

/// Turns reminders on, explaining what to do if notifications are blocked.
Future<void> _turnOn(BuildContext context, ReminderController reminders) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final String lang = context.lang;
  final bool ok = await reminders.enable();
  messenger.showSnackBar(SnackBar(
    content: Text(ok
        ? tr(
            lang,
            "Done! Chipu will remind you at ${_clock(reminders.time)} if you haven't checked in.",
            'Sawa! Chipu atakukumbusha saa ${_clock(reminders.time)} kama hujarekodi hisia.')
        : tr(
            lang,
            "Notifications are blocked for MindQuest. Turn them on in your phone's settings.",
            'Arifa za MindQuest zimezuiwa. Ziwashe kwenye mipangilio ya simu yako.')),
  ));
}

/// Home card that asks once: "Want a daily reminder?"
class ReminderPrompt extends StatelessWidget {
  const ReminderPrompt({super.key, required this.reminders});

  final ReminderController reminders;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return ListenableBuilder(
      listenable: reminders,
      builder: (BuildContext context, _) {
        if (!reminders.shouldAsk) return const SizedBox.shrink();
        return Card(
          key: const Key('reminder-prompt'),
          color: mq.surfaceSoft,
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text('🔔', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          context.tr('Want a daily reminder?',
                              'Ungependa kikumbusho cha kila siku?'),
                          style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(context.tr(
                      'Chipu can remind you to check in at ${_clock(reminders.time)} on days you haven\'t. '
                          'You can change the time in Profile.',
                      'Chipu anaweza kukukumbusha kurekodi hisia saa ${_clock(reminders.time)} siku ambazo hujarekodi. '
                          'Unaweza kubadilisha muda kwenye Wasifu.')),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      key: const Key('reminder-not-now'),
                      onPressed: reminders.dismiss,
                      child: Text(context.tr('Not now', 'Si sasa')),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      key: const Key('reminder-turn-on'),
                      // The app's buttons are full width; this one sits in a row.
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 44)),
                      onPressed: () => _turnOn(context, reminders),
                      child: Text(context.tr('Turn on', 'Washa')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Profile setting: reminder on or off, and its time.
class ReminderSettingsTile extends StatelessWidget {
  const ReminderSettingsTile({super.key, required this.reminders});

  final ReminderController reminders;

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: reminders.time,
      helpText: context.tr('Reminder time', 'Muda wa kikumbusho'),
    );
    if (picked != null) await reminders.setTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: reminders,
      builder: (BuildContext context, _) {
        if (!reminders.supported) return const SizedBox.shrink();
        final bool on = reminders.enabled;
        return Column(
          children: <Widget>[
            SwitchListTile(
              key: const Key('reminder-switch'),
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(
                  context.tr('Daily reminder', 'Kikumbusho cha kila siku')),
              subtitle: Text(on
                  ? context.tr(
                      "At ${_clock(reminders.time)}, only on days you haven't checked in",
                      'Saa ${_clock(reminders.time)}, siku ambazo hujarekodi hisia tu')
                  : context.tr('Off', 'Kimezimwa')),
              value: on,
              onChanged: (bool v) =>
                  v ? _turnOn(context, reminders) : reminders.disable(),
            ),
            if (on)
              ListTile(
                key: const Key('reminder-time'),
                leading: const Icon(Icons.schedule),
                title: Text(context.tr('Reminder time', 'Muda wa kikumbusho')),
                trailing: Text(_clock(reminders.time),
                    style: Theme.of(context).textTheme.titleMedium),
                onTap: () => _pickTime(context),
              ),
            if (on)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: TextButton.icon(
                    key: const Key('reminder-test'),
                    onPressed: reminders.sendTest,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(context.tr(
                        'Send a test reminder', 'Tuma kikumbusho cha majaribio')),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
