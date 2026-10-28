import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/services/route_service.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/data/repositories/routes_repository.dart';
import 'package:dio/dio.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockRouteService extends Mock implements RouteService {}

void main() {
  late MockApiClient mockApiClient;
  late MockRouteService mockRouteService;
  late RoutesRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    mockRouteService = MockRouteService();
    repository = RoutesRepository(
      apiClient: mockApiClient,
      routeService: mockRouteService,
    );
  });

  group('RoutesRepository Tests (Étape 7)', () {
    test('getTransportModes récupère les profils disponibles', () async {
      when(() => mockApiClient.get<dynamic>(ApiEndpoints.routeModes))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ApiEndpoints.routeModes),
                statusCode: 200,
                data: [
                  {
                    'mode': 'moto',
                    'label': 'Moto',
                    'description': 'Rapide',
                    'average_speed_kmh': 35.0,
                  }
                ],
              ));

      final modes = await repository.getTransportModes();
      expect(modes.length, 1);
      expect(modes.first.mode, 'moto');
    });

    test('calculateRoute délègue à RouteService avec origin, waypoints et destination', () async {
      const origin = CoordinateModel(lat: 12.3560, lon: -1.5480, name: 'Départ');
      const wp1 = CoordinateModel(lat: 12.3580, lon: -1.5450, name: 'Étape 1');
      const dest = CoordinateModel(lat: 12.3592, lon: -1.5428, name: 'Arrivée');

      const expectedRoute = RouteModel(
        engine: 'valhalla',
        mode: 'moto',
        distanceMeters: 669.0,
        durationSeconds: 58,
        durationFormatted: '1 min',
        legs: 2,
        geometry: [
          [-1.5480, 12.3560],
          [-1.5450, 12.3580],
          [-1.5428, 12.3592],
        ],
        boundingBox: [12.3560, -1.5480, 12.3592, -1.5428],
        maneuvers: [],
      );

      when(() => mockRouteService.computeRoute(
            points: [origin, wp1, dest],
            mode: 'moto',
          )).thenAnswer((_) async => expectedRoute);

      final result = await repository.calculateRoute(
        origin: origin,
        destination: dest,
        waypoints: [wp1],
        mode: 'moto',
      );

      expect(result.legs, 2);
      expect(result.distanceMeters, 669.0);
      expect(result.engine, 'valhalla');
      verify(() => mockRouteService.computeRoute(
            points: [origin, wp1, dest],
            mode: 'moto',
          )).called(1);
    });

    test('calculateRoute propage les exceptions sans créer de faux itinéraire', () async {
      const origin = CoordinateModel(lat: 12.3560, lon: -1.5480);
      const dest = CoordinateModel(lat: 12.3560, lon: -1.5480);

      when(() => mockRouteService.computeRoute(
            points: [origin, dest],
            mode: 'moto',
          )).thenThrow(const RoutingException(
        code: 'SAME_POINT',
        message: 'Le départ et l\'arrivée sont identiques',
        statusCode: 422,
      ));

      expect(
        () => repository.calculateRoute(
          origin: origin,
          destination: dest,
          mode: 'moto',
        ),
        throwsA(isA<RoutingException>()),
      );
    });
  });
}
