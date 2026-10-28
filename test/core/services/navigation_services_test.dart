import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/services/route_service.dart';
import 'package:qvgestion_mobile/core/services/voice_guide_service.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteService Tests', () {
    late MockApiClient mockApiClient;
    late RouteService routeService;

    setUp(() {
      mockApiClient = MockApiClient();
      routeService = RouteService(mockApiClient);
    });

    test('computeRaw convertit les points au format GeoJSON attendu', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routes,
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.routes),
            statusCode: 200,
            data: {
              'engine': 'valhalla',
              'mode': 'moto',
              'distance_m': 3500.0,
              'duration_s': 420.0,
              'legs': 1,
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [-1.5271, 12.3685],
                  [-1.5200, 12.3700],
                ],
              },
              'maneuvers': [
                {
                  'order': 1,
                  'instruction': 'Prenez l\'Avenue Kwame N\'Krumah',
                  'street_name': 'Avenue Kwame N\'Krumah',
                  'maneuver_type': 'depart',
                  'distance_meters': 1500.0,
                  'duration_seconds': 180,
                  'location': {'latitude': 12.3685, 'longitude': -1.5271},
                },
              ],
            },
          ));

      final result = await routeService.computeRaw([
        [-1.5271, 12.3685],
        [-1.5200, 12.3700],
      ]);

      expect(result['distance_meters'], 3500.0);
      expect(result['duration_seconds'], 420);
      expect(result['geometry'], isA<List>());
      expect(result['engine'], 'valhalla');
    });

    test('computeRaw propage une RoutingException en cas d\'erreur réseau (pas de tracé par défaut)', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routes,
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.routes),
        type: DioExceptionType.connectionError,
        error: 'Réseau indisponible',
      ));

      expect(
        () => routeService.computeRaw([
          [-1.5271, 12.3685],
          [-1.5200, 12.3700],
        ]),
        throwsA(isA<RoutingException>()),
      );
    });
  });

  group('VoiceGuide Tests', () {
    late VoiceGuide voiceGuide;

    setUp(() {
      voiceGuide = VoiceGuide();
    });

    test('say et sayStep s\'exécutent sans lever d\'exception', () async {
      await expectLater(
        voiceGuide.say('Recalcul de l\'itinéraire'),
        completes,
      );

      await expectLater(
        voiceGuide.sayStep({
          'instruction': 'Tournez à gauche',
          'landmark_name': 'Total Patte d\'Oie',
        }, language: 'fr'),
        completes,
      );

      await expectLater(
        voiceGuide.sayStep({
          'localized_instruction': 'Gilli wĩndg-goabga',
          'landmark_name': 'Station Total',
        }, language: 'mos'),
        completes,
      );
    });
  });
}
