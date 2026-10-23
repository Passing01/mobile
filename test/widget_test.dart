import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/features/offline/presentation/providers/offline_providers.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/reports/presentation/providers/reports_providers.dart';
import 'package:qvgestion_mobile/features/weather/data/models/weather_model.dart';
import 'package:qvgestion_mobile/features/weather/presentation/providers/weather_providers.dart';
import 'package:qvgestion_mobile/main.dart';

class FakeActiveReportsNotifier extends ActiveReportsNotifier {
  @override
  AsyncValue<List<ReportModel>> build() => const AsyncValue.data([]);
}

void main() {
  testWidgets('QvGestionApp démarre avec MainTabScaffold et les 5 onglets officiels',
      (WidgetTester tester) async {
    EnvConfig.initialize(environment: AppEnvironment.dev);

    const testPlace = PlaceModel(
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

    const testWeather = WeatherModel(
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyPlacesProvider.overrideWith((ref) async => [testPlace]),
          categoriesProvider.overrideWith((ref) async => [
                const CategoryModel(
                  id: 1,
                  nom: 'Pharmacie',
                  slug: 'pharmacie',
                  icone: 'local_pharmacy',
                ),
                const CategoryModel(
                  id: 2,
                  nom: 'Station-service',
                  slug: 'station-service',
                  icone: 'local_gas_station',
                ),
              ]),
          currentWeatherProvider.overrideWith((ref) async => testWeather),
          availableOfflinePacksProvider.overrideWith((ref) async => []),
          activeReportsProvider.overrideWith(FakeActiveReportsNotifier.new),
        ],
        child: const QvGestionApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Vérification de l'en-tête officiel FASO NAV
    expect(find.text('FASO NAV'), findsOneWidget);

    // 2. Vérification des 4 onglets de la Bottom Navigation Bar publique (Admin masqué pour le grand public)
    expect(find.text('Explorer'), findsWidgets);
    expect(find.text('Itinéraires'), findsOneWidget);
    expect(find.text('Sauvegardés'), findsOneWidget);
    expect(find.text('Compte'), findsOneWidget);
    expect(find.text('Admin'), findsNothing);

    // 3. Navigation vers l'onglet Compte
    await tester.tap(find.text('Compte'));
    await tester.pumpAndSettle();

    expect(find.text('Mon Profil Faso Nav'), findsOneWidget);
  });
}
