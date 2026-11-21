/// Modèle d'un bâtiment, monument ou échangeur 3D placé par un administrateur.
class Building3dModel {
  final int id;
  final String name;
  final String? subtitle;
  final String city;
  final String kind;
  final String shape;
  final double latitude;
  final double longitude;
  final double height;
  final double baseHeight;
  final double widthM;
  final double lengthM;
  final double rotationDeg;
  final String color;

  const Building3dModel({
    required this.id,
    required this.name,
    this.subtitle,
    this.city = 'Ouagadougou',
    this.kind = 'building',
    this.shape = 'rect',
    required this.latitude,
    required this.longitude,
    this.height = 18.0,
    this.baseHeight = 0.0,
    this.widthM = 28.0,
    this.lengthM = 28.0,
    this.rotationDeg = 0.0,
    this.color = '#E6A15C',
  });

  factory Building3dModel.fromJson(Map<String, dynamic> json) {
    return Building3dModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? 'Bâtiment 3D',
      subtitle: json['subtitle'] as String?,
      city: (json['city'] as String?) ?? 'Ouagadougou',
      kind: (json['kind'] as String?) ?? 'building',
      shape: (json['shape'] as String?) ?? 'rect',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      height: (json['height'] as num?)?.toDouble() ?? 18.0,
      baseHeight: (json['base_height'] as num?)?.toDouble() ?? 0.0,
      widthM: (json['width_m'] as num?)?.toDouble() ?? 28.0,
      lengthM: (json['length_m'] as num?)?.toDouble() ?? 28.0,
      rotationDeg: (json['rotation_deg'] as num?)?.toDouble() ?? 0.0,
      color: (json['color'] as String?) ?? '#E6A15C',
    );
  }
}

