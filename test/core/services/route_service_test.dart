import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/services/route_service.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late RouteService routeService;

  setUp(() {
    mockApiClient = MockApiClient();
    routeService = RouteService(mockApiClient);
  });

  group('RouteService Tests (Étape 7)', () {
    test('computeRoute throws TOO_FEW_POINTS when points < 2', () async {
      expect(
        () => routeService.computeRoute(
          points: [const CoordinateModel(lat: 12.356, lon: -1.548)],
          mode: 'moto',
        ),
        throwsA(isA<RoutingException>().having(
          (e) => e.code,
          'code',
          'TOO_FEW_POINTS',
        )),
      );
    });

    test('computeRoute parses successful Valhalla response', () async {
      final fakeResponse = {
        'engine': 'valhalla',
        'mode': 'moto',
        'distance_m': 669.0,
        'duration_s': 57.7,
        'legs': 1,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-1.54815, 12.356232],
            [-1.542907, 12.359387],
          ]
        },
        'maneuvers': [
          {
            'type': 2,
            'instruction': 'Conduisez vers le nord-est sur Avenue Kadiogo.',
            'street_names': ['Avenue Kadiogo'],
            'lat': 12.356232,
            'lng': -1.54815,
            'length_m': 669.0,
            'time_s': 57.7
          }
        ],
        'start_snap_m': 31,
      };

      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routes,
            data: {
              'points': [
                {'lat': 12.3560, 'lng': -1.5480},
                {'lat': 12.3592, 'lng': -1.5428},
              ],
              'mode': 'moto',
            },
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.routes),
            statusCode: 200,
            data: fakeResponse,
          ));

      final route = await routeService.computeRoute(
        points: const [
          CoordinateModel(lat: 12.3560, lon: -1.5480),
          CoordinateModel(lat: 12.3592, lon: -1.5428),
        ],
        mode: 'moto',
      );

      expect(route.engine, 'valhalla');
      expect(route.mode, 'moto');
      expect(route.distanceMeters, 669.0);
      expect(route.durationSeconds, 58);
      expect(route.legs, 1);
      expect(route.geometry.length, 2);
      expect(route.geometry.first, [-1.54815, 12.356232]);
      expect(route.maneuvers.length, 1);
      expect(route.maneuvers.first.instruction,
          'Conduisez vers le nord-est sur Avenue Kadiogo.');
      expect(route.startSnapM, 31);
    });

    test('computeRoute propagates 422 SAME_POINT error without fallback', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routes,
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.routes),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.routes),
          statusCode: 422,
          data: {
            'detail': {
              'error': 'SAME_POINT',
              'message': 'Le départ et l\'arrivée sont identiques',
            }
          },
        ),
      ));

      expect(
        () => routeService.computeRoute(
          points: const [
            CoordinateModel(lat: 12.3560, lon: -1.5480),
            CoordinateModel(lat: 12.3560, lon: -1.5480),
          ],
          mode: 'moto',
        ),
        throwsA(isA<RoutingException>()
            .having((e) => e.code, 'code', 'SAME_POINT')
            .having((e) => e.message, 'message',
                'Le départ et l\'arrivée sont identiques')),
      );
    });

    test('computeRoute propagates 422 OUT_OF_AREA error', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routes,
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.routes),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.routes),
          statusCode: 422,
          data: {
            'detail': {
              'error': 'OUT_OF_AREA',
              'message':
                  'Point hors du Burkina Faso : -1.548, 12.356 (latitude et longitude inversées ?)',
            }
          },
        ),
      ));

      expect(
        () => routeService.computeRoute(
          points: const [
            CoordinateModel(lat: -1.5480, lon: 12.3560),
            CoordinateModel(lat: 12.3592, lon: -1.5428),
          ],
          mode: 'moto',
        ),
        throwsA(isA<RoutingException>()
            .having((e) => e.code, 'code', 'OUT_OF_AREA')
            .having((e) => e.message, 'message',
                contains('Point hors du Burkina Faso'))),
      );
    });

    test('computeRoute propagates 503 ENGINE_DOWN on connection error or 503', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.routes,
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.routes),
        type: DioExceptionType.connectionError,
        error: 'Connection refused',
      ));

      expect(
        () => routeService.computeRoute(
          points: const [
            CoordinateModel(lat: 12.3560, lon: -1.5480),
            CoordinateModel(lat: 12.3592, lon: -1.5428),
          ],
          mode: 'moto',
        ),
        throwsA(isA<RoutingException>()
            .having((e) => e.code, 'code', 'ENGINE_DOWN')
            .having((e) => e.message, 'message',
                'Le calcul d\'itinéraire est indisponible')),
      );
    });
  });
}
