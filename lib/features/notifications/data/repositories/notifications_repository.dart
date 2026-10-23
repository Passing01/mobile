import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/network/api_exceptions.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/notifications/data/models/notification_item_model.dart';

abstract class INotificationsRepository {
  Future<List<NotificationItemModel>> getMyNotifications();
  Future<void> markAsRead(int notificationId);
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
  });
  Future<Map<String, dynamic>> broadcastGeoAlert({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String title,
    required String body,
    int? incidentId,
  });
}

class NotificationsRepository implements INotificationsRepository {
  final ApiClient apiClient;

  NotificationsRepository({required this.apiClient});

  @override
  Future<List<NotificationItemModel>> getMyNotifications() async {
    try {
      final response = await apiClient.get(ApiEndpoints.notificationsMy);
      final list = (response.data as List<dynamic>)
          .map((e) => NotificationItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } on UnauthorizedException {
      AppLogger.d('Utilisateur invité (non authentifié) : aucune alerte personnelle.');
      return const [];
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.d('Utilisateur non connecté : liste d\'alertes vide.');
        return const [];
      }
      AppLogger.w('Serveur d\'alertes inaccessible (mode hors-ligne): $e');
      return const [];
    } catch (e) {
      AppLogger.w('Mode hors-ligne: alertes indisponibles ($e)');
      return const [];
    }
  }

  @override
  Future<void> markAsRead(int notificationId) async {
    try {
      await apiClient.patch(ApiEndpoints.notificationRead(notificationId));
    } on UnauthorizedException {
      // Ignorer silencieusement si déconnecté
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      AppLogger.e('Erreur lors du marquage de l\'alerte $notificationId comme lue: $e');
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Erreur lors du marquage de l\'alerte $notificationId comme lue', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await apiClient.post(
        ApiEndpoints.notificationsDevices,
        data: {
          'fcm_token': fcmToken,
          'platform': platform,
        },
      );
    } on UnauthorizedException {
      AppLogger.d('Enregistrement FCM différé : utilisateur non authentifié.');
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.d('Enregistrement FCM différé (401).');
        return;
      }
      AppLogger.e('Erreur lors de l\'enregistrement du terminal: $e');
      rethrow;
    } catch (e, stack) {
      AppLogger.e('Erreur lors de l\'enregistrement du terminal', e, stack);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> broadcastGeoAlert({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String title,
    required String body,
    int? incidentId,
  }) async {
    try {
      final response = await apiClient.post(
        ApiEndpoints.notificationsGeoAlert,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'radius_km': radiusKm,
          'title': title,
          'body': body,
          'incident_id': ?incidentId,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la diffusion de la géo-alerte', e, stack);
      rethrow;
    }
  }
}
