import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/weather/data/models/weather_model.dart';
import 'package:qvgestion_mobile/features/weather/data/repositories/weather_repository.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WeatherRepository(apiClient: apiClient);
});

final currentWeatherProvider = FutureProvider<WeatherModel>((ref) async {
  final repository = ref.watch(weatherRepositoryProvider);
  final location = ref.watch(currentLocationProvider);
  return repository.getCurrentWeather(lat: location.lat, lon: location.lon);
});
