import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/live_tracking_model.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/telemetry_ping_model.dart';
import 'package:qvgestion_mobile/features/traffic/data/repositories/traffic_repository.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/providers/traffic_providers.dart';

class MockTrafficRepository extends Mock implements ITrafficRepository {}

void main() {
  late MockTrafficRepository mockRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(const TelemetryPingModel(
      sessionId: 'test',
      latitude: 0,
      longitude: 0,
      speedKmh: 0,
    ));
    registerFallbackValue(const LiveTrackingUpdatePayload(
      latitude: 0,
      longitude: 0,
    ));
  });

  setUp(() {
    mockRepository = MockTrafficRepository();
    container = ProviderContainer(
      overrides: [
        trafficRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ActiveTrackingNotifier Tests', () {
    final now = DateTime.parse('2026-10-09T23:00:00.000Z');
    final expires = DateTime.parse('2026-10-10T01:00:00.000Z');

    final testSession = LiveTrackingModel(
      token: 'trk_unit_test',
      userName: 'Rasmané Ouedraogo',
      destinationName: '1200 Logements',
      latitude: 12.3685,
      longitude: -1.5271,
      speedKmh: 0.0,
      bearing: 0.0,
      isActive: true,
      createdAt: now,
      expiresAt: expires,
      lastUpdated: now,
    );

    test('L\'état initial est null', () {
      final state = container.read(activeTrackingProvider);
      expect(state, isNull);
    });

    test('startTracking démarre la session et met à jour l\'état', () async {
      when(() => mockRepository.startLiveTracking(
            lat: 12.3685,
            lon: -1.5271,
            destinationName: '1200 Logements',
            durationMinutes: 120,
          )).thenAnswer((_) async => testSession);

      final result = await container.read(activeTrackingProvider.notifier).startTracking(
            lat: 12.3685,
            lon: -1.5271,
            destination: '1200 Logements',
            durationMinutes: 120,
          );

      expect(result.token, 'trk_unit_test');
      expect(container.read(activeTrackingProvider), equals(testSession));
    });

    test('updatePosition met à jour les coordonnées de la session active', () async {
      when(() => mockRepository.startLiveTracking(
            lat: 12.3685,
            lon: -1.5271,
            destinationName: any(named: 'destinationName'),
            durationMinutes: any(named: 'durationMinutes'),
          )).thenAnswer((_) async => testSession);

      await container.read(activeTrackingProvider.notifier).startTracking(
            lat: 12.3685,
            lon: -1.5271,
          );

      final updatedSession = LiveTrackingModel(
        token: 'trk_unit_test',
        userName: 'Rasmané Ouedraogo',
        destinationName: '1200 Logements',
        latitude: 12.3700,
        longitude: -1.5200,
        speedKmh: 45.0,
        bearing: 90.0,
        isActive: true,
        createdAt: now,
        expiresAt: expires,
        lastUpdated: now,
      );

      when(() => mockRepository.updateLiveTracking(
            'trk_unit_test',
            any(),
          )).thenAnswer((_) async => updatedSession);

      await container.read(activeTrackingProvider.notifier).updatePosition(
            lat: 12.3700,
            lon: -1.5200,
            speedKmh: 45.0,
            bearing: 90.0,
          );

      expect(container.read(activeTrackingProvider)?.latitude, 12.3700);
      expect(container.read(activeTrackingProvider)?.speedKmh, 45.0);
    });

    test('stopTracking termine la session et réinitialise l\'état à null', () async {
      when(() => mockRepository.startLiveTracking(
            lat: any(named: 'lat'),
            lon: any(named: 'lon'),
            destinationName: any(named: 'destinationName'),
            durationMinutes: any(named: 'durationMinutes'),
          )).thenAnswer((_) async => testSession);

      when(() => mockRepository.stopLiveTracking('trk_unit_test'))
          .thenAnswer((_) async {});

      await container.read(activeTrackingProvider.notifier).startTracking(
            lat: 12.3685,
            lon: -1.5271,
          );
      expect(container.read(activeTrackingProvider), isNotNull);

      await container.read(activeTrackingProvider.notifier).stopTracking();
      expect(container.read(activeTrackingProvider), isNull);
    });
  });
}
