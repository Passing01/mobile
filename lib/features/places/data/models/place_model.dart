import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:qvgestion_mobile/core/theme/map_theme.dart';
import 'category_model.dart';

/// Modèle d'un lieu d'intérêt (POI) connecté à l'API QvGestion / FASO NAV
/// Supporte à la fois les endpoints REST standards et les FeatureCollection GeoJSON
class PlaceModel extends Equatable {
  final int id;
  final String? uuid;
  final String nom;
  final List<String> nameVariants;
  final String? description;
  final int categorieId;
  final double latitude;
  final double longitude;
  final String? adresse;
  final String ville;
  final String? quartier;
  final String? telephone;
  final String? horaires;
  final bool estValide;
  final CategoryModel? categorie;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isFavorite;
  final double? distanceMeters;

  // Attributs avancés FASO NAV (Ancres, Confiance, Tags, Importance)
  final int importance; // 1 à 5
  final bool isAnchor; // Utilisable comme repère dans les consignes vocales
  final int confidence; // 3 relevé terrain, 2 déduit d'une source ouverte, 1 incertain
  final String source; // admin | survey | user | osm | overture | foursquare
  final Map<String, dynamic> tags; // {"de_garde": true, "open_24_7": true}
  final String? nameTts; // Correction phonétique pour synthèse vocale (Étape 9)

