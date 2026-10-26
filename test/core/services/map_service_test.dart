import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/config/map_config.dart';
import 'package:qvgestion_mobile/core/services/map_service.dart';
import 'package:qvgestion_mobile/core/theme/map_theme.dart';
import 'package:qvgestion_mobile/core/theme/theme_provider.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

void main() {
  group('MapConfig Tests', () {
    test('MapConfig.defaults retourne les styles souverains FASO NAV locaux', () {
      final config = MapConfig.defaults();
      expect(config.styleLight, 'assets/map/styles/faso-light.json');
      expect(config.styleDark, 'assets/map/styles/faso-dark.json');
      expect(config.styleSatellite, 'assets/map/styles/faso-satellite.json');
      expect(config.attribution, contains('OpenStreetMap'));
    });

    test('MapConfig.fromJson parse correctement la réponse du backend et assainit HTTP en HTTPS', () {
      final json = {
        'style_light': 'http://qvgestion-backend-production.up.railway.app/static/map/styles/faso-light.json',
        'style_dark': 'https://custom.server.com/static/map/styles/faso-dark.json',
        'style_satellite': 'https://custom.server.com/static/map/styles/faso-satellite.json',
        'attribution': '© OpenStreetMap contributors',
      };
      final config = MapConfig.fromJson(json);
      expect(config.styleLight, 'https://qvgestion-backend-production.up.railway.app/static/map/styles/faso-light.json');
      expect(config.styleDark, 'https://custom.server.com/static/map/styles/faso-dark.json');
      expect(config.styleSatellite, 'https://custom.server.com/static/map/styles/faso-satellite.json');
      expect(config.attribution, '© OpenStreetMap contributors');
    });
  });

  group('MapTheme Tests', () {
    test('MapTheme.light et dark fournissent les couleurs du cahier des charges', () {
      expect(MapTheme.light.route, '#1A73E8');
      expect(MapTheme.light.routeCasing, '#FFFFFF');
      expect(MapTheme.light.label, '#2B2A27');
      expect(MapTheme.light.halo, '#FFFFFF');
      expect(MapTheme.light.isDark, false);

      expect(MapTheme.dark.route, '#5AA2FF');
      expect(MapTheme.dark.routeCasing, '#0F1722');
      expect(MapTheme.dark.label, '#E8ECF2');
      expect(MapTheme.dark.halo, '#0F1722');
      expect(MapTheme.dark.isDark, true);

      expect(MapTheme.satellite.route, '#00E5FF');
      expect(MapTheme.satellite.label, '#FFFFFF');
      expect(MapTheme.satellite.halo, '#000000');
      expect(MapTheme.satellite.isDark, true);
    });

    test('MapTheme.colorForCategory attribue les couleurs franches normalisées', () {
      expect(MapTheme.colorForCategory('pharmacie'), '#00A651');
      expect(MapTheme.colorForCategory('hopital-sante'), '#E53935');
      expect(MapTheme.colorForCategory('maquis-restaurant'), '#FB8C00');
      expect(MapTheme.colorForCategory('station-service'), '#FDD835');
      expect(MapTheme.colorForCategory('administration'), '#1E88E5');
      expect(MapTheme.colorForCategory('banque-distributeur'), '#8E24AA');
      expect(MapTheme.colorForCategory('ecole-universite'), '#00ACC1');
      expect(MapTheme.colorForCategory('marche-commerce'), '#8D6E63');
    });

    test('MapTheme.strokeColorForCategory assure le contour sombre pour la station au soleil', () {
      expect(MapTheme.strokeColorForCategory('station-service'), '#2B2A27');
      expect(MapTheme.strokeColorForCategory('pharmacie'), '#FFFFFF');
      expect(MapTheme.strokeColorForCategory('hopital'), '#FFFFFF');
    });
  });

  group('ThemeModeNotifier & SatelliteModeNotifier Tests', () {
    test('ThemeModeNotifier bascule entre les modes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);

      container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('SatelliteModeNotifier active et désactive le mode satellite', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isSatelliteModeProvider), false);

      container.read(isSatelliteModeProvider.notifier).toggle();
      expect(container.read(isSatelliteModeProvider), true);

      container.read(isSatelliteModeProvider.notifier).toggle();
      expect(container.read(isSatelliteModeProvider), false);
    });
  });

  group('MapLibreMapService Tests', () {
    test('MapLibreMapService initialise et met en cache places, position et lieu sélectionné', () async {
      final service = MapLibreMapService();
      expect(service.isReady, false);
      expect(service.currentTheme, MapTheme.light);

      final place = PlaceModel(
        id: 1,
        nom: 'Pharmacie de la Paix',
        latitude: 12.3685,
        longitude: -1.5271,
        categorieId: 1,
      );

      // Met en cache les lieux, la position GPS et le lieu sélectionné
      await service.setPlaces([place]);
      await service.updateUserLocation(12.3685, -1.5271);
      await service.setSelectedPlace(place);

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
