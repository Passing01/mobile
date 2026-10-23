import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/data/repositories/routes_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late RoutesRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = RoutesRepository(apiClient: mockApiClient);
  });

  group('RoutesRepository Tests', () {
    test('getTransportModes récupère les profils disponibles', () async {
      when(() => mockApiClient.get<dynamic>(ApiEndpoints.routeModes))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ApiEndpoints.routeModes),
                statusCode: 200,
                data: [
                  {
                    'mode': 'motorcycle',
                    'label': 'Moto',
                    'description': 'Rapide',
                    'average_speed_kmh': 35.0,
                  }
                ],
              ));

      final modes = await repository.getTransportModes();
      expect(modes.length, 1);
      expect(modes.first.mode, 'motorcycle');
    });

    test('calculateRoute transmet origin, destination et mode au backend', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routeCalculate,
            data: {
              'origin': {'lat': 12.3685, 'lon': -1.5271, 'name': '1200 Logements'},
              'destination': {'lat': 12.3644, 'lon': -1.5222, 'name': 'Rood-Woko'},
              'mode': 'motorcycle',
            },
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.routeCalculate),
            statusCode: 200,
            data: {
              'mode': 'motorcycle',
              'distance_meters': 841.0,
              'duration_seconds': 86,
              'duration_formatted': '1 min',
              'geometry': [
                [12.3685, -1.5271],
                [12.3644, -1.5222]
              ],
              'bounding_box': [12.3644, -1.5271, 12.3685, -1.5222],
              'maneuvers': [],
              'engine': 'valhalla',
            },
          ));

      final route = await repository.calculateRoute(
        origin: const CoordinateModel(lat: 12.3685, lon: -1.5271, name: '1200 Logements'),
        destination: const CoordinateModel(lat: 12.3644, lon: -1.5222, name: 'Rood-Woko'),
        mode: 'motorcycle',
      );

      expect(route.mode, 'motorcycle');
      expect(route.distanceMeters, 841.0);
      expect(route.durationFormatted, '1 min');
      expect(route.engine, 'valhalla');
    });

    test('calculateRoute retourne une arrivée immédiate si origine et destination sont identiques (<5m)', () async {
      final route = await repository.calculateRoute(
        origin: const CoordinateModel(lat: 12.3688, lon: -1.4988, name: 'Pharmacie 1200'),
        destination: const CoordinateModel(lat: 12.3688, lon: -1.4988, name: 'Pharmacie 1200'),
        mode: 'moto',
      );

      expect(route.mode, 'motorcycle');
      expect(route.distanceMeters, 0.0);
      expect(route.durationSeconds, 0);
      expect(route.engine, 'immediate_arrival');
      expect(route.maneuvers.first.instruction, contains('Vous êtes déjà à destination'));
      verifyNever(() => mockApiClient.post(any(), data: any(named: 'data')));
    });

    test('calculateRoute normalise les alias de modes (\'moto\' -> \'motorcycle\', \'voiture\' -> \'auto\')', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routeCalculate,
            data: {
              'origin': {'lat': 12.3685, 'lon': -1.5271, 'name': '1200 Logements'},
              'destination': {'lat': 12.3644, 'lon': -1.5222, 'name': 'Rood-Woko'},
              'mode': 'auto',
            },
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.routeCalculate),
            statusCode: 200,
            data: {
              'mode': 'auto',
              'distance_meters': 1200.0,
              'duration_seconds': 120,
              'duration_formatted': '2 min',
              'geometry': [
                [12.3685, -1.5271],
                [12.3644, -1.5222]
              ],
              'bounding_box': [12.3644, -1.5271, 12.3685, -1.5222],
              'maneuvers': [],
              'engine': 'valhalla',
            },
          ));

      final route = await repository.calculateRoute(
        origin: const CoordinateModel(lat: 12.3685, lon: -1.5271, name: '1200 Logements'),
        destination: const CoordinateModel(lat: 12.3644, lon: -1.5222, name: 'Rood-Woko'),
        mode: 'voiture',
      );

      expect(route.mode, 'auto');
    });
  });
}
