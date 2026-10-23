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
            ApiEndpoints.routeCalculate,
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.routeCalculate),
            statusCode: 200,
            data: {
              'distance_meters': 3500.0,
              'duration_seconds': 420,
              'geometry': [
                [12.3685, -1.5271],
                [12.3700, -1.5200],
              ],
              'maneuvers': [
                {
                  'order': 1,
                  'instruction': 'Prenez l\'Avenue Kwame N\'Krumah',
                  'maneuver_type': 'depart',
                  'distance_meters': 1500.0,
                  'duration_seconds': 180.0,
                  'location': {'latitude': 12.3685, 'longitude': -1.5271},
                },
              ],
            },
          ));

      final result = await routeService.computeRaw([
        [-1.5271, 12.3685],
        [-1.5200, 12.3700],
      ]);

      expect(result['distance_m'], 3500.0);
      expect(result['duration_s'], 420);
      expect(result['geometry']['type'], 'LineString');
      // Format GeoJSON : [lng, lat]
      final coords = result['geometry']['coordinates'] as List;
      expect(coords.first, [-1.5271, 12.3685]);
      expect(coords.last, [-1.5200, 12.3700]);
    });

    test('computeRaw active le tracé géodésique de secours en cas d\'erreur réseau', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routeCalculate,
            data: any(named: 'data'),
          )).thenThrow(Exception('Réseau indisponible'));

      final result = await routeService.computeRaw([
        [-1.5271, 12.3685],
        [-1.5200, 12.3700],
      ]);

      expect(result['geometry']['type'], 'LineString');
      expect(result['steps'], isNotEmpty);
      expect(result['distance_m'], isNotNull);
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
