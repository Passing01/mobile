import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment {
  dev,
  staging,
  prod,
}

class EnvConfig {
  /// URL de production déployée sur Railway
  static const String railwayBaseUrl =
      'https://qvgestion-backend-production.up.railway.app/api/v1';
  static const String railwayWsUrl =
      'wss://qvgestion-backend-production.up.railway.app/api/v1';

  static AppEnvironment _environment = AppEnvironment.prod;
  static String? _customBaseUrl;

  /// Initialise la configuration d'environnement asynchrone (charge le fichier .env si présent)
  static Future<void> initializeAsync({
    AppEnvironment? environment,
    String? customBaseUrl,
  }) async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Ignorer si le fichier .env est absent (ex: tests automatisés)
    }
    initialize(environment: environment, customBaseUrl: customBaseUrl);
  }

  /// Initialise la configuration d'environnement synchrone
  static void initialize({
    AppEnvironment? environment,
    String? customBaseUrl,
  }) {
    if (environment != null) {
      _environment = environment;
    } else {
      final envFromDotEnv = dotenv.isInitialized ? dotenv.maybeGet('ENVIRONMENT') : null;
      final envString = envFromDotEnv ??
          const String.fromEnvironment('ENVIRONMENT', defaultValue: 'prod');
      _environment = _parseEnvironment(envString);
    }

    final baseFromDotEnv = dotenv.isInitialized ? dotenv.maybeGet('API_BASE_URL') : null;
    _customBaseUrl = customBaseUrl ??
        (baseFromDotEnv != null && baseFromDotEnv.isNotEmpty
            ? baseFromDotEnv
            : (const String.fromEnvironment('API_BASE_URL').isNotEmpty
                ? const String.fromEnvironment('API_BASE_URL')
                : null));
  }

  static AppEnvironment _parseEnvironment(String env) {
    switch (env.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'staging':
        return AppEnvironment.staging;
      case 'dev':
      case 'development':
      default:
        return AppEnvironment.dev;
    }
  }

  static AppEnvironment get environment => _environment;

  static bool get isDev => _environment == AppEnvironment.dev;
  static bool get isStaging => _environment == AppEnvironment.staging;
  static bool get isProd => _environment == AppEnvironment.prod;

  /// Hôte de développement adapté selon la plateforme (10.0.2.2 pour émulateur Android, 127.0.0.1 pour Linux/Web/iOS)
  static String get defaultHost {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2:8000';
    }
    return '127.0.0.1:8000';
  }

  /// URL de base HTTP de l'API Backend QvGestion
  static String get apiBaseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    switch (_environment) {
      case AppEnvironment.prod:
      case AppEnvironment.staging:
        return railwayBaseUrl;
      case AppEnvironment.dev:
        return 'http://$defaultHost/api/v1';
    }
  }

  /// URL de base WebSocket pour le trafic temps réel et le live-tracking
  static String get wsBaseUrl {
    switch (_environment) {
      case AppEnvironment.prod:
      case AppEnvironment.staging:
        return railwayWsUrl;
      case AppEnvironment.dev:
        return 'ws://$defaultHost/api/v1';
    }
  }

  /// Délais d'expiration réseau (adaptés aux réseaux mobiles)
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Intervalle d'envoi de la télémétrie (20 secondes préconisé pour économiser la batterie et éviter la surchauffe)
  static const Duration telemetryInterval = Duration(seconds: 20);

  /// Jeton d'accès public Mapbox (priorité : .env > --dart-define > vide)
  static String get mapboxToken {
    if (dotenv.isInitialized) {
      final fromDotenv = dotenv.maybeGet('MAPBOX_TOKEN');
      if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
        return fromDotenv.trim();
      }
    }
    return const String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');
  }
}
