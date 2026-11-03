import 'package:equatable/equatable.dart';

/// Types de clients pour l'API B2B / B2G de FASO NAV
enum ApiClientType {
  delivery('delivery', 'Livraison & Logistique'),
  emergency('emergency', 'SAMU / Pompiers / Urgences'),
  vtc('vtc', 'VTC & Taxis'),
  municipality('municipality', 'Mairie & Travaux Publics'),
  developer('developer', 'Développeur / Startup');

  final String slug;
  final String label;
  const ApiClientType(this.slug, this.label);

  static ApiClientType fromString(String raw) {
    for (final val in ApiClientType.values) {
      if (val.slug == raw || val.name == raw) return val;
    }
    return ApiClientType.developer;
  }
}

/// Niveaux d'abonnement / priorité API
enum ApiTier {
  starter('starter', 'Starter (Gratuit)'),
  pro('pro', 'Pro B2B'),
  enterprise('enterprise', 'Entreprise B2B'),
  emergencyPriority('emergency_priority', 'Priorité État / Secours');

  final String slug;
  final String label;
  const ApiTier(this.slug, this.label);

  static ApiTier fromString(String raw) {
    for (final val in ApiTier.values) {
      if (val.slug == raw || val.name == raw) return val;
    }
    return ApiTier.starter;
  }
}

/// Modèle d'une clé API B2B/B2G
class ApiKeyModel extends Equatable {
  final int id;
  final String key;
  final String name;
  final ApiClientType clientType;
  final ApiTier tier;
  final int monthlyQuota;
  final int currentUsage;
  final bool isActive;
  final String? description;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;

  const ApiKeyModel({
    required this.id,
    required this.key,
    required this.name,
    required this.clientType,
    required this.tier,
    required this.monthlyQuota,
    required this.currentUsage,
    required this.isActive,
    this.description,
    required this.createdAt,
    this.expiresAt,
    this.lastUsedAt,
  });

  /// Pourcentage d'utilisation du quota
  double get usagePercentage {
    if (monthlyQuota <= 0) return 0.0;
    return (currentUsage / monthlyQuota).clamp(0.0, 1.0);
  }

  factory ApiKeyModel.fromJson(Map<String, dynamic> json) {
    return ApiKeyModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      clientType: ApiClientType.fromString(json['client_type']?.toString() ?? 'developer'),
      tier: ApiTier.fromString(json['tier']?.toString() ?? 'starter'),
      monthlyQuota: (json['monthly_quota'] as num?)?.toInt() ?? 50000,
      currentUsage: (json['current_usage'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'name': name,
      'client_type': clientType.slug,
      'tier': tier.slug,
      'monthly_quota': monthlyQuota,
      'current_usage': currentUsage,
      'is_active': isActive,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'last_used_at': lastUsedAt?.toIso8601String(),
    };
  }

  ApiKeyModel copyWith({
    int? id,
    String? key,
    String? name,
    ApiClientType? clientType,
    ApiTier? tier,
    int? monthlyQuota,
    int? currentUsage,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? lastUsedAt,
  }) {
    return ApiKeyModel(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      clientType: clientType ?? this.clientType,
      tier: tier ?? this.tier,
      monthlyQuota: monthlyQuota ?? this.monthlyQuota,
      currentUsage: currentUsage ?? this.currentUsage,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        key,
        name,
        clientType,
        tier,
        monthlyQuota,
        currentUsage,
        isActive,
        description,
        createdAt,
        expiresAt,
        lastUsedAt,
      ];
}

