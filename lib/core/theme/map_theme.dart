import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Thème officiel de la cartographie FASO NAV optimisé pour la lisibilité en plein soleil
class MapTheme {
  const MapTheme({
    required this.route,
    required this.routeCasing,
    required this.label,
    required this.halo,
    required this.isDark,
  });

  /// Couleur principale du tracé de navigation
  final String route;

  /// Liseré de contraste du tracé
  final String routeCasing;

  /// Couleur des étiquettes textuelles
  final String label;

  /// Halo de contraste autour des textes
  final String halo;

  /// Mode sombre actif
  final bool isDark;

  /// Thème Mode Clair (FASO NAV Light)
  static const light = MapTheme(
    route: '#1A73E8', // Bleu vif
    routeCasing: '#FFFFFF', // Liseré blanc net
    label: '#2B2A27',
    halo: '#FFFFFF',
    isDark: false,
  );

  /// Thème Mode Sombre (FASO NAV Dark)
  static const dark = MapTheme(
    route: '#5AA2FF', // Bleu lumineux contrasté
    routeCasing: '#0F1722', // Liseré sombre net
    label: '#E8ECF2',
    halo: '#0F1722',
    isDark: true,
  );

  /// Thème Mode Satellite (FASO NAV Satellite)
  static const satellite = MapTheme(
    route: '#00E5FF', // Cyan vif haute visibilité sur imagerie
    routeCasing: '#000000', // Liseré sombre net
    label: '#FFFFFF',
    halo: '#000000',
    isDark: true,
  );

  static MapTheme fromBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  /// Couleurs officielles des catégories FASO NAV (visibilité optimale plein soleil)
  static String colorForCategory(String? slug) {
    switch (slug?.toLowerCase()) {
      case 'pharmacie':
        return '#00A651'; // Vert vif
      case 'hopital-sante':
      case 'hopital':
        return '#E53935'; // Rouge vif
      case 'maquis-restaurant':
      case 'maquis':
        return '#FB8C00'; // Orange vif
      case 'station-service':
      case 'station':
        return '#FDD835'; // Jaune solaire
      case 'administration':
        return '#1E88E5'; // Bleu franc
      case 'banque-distributeur':
      case 'banque':
        return '#8E24AA'; // Violet
      case 'ecole-universite':
      case 'ecole':
        return '#00ACC1'; // Turquoise
      case 'marche-commerce':
      case 'marche':
        return '#8D6E63'; // Marron
      default:
        return '#1E88E5';
    }
  }

  /// Contour contrasté : contour sombre pour les stations jaunes au soleil, blanc pour les autres
  static String strokeColorForCategory(String? slug) {
    final s = slug?.toLowerCase();
    if (s == 'station-service' || s == 'station') {
      return '#2B2A27'; // Contour sombre pour éviter l'éblouissement solaire
    }
    return '#FFFFFF'; // Contour blanc franc
  }

  /// Propriétés du calque de points des catégories
  /// Rayon interpolé dynamiquement selon le niveau de zoom (9 à 14 px au zoom utile)
  static CircleLayerProperties get placeCircleProperties => const CircleLayerProperties(
        circleColor: [Expressions.get, 'color'],
        circleRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          10,
          ['*', ['get', 'size'], 1.6],
          16,
          ['*', ['get', 'size'], 4.2],
        ],
        circleStrokeColor: [Expressions.get, 'strokeColor'],
        circleStrokeWidth: 2.5,
      );
}
