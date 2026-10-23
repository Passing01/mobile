import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/live_tracking_model.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/telemetry_ping_model.dart';

abstract class ITrafficRepository {
  Future<TrafficSegmentModel> sendTelemetry(TelemetryPingModel ping);
  Future<LiveTrackingModel> startLiveTracking({
    required double lat,
    required double lon,
    String? destinationName,
    int durationMinutes = 120,
  });
  Future<LiveTrackingModel> getLiveTracking(String token);
  Future<LiveTrackingModel> updateLiveTracking(
    String token,
    LiveTrackingUpdatePayload update,
  );
  Future<void> stopLiveTracking(String token);
}

class TrafficRepository implements ITrafficRepository {
  final ApiClient apiClient;

  TrafficRepository({required this.apiClient});

  @override
  Future<TrafficSegmentModel> sendTelemetry(TelemetryPingModel ping) async {
    try {
      final response = await apiClient.post(
        ApiEndpoints.telemetry,
        data: ping.toJson(),
      );
      return TrafficSegmentModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de l\'envoi de la télémétrie', e, stack);
      rethrow;
    }
  }

  @override
  Future<LiveTrackingModel> startLiveTracking({
    required double lat,
    required double lon,
    String? destinationName,
    int durationMinutes = 120,
  }) async {
    try {
      final endpoint = '${ApiEndpoints.trackingShare}?lat=$lat&lon=$lon';
      final request = LiveTrackingCreateRequest(
        destinationName: destinationName,
        durationMinutes: durationMinutes,
      );
      final response = await apiClient.post(
        endpoint,
        data: request.toJson(),
      );
      return LiveTrackingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.w(
          'Partage serveur non disponible ou utilisateur invité ($e). Démarrage de la session locale.');
      final now = DateTime.now();
      return LiveTrackingModel(
        token: 'fn_${now.millisecondsSinceEpoch.toRadixString(36)}',
        userName: 'Conducteur Faso Nav',
        destinationName: destinationName,
        latitude: lat,
        longitude: lon,
        isActive: true,
        createdAt: now,
        expiresAt: now.add(Duration(minutes: durationMinutes)),
        lastUpdated: now,
      );
    }
  }

  @override
  Future<LiveTrackingModel> getLiveTracking(String token) async {
    if (token.startsWith('fn_')) {
      final now = DateTime.now();
      return LiveTrackingModel(
        token: token,
        userName: 'Conducteur Faso Nav',
        latitude: 12.3685,
        longitude: -1.5222,
        isActive: true,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        lastUpdated: now,
      );
    }
    try {
      final response = await apiClient.get(ApiEndpoints.trackingDetail(token));
      return LiveTrackingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la récupération du trajet $token', e, stack);
      rethrow;
    }
  }

  @override
  Future<LiveTrackingModel> updateLiveTracking(
    String token,
    LiveTrackingUpdatePayload update,
  ) async {
    if (token.startsWith('fn_')) {
      final now = DateTime.now();
      return LiveTrackingModel(
        token: token,
        userName: 'Conducteur Faso Nav',
        latitude: update.latitude,
        longitude: update.longitude,
        speedKmh: update.speedKmh,
        bearing: update.bearing,
        isActive: true,
        createdAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(hours: 2)),
        lastUpdated: now,
      );
    }
    try {
      final response = await apiClient.post(
        ApiEndpoints.trackingUpdate(token),
        data: update.toJson(),
      );
      return LiveTrackingModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la mise à jour GPS du trajet $token', e, stack);
      rethrow;
    }
  }

  @override
  Future<void> stopLiveTracking(String token) async {
    if (token.startsWith('fn_')) return;
    try {
      await apiClient.delete(ApiEndpoints.trackingStop(token));
    } catch (e, stack) {
      AppLogger.e('Erreur lors de l\'arrêt du trajet partagé $token', e, stack);
      rethrow;
    }
  }
}
