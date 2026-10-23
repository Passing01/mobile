import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/reports/data/models/create_report_request.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_type_model.dart';

/// Repository pour interagir avec les endpoints de signalements collaboratifs (Étape 5)
class ReportsRepository {
  final ApiClient apiClient;

  ReportsRepository({required this.apiClient});

  /// Récupère la typologie des incidents routiers burkinabè (GET /api/v1/reports/types)
  Future<List<ReportTypeModel>> getReportTypes() async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.reportsTypes);
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((item) => ReportTypeModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la récupération des types de signalement', e, stack);
      rethrow;
    }
  }

  /// Récupère les signalements actifs sur la zone cartographique visible (GET /api/v1/reports/active)
  Future<List<ReportModel>> getActiveReports({
    double? minLat,
    double? maxLat,
    double? minLon,
    double? maxLon,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (minLat != null) queryParams['min_lat'] = minLat;
      if (maxLat != null) queryParams['max_lat'] = maxLat;
      if (minLon != null) queryParams['min_lon'] = minLon;
      if (maxLon != null) queryParams['max_lon'] = maxLon;

      final response = await apiClient.get<dynamic>(
        ApiEndpoints.reportsActive,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((item) => ReportModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.w('Signalements actifs inaccessibles (mode hors-ligne): $e');
      return const [];
    }
  }

  /// Soumet un nouveau signalement d'obstacle routier (POST /api/v1/reports/)
  Future<ReportModel> createReport(CreateReportRequest request) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.reports,
        data: request.toJson(),
      );
      return ReportModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la création d\'un signalement', e, stack);
      rethrow;
    }
  }

  /// Vote pour confirmer (+1) ou infirmer (-1) un signalement (POST /api/v1/reports/{id}/vote)
  Future<ReportModel> voteReport(int reportId, int vote) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.reportVote(reportId),
        data: {'vote': vote},
      );
      return ReportModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors du vote sur le signalement $reportId', e, stack);
      rethrow;
    }
  }

  /// Récupère le détail complet d'un signalement (GET /api/v1/reports/{id})
  Future<ReportModel> getReportDetail(int reportId) async {
    try {
      final response = await apiClient.get<dynamic>(
        ApiEndpoints.reportDetail(reportId),
      );
      return ReportModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la récupération du signalement $reportId', e, stack);
      rethrow;
    }
  }
}
