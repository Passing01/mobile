import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/config/map_config.dart';
import 'package:qvgestion_mobile/core/services/smooth_motion_interpolator.dart';
import 'package:qvgestion_mobile/core/services/voice_guide_service.dart';
import 'package:qvgestion_mobile/core/theme/map_theme.dart';
import 'package:qvgestion_mobile/core/theme/theme_provider.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/radar_scene_model.dart';
import 'package:qvgestion_mobile/features/map/presentation/screens/home_map_screen.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_radar_hud_view.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'package:qvgestion_mobile/features/weather/data/models/weather_model.dart';
import 'package:qvgestion_mobile/features/weather/presentation/providers/weather_providers.dart';

class _TestActiveRouteNotifier extends ActiveRouteNotifier {
  final RouteModel initialRoute;
  _TestActiveRouteNotifier(this.initialRoute);

  @override
  AsyncValue<RouteModel?> build() => AsyncValue.data(initialRoute);

  @override
  Future<RouteModel?> calculate({
    required CoordinateModel origin,
    required CoordinateModel destination,
    List<CoordinateModel>? waypoints,
    required String mode,
  }) async {
    state = AsyncValue.data(initialRoute);
    return initialRoute;
  }
}

void main() {
  group('MapConfig & MapTheme 3D Tests', () {
    test('MapConfig expose style3d par défaut et depuis JSON backend', () {
      final defaults = MapConfig.defaults();
      expect(defaults.style3d, 'assets/map/styles/faso-3d.json');

      final parsed = MapConfig.fromJson({
        'style_light': 'https://cdn.example.com/light.json',
        'style_dark': 'https://cdn.example.com/dark.json',
        'style_satellite': 'https://cdn.example.com/sat.json',
        'style_3d': 'http://qvgestion-backend-production.up.railway.app/static/map/styles/faso-3d.json',
        'attribution': '© OpenStreetMap',
      });
      expect(
        parsed.style3d,
        'https://qvgestion-backend-production.up.railway.app/static/map/styles/faso-3d.json',
      );
      expect(MapTheme.faso3d.is3D, true);
    });

    test('is3dMapModeProvider et isRadarViewEnabledProvider basculent correctement', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(is3dMapModeProvider), false);
      container.read(is3dMapModeProvider.notifier).toggle();
      expect(container.read(is3dMapModeProvider), true);

      expect(container.read(isRadarViewEnabledProvider), false);
      container.read(isRadarViewEnabledProvider.notifier).setEnabled(true);
      expect(container.read(isRadarViewEnabledProvider), true);
    });
  });

  group('SmoothMotionInterpolator Tests', () {
    test('shortestAngleDelta gère correctement le passage 350° -> 10°', () {
      expect(SmoothMotionInterpolator.shortestAngleDelta(350.0, 10.0), closeTo(20.0, 0.01));
      expect(SmoothMotionInterpolator.shortestAngleDelta(10.0, 350.0), closeTo(-20.0, 0.01));
    });

    test('pushTarget et sampleAt interpolent la position et le cap sans saut', () {
      final interp = SmoothMotionInterpolator();
      interp.pushTarget(
        latitude: 12.3685,
        longitude: -1.5271,
        bearingDeg: 350.0,
        speedKmh: 20.0,
      );
      interp.pushTarget(
        latitude: 12.3695,
        longitude: -1.5261,
        bearingDeg: 10.0,
        speedKmh: 40.0,
        duration: const Duration(milliseconds: 1000),
      );

      final mid = interp.sampleAt(DateTime.now().add(const Duration(milliseconds: 500)));
      expect(mid, isNotNull);
      expect(mid!.latitude, greaterThan(12.3685));
      expect(mid.latitude, lessThan(12.3695));
      expect(mid.speedKmh, greaterThan(20.0));
      expect(mid.speedKmh, lessThan(40.0));
    });
  });

  group('RadarSceneModel Tests', () {
    test('buildFallbackMonumentsGeoJson contient les monuments ancrés au sol (min_height=0)', () {
      final geojson = RadarSceneModel.buildFallbackMonumentsGeoJson();
      expect(geojson['type'], 'FeatureCollection');
      final features = geojson['features'] as List<dynamic>;
      expect(features.length, greaterThanOrEqualTo(12));
      for (final f in features) {
        final props = f['properties'] as Map;
        expect(props['min_height'], 0.0);
      }
      expect(
        features.any((f) => (f['properties'] as Map)['name'].toString().contains('Échangeur')),
        true,
      );
    });
  });

  group('VoiceGuide Neural TTS Tests', () {
    test('GuideStep.audioFor pointe vers /guidance/tts en Français et Mooré sans fichiers figés', () {
      const step = GuideStep(
        order: 1,
        along: 400.0,
        instruction: 'Tournez à droite',
        maneuverType: 'turn_right',
        distanceMeters: 400.0,
        confidence: 3,
        anchorName: 'Pharmacie Yennenga',
      );

      final frUrl = step.audioFor(dist: 200, language: 'fr');
      final mosUrl = step.audioFor(dist: 200, language: 'mos');

      expect(frUrl, contains('/guidance/tts'));
      expect(frUrl, contains('lang=fr'));
      expect(mosUrl, contains('/guidance/tts'));
      expect(mosUrl, contains('lang=mos'));
      expect(mosUrl, isNot(contains('assets/audio/mos/')));
    });
  });

  group('HomeMapScreen Sélecteur 3D & Vue Radar Live Widget Tests', () {
    const sampleCategories = [
      CategoryModel(
        id: 1,
        nom: 'Pharmacie',
        slug: 'pharmacie',
        icone: 'local_pharmacy',
        labels: {'fr': 'Pharmacies'},
      ),
    ];
    const samplePlace = PlaceModel(
      id: 1,
      nom: 'Monument des Martyrs',
      categorieId: 1,
      latitude: 12.3160,
      longitude: -1.5030,
      quartier: 'Ouaga 2000',
    );
    const sampleRoute = RouteModel(
      mode: 'motorcycle',
      distanceMeters: 1200.0,
      durationSeconds: 180,
      durationFormatted: '3 min',
      geometry: [
        [12.3685, -1.5271],
        [12.3650, -1.5240],
        [12.3610, -1.5200],
      ],
      boundingBox: [12.3610, -1.5271, 12.3685, -1.5200],
      maneuvers: [
        ManeuverModel(
          order: 1,
          instruction: 'Continuez vers l\'échangeur',
          maneuverType: 'depart',
          distanceMeters: 400.0,
          durationSeconds: 60,
          location: CoordinateModel(lat: 12.3685, lon: -1.5271),
        ),
      ],
      engine: 'osrm',
    );
    const sampleWeather = WeatherModel(
      latitude: 12.3685,
      longitude: -1.5271,
      temperatureCelsius: 33.0,
      apparentTemperatureCelsius: 35.0,
      humidityPercent: 35,
      precipitationMm: 0.0,
      windSpeedKmh: 10.0,
      windGustsKmh: 14.0,
      weatherCode: 1,
      description: 'Ensoleillé',
      drivingAdvisory: 'Bonne visibilité',
    );

    Widget buildTestApp() {
      return ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) async => sampleCategories),
          nearbyPlacesProvider.overrideWith((ref) async => [samplePlace]),
          selectedPlaceProvider.overrideWith(SelectedPlaceNotifier.new),
          activeRouteProvider.overrideWith(() => _TestActiveRouteNotifier(sampleRoute)),
          multiModeRoutesProvider.overrideWith((ref) async => {'motorcycle': sampleRoute}),
          currentWeatherProvider.overrideWith((ref) async => sampleWeather),
        ],
        child: const MaterialApp(home: HomeMapScreen()),
      );
    }

    testWidgets('Le sélecteur de carte permet de choisir Faso 3D et la Vue Radar Live',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(480, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Ouvrir le sélecteur de type de carte
      final selectorBtn = find.byKey(const Key('fab_map_style_selector'));
      expect(selectorBtn, findsOneWidget);
      await tester.tap(selectorBtn);
      await tester.pumpAndSettle();

      expect(find.text('Choisir le type de carte'), findsOneWidget);
      expect(find.text('Faso 3D'), findsOneWidget);

      // Activer l'option Vue Radar Live dans le sélecteur
      final radarSwitch = find.byKey(const Key('switch_radar_view_mode'));
      await tester.ensureVisible(radarSwitch);
      await tester.tap(radarSwitch);
      await tester.pumpAndSettle();

      // Sélectionner la carte Faso 3D
      await tester.tap(find.byKey(const Key('map_style_option_3d')));
      await tester.pumpAndSettle();

      // Lancer un itinéraire puis démarrer la navigation -> la Vue Radar Live s'affiche
      await tester.tap(find.text('Héros Nationaux'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Itinéraire Moto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Démarrer la navigation vocale'));
      await tester.pumpAndSettle();

      expect(find.byType(FasoRadarHudView), findsOneWidget);
      expect(find.byKey(const Key('btn_exit_radar_view')), findsOneWidget);

      // Revenir en 1 tap vers la carte 3D
      await tester.tap(find.byKey(const Key('btn_exit_radar_view')));
      await tester.pumpAndSettle();
      expect(find.byType(FasoRadarHudView), findsNothing);
    });
  });
}

