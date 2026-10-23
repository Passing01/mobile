import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/map/presentation/screens/home_map_screen.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'package:qvgestion_mobile/features/weather/data/models/weather_model.dart';
import 'package:qvgestion_mobile/features/weather/presentation/providers/weather_providers.dart';

class FakeActiveRouteNotifier extends ActiveRouteNotifier {
  final RouteModel initialRoute;
  FakeActiveRouteNotifier(this.initialRoute);

  @override
  AsyncValue<RouteModel?> build() {
    return AsyncValue.data(initialRoute);
  }

  @override
  Future<RouteModel?> calculate({
    required CoordinateModel origin,
    required CoordinateModel destination,
    required String mode,
  }) async {
    state = AsyncValue.data(initialRoute);
    return initialRoute;
  }
}

void main() {
  const sampleCategories = [
    CategoryModel(
      id: 1,
      nom: 'Pharmacie',
      slug: 'pharmacie',
      icone: 'local_pharmacy',
      labels: {'fr': 'Pharmacies de garde'},
    ),
    CategoryModel(
      id: 2,
      nom: 'Station-service',
      slug: 'station-service',
      icone: 'local_gas_station',
      labels: {'fr': 'Stations d\'essence'},
    ),
  ];

  const samplePlace = PlaceModel(
    id: 1,
    nom: 'Phcie de la Paix',
    categorieId: 1,
    latitude: 12.3850,
    longitude: -1.5020,
    quartier: 'Somgandé',
    distanceMeters: 350.0,
    horaires: 'De garde • 24/7',
    categorie: CategoryModel(
      id: 1,
      nom: 'Pharmacie',
      slug: 'pharmacie',
      icone: 'local_pharmacy',
    ),
  );

  const sampleMotoRoute = RouteModel(
    mode: 'motorcycle',
    distanceMeters: 841.0,
    durationSeconds: 86,
    durationFormatted: '11 min',
    geometry: [
      [12.3685, -1.5271],
      [12.3644, -1.5222],
    ],
    boundingBox: [12.3644, -1.5271, 12.3685, -1.5222],
    maneuvers: [
      ManeuverModel(
        order: 1,
        instruction: 'Prenez la voie de droite vers le carrefour',
        maneuverType: 'depart',
        distanceMeters: 250.0,
        durationSeconds: 30,
        location: CoordinateModel(lat: 12.3685, lon: -1.5271),
      ),
    ],
    engine: 'geodesic_fallback',
  );

  const sampleWeather = WeatherModel(
    latitude: 12.3685,
    longitude: -1.5271,
    temperatureCelsius: 32.0,
    apparentTemperatureCelsius: 35.0,
    humidityPercent: 40,
    precipitationMm: 0.0,
    windSpeedKmh: 10.0,
    windGustsKmh: 15.0,
    weatherCode: 1,
    description: 'Ensoleillé',
    drivingAdvisory: 'Trafic fluide sur l\'Avenue Kwame N\'Krumah',
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        categoriesProvider.overrideWith((ref) async => sampleCategories),
        nearbyPlacesProvider.overrideWith((ref) async => [samplePlace]),
        selectedPlaceProvider.overrideWith(SelectedPlaceNotifier.new),
        activeRouteProvider.overrideWith(() => FakeActiveRouteNotifier(sampleMotoRoute)),
        multiModeRoutesProvider.overrideWith((ref) async => {
              'motorcycle': sampleMotoRoute,
            }),
        currentWeatherProvider.overrideWith((ref) async => sampleWeather),
      ],
      child: const MaterialApp(
        home: HomeMapScreen(),
      ),
    );
  }

  testWidgets('HomeMapScreen affiche fidèlement les éléments de la maquette officielle FASO NAV',
      (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // 1. En-tête FASO NAV & Explorer
    expect(find.text('FASO NAV'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);

    // 2. Barre de recherche avec badge FN
    expect(find.text('Rechercher un lieu, carrefour, maquis...'), findsOneWidget);
    expect(find.text('FN'), findsOneWidget);

    // 3. Bandeau météo & trafic
    expect(find.textContaining('Ouagadougou 32°C'), findsOneWidget);

    // 4. Filtres de catégories de la maquette
    expect(find.text('Stations d\'essence'), findsOneWidget);
    expect(find.text('Pharmacies de garde'), findsOneWidget);

    // 5. Badge Hors-ligne prêt sur la carte
    expect(find.text('Hors-ligne prêt'), findsOneWidget);

    // 6. Tiroir "Explorer Ouaga & Environs"
    expect(find.text('Explorer Ouaga & Environs'), findsOneWidget);
    expect(find.text('Populaire'), findsWidgets);
    expect(find.text('Tout voir'), findsOneWidget);
    expect(find.text('Héros Nationaux'), findsOneWidget);
  });

  testWidgets('Sélection d\'un lieu depuis le tiroir ouvre la fiche POI et le calcul d\'itinéraire',
      (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Clic sur la carte Héros Nationaux
    await tester.tap(find.text('Héros Nationaux'));
    await tester.pumpAndSettle();

    // La carte POI Preview s'ouvre
    expect(find.text('Itinéraire Moto'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);

    // Lancer le calcul
    await tester.tap(find.text('Itinéraire Moto'));
    await tester.pumpAndSettle();

    // Écran 2 : Choix du moyen de déplacement
    expect(find.text('Choisir votre moyen de déplacement'), findsOneWidget);
    expect(find.text('Moto / Deux-Roues'), findsOneWidget);
    expect(find.text('Démarrer la navigation vocale'), findsOneWidget);

    // Écran 3 : Guidage actif
    await tester.tap(find.text('Démarrer la navigation vocale'));
    await tester.pumpAndSettle();

    expect(find.text('Prenez la voie de droite vers le carrefour'), findsOneWidget);
    expect(find.byTooltip('Arrêter la navigation'), findsOneWidget);
  });
}
