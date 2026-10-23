import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';

void main() {
  group('EnvConfig Tests', () {
    test('Par défaut, l\'environnement est prod (Railway)', () {
      EnvConfig.initialize();
      expect(EnvConfig.environment, AppEnvironment.prod);
      expect(EnvConfig.isProd, isTrue);
      expect(EnvConfig.apiBaseUrl, equals(EnvConfig.railwayBaseUrl));
      expect(EnvConfig.wsBaseUrl, equals(EnvConfig.railwayWsUrl));
    });

    test('Configuration explicite pour Dev local', () {
      EnvConfig.initialize(environment: AppEnvironment.dev);
      expect(EnvConfig.environment, AppEnvironment.dev);
      expect(EnvConfig.isDev, isTrue);
      expect(EnvConfig.isProd, isFalse);
      expect(EnvConfig.isStaging, isFalse);
      expect(EnvConfig.apiBaseUrl, equals('http://${EnvConfig.defaultHost}/api/v1'));
      expect(EnvConfig.wsBaseUrl, equals('ws://${EnvConfig.defaultHost}/api/v1'));
    });

    test('Configuration pour Staging', () {
      EnvConfig.initialize(environment: AppEnvironment.staging);
      expect(EnvConfig.environment, AppEnvironment.staging);
      expect(EnvConfig.isStaging, isTrue);
      expect(EnvConfig.apiBaseUrl, equals(EnvConfig.railwayBaseUrl));
      expect(EnvConfig.wsBaseUrl, equals(EnvConfig.railwayWsUrl));
    });

    test('Configuration pour Production', () {
      EnvConfig.initialize(environment: AppEnvironment.prod);
      expect(EnvConfig.environment, AppEnvironment.prod);
      expect(EnvConfig.isProd, isTrue);
      expect(EnvConfig.apiBaseUrl, equals(EnvConfig.railwayBaseUrl));
      expect(EnvConfig.wsBaseUrl, equals(EnvConfig.railwayWsUrl));
    });

    test('Configuration avec URL personnalisée surchargée', () {
      EnvConfig.initialize(
        environment: AppEnvironment.dev,
        customBaseUrl: 'http://192.168.1.100:8000/api/v1',
      );
      expect(EnvConfig.apiBaseUrl, equals('http://192.168.1.100:8000/api/v1'));
    });

    test('Délais et télémétrie sont bien configurés', () {
      expect(EnvConfig.connectTimeout, equals(const Duration(seconds: 30)));
      expect(EnvConfig.receiveTimeout, equals(const Duration(seconds: 30)));
      expect(EnvConfig.telemetryInterval, equals(const Duration(seconds: 20)));
    });
  });
}
