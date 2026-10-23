import 'package:equatable/equatable.dart';

/// DTO pour la création d'un signalement citoyen (POST /api/v1/reports/)
class CreateReportRequest extends Equatable {
  final String typeIncident;
  final String? description;
  final double latitude;
  final double longitude;
  final String? adresse;
  final String? quartier;
  final String ville;

  const CreateReportRequest({
    required this.typeIncident,
    this.description,
    required this.latitude,
    required this.longitude,
    this.adresse,
    this.quartier,
    this.ville = 'Ouagadougou',
  });

  Map<String, dynamic> toJson() {
    return {
      'type_incident': typeIncident,
      if (description != null && description!.isNotEmpty) 'description': description,
      'latitude': latitude,
      'longitude': longitude,
      if (adresse != null && adresse!.isNotEmpty) 'adresse': adresse,
      if (quartier != null && quartier!.isNotEmpty) 'quartier': quartier,
      'ville': ville,
    };
  }

  @override
  List<Object?> get props => [
        typeIncident,
        description,
        latitude,
        longitude,
        adresse,
        quartier,
        ville,
      ];
}
