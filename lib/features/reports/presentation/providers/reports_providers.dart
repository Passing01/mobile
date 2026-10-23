import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/reports/data/models/create_report_request.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_type_model.dart';
import 'package:qvgestion_mobile/features/reports/data/repositories/reports_repository.dart';

/// Provider d'accès au repository des signalements
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportsRepository(apiClient: apiClient);
});

/// Provider de la liste des types d'incidents routiers
final reportTypesProvider = FutureProvider<List<ReportTypeModel>>((ref) async {
  final repository = ref.watch(reportsRepositoryProvider);
  return repository.getReportTypes();
});

/// Gestionnaire des signalements actifs visibles sur la carte
class ActiveReportsNotifier extends Notifier<AsyncValue<List<ReportModel>>> {
  @override
  AsyncValue<List<ReportModel>> build() {
    Future.microtask(() => loadReports());
    return const AsyncValue.loading();
  }

  /// Recharge les signalements depuis le serveur
  Future<void> loadReports({
    double? minLat,
    double? maxLat,
    double? minLon,
    double? maxLon,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(reportsRepositoryProvider);
      final list = await repository.getActiveReports(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
      );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Soumet un vote citoyen (+1 confirmation / -1 infirmation)
  Future<ReportModel?> voteOnReport(int reportId, int vote) async {
    final repository = ref.read(reportsRepositoryProvider);
    try {
      final updatedReport = await repository.voteReport(reportId, vote);

      final current = state.value ?? [];
      if (!updatedReport.isActive || updatedReport.statut == 'resolved') {
        // Si le signalement a été auto-résolu par consensus, le retirer de la carte
        state = AsyncValue.data(current.where((r) => r.id != reportId).toList());
      } else {
        state = AsyncValue.data(
          current.map((r) => r.id == reportId ? updatedReport : r).toList(),
        );
      }

      return updatedReport;
    } catch (e, stack) {
      AppLogger.e('Erreur lors du vote sur le signalement $reportId', e, stack);
      rethrow;
    }
  }

  /// Ajoute immédiatement un signalement nouvellement créé en tête de liste
  void addCreatedReport(ReportModel report) {
    final current = state.value ?? [];
    state = AsyncValue.data([report, ...current]);
  }
}

final activeReportsProvider =
    NotifierProvider<ActiveReportsNotifier, AsyncValue<List<ReportModel>>>(
  ActiveReportsNotifier.new,
);

/// Signalement sélectionné par l'utilisateur pour affichage de la fiche détaillée
class SelectedReportNotifier extends Notifier<ReportModel?> {
  @override
  ReportModel? build() => null;

  void select(ReportModel report) => state = report;
  void clear() => state = null;
}

final selectedReportProvider =
    NotifierProvider<SelectedReportNotifier, ReportModel?>(
  SelectedReportNotifier.new,
);

/// Contrôleur pour la création asynchrone d'un signalement
class CreateReportNotifier extends Notifier<AsyncValue<ReportModel?>> {
  @override
  AsyncValue<ReportModel?> build() {
    return const AsyncValue.data(null);
  }

  Future<ReportModel?> submitReport(CreateReportRequest request) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(reportsRepositoryProvider);
      final report = await repository.createReport(request);
      ref.read(activeReportsProvider.notifier).addCreatedReport(report);
      state = AsyncValue.data(report);
      return report;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }
}

final createReportNotifierProvider =
    NotifierProvider<CreateReportNotifier, AsyncValue<ReportModel?>>(
  CreateReportNotifier.new,
);