  const PlaceModel({
    required this.id,
    this.uuid,
    required this.nom,
    this.nameVariants = const [],
    this.description,
    required this.categorieId,
    required this.latitude,
    required this.longitude,
    this.adresse,
    this.ville = 'Ouagadougou',
    this.quartier,
    this.telephone,
    this.horaires,
    this.estValide = true,
    this.categorie,
    this.createdAt,
    this.updatedAt,
    this.isFavorite = false,
    this.distanceMeters,
    this.importance = 3,
    this.isAnchor = false,
    this.confidence = 2,
    this.source = 'admin',
    this.tags = const {},
    this.nameTts,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    int parsedId = 0;
    String? parsedUuid;

    if (rawId is int) {
      parsedId = rawId;
      parsedUuid = rawId.toString();
    } else if (rawId != null) {
      parsedUuid = rawId.toString();
      parsedId = int.tryParse(parsedUuid) ?? (parsedUuid.hashCode & 0x7FFFFFFF);
    }

    final nom = (json['nom'] as String?) ??
        (json['name'] as String?) ??
        'Lieu sans nom';

    final rawVariants = json['name_variants'];
    List<String> variants = [];
    if (rawVariants is List) {
      variants = rawVariants.map((e) => e.toString()).toList();
    }

    final rawTags = json['tags'];
    Map<String, dynamic> parsedTags = {};
    if (rawTags is Map) {
      rawTags.forEach((k, v) => parsedTags[k.toString()] = v);
    }

    // Gestion de la géométrie GeoJSON si présente
    double lat = 0.0;
    double lon = 0.0;
    if (json.containsKey('latitude') && json.containsKey('longitude')) {
      lat = (json['latitude'] as num).toDouble();
      lon = (json['longitude'] as num).toDouble();
    } else if (json['geometry'] is Map) {
      final geom = _safeCastMap(json['geometry']);
      final coords = geom['coordinates'] as List<dynamic>?;
      if (coords != null && coords.length >= 2) {
        lon = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    }

    return PlaceModel(
      id: parsedId,
      uuid: parsedUuid,
      nom: nom,
      nameVariants: variants,
      description: json['description'] as String?,
      categorieId: (json['categorie_id'] as num?)?.toInt() ??
          (json['category_id'] as num?)?.toInt() ??
          1,
      latitude: lat,
      longitude: lon,
      adresse: (json['adresse'] as String?) ?? (json['address_text'] as String?),
      ville: (json['ville'] as String?) ?? 'Ouagadougou',
      quartier: json['quartier'] as String?,
      telephone: (json['telephone'] as String?) ?? (json['phone'] as String?),
      horaires: json['horaires']?.toString() ?? json['hours']?.toString(),
      estValide: (json['est_valide'] as bool?) ??
          (json['status'] == null || json['status'] == 'validated'),
      categorie: json['categorie'] is Map
          ? CategoryModel.fromJson(_safeCastMap(json['categorie']))
          : (json['category'] != null && json['category'] is String
              ? CategoryModel(
                  id: 0,
                  nom: json['category'].toString(),
                  slug: json['category'].toString(),
                  icone: 'place',
                )
              : null),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      isFavorite: (json['is_favorite'] as bool?) ?? false,
      distanceMeters: json['distance_meters'] != null
          ? (json['distance_meters'] as num).toDouble()
          : null,
      importance: (json['importance'] as num?)?.toInt() ?? 3,
      isAnchor: (json['is_anchor'] as bool?) ?? false,
      confidence: (json['confidence'] as num?)?.toInt() ?? 2,
      source: (json['source'] as String?) ?? 'admin',
      tags: parsedTags,
      nameTts: (json['name_tts'] as String?) ?? (json['nameTts'] as String?),
    );
  }

  /// Convertit récursivement n'importe quel Map (y compris `_Map<Object?, Object?>` des plugins natifs)
  static Map<String, dynamic> _safeCastMap(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, dynamic>{};
    raw.forEach((k, v) {
      if (k != null) {
        if (v is Map) {
          result[k.toString()] = _safeCastMap(v);
        } else {
          result[k.toString()] = v;
        }
      }
    });
    return result;
  }

  /// Constructeur spécialisé depuis un Feature GeoJSON retourné par l'API ou le moteur cartographique
  factory PlaceModel.fromGeoJsonFeature(Map<dynamic, dynamic> rawFeature) {
    final feature = _safeCastMap(rawFeature);
    final geometry = _safeCastMap(feature['geometry']);
    final coordinates = (geometry['coordinates'] as List<dynamic>?) ?? [0.0, 0.0];
    final props = _safeCastMap(feature['properties']);

    final lon = coordinates.isNotEmpty ? (coordinates[0] as num).toDouble() : 0.0;
    final lat = coordinates.length > 1 ? (coordinates[1] as num).toDouble() : 0.0;

    final rawId = props['id'];
    int id = 0;
    String? uuid;
    if (rawId is int) {
      id = rawId;
      uuid = id.toString();
    } else if (rawId != null) {
      uuid = rawId.toString();
      id = int.tryParse(uuid) ?? (uuid.hashCode & 0x7FFFFFFF);
    }

    final catSlug = (props['category'] as String?) ?? 'divers';
    final catColor = (props['color'] as String?) ?? '#2563EB';
    final catSize = (props['size'] as num?)?.toInt() ?? 3;

    return PlaceModel(
      id: id,
      uuid: uuid,
      nom: (props['name'] as String?) ?? (props['nom'] as String?) ?? 'Lieu',
      categorieId: (props['category_id'] as num?)?.toInt() ?? 0,
      latitude: lat,
      longitude: lon,
      importance: (props['importance'] as num?)?.toInt() ?? 3,
      tags: _safeCastMap(props['tags']),
      categorie: CategoryModel(
        id: 0,
        nom: catSlug,
        slug: catSlug,
        icone: 'place',
        color: catColor,
        markerSize: catSize,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (uuid != null) 'uuid': uuid,
      'nom': nom,
      if (nameVariants.isNotEmpty) 'name_variants': nameVariants,
      if (description != null) 'description': description,
      'categorie_id': categorieId,
      'latitude': latitude,
      'longitude': longitude,
      if (adresse != null) 'adresse': adresse,
      'ville': ville,
      if (quartier != null) 'quartier': quartier,
      if (telephone != null) 'telephone': telephone,
      if (horaires != null) 'horaires': horaires,
      'est_valide': estValide,
      if (categorie != null) 'categorie': categorie!.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'is_favorite': isFavorite,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      'importance': importance,
      'is_anchor': isAnchor,
      'confidence': confidence,
      'source': source,
      if (tags.isNotEmpty) 'tags': tags,
      if (nameTts != null) 'name_tts': nameTts,
    };
  }

  /// Conversion en Feature GeoJSON pour intégration directe dans la couche cartographique
  Map<String, dynamic> toGeoJsonFeature() {
    final catSlug = categorie?.slug ?? 'divers';
    return {
      'type': 'Feature',
      'id': uuid ?? id.toString(),
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'properties': {
        'id': uuid ?? id.toString(),
        'name': nom,
        'nom': nom,
        'category': catSlug,
        'category_slug': catSlug,
        'color': MapTheme.colorForCategory(catSlug),
        'strokeColor': MapTheme.strokeColorForCategory(catSlug),
        'icon': _pinIconFor(catSlug),
        'size': categorie?.markerSize ?? importance,
        'importance': importance,
        'tags': tags,
      },
    };
  }

  static String _pinIconFor(String slug) {
    final s = slug.toLowerCase().trim();
    if (s.contains('pharmacie')) return 'pin-pharmacie';
    if (s.contains('station')) return 'pin-station-service';
    if (s.contains('maquis') || s.contains('resto') || s.contains('restaurant')) return 'pin-maquis-restaurant';
    if (s.contains('hopital') || s.contains('sante') || s.contains('clinique') || s.contains('csps')) return 'pin-hopital-sante';
    if (s.contains('banque') || s.contains('distributeur') || s.contains('atm')) return 'pin-banque-distributeur';
    if (s.contains('administration') || s.contains('mairie') || s.contains('police')) return 'pin-administration';
    if (s.contains('ecole') || s.contains('universite') || s.contains('lycee') || s.contains('college')) return 'pin-ecole-universite';
    if (s.contains('marche') || s.contains('commerce') || s.contains('boutique') || s.contains('alimentation')) return 'pin-marche-commerce';
    return 'pin-default';
  }

  PlaceModel copyWith({
    int? id,
    String? uuid,
    String? nom,
    List<String>? nameVariants,
    String? description,
    int? categorieId,
    double? latitude,
    double? longitude,
    String? adresse,
    String? ville,
    String? quartier,
    String? telephone,
    String? horaires,
    bool? estValide,
    CategoryModel? categorie,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    double? distanceMeters,
    int? importance,
    bool? isAnchor,
    int? confidence,
    String? source,
    Map<String, dynamic>? tags,
    String? nameTts,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nom: nom ?? this.nom,
      nameVariants: nameVariants ?? this.nameVariants,
      description: description ?? this.description,
      categorieId: categorieId ?? this.categorieId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      adresse: adresse ?? this.adresse,
      ville: ville ?? this.ville,
      quartier: quartier ?? this.quartier,
      telephone: telephone ?? this.telephone,
      horaires: horaires ?? this.horaires,
      estValide: estValide ?? this.estValide,
      categorie: categorie ?? this.categorie,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      importance: importance ?? this.importance,
      isAnchor: isAnchor ?? this.isAnchor,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      tags: tags ?? this.tags,
      nameTts: nameTts ?? this.nameTts,
    );
  }

  /// Calcule la distance en mètres jusqu'aux coordonnées (lat, lon) via la formule de Haversine
  double distanceTo(double lat, double lon) {
    const double earthRadius = 6371000.0;
    final dLat = (lat - latitude) * (math.pi / 180.0);
    final dLon = (lon - longitude) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(latitude * (math.pi / 180.0)) *
            math.cos(lat * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Distance formatée lisible pour l'utilisateur burkinabé
  String? get formattedDistance {
    if (distanceMeters == null) return null;
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  /// Sous-titre géographique contextuel (Quartier ou Adresse)
  String get subtitle {
    if (quartier != null && quartier!.isNotEmpty) {
      return quartier!;
    }
    if (adresse != null && adresse!.isNotEmpty) {
      return adresse!;
    }
    return ville;
  }

  /// Indique si la pharmacie est actuellement de garde
  bool get isDeGarde => tags['de_garde'] == true;

  /// Indique si le lieu est ouvert 24h/24
  bool get isOpen24_7 => tags['open_24_7'] == true;

  @override
  List<Object?> get props => [
        id,
        uuid,
        nom,
        nameVariants,
        description,
        categorieId,
        latitude,
        longitude,
        adresse,
        ville,
        quartier,
        telephone,
        horaires,
        estValide,
        categorie,
        createdAt,
        updatedAt,
        isFavorite,
        distanceMeters,
        importance,
        isAnchor,
        confidence,
        source,
        tags,
        nameTts,
      ];
}
