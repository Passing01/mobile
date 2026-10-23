import 'package:equatable/equatable.dart';

/// Modèle pour les alertes et notifications officielles (crue, sécurité, météo, voirie)
class NotificationItemModel extends Equatable {
  final int id;
  final int utilisateurId;
  final String title;
  final String body;
  final bool isRead;
  final int? incidentId;
  final DateTime createdAt;

  const NotificationItemModel({
    required this.id,
    required this.utilisateurId,
    required this.title,
    required this.body,
    required this.isRead,
    this.incidentId,
    required this.createdAt,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as int,
      utilisateurId: json['utilisateur_id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool? ?? false,
      incidentId: json['incident_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'title': title,
      'body': body,
      'is_read': isRead,
      'incident_id': incidentId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationItemModel copyWith({
    int? id,
    int? utilisateurId,
    String? title,
    String? body,
    bool? isRead,
    int? incidentId,
    DateTime? createdAt,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      incidentId: incidentId ?? this.incidentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        utilisateurId,
        title,
        body,
        isRead,
        incidentId,
        createdAt,
      ];
}
