import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';

/// Raccourci dynamique de recherche par catégorie (fourni par GET /api/v1/search/aliases)
class SearchAliasModel {
  final String alias;
  final String label;
  final String? icon;
  final String? color;
  final List<int> categoryIds;
  final List<String> categorySlugs;

  const SearchAliasModel({
    required this.alias,
    required this.label,
    this.icon,
    this.color,
    this.categoryIds = const [],
    this.categorySlugs = const [],
  });

  factory SearchAliasModel.fromJson(Map<String, dynamic> json) {
    return SearchAliasModel(
      alias: json['alias'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      categoryIds: (json['category_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      categorySlugs: (json['category_slugs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  IconData get iconData {
    switch (icon) {
      case 'local_hospital':
      case 'emergency':
        return Icons.local_hospital_rounded;
      case 'local_pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'atm':
        return Icons.atm_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'storefront':
        return Icons.storefront_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'local_police':
        return Icons.local_police_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color get colorValue {
    if (color == null || color!.isEmpty) return const Color(0xFF2563EB);
    try {
      final hex = color!.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }
}

/// Résultat complet d'une recherche depuis GET /api/v1/search
class SearchResultModel {
  final List<PlaceModel> places;
  final int count;
  final List<String> suggestions;
  final String? message;

  const SearchResultModel({
    this.places = const [],
    this.count = 0,
    this.suggestions = const [],
    this.message,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['results'] as List<dynamic>? ?? [];
    final places = rawList
        .map((e) => PlaceModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final suggestions = (json['suggestions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    return SearchResultModel(
      places: places,
      count: json['count'] as int? ?? places.length,
      suggestions: suggestions,
      message: json['message'] as String?,
    );
  }
}

