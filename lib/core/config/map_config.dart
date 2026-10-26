import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

class MapConfig {
  final String styleLight;
  final String styleDark;
  final String attribution;

  const MapConfig({
    required this.styleLight,
    required this.styleDark,
    required this.attribution,
  });

  static const defaultFasoLight = 'assets/map/styles/faso-light.json';
  static const defaultFasoDark = 'assets/map/styles/faso-dark.json';
  static const defaultAttribution = '© OpenStreetMap contributors';

  factory MapConfig.defaults() => const MapConfig(
        styleLight: defaultFasoLight,
        styleDark: defaultFasoDark,
        attribution: defaultAttribution,
      );

  static String _sanitizeUrl(String? url, String fallback) {
    if (url == null || url.isEmpty) return fallback;
    if (url.startsWith('http://') && url.contains('railway.app')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  factory MapConfig.fromJson(Map<String, dynamic> json) {
    return MapConfig(
      styleLight: _sanitizeUrl(json['style_light'] as String?, defaultFasoLight),
      styleDark: _sanitizeUrl(json['style_dark'] as String?, defaultFasoDark),
      attribution: json['attribution'] as String? ?? defaultAttribution,
    );
  }
}

/// Provider pour charger la configuration de style depuis le backend (/config/map)
final mapConfigProvider = FutureProvider<MapConfig>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get('/config/map');
    if (response.data is Map<String, dynamic>) {
      AppLogger.i('Configuration carte reçue du backend: ${response.data}');
      return MapConfig.fromJson(response.data as Map<String, dynamic>);
    }
  } catch (e) {
    AppLogger.d('Route /config/map non disponible sur le serveur ($e), repli sur OpenFreeMap par défaut');
  }
  return MapConfig.defaults();
});
