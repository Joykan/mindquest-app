import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// A white card with a title, used for every block on the dashboard.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: mq.textMuted)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// A big number with a label, e.g. "42 Active students".
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.icon,
    this.alert = false,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData? icon;

  /// Shown in the crisis colour (crisis responses).
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final Color accent = alert ? mq.crisis : theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      color: alert ? mq.crisisSurface : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: mq.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: alert ? mq.crisis : null)),
            if (detail != null)
              Text(detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: mq.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// One labelled horizontal bar: label, bar, value.
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.valueLabel,
    this.color,
    this.leading,
  });

  final String label;
  final num value;
  final num max;
  final String? valueLabel;
  final Color? color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final double fraction =
        max <= 0 ? 0 : (value / max).clamp(0, 1).toDouble();
    return Semantics(
      label: '$label: ${valueLabel ?? value}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: 8),
            ],
            SizedBox(
              width: 150,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 12,
                  backgroundColor: mq.surfaceSoft,
                  color: color ?? theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: Text(valueLabel ?? '$value',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelLarge),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple bar chart with one bar per day.
class DayBars extends StatelessWidget {
  const DayBars({
    super.key,
    required this.values,
    required this.labels,
    required this.tooltips,
    this.max,
    this.color,
    this.height = 140,
  });

  /// Null means no data that day (no bar).
  final List<double?> values;

  /// Shown under some of the bars (every few days when there are many).
  final List<String> labels;
  final List<String> tooltips;

  /// Top of the scale; defaults to the biggest value.
  final double? max;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    final double top = max ??
        values.fold<double>(0, (double m, double? v) => v != null && v > m ? v : m);
    final int every = values.length <= 10 ? 1 : (values.length / 7).ceil();
    return Column(
      children: <Widget>[
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int i = 0; i < values.length; i++)
                Expanded(
                  child: Tooltip(
                    message: tooltips[i],
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: values.length > 40 ? 0.5 : 2),
                      child: Container(
                        height: top <= 0 || values[i] == null
                            ? 2.0
                            : (height * (values[i]! / top))
                                .clamp(2.0, height)
                                .toDouble(),
                        decoration: BoxDecoration(
                          color: values[i] == null || values[i] == 0
                              ? mq.surfaceSoft
                              : (color ?? theme.colorScheme.primary),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            for (int i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  i % every == 0 || i == labels.length - 1 ? labels[i] : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style:
                      theme.textTheme.labelSmall?.copyWith(color: mq.textMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Shown when a page couldn't load, with a retry.
class LoadProblem extends StatelessWidget {
  const LoadProblem({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

/// Asks before deleting something.
Future<bool> confirmDelete(BuildContext context,
    {required String title, required String message}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        TextButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context)
                        .extension<MindQuestColors>()!
                        .crisis))),
      ],
    ),
  );
  return ok ?? false;
}

/// Shows a short message, replacing the one already showing.
void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
