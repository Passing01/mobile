import 'package:equatable/equatable.dart';

/// Modèle pour un POI compact indexé dans le pack hors-ligne
class CompactPoiModel extends Equatable {
  final int id;
  final String nom;
  final String categorieSlug;
  final double latitude;
  final double longitude;
  final String? quartier;
  final String? telephone;

  const CompactPoiModel({
    required this.id,
    required this.nom,
    required this.categorieSlug,
    required this.latitude,
    required this.longitude,
    this.quartier,
    this.telephone,
  });

  factory CompactPoiModel.fromJson(Map<String, dynamic> json) {
    return CompactPoiModel(
      id: json['id'] as int? ?? 0,
      nom: json['nom'] as String? ?? '',
      categorieSlug: json['categorie_slug'] as String? ?? 'autre',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      quartier: json['quartier'] as String?,
      telephone: json['telephone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'categorie_slug': categorieSlug,
      'latitude': latitude,
      'longitude': longitude,
      'quartier': quartier,
      'telephone': telephone,
    };
  }

  @override
  List<Object?> get props => [
        id,
        nom,
        categorieSlug,
        latitude,
        longitude,
        quartier,
        telephone,
      ];
}

/// Modèle de l'export compact des POIs régionaux hors-ligne
class OfflinePoisExportModel extends Equatable {
  final String regionId;
  final String version;
  final int totalPois;
  final List<CompactPoiModel> pois;

  const OfflinePoisExportModel({
    required this.regionId,
    required this.version,
    required this.totalPois,
    required this.pois,
  });

  factory OfflinePoisExportModel.fromJson(Map<String, dynamic> json) {
    final list = json['pois'] as List<dynamic>? ?? [];
    return OfflinePoisExportModel(
      regionId: json['region_id'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      totalPois: json['total_pois'] as int? ?? 0,
      pois: list
          .map((item) => CompactPoiModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [regionId, version, totalPois, pois];
}
