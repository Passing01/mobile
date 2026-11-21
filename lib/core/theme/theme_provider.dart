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

/// Modes de vue disponibles pendant la navigation active :
/// - [buildings3d] : Immersion entre les bâtiments 3D le long de la rue (tilt ~64°, zoom ~18.2)
/// - [radar] : Cockpit Radar 3D temps réel façon voiture autonome
/// - [mapTop] : Vue carte classique aérienne
enum NavigationViewMode {
  buildings3d,
  radar,
  mapTop,
}

/// Notifier gérant la vue active pendant un trajet guidé.
class NavigationViewModeNotifier extends Notifier<NavigationViewMode> {
  @override
  NavigationViewMode build() => NavigationViewMode.buildings3d;

  void setMode(NavigationViewMode mode) => state = mode;
}

final navigationViewModeProvider =
    NotifierProvider<NavigationViewModeNotifier, NavigationViewMode>(
  NavigationViewModeNotifier.new,
);

/// Notifier pour activer/désactiver la Vue Radar Live (style véhicule autonome) en navigation
class RadarViewNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    final next = !state;
    state = next;
    ref.read(navigationViewModeProvider.notifier).setMode(
          next ? NavigationViewMode.radar : NavigationViewMode.buildings3d,
        );
  }

  void setEnabled(bool value) {
    state = value;
    ref.read(navigationViewModeProvider.notifier).setMode(
          value ? NavigationViewMode.radar : NavigationViewMode.buildings3d,
        );
  }
}

final isRadarViewEnabledProvider =
    NotifierProvider<RadarViewNotifier, bool>(RadarViewNotifier.new);

/// Bascule proprement entre les 3 modes de navigation :
/// 3D entre bâtiments, Radar Live ou Vue Carte classique.
void selectNavigationViewMode(WidgetRef ref, NavigationViewMode mode) {
  if (mode == NavigationViewMode.radar) {
    ref.read(isRadarViewEnabledProvider.notifier).setEnabled(true);
  } else {
    ref.read(isRadarViewEnabledProvider.notifier).setEnabled(false);
    ref.read(navigationViewModeProvider.notifier).setMode(mode);
  }
}

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

