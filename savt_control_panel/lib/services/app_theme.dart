import 'package:flutter/material.dart';
import 'preferences_service.dart';

class AppTheme {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  
  static void loadTheme() {
    final themeStr = PreferencesService.getThemeModeString();
    if (themeStr != null) {
      themeNotifier.value = ThemeMode.values.firstWhere(
        (e) => e.toString() == themeStr,
        orElse: () => ThemeMode.light,
      );
    }
  }
  
  static Future<void> saveTheme(ThemeMode mode) async {
    await PreferencesService.saveThemeModeString(mode.toString());
  }
}
