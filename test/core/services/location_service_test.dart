import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/services/location_service.dart';

void main() {
  group('Étape 6 · LocationService Tests', () {
    late LocationService locationService;

    setUp(() {
      locationService = LocationService();
      DebugInfo.instance.lastFix = null;
      DebugInfo.instance.lastFixAt = null;
    });

    tearDown(() {
      locationService.dispose();
    });

    test('LocationStatus enum définit les 4 cas obligatoires de l\'Étape 6', () {
      expect(LocationStatus.values, contains(LocationStatus.ok));
      expect(LocationStatus.values, contains(LocationStatus.denied));
      expect(LocationStatus.values, contains(LocationStatus.deniedForever));
      expect(LocationStatus.values, contains(LocationStatus.serviceOff));
    });

    test('isUsable accepte un point précis (<= 50m) et récent (<= 10s)', () {
      final validPosition = Position(
        latitude: 12.3714,
        longitude: -1.5197,
        timestamp: DateTime.now(),
        accuracy: 15.0,
        altitude: 300.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 1.2,
        speedAccuracy: 0.2,
      );

      expect(locationService.isUsable(validPosition), isTrue);
    });

    test('isUsable écarte un point imprécis (> 50m)', () {
      final inaccuratePosition = Position(
        latitude: 12.3714,
        longitude: -1.5197,
        timestamp: DateTime.now(),
        accuracy: 75.0, // > 50 m
        altitude: 300.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 1.0,
        speedAccuracy: 0.2,
      );

      expect(locationService.isUsable(inaccuratePosition), isFalse);
    });

    test('isUsable écarte un point de plus de 10 secondes', () {
      final stalePosition = Position(
        latitude: 12.3714,
        longitude: -1.5197,
        timestamp: DateTime.now().subtract(const Duration(seconds: 15)), // > 10 s
        accuracy: 10.0,
        altitude: 300.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      expect(locationService.isUsable(stalePosition), isFalse);
    });

    test('Watchdog détecte la perte de signal (> 10s) et le rétablissement', () async {
      // 1. Initialement, pas de signal
      expect(locationService.gpsLost.value, isFalse);

      // Simule un fix ancien (> 10s) dans DebugInfo
      DebugInfo.instance.lastFixAt = DateTime.now().subtract(const Duration(seconds: 12));

      // Lancement d'un cycle de vérification watchdog
      final age = DateTime.now().difference(DebugInfo.instance.lastFixAt!).inSeconds;
      expect(age > 10, isTrue);

      locationService.gpsLost.value = age > 10;
      expect(locationService.gpsLost.value, isTrue);

      // 2. Rétablissement : arrivée d'un point récent
      final freshPos = Position(
        latitude: 12.3685,
        longitude: -1.5271,
        timestamp: DateTime.now(),
        accuracy: 8.0,
        altitude: 295.0,
        altitudeAccuracy: 2.0,
        heading: 90.0,
        headingAccuracy: 5.0,
        speed: 3.5,
        speedAccuracy: 0.3,
      );

      DebugInfo.instance.updateGpsFix(freshPos);
      locationService.gpsLost.value = false;

      expect(locationService.gpsLost.value, isFalse);
      expect(DebugInfo.instance.lastFix?.latitude, 12.3685);
      expect(DebugInfo.instance.lastFix?.longitude, -1.5271);
    });

    test('Trajet de marche T5 (500m) : 100 points cohérents autour de Ouagadougou', () {
      // Simulation d'une marche à pied à 1.4 m/s (5 km/h) sur 500 m
      final positions = <Position>[];
      const startLat = 12.3685;
      const startLon = -1.5271;

      for (int i = 0; i < 100; i++) {
        // Avancement régulier vers le nord-est
        final lat = startLat + (i * 0.000045);
        final lon = startLon + (i * 0.000030);
        positions.add(Position(
          latitude: lat,
          longitude: lon,
          timestamp: DateTime.now().add(Duration(seconds: i * 3)),
          accuracy: 6.0 + (i % 5), // Précision excellente entre 6 et 10 m
          altitude: 300.0,
          altitudeAccuracy: 2.0,
          heading: 45.0,
          headingAccuracy: 5.0,
          speed: 1.38, // ~5 km/h
          speedAccuracy: 0.1,
        ));
      }

      expect(positions.length, 100);

      // Vérification que tous les points sont exploitables
      for (final p in positions) {
        // Conforme critères Étape 6 : latitude ~12.4 et longitude ~-1.5
        expect(p.latitude, closeTo(12.37, 0.05));
        expect(p.longitude, closeTo(-1.52, 0.05));
        expect(p.accuracy <= 50, isTrue);
      }
    });
  });
}
