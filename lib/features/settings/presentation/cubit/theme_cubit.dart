import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  static const String _themeKey = 'theme_preference';
  final SharedPreferences _prefs;

  ThemeCubit({SharedPreferences? prefs})
      : _prefs =
            prefs ?? (throw Exception('SharedPreferences not initialized')),
        super(const ThemeState());

  static Future<ThemeCubit> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeCubit(prefs: prefs);
  }

  Future<void> initialize([bool? initialIsDark]) async {
    if (initialIsDark != null) {
      // If we have an initial theme from the system, use it
      _updateTheme(initialIsDark);
    } else {
      // Otherwise, load from preferences
      final themeIndex = _prefs.getInt(_themeKey) ?? AppTheme.system.index;
      final theme = AppTheme.values[themeIndex];

      bool isDark;
      switch (theme) {
        case AppTheme.light:
          isDark = false;
          break;
        case AppTheme.dark:
          isDark = true;
          break;
        case AppTheme.system:
          isDark = PlatformDispatcher.instance.platformBrightness ==
              Brightness.dark;
          break;
      }

      _updateTheme(isDark, theme);
    }
  }

  Future<void> toggleTheme() async {
    final isDark = !state.isDarkMode;
    final theme = isDark ? AppTheme.dark : AppTheme.light;
    await _prefs.setInt(_themeKey, theme.index);
    _updateTheme(isDark, theme);
  }

  Future<void> setTheme(AppTheme theme) async {
    await _prefs.setInt(_themeKey, theme.index);
    final isDark = theme == AppTheme.dark ||
        (theme == AppTheme.system &&
            PlatformDispatcher.instance.platformBrightness ==
                Brightness.dark);
    _updateTheme(isDark, theme);
  }

  void _updateTheme(bool isDark, [AppTheme? theme]) {
    final newTheme = theme ?? (isDark ? AppTheme.dark : AppTheme.light);

    emit(state.copyWith(
      isDarkMode: isDark,
      themeMode: _getThemeMode(newTheme),
      appTheme: newTheme,
    ));
  }

  ThemeMode _getThemeMode(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }
}
