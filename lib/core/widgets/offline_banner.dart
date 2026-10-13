import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../offline/offline_store.dart';
import '../theme/app_colors.dart';

/// A slim bar above the bottom navigation while the phone is offline or
/// something is waiting to sync. Tapping it tries again.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.status, this.onRetry});

  final ConnectionStatus status;
  final VoidCallback? onRetry;

  /// "14:05", or "12 Oct 14:05" if it wasn't today (Nairobi time).
  static String savedTime(String language, DateTime savedAt, [DateTime? now]) {
    DateTime nairobi(DateTime d) => d.toUtc().add(const Duration(hours: 3));
    final DateTime s = nairobi(savedAt);
    final DateTime n = nairobi(now ?? DateTime.now());
    final bool today = s.year == n.year && s.month == n.month && s.day == n.day;
    return today ? clock(s) : '${shortDate(language, s)} ${clock(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MindQuestColors mq = theme.extension<MindQuestColors>()!;
    return ListenableBuilder(
      listenable: status,
      builder: (BuildContext context, _) {
        if (!status.offline && status.pending == 0) {
          return const SizedBox.shrink();
        }
        final String lang = context.lang;
        final int n = status.pending;
        final DateTime? at = status.savedAt;
        final String text = <String>[
          if (status.offline)
            at == null
                ? tr(lang, "You're offline.", 'Huna mtandao.')
                : tr(
                    lang,
                    "You're offline. Showing what was saved at ${savedTime(lang, at)}.",
                    'Huna mtandao. Unaona yaliyohifadhiwa saa ${savedTime(lang, at)}.'),
          if (n > 0)
            status.offline
                ? tr(lang, '$n waiting to sync.', '$n zinasubiri kutumwa.')
                : tr(lang, 'Syncing $n saved on your phone...',
                    'Inatuma $n zilizohifadhiwa kwenye simu...'),
        ].join(' ');
        return Material(
          key: const Key('offline-banner'),
          color: mq.surfaceSoft,
          child: InkWell(
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                      status.offline
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_upload_outlined,
                      size: 18,
                      color: mq.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(text, style: theme.textTheme.bodySmall)),
                  if (onRetry != null && status.offline)
                    Text(context.tr('Retry', 'Jaribu tena'),
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
