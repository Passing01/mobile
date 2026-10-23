import 'package:equatable/equatable.dart';

/// Modèle des métriques opérationnelles du tableau de bord d'administration
class AdminDashboardStatsModel extends Equatable {
  final int totalUsers;
  final Map<String, dynamic> usersByRole;
  final Map<String, dynamic> usersByLanguage;
  final int totalPlaces;
  final int pendingPlacesCount;
  final int totalReports;
  final int activeReportsCount;
  final int totalRoutesCalculated;
  final Map<String, dynamic> routesByMode;
  final int activeDevicesCount;

  const AdminDashboardStatsModel({
    required this.totalUsers,
    this.usersByRole = const {},
    this.usersByLanguage = const {},
    required this.totalPlaces,
    required this.pendingPlacesCount,
    required this.totalReports,
    required this.activeReportsCount,
    required this.totalRoutesCalculated,
    this.routesByMode = const {},
    required this.activeDevicesCount,
  });

  factory AdminDashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStatsModel(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      usersByRole: (json['users_by_role'] as Map<String, dynamic>?) ?? {},
      usersByLanguage: (json['users_by_language'] as Map<String, dynamic>?) ?? {},
      totalPlaces: (json['total_places'] as num?)?.toInt() ?? 0,
      pendingPlacesCount: (json['pending_places_count'] as num?)?.toInt() ?? 0,
      totalReports: (json['total_reports'] as num?)?.toInt() ?? 0,
      activeReportsCount: (json['active_reports_count'] as num?)?.toInt() ?? 0,
      totalRoutesCalculated: (json['total_routes_calculated'] as num?)?.toInt() ?? 0,
      routesByMode: (json['routes_by_mode'] as Map<String, dynamic>?) ?? {},
      activeDevicesCount: (json['active_devices_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        totalUsers,
        totalPlaces,
        pendingPlacesCount,
        totalReports,
        activeReportsCount,
        totalRoutesCalculated,
        activeDevicesCount,
      ];
}
