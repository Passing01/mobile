import 'package:flutter/material.dart';

/// Palette de couleurs adaptée à la visibilité extérieure au Burkina Faso
class AppColors {
  // Couleurs d'identité QvGestion (inspirées des couleurs nationales burkinabè)
  static const Color primary = Color(0xFF008751); // Vert Faso
  static const Color primaryDark = Color(0xFF005C37);
  static const Color primaryLight = Color(0xFFE8F5E9);

  static const Color secondary = Color(0xFFD21034); // Rouge Faso (Alertes, Nids de poule)
  static const Color accent = Color(0xFFFCD116); // Jaune Faso (Trafic modéré, travaux)

  // Couleurs de statut trafic / navigation
  static const Color trafficFluid = Color(0xFF2E7D32); // Vert fluide
  static const Color trafficModerate = Color(0xFFF57F17); // Orange modéré
  static const Color trafficHeavy = Color(0xFFC62828); // Rouge bouchon
  static const Color motorcyclePath = Color(0xFF0288D1); // Voie deux-roues

  // Neutres & Surfaces
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Mode Sombre (pour conduite nocturne)
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFF3F4F6);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
}
