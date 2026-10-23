import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Modèle représentant un pack cartographique régional (PMTiles) du Burkina Faso
class OfflinePackModel extends Equatable {
  final String regionId;
  final String nomRegion;
  final String description;
  final int tailleOctets;
  final double tailleMo;
  final String version;
  final String sha256Checksum;
  final String fileFormat;
  final List<double> boundingBox;
  final int poiCount;
  final DateTime? updatedAt;
  final bool isDownloaded;
  final double? downloadProgress;
  final bool isDownloading;

  const OfflinePackModel({
    required this.regionId,
    required this.nomRegion,
    required this.description,
    required this.tailleOctets,
    required this.tailleMo,
    required this.version,
    required this.sha256Checksum,
    this.fileFormat = 'pmtiles',
    this.boundingBox = const [],
    this.poiCount = 0,
    this.updatedAt,
    this.isDownloaded = false,
    this.downloadProgress,
    this.isDownloading = false,
  });

  factory OfflinePackModel.fromJson(
    Map<String, dynamic> json, {
    bool isDownloaded = false,
  }) {
    final rawBox = json['bounding_box'] as List<dynamic>? ?? [];
    final box = rawBox.map((b) => (b as num).toDouble()).toList();

    return OfflinePackModel(
      regionId: json['region_id'] as String? ?? 'unknown',
      nomRegion: json['nom_region'] as String? ?? 'Région',
      description: json['description'] as String? ?? '',
      tailleOctets: json['taille_octets'] as int? ?? 0,
      tailleMo: (json['taille_mo'] as num?)?.toDouble() ?? 0.0,
      version: json['version'] as String? ?? '1.0.0',
      sha256Checksum: json['sha256_checksum'] as String? ?? '',
      fileFormat: json['file_format'] as String? ?? 'pmtiles',
      boundingBox: box,
      poiCount: json['poi_count'] as int? ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      isDownloaded: isDownloaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'region_id': regionId,
      'nom_region': nomRegion,
      'description': description,
      'taille_octets': tailleOctets,
      'taille_mo': tailleMo,
      'version': version,
      'sha256_checksum': sha256Checksum,
      'file_format': fileFormat,
      'bounding_box': boundingBox,
      'poi_count': poiCount,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  OfflinePackModel copyWith({
    String? regionId,
    String? nomRegion,
    String? description,
    int? tailleOctets,
    double? tailleMo,
    String? version,
    String? sha256Checksum,
    String? fileFormat,
    List<double>? boundingBox,
    int? poiCount,
    DateTime? updatedAt,
    bool? isDownloaded,
    double? downloadProgress,
    bool? isDownloading,
  }) {
    return OfflinePackModel(
      regionId: regionId ?? this.regionId,
      nomRegion: nomRegion ?? this.nomRegion,
      description: description ?? this.description,
      tailleOctets: tailleOctets ?? this.tailleOctets,
      tailleMo: tailleMo ?? this.tailleMo,
      version: version ?? this.version,
      sha256Checksum: sha256Checksum ?? this.sha256Checksum,
      fileFormat: fileFormat ?? this.fileFormat,
      boundingBox: boundingBox ?? this.boundingBox,
      poiCount: poiCount ?? this.poiCount,
      updatedAt: updatedAt ?? this.updatedAt,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isDownloading: isDownloading ?? this.isDownloading,
    );
  }

  /// Icône Material adaptée à la région
  IconData get iconData {
    if (regionId.contains('centre') || regionId.contains('ouagadougou')) {
      return Icons.location_city_rounded;
    } else if (regionId.contains('cascades') || regionId.contains('banfora')) {
      return Icons.landscape_rounded;
    } else if (regionId.contains('national')) {
      return Icons.public_rounded;
    } else if (regionId.contains('bobo') || regionId.contains('bassins')) {
      return Icons.domain_rounded;
    }
    return Icons.map_rounded;
  }

  /// Taille formatée en Mo
  String get formattedSize {
    return '${tailleMo.toStringAsFixed(1)} Mo';
  }

  @override
  List<Object?> get props => [
        regionId,
        nomRegion,
        description,
        tailleOctets,
        tailleMo,
        version,
        sha256Checksum,
        fileFormat,
        boundingBox,
        poiCount,
        updatedAt,
        isDownloaded,
        downloadProgress,
        isDownloading,
      ];
}
