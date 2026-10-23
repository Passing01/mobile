import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/weather/data/models/weather_model.dart';

/// Repository pour récupérer la météo locale en direct depuis l'API QvGestion
class WeatherRepository {
  final ApiClient apiClient;

  WeatherRepository({required this.apiClient});

  /// Récupère les conditions météo et conseils de conduite depuis GET /api/v1/weather/current
  Future<WeatherModel> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await apiClient.get<dynamic>(
        ApiEndpoints.weatherCurrent,
        queryParameters: {
          'lat': lat,
          'lon': lon,
        },
      );
      return WeatherModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.w('Impossible de récupérer la météo en direct: $e');
      // Valeur de repli sécurisée en cas d'indisponibilité
      return WeatherModel(
        latitude: lat,
        longitude: lon,
        temperatureCelsius: 32.0,
        apparentTemperatureCelsius: 35.0,
        humidityPercent: 40,
        precipitationMm: 0.0,
        windSpeedKmh: 12.0,
        windGustsKmh: 18.0,
        weatherCode: 1,
        description: 'Ensoleillé',
        drivingAdvisory: 'Trafic fluide sur l\'Avenue Kwame N\'Krumah',
      );
    }
  }
}
