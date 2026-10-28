import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

class RoutingException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const RoutingException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// Service de calcul d'itinéraire réel (OpenStreetMap / Valhalla via Backend)
class RouteService {
  final ApiClient apiClient;

  RouteService(this.apiClient);

  String normalizeMode(String mode) {
    switch (mode.toLowerCase().trim()) {
      case 'moto':
      case 'motorcycle':
      case 'deux-roues':
      case 'deux_roues':
        return 'moto';
      case 'voiture':
      case 'auto':
      case 'car':
      case 'taxi':
        return 'voiture';
      case 'pied':
      case 'pieton':
      case 'piéton':
      case 'pedestrian':
      case 'marche':
      case 'walk':
        return 'pied';
      default:
        return 'moto';
    }
  }

  /// Calcule l'itinéraire réel via POST /api/v1/routes
  Future<RouteModel> computeRoute({
    required List<CoordinateModel> points,
    String mode = 'moto',
    String lang = 'fr-FR',
  }) async {
    if (points.length < 2) {
      throw const RoutingException(
        code: 'TOO_FEW_POINTS',
        message: 'Il faut au moins un départ et une arrivée',
        statusCode: 422,
      );
    }

    final normalizedMode = normalizeMode(mode);

    try {
      final payload = {
        'points': points.map((p) => {'lat': p.lat, 'lng': p.lon}).toList(),
        'mode': normalizedMode,
      };

      final response = await apiClient.post<dynamic>(
        ApiEndpoints.routes,
        data: payload,
      );

      final data = response.data as Map<String, dynamic>;
      return RouteModel.fromJson(data);
    } on DioException catch (e) {
      AppLogger.e('Erreur API itinéraire: ${e.response?.statusCode} - ${e.message}');
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (status == 503 ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw const RoutingException(
          code: 'ENGINE_DOWN',
          message: 'Le calcul d\'itinéraire est indisponible',
          statusCode: 503,
        );
      }

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is Map<String, dynamic>) {
          throw RoutingException(
            code: detail['error']?.toString() ?? 'ROUTING_ERROR',
            message: detail['message']?.toString() ?? 'Erreur lors du calcul d\'itinéraire',
            statusCode: status ?? 422,
          );
        } else if (detail is String) {
          throw RoutingException(
            code: 'ROUTING_ERROR',
            message: detail,
            statusCode: status ?? 422,
          );
        }
      }

      throw RoutingException(
        code: 'ROUTING_ERROR',
        message: 'Erreur lors du calcul d\'itinéraire',
        statusCode: status,
      );
    } catch (e) {
      if (e is RoutingException) rethrow;
      AppLogger.e('Exception calcul itinéraire: $e');
      throw RoutingException(
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
      );
    }
  }

  /// Calcule l'itinéraire à partir d'une liste de points [[lng, lat], ...]
  Future<Map<String, dynamic>> computeRaw(
    List<List<double>> points, {
    String profile = 'moto',
    String language = 'fr',
  }) async {
    final coordModels = points
        .map((pt) => CoordinateModel(lat: pt[1], lon: pt[0]))
        .toList();
    final route = await computeRoute(
      points: coordModels,
      mode: profile,
      lang: language,
    );
    return route.toJson();
  }
}

final routeServiceProvider = Provider<RouteService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RouteService(apiClient);
});
