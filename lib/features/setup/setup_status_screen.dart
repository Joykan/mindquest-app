import 'package:flutter/material.dart';

import '../../core/config/env.dart';

/// Temporary first screen for step 3 (project setup).
///
/// It confirms the app builds and shows whether Supabase keys were supplied.
/// It is replaced by the Welcome screen (wireframe 01) in step 8.
class SetupStatusScreen extends StatelessWidget {
  const SetupStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool ready = Env.isConfigured;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'MindQuest',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Project setup complete',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(ready ? Icons.check_circle : Icons.info_outline),
                    const SizedBox(width: 8),
                    Text(
                      ready
                          ? 'Supabase connected'
                          : 'Supabase keys not set',
                      key: const Key('supabase-status'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
