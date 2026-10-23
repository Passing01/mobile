import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/live_tracking_model.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/telemetry_ping_model.dart';

void main() {
  group('TelemetryPingModel & TrafficSegmentModel Tests', () {
    test('TelemetryPingModel toJson et fromJson sérialisent fidèlement', () {
      const ping = TelemetryPingModel(
        sessionId: 'sess_ouaga_2026_01',
        latitude: 12.3685,
        longitude: -1.5271,
        speedKmh: 45.2,
        bearing: 90.0,
      );

      final json = ping.toJson();
      expect(json['session_id'], 'sess_ouaga_2026_01');
      expect(json['latitude'], 12.3685);
      expect(json['longitude'], -1.5271);
      expect(json['speed_kmh'], 45.2);
      expect(json['bearing'], 90.0);

      final fromJson = TelemetryPingModel.fromJson(json);
      expect(fromJson, equals(ping));
    });

    test('TrafficSegmentModel parse correctement la réponse de congestion', () {
      final json = {
        'segment_id': '12.368:-1.527',
        'latitude': 12.3685,
        'longitude': -1.5271,
        'average_speed_kmh': 35.0,
        'congestion_level': 'fluid',
        'samples_count': 5,
        'last_updated': '2026-10-09T23:00:00.000Z',
      };

      final segment = TrafficSegmentModel.fromJson(json);
      expect(segment.segmentId, '12.368:-1.527');
      expect(segment.congestionLevel, 'fluid');
      expect(segment.samplesCount, 5);
      expect(segment.averageSpeedKmh, 35.0);
    });
  });

  group('LiveTrackingModel Tests', () {
    final now = DateTime.parse('2026-10-09T23:00:00.000Z');
    final expires = DateTime.parse('2026-10-10T01:00:00.000Z');

    test('LiveTrackingModel parse le JSON et génère le lien de partage public', () {
      final json = {
        'token': 'trk_OuagaSecure2026',
        'user_name': 'Rasmané Ouedraogo',
        'destination_name': 'Maison Ouaga 2000',
        'latitude': 12.3685,
        'longitude': -1.5271,
        'speed_kmh': 38.5,
        'bearing': 180.0,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'expires_at': expires.toIso8601String(),
        'last_updated': now.toIso8601String(),
      };

      final model = LiveTrackingModel.fromJson(json);
      expect(model.token, 'trk_OuagaSecure2026');
      expect(model.userName, 'Rasmané Ouedraogo');
      expect(model.destinationName, 'Maison Ouaga 2000');
      expect(model.isActive, isTrue);

      final shareUrl = model.shareUrl('https://api.qvgestion.bf/api/v1');
      expect(shareUrl, 'https://api.qvgestion.bf/api/v1/traffic/tracking/trk_OuagaSecure2026');
    });

    test('LiveTrackingCreateRequest sérialise avec ou sans destination', () {
      const reqWithDest = LiveTrackingCreateRequest(
        destinationName: '1200 Logements',
        durationMinutes: 60,
      );
      expect(reqWithDest.toJson(), {
        'destination_name': '1200 Logements',
        'duration_minutes': 60,
      });

      const reqNoDest = LiveTrackingCreateRequest(durationMinutes: 120);
      expect(reqNoDest.toJson(), {
        'duration_minutes': 120,
      });
    });

    test('LiveTrackingUpdatePayload sérialise les coordonnées GPS et métriques', () {
      const update = LiveTrackingUpdatePayload(
        latitude: 12.3700,
        longitude: -1.5200,
        speedKmh: 40.0,
        bearing: 45.0,
      );
      expect(update.toJson(), {
        'latitude': 12.3700,
        'longitude': -1.5200,
        'speed_kmh': 40.0,
        'bearing': 45.0,
      });
    });
  });
}
