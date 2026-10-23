import 'package:equatable/equatable.dart';

/// Modèle météo retourné par le backend QvGestion /weather/current
class WeatherModel extends Equatable {
  final double latitude;
  final double longitude;
  final double temperatureCelsius;
  final double apparentTemperatureCelsius;
  final int humidityPercent;
  final double precipitationMm;
  final double windSpeedKmh;
  final double windGustsKmh;
  final int weatherCode;
  final String description;
  final String drivingAdvisory;
  final bool isCached;

  const WeatherModel({
    required this.latitude,
    required this.longitude,
    required this.temperatureCelsius,
    required this.apparentTemperatureCelsius,
    required this.humidityPercent,
    required this.precipitationMm,
    required this.windSpeedKmh,
    required this.windGustsKmh,
    required this.weatherCode,
    required this.description,
    required this.drivingAdvisory,
    this.isCached = false,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      temperatureCelsius: (json['temperature_celsius'] as num).toDouble(),
      apparentTemperatureCelsius:
          (json['apparent_temperature_celsius'] as num).toDouble(),
      humidityPercent: json['humidity_percent'] as int,
      precipitationMm: (json['precipitation_mm'] as num).toDouble(),
      windSpeedKmh: (json['wind_speed_kmh'] as num).toDouble(),
      windGustsKmh: (json['wind_gusts_kmh'] as num).toDouble(),
      weatherCode: json['weather_code'] as int,
      description: json['description'] as String,
      drivingAdvisory: json['driving_advisory'] as String,
      isCached: (json['is_cached'] as bool?) ?? false,
    );
  }

  /// Chaîne formatée pour le bandeau supérieur de l'application (ex: "Ouagadougou 32°C")
  String get formattedTicker {
    final temp = temperatureCelsius.round();
    return 'Ouagadougou $temp°C';
  }

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        temperatureCelsius,
        apparentTemperatureCelsius,
        humidityPercent,
        precipitationMm,
        windSpeedKmh,
        windGustsKmh,
        weatherCode,
        description,
        drivingAdvisory,
        isCached,
      ];
}
