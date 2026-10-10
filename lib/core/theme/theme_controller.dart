import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's appearance choice: follow the phone, always light, or always
/// dark. Saved on the device so it survives restarts.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.system]);

  static const String _key = 'theme_mode';

  /// Reads the saved choice. Falls back to following the phone.
  static Future<ThemeController> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_key);
      return ThemeController(
        ThemeMode.values.firstWhere(
          (ThemeMode m) => m.name == saved,
          orElse: () => ThemeMode.system,
        ),
      );
    } catch (_) {
      return ThemeController();
    }
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // Not saved, but the change still applies for this session.
    }
  }
}
