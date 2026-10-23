import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Catégorie de lieux (POI) retournée par le backend QvGestion / FASO NAV
/// Conforme à la taxonomie pilotée par l'administrateur
class CategoryModel extends Equatable {
  final int id;
  final String nom;
  final String slug;
  final String icone;
  final String? description;
  final String color;
  final int markerSize; // 1 à 5 : taille du point sur la carte
  final Map<String, String> labels; // {"fr": "Pharmacie", "moore": "...", "dioula": "..."}
  final List<dynamic> osmTags; // [["amenity", "pharmacy"]]
  final bool isFilter;
  final int sortOrder;
  final int? parentId;

  const CategoryModel({
    required this.id,
    required this.nom,
    required this.slug,
    required this.icone,
    this.description,
    this.color = '#2563EB',
    this.markerSize = 3,
    this.labels = const {},
    this.osmTags = const [],
    this.isFilter = true,
    this.sortOrder = 100,
    this.parentId,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    final Map<String, String> parsedLabels = {};
    if (rawLabels is Map) {
      rawLabels.forEach((k, v) {
        if (k != null && v != null) {
          parsedLabels[k.toString()] = v.toString();
        }
      });
    }

    // Nom par défaut : labels['fr'] -> champ 'nom' -> slug
    final nom = (json['nom'] as String?) ??
        parsedLabels['fr'] ??
        (json['slug'] as String? ?? 'Lieu');

    return CategoryModel(
      id: json['id'] as int? ?? 0,
      nom: nom,
      slug: (json['slug'] as String?) ?? 'divers',
      icone: (json['icone'] as String?) ?? (json['icon'] as String?) ?? 'place',
      description: json['description'] as String?,
      color: (json['color'] as String?) ?? _defaultColorForSlug(json['slug'] as String?),
      markerSize: (json['marker_size'] as num?)?.toInt() ?? _defaultSizeForSlug(json['slug'] as String?),
      labels: parsedLabels,
      osmTags: (json['osm_tags'] as List<dynamic>?) ?? const [],
      isFilter: (json['is_filter'] as bool?) ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      parentId: (json['parent_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'slug': slug,
      'icone': icone,
      'color': color,
      'marker_size': markerSize,
      if (description != null) 'description': description,
      if (labels.isNotEmpty) 'labels': labels,
      if (osmTags.isNotEmpty) 'osm_tags': osmTags,
      'is_filter': isFilter,
      'sort_order': sortOrder,
      if (parentId != null) 'parent_id': parentId,
    };
  }

  /// Récupère le libellé adapté à la langue demandée (fr, moore, dioula)
  String labelIn(String languageCode) {
    final lang = languageCode.toLowerCase();
    if (lang == 'mos' || lang == 'moore') {
      return labels['moore'] ?? labels['mos'] ?? nom;
    }
    if (lang == 'diu' || lang == 'dioula') {
      return labels['dioula'] ?? labels['diu'] ?? nom;
    }
    if (labels.containsKey('fr') && labels['fr']!.isNotEmpty) {
      return labels['fr']!;
    }
    if (slug == 'pharmacie') return 'Pharmacies de garde';
    if (slug == 'station-service') return 'Stations d\'essence';
    return nom;
  }

  /// Couleur Flutter prête à l'emploi (parse le code hex #RRGGBB)
  Color get displayColor {
    try {
      final hex = color.replaceAll('#', '').trim();
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      AppLogger.d('Erreur parsing hex couleur: $e (valeur: $color)');
    }
    return const Color(0xFF2563EB);
  }

  /// Icône Flutter correspondante au slug backend
  IconData get iconData {
    switch (slug) {
      case 'pharmacie':
        return Icons.local_pharmacy_rounded;
      case 'station-service':
      case 'station':
        return Icons.local_gas_station_rounded;
      case 'maquis-restaurant':
      case 'maquis':
        return Icons.restaurant_rounded;
      case 'hopital-sante':
      case 'hopital':
        return Icons.local_hospital_rounded;
      case 'banque-distributeur':
      case 'banque':
        return Icons.account_balance_rounded;
      case 'administration':
        return Icons.account_balance_outlined;
      case 'ecole':
        return Icons.school_rounded;
      case 'marche':
        return Icons.storefront_rounded;
      case 'patrimoine':
        return Icons.museum_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static String _defaultColorForSlug(String? slug) {
    switch (slug) {
      case 'pharmacie':
        return '#16A34A'; // Vert
      case 'hopital-sante':
      case 'hopital':
        return '#DC2626'; // Rouge
      case 'maquis-restaurant':
      case 'maquis':
        return '#EA580C'; // Orange
      case 'station-service':
      case 'station':
        return '#CA8A04'; // Jaune ambré
      case 'administration':
        return '#2563EB'; // Bleu
      case 'banque-distributeur':
      case 'banque':
        return '#7C3AED'; // Violet
      case 'ecole':
        return '#0D9488'; // Turquoise
      case 'marche':
        return '#854D0E'; // Marron
      default:
        return '#1E3A5F';
    }
  }

  static int _defaultSizeForSlug(String? slug) {
    switch (slug) {
      case 'hopital-sante':
      case 'hopital':
      case 'marche':
        return 5;
      case 'pharmacie':
      case 'station-service':
      case 'station':
      case 'administration':
        return 4;
      case 'maquis-restaurant':
      case 'maquis':
      case 'banque-distributeur':
      case 'banque':
      case 'ecole':
        return 3;
      default:
        return 3;
    }
  }

  @override
  List<Object?> get props => [
        id,
        nom,
        slug,
        icone,
        description,
        color,
        markerSize,
        labels,
        osmTags,
        isFilter,
        sortOrder,
        parentId,
      ];
}

/// Liste des catégories officielles de départ conformes à la spécification technique FASO NAV
const List<CategoryModel> defaultOuagaCategories = [
  CategoryModel(
    id: 1,
    nom: 'Pharmacie',
    slug: 'pharmacie',
    icone: 'local_pharmacy',
    color: '#16A34A',
    markerSize: 4,
    labels: {'fr': 'Pharmacie', 'moore': 'Tɩɩm-roogo', 'dioula': 'Fura-so'},
    osmTags: [['amenity', 'pharmacy']],
    sortOrder: 1,
  ),
  CategoryModel(
    id: 2,
    nom: 'Hôpital & Clinique',
    slug: 'hopital',
    icone: 'local_hospital',
    color: '#DC2626',
    markerSize: 5,
    labels: {'fr': 'Hôpital, clinique', 'moore': 'Logtoré', 'dioula': 'Dɔgɔtɔrɔso'},
    osmTags: [['amenity', 'hospital'], ['amenity', 'clinic']],
    sortOrder: 2,
  ),
  CategoryModel(
    id: 3,
    nom: 'Maquis & Restaurant',
    slug: 'maquis',
    icone: 'restaurant',
    color: '#EA580C',
    markerSize: 3,
    labels: {'fr': 'Maquis, restaurant, bar', 'moore': 'Dɩɩb-ziiga', 'dioula': 'Dumuni-yɔrɔ'},
    osmTags: [['amenity', 'restaurant'], ['amenity', 'bar'], ['amenity', 'cafe']],
    sortOrder: 3,
  ),
  CategoryModel(
    id: 4,
    nom: 'Station d\'essence',
    slug: 'station',
    icone: 'local_gas_station',
    color: '#CA8A04',
    markerSize: 4,
    labels: {'fr': 'Station d\'essence', 'moore': 'Karozɛn-ziiga', 'dioula': 'Esi-yɔrɔ'},
    osmTags: [['amenity', 'fuel']],
    sortOrder: 4,
  ),
  CategoryModel(
    id: 5,
    nom: 'Administration',
    slug: 'administration',
    icone: 'account_balance',
    color: '#2563EB',
    markerSize: 4,
    labels: {'fr': 'Bâtiment administratif', 'moore': 'Gomna roogo', 'dioula': 'Fanga-so'},
    osmTags: [['office', 'government'], ['amenity', 'townhall'], ['amenity', 'police']],
    sortOrder: 5,
  ),
  CategoryModel(
    id: 6,
    nom: 'Banque & DAB',
    slug: 'banque',
    icone: 'account_balance',
    color: '#7C3AED',
    markerSize: 3,
    labels: {'fr': 'Banque, DAB', 'moore': 'Ligdi roogo', 'dioula': 'Wari-so'},
    osmTags: [['amenity', 'bank'], ['amenity', 'atm']],
    sortOrder: 6,
  ),
  CategoryModel(
    id: 7,
    nom: 'École & Université',
    slug: 'ecole',
    icone: 'school',
    color: '#0D9488',
    markerSize: 3,
    labels: {'fr': 'École, université', 'moore': 'Lekoll', 'dioula': 'Kalan-so'},
    osmTags: [['amenity', 'school'], ['amenity', 'college'], ['amenity', 'university']],
    sortOrder: 7,
  ),
  CategoryModel(
    id: 8,
    nom: 'Marché',
    slug: 'marche',
    icone: 'storefront',
    color: '#854D0E',
    markerSize: 5,
    labels: {'fr': 'Marché', 'moore': 'Raaga', 'dioula': 'Sugu'},
    osmTags: [['amenity', 'marketplace']],
    sortOrder: 8,
  ),
];
