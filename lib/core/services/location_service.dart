import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service de gestion de la géolocalisation ponctuelle et en flux continu
class LocationService {
  /// S'assure que les permissions GPS sont accordées
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.deniedForever) {
      // Tente d'ouvrir les paramètres si nécessaire via permission_handler
      await Permission.locationWhenInUse.request();
    }
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  /// Position unique (bouton « Ma position »)
  Future<Position> current() => Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

  /// Flux continu pour la navigation en temps réel
  Stream<Position> stream() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5, // 5 mètres
        ),
      );
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
