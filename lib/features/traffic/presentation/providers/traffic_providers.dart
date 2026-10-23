import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/live_tracking_model.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/telemetry_ping_model.dart';
import 'package:qvgestion_mobile/features/traffic/data/repositories/traffic_repository.dart';

final trafficRepositoryProvider = Provider<ITrafficRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TrafficRepository(apiClient: apiClient);
});

/// Gestionnaire de la session de partage de trajet en cours
class ActiveTrackingNotifier extends Notifier<LiveTrackingModel?> {
  @override
  LiveTrackingModel? build() => null;

  Future<LiveTrackingModel> startTracking({
    required double lat,
    required double lon,
    String? destination,
    int durationMinutes = 120,
  }) async {
    final repo = ref.read(trafficRepositoryProvider);
    final tracking = await repo.startLiveTracking(
      lat: lat,
      lon: lon,
      destinationName: destination,
      durationMinutes: durationMinutes,
    );
    state = tracking;
    return tracking;
  }

  Future<void> updatePosition({
    required double lat,
    required double lon,
    double? speedKmh,
    double? bearing,
  }) async {
    final current = state;
    if (current == null || !current.isActive) return;

    try {
      final repo = ref.read(trafficRepositoryProvider);
      final updated = await repo.updateLiveTracking(
        current.token,
        LiveTrackingUpdatePayload(
          latitude: lat,
          longitude: lon,
          speedKmh: speedKmh,
          bearing: bearing,
        ),
      );
      state = updated;
    } catch (e) {
      AppLogger.w('Échec mise à jour suivi en direct: $e');
    }
  }

  Future<void> stopTracking() async {
    final current = state;
    if (current == null) return;

    try {
      final repo = ref.read(trafficRepositoryProvider);
      await repo.stopLiveTracking(current.token);
    } finally {
      state = null;
    }
  }
}

final activeTrackingProvider =
    NotifierProvider<ActiveTrackingNotifier, LiveTrackingModel?>(
  ActiveTrackingNotifier.new,
);

/// Gestionnaire d'envoi de la télémétrie de trafic
class TelemetryNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> sendPing({
    required String sessionId,
    required double latitude,
    required double longitude,
    required double speedKmh,
    double? bearing,
  }) async {
    try {
      final repo = ref.read(trafficRepositoryProvider);
      await repo.sendTelemetry(
        TelemetryPingModel(
          sessionId: sessionId,
          latitude: latitude,
          longitude: longitude,
          speedKmh: speedKmh,
          bearing: bearing,
        ),
      );
    } catch (e) {
      AppLogger.w('Échec émission ping télémétrie: $e');
    }
  }
}

final telemetryProvider = NotifierProvider<TelemetryNotifier, void>(
  TelemetryNotifier.new,
);
