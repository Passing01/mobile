import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Modèle d'état et télémétrie de débogage (FASO NAV - Étape 0)
/// Alimenté en temps réel par les services (GPS, Routing, API, Network)
/// et affiché sur l'écran de debug.
class DebugInfo extends ChangeNotifier {
  static final DebugInfo instance = DebugInfo._internal();

  DebugInfo._internal();

  // 1. Position GPS réelle
  Position? lastFix;
  DateTime? lastFixAt;

  // 2. Destination
  LatLng? destination;
  String destinationSource = '-'; // 'recherche' | 'lieu touché' | 'défaut'

  // 3. Itinéraire actif
  int routePoints = 0;
  double routeDistanceM = 0;
  double routeDurationS = 0;

  // 4. Test d'arrivée & Navigation (Étape 8)
  double? distanceToArrivalM;
  double arrivalThresholdM = 25.0;
  String navState = 'idle';
  double navAlongM = 0;
  double navRemainingM = 0;
  double navOffRouteM = 0;
  double navSpeedKmh = 0;

  // 5. Erreurs d'API
  String? lastApiError;
  DateTime? lastApiErrorAt;

  // 6. Connectivité réseau
  String networkStatus = 'Inconnu';

  /// Met à jour la position GPS
  void updateGpsFix(Position position) {
    lastFix = position;
    lastFixAt = DateTime.now();
    notifyListeners();
  }

  /// Définit la destination
  void setDestination(LatLng? dest, {required String source}) {
    destination = dest;
    destinationSource = source;
    notifyListeners();
  }

  /// Efface la destination
  void clearDestination() {
    destination = null;
    destinationSource = '-';
    notifyListeners();
  }

  /// Définit l'itinéraire courant
  void setRoute({
    required int points,
    required double distanceM,
    required double durationS,
  }) {
    routePoints = points;
    routeDistanceM = distanceM;
    routeDurationS = durationS;
    notifyListeners();
  }

  /// Efface l'itinéraire
  void clearRoute() {
    routePoints = 0;
    routeDistanceM = 0;
    routeDurationS = 0;
    distanceToArrivalM = null;
    notifyListeners();
  }

  /// Met à jour la distance restante à l'arrivée
  void updateArrivalDistance(double distM) {
    distanceToArrivalM = distM;
    notifyListeners();
  }

  /// Met à jour la progression de navigation en temps réel (Étape 8)
  void updateNavProgress({
    required String state,
    required double alongM,
    required double remainingM,
    required double offM,
    double speedKmh = 0,
  }) {
    navState = state;
    navAlongM = alongM;
    navRemainingM = remainingM;
    navOffRouteM = offM;
    navSpeedKmh = speedKmh;
    distanceToArrivalM = remainingM;
    notifyListeners();
  }

  /// Enregistre ou efface la dernière erreur API survenue
  void setLastApiError(String? error) {
    lastApiError = error;
    lastApiErrorAt = error != null ? DateTime.now() : null;
    notifyListeners();
  }

  /// Met à jour l'état du réseau
  void updateNetworkStatus(String status) {
    networkStatus = status;
    notifyListeners();
  }
}
