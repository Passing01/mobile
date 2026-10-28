import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/core/services/location_service.dart';
import 'package:qvgestion_mobile/features/map/presentation/screens/home_map_screen.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_map.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/weather/data/models/weather_model.dart';
import 'package:qvgestion_mobile/features/weather/presentation/providers/weather_providers.dart';

class FakeLocationService extends LocationService {
  final LocationStatus forcedStatus;
  FakeLocationService({this.forcedStatus = LocationStatus.ok});

  @override
  Future<LocationStatus> ensurePermission() async {
    statusNotifier.value = forcedStatus;
    return forcedStatus;
  }

  @override
  Future<void> start() async {
    last = Position(
      latitude: 12.3685,
      longitude: -1.5271,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 300.0,
      altitudeAccuracy: 5.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 1.0,
      speedAccuracy: 0.1,
    );
  }
}

class FakeGpsLostNotifier extends GpsLostNotifier {
  final bool initialLost;
  FakeGpsLostNotifier({this.initialLost = false}) : super();

  @override
  bool build() {
    return initialLost;
  }
}

void main() {
  const sampleCategories = [
    CategoryModel(
      id: 1,
      nom: 'Pharmacie',
      slug: 'pharmacie',
      icone: 'local_pharmacy',
      labels: {'fr': 'Pharmacies'},
    ),
  ];

  const sampleWeather = WeatherModel(
    latitude: 12.3685,
    longitude: -1.5271,
    temperatureCelsius: 30.0,
    apparentTemperatureCelsius: 32.0,
    humidityPercent: 40,
    precipitationMm: 0.0,
    windSpeedKmh: 10.0,
    windGustsKmh: 15.0,
    weatherCode: 1,
    description: 'Ensoleillé',
    drivingAdvisory: 'Trafic normal',
  );

  Widget createTestWidget({
    LocationStatus status = LocationStatus.ok,
    bool gpsLost = false,
  }) {
    return ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService(forcedStatus: status)),
        if (gpsLost)
          gpsLostProvider.overrideWith(() => FakeGpsLostNotifier(initialLost: true)),
        categoriesProvider.overrideWith((ref) async => sampleCategories),
        nearbyPlacesProvider.overrideWith((ref) async => []),
        currentWeatherProvider.overrideWith((ref) async => sampleWeather),
      ],
      child: const MaterialApp(
        home: HomeMapScreen(),
      ),
    );
  }

  group('Étape 6 · Tests UI Position Réelle & Suivi GPS', () {
    testWidgets('Bouton de recentrage fab_recenter présent sur la carte', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final fabRecenter = find.byKey(const Key('fab_recenter'));
      expect(fabRecenter, findsOneWidget);
    });

    testWidgets('FasoMap configure le suivi MyLocationTrackingMode', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final fasoMapFinder = find.byType(FasoMap);
      expect(fasoMapFinder, findsOneWidget);

      final fasoMap = tester.widget<FasoMap>(fasoMapFinder);
      expect(fasoMap.myLocationEnabled, isTrue);
      expect(fasoMap.myLocationTrackingMode, MyLocationTrackingMode.tracking);
    });

    testWidgets('Bandeau « Signal GPS perdu » apparaît en cas d\'interruption du flux', (tester) async {
      await tester.pumpWidget(createTestWidget(gpsLost: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final bannerLost = find.byKey(const Key('banner_gps_lost'));
      expect(bannerLost, findsOneWidget);
      expect(find.text('Signal GPS perdu'), findsOneWidget);
    });

    testWidgets('Cas serviceOff : affiche le bandeau service désactivé avec bouton Activer', (tester) async {
      await tester.pumpWidget(createTestWidget(status: LocationStatus.serviceOff));
      await tester.pumpAndSettle();

      final bannerServiceOff = find.byKey(const Key('banner_gps_service_off'));
      expect(bannerServiceOff, findsOneWidget);
      expect(find.text('Service de localisation désactivé'), findsOneWidget);
      expect(find.text('Activer'), findsOneWidget);
    });

    testWidgets('Cas denied : affiche le bandeau permission refusée avec bouton Autoriser', (tester) async {
      await tester.pumpWidget(createTestWidget(status: LocationStatus.denied));
      await tester.pumpAndSettle();

      final bannerDenied = find.byKey(const Key('banner_gps_denied'));
      expect(bannerDenied, findsOneWidget);
      expect(find.text('Permission de localisation requise'), findsOneWidget);
      expect(find.text('Autoriser'), findsOneWidget);
    });

    testWidgets('Cas deniedForever : affiche le bandeau réglages avec bouton Réglages', (tester) async {
      await tester.pumpWidget(createTestWidget(status: LocationStatus.deniedForever));
      await tester.pumpAndSettle();

      final bannerDeniedForever = find.byKey(const Key('banner_gps_denied_forever'));
      expect(bannerDeniedForever, findsOneWidget);
      expect(find.text('Permission refusée dans les réglages'), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget);
    });
  });
}
