import 'package:flutter_riverpod/flutter_riverpod.dart';

/// États possibles de l'écran principal de cartographie Faso Nav
enum MapScreenState {
  explore, // Écran 1 : Carte fonctionnelle + Top Bar Faso Nav + Drawer "Explorer Ouaga & Environs"
  routeSelection, // Écran 2 : Sélection du mode de transport calculé en direct
  activeNavigation, // Écran 3 : Guidage actif pas-à-pas avec voix locale et manœuvres réelles
}

/// Notifier gérant l'état d'affichage de la carte et du guidage
class MapScreenStateNotifier extends Notifier<MapScreenState> {
  @override
  MapScreenState build() => MapScreenState.explore;

  void setState(MapScreenState newState) => state = newState;
  void toExplore() => state = MapScreenState.explore;
  void toRouteSelection() => state = MapScreenState.routeSelection;
  void toActiveNavigation() => state = MapScreenState.activeNavigation;
}

final mapScreenStateProvider =
    NotifierProvider<MapScreenStateNotifier, MapScreenState>(
  MapScreenStateNotifier.new,
);
