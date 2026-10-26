import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier pour gérer le mode de thème (Système, Clair, Sombre) avec persistance mémoire
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void toggle() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Notifier pour gérer l'activation du mode satellite haute résolution
class SatelliteModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setSatellite(bool value) => state = value;
}

final isSatelliteModeProvider =
    NotifierProvider<SatelliteModeNotifier, bool>(SatelliteModeNotifier.new);

