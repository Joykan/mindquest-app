import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/logo_mark.dart';
import 'session_controller.dart';

/// Shown while the profile loads after sign-in, with a retry if it fails.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final MindQuestColors mq = Theme.of(context).extension<MindQuestColors>()!;
    return Scaffold(
      backgroundColor: mq.brand,
      body: Center(
        child: ListenableBuilder(
          listenable: session,
          builder: (BuildContext context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const LogoMark(size: 72),
              const SizedBox(height: 24),
              if (!session.failed)
                const CircularProgressIndicator(color: AppPalette.mint)
              else ...<Widget>[
                const Text("Couldn't load your profile.",
                    style: TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: session.refresh,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 48),
                    backgroundColor: AppPalette.mint,
                    foregroundColor: AppPalette.forest,
                  ),
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: session.signOut,
                  child: const Text('Back to start',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
