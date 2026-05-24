import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum AppTheme { light, dark, system }

class ThemeState extends Equatable {
  final ThemeMode themeMode;
  final bool isDarkMode;
  final AppTheme appTheme;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.isDarkMode = false,
    this.appTheme = AppTheme.system,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isDarkMode,
    AppTheme? appTheme,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      appTheme: appTheme ?? this.appTheme,
    );
  }

  @override
  List<Object> get props => [themeMode, isDarkMode, appTheme];
}
