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

/// Styles de carte disponibles dans FASO NAV
enum MapStyleMode {
  light,
  dark,
  satellite,
  faso3d,
}

/// Notifier pour gérer l'activation du mode satellite haute résolution
class SatelliteModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setSatellite(bool value) => state = value;
}

final isSatelliteModeProvider =
    NotifierProvider<SatelliteModeNotifier, bool>(SatelliteModeNotifier.new);

/// Notifier pour gérer l'activation du mode carte 3D Burkina Faso (bâtiments, monuments, échangeurs)
class Map3dModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set3d(bool value) => state = value;
}

final is3dMapModeProvider =
    NotifierProvider<Map3dModeNotifier, bool>(Map3dModeNotifier.new);

/// Notifier pour activer/désactiver la Vue Radar Live (style véhicule autonome) en navigation
class RadarViewNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setEnabled(bool value) => state = value;
}

final isRadarViewEnabledProvider =
    NotifierProvider<RadarViewNotifier, bool>(RadarViewNotifier.new);

/// Sélectionne proprement un style de carte complet sans ambiguïté entre les modes
void selectMapStyleMode(WidgetRef ref, MapStyleMode mode) {
  switch (mode) {
    case MapStyleMode.light:
      ref.read(isSatelliteModeProvider.notifier).setSatellite(false);
      ref.read(is3dMapModeProvider.notifier).set3d(false);
      ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      break;
    case MapStyleMode.dark:
      ref.read(isSatelliteModeProvider.notifier).setSatellite(false);
      ref.read(is3dMapModeProvider.notifier).set3d(false);
      ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      break;
    case MapStyleMode.satellite:
      ref.read(is3dMapModeProvider.notifier).set3d(false);
      ref.read(isSatelliteModeProvider.notifier).setSatellite(true);
      break;
    case MapStyleMode.faso3d:
      ref.read(isSatelliteModeProvider.notifier).setSatellite(false);
      ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      ref.read(is3dMapModeProvider.notifier).set3d(true);
      break;
  }
}

