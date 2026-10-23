import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/features/places/data/repositories/places_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late PlacesRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = PlacesRepository(apiClient: mockApiClient);
  });

  group('PlacesRepository Tests', () {
    test('getCategories retourne la liste des catégories désérialisées', () async {
      when(() => mockApiClient.get<dynamic>(ApiEndpoints.categories))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ApiEndpoints.categories),
                statusCode: 200,
                data: [
                  {'id': 1, 'nom': 'Pharmacie', 'slug': 'pharmacie', 'icone': 'local_pharmacy'},
                  {'id': 2, 'nom': 'Station', 'slug': 'station-service', 'icone': 'local_gas_station'},
                ],
              ));

      final result = await repository.getCategories();

      expect(result.length, 2);
      expect(result.first.nom, 'Pharmacie');
      expect(result.first.slug, 'pharmacie');
      expect(result.last.nom, 'Station');
    });

    test('getNearbyPlaces passe les paramètres géographiques au backend', () async {
      when(() => mockApiClient.get<dynamic>(
            ApiEndpoints.placesNearby,
            queryParameters: {
              'lat': 12.3685,
              'lon': -1.5271,
              'radius': 5000.0,
              'limit': 30,
              'slug': 'pharmacie',
            },
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.placesNearby),
            statusCode: 200,
            data: [
              {
                'id': 1,
                'nom': 'Pharmacie du 1200 Logements',
                'categorie_id': 1,
                'latitude': 12.3688,
                'longitude': -1.4988,
                'est_valide': true,
                'distance_meters': 350.0,
              }
            ],
          ));

      final places = await repository.getNearbyPlaces(
        lat: 12.3685,
        lon: -1.5271,
        radius: 5000.0,
        slug: 'pharmacie',
      );

      expect(places.length, 1);
      expect(places.first.nom, 'Pharmacie du 1200 Logements');
      expect(places.first.distanceMeters, 350.0);
    });

    test('searchPlaces effectue la requête de recherche textuelle', () async {
      when(() => mockApiClient.get<dynamic>(
            ApiEndpoints.placesSearch,
            queryParameters: {
              'q': 'Rood-Woko',
              'limit': 20,
            },
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.placesSearch),
            statusCode: 200,
            data: [
              {
                'id': 4,
                'nom': 'Grand Marché Rood-Woko',
                'categorie_id': 3,
                'latitude': 12.3685,
                'longitude': -1.5222,
                'est_valide': true,
              }
            ],
          ));

      final results = await repository.searchPlaces(query: 'Rood-Woko');

      expect(results.length, 1);
      expect(results.first.nom, 'Grand Marché Rood-Woko');
    });

    test('toggleFavorite ajoute un favori quand isCurrentlyFavorite est false', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.placeFavorite(5),
            data: {'lieu_id': 5, 'alias': 'Mon CSPS'},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.placeFavorite(5)),
            statusCode: 201,
            data: {},
          ));

      final isFav = await repository.toggleFavorite(
        placeId: 5,
        isCurrentlyFavorite: false,
        alias: 'Mon CSPS',
      );

      expect(isFav, true);
    });

    test('toggleFavorite supprime un favori quand isCurrentlyFavorite est true', () async {
      when(() => mockApiClient.delete<dynamic>(ApiEndpoints.removeFavorite(5)))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ApiEndpoints.removeFavorite(5)),
                statusCode: 204,
                data: null,
              ));

      final isFav = await repository.toggleFavorite(
        placeId: 5,
        isCurrentlyFavorite: true,
      );

      expect(isFav, false);
    });
  });
}
