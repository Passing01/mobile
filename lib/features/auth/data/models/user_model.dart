import 'package:equatable/equatable.dart';

/// Modèle représentant un utilisateur du système QvGestion
class UserModel extends Equatable {
  final int id;
  final String nom;
  final String? email;
  final String telephone;
  final String role;
  final String languePreferee;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.nom,
    this.email,
    required this.telephone,
    this.role = 'user',
    this.languePreferee = 'mos',
    this.isActive = true,
  });

  /// Nom lisible de la langue préférée
  String get nomLangue {
    switch (languePreferee.toLowerCase()) {
      case 'mos':
        return 'Mooré';
      case 'diu':
        return 'Dioula';
      case 'fr':
      default:
        return 'Français';
    }
  }

  /// Vérifie si l'utilisateur possède les privilèges administrateur ou modérateur
  bool get isAdmin =>
      role.toLowerCase() == 'admin' || role.toLowerCase() == 'moderator';

  /// Initiales pour l'avatar
  String get initiales {
    if (nom.trim().isEmpty) return 'U';
    final parts = nom.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.trim()[0].toUpperCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      nom: json['nom'] as String,
      email: json['email'] as String?,
      telephone: json['telephone'] as String,
      role: (json['role'] as String?) ?? 'user',
      languePreferee: (json['langue_preferee'] as String?) ?? 'mos',
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      if (email != null) 'email': email,
      'telephone': telephone,
      'role': role,
      'langue_preferee': languePreferee,
      'is_active': isActive,
    };
  }

  UserModel copyWith({
    int? id,
    String? nom,
    String? email,
    String? telephone,
    String? role,
    String? languePreferee,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      languePreferee: languePreferee ?? this.languePreferee,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nom,
        email,
        telephone,
        role,
        languePreferee,
        isActive,
      ];
}
