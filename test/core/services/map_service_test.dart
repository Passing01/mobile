import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/config/map_config.dart';
import 'package:qvgestion_mobile/core/services/map_service.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

void main() {
  group('MapConfig Tests', () {
    test('MapConfig.defaults retourne les styles et l\'attribution OpenFreeMap/OSM', () {
      final config = MapConfig.defaults();
      expect(config.styleLight, 'https://tiles.openfreemap.org/styles/liberty');
      expect(config.styleDark, 'https://tiles.openfreemap.org/styles/bright');
      expect(config.attribution, '© OpenStreetMap contributors');
    });

    test('MapConfig.fromJson parse correctement la réponse du backend', () {
      final json = {
        'style_light': 'https://custom.server.com/styles/liberty',
        'style_dark': 'https://custom.server.com/styles/dark',
        'attribution': '© OpenStreetMap contributors',
      };
      final config = MapConfig.fromJson(json);
      expect(config.styleLight, 'https://custom.server.com/styles/liberty');
      expect(config.styleDark, 'https://custom.server.com/styles/dark');
      expect(config.attribution, '© OpenStreetMap contributors');
    });
  });

  group('MapLibreMapService Tests', () {
    test('MapLibreMapService initialise et met en cache places et routes', () async {
      final service = MapLibreMapService();
      expect(service.isReady, false);

      final place = PlaceModel(
        id: 1,
        nom: 'Pharmacie de la Paix',
        latitude: 12.3685,
        longitude: -1.5271,
        categorieId: 1,
      );

      // Met en cache les lieux sans crash même sans contrôleur attaché
      await service.setPlaces([place]);

      final route = RouteModel(
        mode: 'motorcycle',
        distanceMeters: 2500,
        durationSeconds: 300,
        durationFormatted: '5 min',
        geometry: [
          [12.3685, -1.5271],
          [12.3700, -1.5200],
        ],
        boundingBox: [12.3685, -1.5271, 12.3700, -1.5200],
        maneuvers: [],
        engine: 'osrm',
      );

      await service.setRoute(route);
      await service.clearRoute();
      await service.moveCamera(lat: 12.37, lng: -1.52);
      await service.animateCamera(lat: 12.37, lng: -1.52);
      await service.fitBounds(minLat: 12.30, minLon: -1.55, maxLat: 12.40, maxLon: -1.50);

      final queried = await service.queryPlaceAt(const Point(100.0, 200.0));
      expect(queried, isNull);

      service.dispose();
      expect(service.isReady, false);
    });
  });
}
