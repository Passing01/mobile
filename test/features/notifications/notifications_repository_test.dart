import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/network/api_exceptions.dart';
import 'package:qvgestion_mobile/features/notifications/data/repositories/notifications_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late NotificationsRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = NotificationsRepository(apiClient: mockApiClient);
  });

  group('NotificationsRepository Tests', () {
    test('getMyNotifications récupère la liste des alertes de l\'utilisateur', () async {
      when(() => mockApiClient.get(ApiEndpoints.notificationsMy))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ApiEndpoints.notificationsMy),
                statusCode: 200,
                data: [
                  {
                    'id': 1,
                    'utilisateur_id': 42,
                    'title': 'Alerte Inondation',
                    'body': 'Axe Bassawarga submergé',
                    'is_read': false,
                    'incident_id': null,
                    'created_at': '2026-10-09T23:00:00.000Z',
                  },
                ],
              ));

      final result = await repository.getMyNotifications();
      expect(result.length, 1);
      expect(result.first.title, 'Alerte Inondation');
      expect(result.first.isRead, isFalse);
    });

    test('markAsRead appelle PATCH /notifications/{id}/read', () async {
      final endpoint = ApiEndpoints.notificationRead(1);
      when(() => mockApiClient.patch(endpoint))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: endpoint),
                statusCode: 204,
              ));

      await repository.markAsRead(1);
      verify(() => mockApiClient.patch(endpoint)).called(1);
    });

    test('registerDeviceToken envoie le jeton FCM au backend', () async {
      when(() => mockApiClient.post(
            ApiEndpoints.notificationsDevices,
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.notificationsDevices),
            statusCode: 200,
            data: {'status': 'registered'},
          ));

      await repository.registerDeviceToken(
        fcmToken: 'fcm_token_sample_123',
        platform: 'android',
      );

      verify(() => mockApiClient.post(
            ApiEndpoints.notificationsDevices,
            data: {
              'fcm_token': 'fcm_token_sample_123',
              'platform': 'android',
            },
          )).called(1);
    });

    test('broadcastGeoAlert diffuse une alerte push ciblée', () async {
      when(() => mockApiClient.post(
            ApiEndpoints.notificationsGeoAlert,
            data: any(named: 'data'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.notificationsGeoAlert),
            statusCode: 200,
            data: {
              'broadcasted': true,
              'targeted_devices': 150,
            },
          ));

      final result = await repository.broadcastGeoAlert(
        latitude: 12.3685,
        longitude: -1.5271,
        radiusKm: 5.0,
        title: 'Alerte Voie Coupée',
        body: 'Avenue Bassawarga submergée',
      );

      expect(result['broadcasted'], isTrue);
      expect(result['targeted_devices'], 150);
    });

    test('getMyNotifications retourne une liste vide sans lever d\'erreur si UnauthorizedException (401)', () async {
      when(() => mockApiClient.get(ApiEndpoints.notificationsMy))
          .thenThrow(const UnauthorizedException(message: 'Authentification requise'));

      final result = await repository.getMyNotifications();
      expect(result, isEmpty);
    });

    test('markAsRead et registerDeviceToken ne lèvent pas d\'erreur si UnauthorizedException (401)', () async {
      when(() => mockApiClient.patch(any()))
          .thenThrow(const UnauthorizedException(message: 'Authentification requise'));
      when(() => mockApiClient.post(any(), data: any(named: 'data')))
          .thenThrow(const UnauthorizedException(message: 'Authentification requise'));

      await expectLater(repository.markAsRead(42), completes);
      await expectLater(
        repository.registerDeviceToken(fcmToken: 'token', platform: 'android'),
        completes,
      );
    });
  });
}
