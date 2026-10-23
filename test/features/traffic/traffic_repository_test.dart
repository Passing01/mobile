import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/live_tracking_model.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/telemetry_ping_model.dart';
import 'package:qvgestion_mobile/features/traffic/data/repositories/traffic_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late TrafficRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = TrafficRepository(apiClient: mockApiClient);
  });

  group('TrafficRepository Tests', () {
    test('sendTelemetry envoie les pings GPS et reçoit l\'état de congestion', () async {
      when(() => mockApiClient.post(
            ApiEndpoints.telemetry,
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.telemetry),
            statusCode: 200,
            data: {
              'segment_id': '12.368:-1.527',
              'latitude': 12.3685,
              'longitude': -1.5271,
              'average_speed_kmh': 42.0,
              'congestion_level': 'fluid',
              'samples_count': 1,
              'last_updated': '2026-10-09T23:00:00.000Z',
            },
          ));

      const ping = TelemetryPingModel(
        sessionId: 'session_test_123',
        latitude: 12.3685,
        longitude: -1.5271,
        speedKmh: 42.0,
      );

      final result = await repository.sendTelemetry(ping);
      expect(result.segmentId, '12.368:-1.527');
      expect(result.congestionLevel, 'fluid');
      expect(result.averageSpeedKmh, 42.0);
    });

    test('startLiveTracking démarre une session avec lat et lon en query params', () async {
      final endpoint = '${ApiEndpoints.trackingShare}?lat=12.3685&lon=-1.5271';
      when(() => mockApiClient.post(
            endpoint,
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: endpoint),
            statusCode: 201,
            data: {
              'token': 'trk_test_abc123',
              'user_name': 'Rasmané Ouedraogo',
              'destination_name': 'Maison Ouaga 2000',
              'latitude': 12.3685,
              'longitude': -1.5271,
              'speed_kmh': 0.0,
              'bearing': 0.0,
              'is_active': true,
              'created_at': '2026-10-09T23:00:00.000Z',
              'expires_at': '2026-10-10T01:00:00.000Z',
              'last_updated': '2026-10-09T23:00:00.000Z',
            },
          ));

      final result = await repository.startLiveTracking(
        lat: 12.3685,
        lon: -1.5271,
        destinationName: 'Maison Ouaga 2000',
        durationMinutes: 120,
      );

      expect(result.token, 'trk_test_abc123');
      expect(result.userName, 'Rasmané Ouedraogo');
      expect(result.isActive, isTrue);
    });

    test('updateLiveTracking met à jour la position GPS de la session', () async {
      final endpoint = ApiEndpoints.trackingUpdate('trk_test_abc123');
      when(() => mockApiClient.post(
            endpoint,
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: endpoint),
            statusCode: 200,
            data: {
              'token': 'trk_test_abc123',
              'user_name': 'Rasmané Ouedraogo',
              'destination_name': 'Maison Ouaga 2000',
              'latitude': 12.3700,
              'longitude': -1.5200,
              'speed_kmh': 50.0,
              'bearing': 90.0,
              'is_active': true,
              'created_at': '2026-10-09T23:00:00.000Z',
              'expires_at': '2026-10-10T01:00:00.000Z',
              'last_updated': '2026-10-09T23:05:00.000Z',
            },
          ));

      final result = await repository.updateLiveTracking(
        'trk_test_abc123',
        const LiveTrackingUpdatePayload(
          latitude: 12.3700,
          longitude: -1.5200,
          speedKmh: 50.0,
          bearing: 90.0,
        ),
      );

      expect(result.latitude, 12.3700);
      expect(result.speedKmh, 50.0);
    });

    test('stopLiveTracking appelle DELETE sur le token', () async {
      final endpoint = ApiEndpoints.trackingStop('trk_test_abc123');
      when(() => mockApiClient.delete(endpoint)).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: endpoint),
            statusCode: 204,
          ));

      await repository.stopLiveTracking('trk_test_abc123');
      verify(() => mockApiClient.delete(endpoint)).called(1);
    });
  });
}
