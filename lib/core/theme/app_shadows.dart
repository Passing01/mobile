import 'package:flutter/material.dart';

/// Ombres douces pour les cartes et éléments flottants au-dessus de la carte
class AppShadows {
  // Ombre subtile (pour petits boutons flottants)
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  // Ombre moyenne (pour barres supérieures et cartes de contenu)
  static final List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ];

  // Ombre prononcée (pour feuilles modales et cartes en surbrillance)
  static final List<BoxShadow> strong = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.14),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
