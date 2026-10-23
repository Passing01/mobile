import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Modèle représentant un repère visuel familier du Burkina Faso (Étape 4)
class LandmarkModel extends Equatable {
  final int id;
  final String nom;
  final String? nomMoore;
  final String? nomDioula;
  final double latitude;
  final double longitude;
  final int importance;
  final double visibiliteMetres;
  final String typeRepere;
  final String? description;

  const LandmarkModel({
    required this.id,
    required this.nom,
    this.nomMoore,
    this.nomDioula,
    required this.latitude,
    required this.longitude,
    this.importance = 3,
    this.visibiliteMetres = 80.0,
    this.typeRepere = 'monument',
    this.description,
  });

  factory LandmarkModel.fromJson(Map<String, dynamic> json) {
    return LandmarkModel(
      id: json['id'] as int? ?? 0,
      nom: json['nom'] as String? ?? 'Repère local',
      nomMoore: json['nom_moore'] as String?,
      nomDioula: json['nom_dioula'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      importance: json['importance'] as int? ?? 3,
      visibiliteMetres: (json['visibilite_metres'] as num?)?.toDouble() ?? 80.0,
      typeRepere: json['type_repere'] as String? ?? 'monument',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'nom_moore': nomMoore,
      'nom_dioula': nomDioula,
      'latitude': latitude,
      'longitude': longitude,
      'importance': importance,
      'visibilite_metres': visibiliteMetres,
      'type_repere': typeRepere,
      'description': description,
    };
  }

  /// Retourne le nom du repère selon la langue préférée de l'usager
  String localizedName(String lang) {
    switch (lang.toLowerCase()) {
      case 'mos':
        return nomMoore?.isNotEmpty == true ? nomMoore! : nom;
      case 'diu':
        return nomDioula?.isNotEmpty == true ? nomDioula! : nom;
      case 'fr':
      default:
        return nom;
    }
  }

  /// Icône Material adaptée au type de repère burkinabè
  IconData get iconData {
    switch (typeRepere) {
      case 'rond_point':
        return Icons.rotate_right_rounded;
      case 'monument':
        return Icons.account_balance_rounded;
      case 'marche':
        return Icons.storefront_rounded;
      case 'pharmacie':
        return Icons.local_pharmacy_rounded;
      case 'station':
        return Icons.local_gas_station_rounded;
      case 'maquis':
        return Icons.restaurant_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  List<Object?> get props => [
        id,
        nom,
        nomMoore,
        nomDioula,
        latitude,
        longitude,
        importance,
        visibiliteMetres,
        typeRepere,
        description,
      ];
}
