import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/features/guidance/data/repositories/guidance_repository.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late GuidanceRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = GuidanceRepository(apiClient: mockApiClient);
  });

  group('GuidanceRepository Tests', () {
    test('getLandmarks retourne les repères de Ouagadougou', () async {
      when(() => mockApiClient.get<dynamic>(
            ApiEndpoints.guidanceLandmarks,
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.guidanceLandmarks),
            statusCode: 200,
            data: [
              {
                'id': 1,
                'nom': 'Échangeur de l\'Est',
                'nom_moore': 'Yaarã wĩndg pʋgẽ échangeur',
                'latitude': 12.3685,
                'longitude': -1.5020,
                'importance': 5,
                'visibilite_metres': 100.0,
                'type_repere': 'monument',
              },
            ],
          ));

      final result = await repository.getLandmarks();

      expect(result.length, 1);
      expect(result.first.nom, 'Échangeur de l\'Est');
      expect(result.first.importance, 5);
    });

    test('enrichRoute enrichit un itinéraire avec des consignes vocales', () async {
      const dummyRoute = RouteModel(
        mode: 'motorcycle',
        distanceMeters: 3000.0,
        durationSeconds: 300,
        durationFormatted: '5 min',
        geometry: [
          [12.36, -1.52],
          [12.37, -1.50],
        ],
        boundingBox: [12.36, -1.52, 12.37, -1.50],
        maneuvers: [],
        engine: 'Valhalla',
      );

      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.guidanceEnrichRoute,
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.guidanceEnrichRoute),
            statusCode: 200,
            data: {
              'mode': 'motorcycle',
              'total_distance_meters': 3000.0,
              'total_duration_formatted': '5 min',
              'language': 'mos',
              'enriched_maneuvers': [
                {
                  'order': 1,
                  'original_instruction': 'Tournez à gauche',
                  'localized_instruction': 'Échangeur de l\'Est poore, gilli wĩndg-goabga',
                  'language': 'mos',
                  'maneuver_type': 'turn_left',
                  'has_landmark': true,
                  'landmark_name': 'Échangeur de l\'Est',
                  'distance_meters': 800.0,
                  'duration_seconds': 90,
                  'audio_sound_id': 'mos_turn_left',
                }
              ],
            },
          ));

      final result = await repository.enrichRoute(route: dummyRoute, language: 'mos');

      expect(result.language, 'mos');
      expect(result.enrichedManeuvers.length, 1);
      expect(result.enrichedManeuvers.first.landmarkName, 'Échangeur de l\'Est');
    });

    test('getAudioUrl génère l\'URL WAV complète', () {
      final url = repository.getAudioUrl('mos_depart');
      expect(url, contains('/guidance/audio/mos_depart.wav'));
    });
  });
}
