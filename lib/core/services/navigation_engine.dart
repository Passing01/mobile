import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Résultat de la projection orthogonale d'une position GPS sur le tracé
class Projection {
  final double along;
  final double off;
  final int segmentIndex;

  const Projection(this.along, this.off, {this.segmentIndex = 0});
}

/// Géométrie d'un tracé routier et projection locale en mètres (Étape 8)
class RouteGeometry {
  RouteGeometry(this.pts) {
    cum = [0.0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + _dist(pts[i - 1], pts[i]));
    }
  }

  /// Construit une géométrie à partir d'un [RouteModel] en normalisant [lat, lon] / [lon, lat]
  factory RouteGeometry.fromRoute(RouteModel route) {
    final points = <LatLng>[];
    for (final pt in route.geometry) {
      if (pt.length >= 2 && pt[0].isFinite && pt[1].isFinite) {
        // Au Burkina Faso : latitude ~ [9..15.5], longitude ~ [-5.5..2.5]
        final lon = pt[0] < 5.0 ? pt[0].toDouble() : pt[1].toDouble();
        final lat = pt[1] > 8.0 ? pt[1].toDouble() : pt[0].toDouble();
        points.add(LatLng(lat, lon));
      }
    }
    return RouteGeometry(points);
  }

  final List<LatLng> pts;
  late final List<double> cum;

  double get total => cum.isEmpty ? 0.0 : cum.last;

  /// Distance approximative locale en mètres entre deux coordonnées
  static double _dist(LatLng a, LatLng b) {
    final dx =
        (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180) * 111320;
    final dy = (b.latitude - a.latitude) * 110540;
    return math.sqrt(dx * dx + dy * dy);
  }

  Offset _xy(LatLng p) => Offset(
        (p.longitude - pts.first.longitude) *
            math.cos(pts.first.latitude * math.pi / 180) *
            111320,
        (p.latitude - pts.first.latitude) * 110540,
      );

  /// Projette [p] sur le tracé.
  /// Sur un très long trajet (> 80 segments), limite d'abord la recherche aux segments proches
  /// de [hintSegment] pour garder un calcul instantané et éviter de sauter sur une boucle éloignée.
  Projection project(LatLng p, {int? hintSegment, int windowRadius = 40}) {
    if (pts.isEmpty) return const Projection(0, 0);
    if (pts.length == 1) {
      return Projection(0, _dist(pts.first, p), segmentIndex: 0);
    }

    final segmentCount = pts.length - 1;
    if (hintSegment != null && segmentCount > windowRadius * 2) {
      final startIdx = math.max(0, hintSegment - windowRadius);
      final endIdx = math.min(segmentCount - 1, hintSegment + windowRadius);
      final windowed = _projectInRange(p, startIdx, endIdx);
      if (windowed.off <= 200.0) {
        return windowed;
      }
    }

    return _projectInRange(p, 0, segmentCount - 1);
  }

  Projection _projectInRange(LatLng p, int startIdx, int endIdx) {
    double best = double.infinity;
    double bestAlong = 0;
    int bestSeg = startIdx;
    final q = _xy(p);

    for (var i = startIdx; i <= endIdx; i++) {
      final a = _xy(pts[i]);
      final b = _xy(pts[i + 1]);
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0
          ? 0.0
          : (((q.dx - a.dx) * dx + (q.dy - a.dy) * dy) / len2).clamp(0.0, 1.0);
      final px = a.dx + t * dx;
      final py = a.dy + t * dy;
      final d = math.sqrt((q.dx - px) * (q.dx - px) + (q.dy - py) * (q.dy - py));
      if (d < best) {
        best = d;
        bestAlong = cum[i] + t * math.sqrt(len2);
        bestSeg = i;
      }
    }
    return Projection(bestAlong, best, segmentIndex: bestSeg);
  }
}

/// États officiels de la navigation (Étape 8)
enum NavState { idle, navigating, rerouting, arrived }

/// Mise à jour produite à chaque point GPS reçu par le moteur de navigation
class NavUpdate {
  const NavUpdate(
    this.state, {
    this.along = 0,
    this.remaining = 0,
    this.off = 0,
    this.needsReroute = false,
    this.error,
  });

  final NavState state;
  final double along;
  final double remaining;
  final double off;
  final bool needsReroute;
  final String? error;
}

/// Moteur de navigation isolé (sans carte ni réseau), testable unitairement (Étape 8)
class NavigationEngine {
  NavigationEngine(
    this.route, {
    this.offRouteM = 40,
    this.offRouteFixes = 3,
    this.arrivalM = 25,
  });

  final RouteGeometry route;
  final double offRouteM;
  final double arrivalM;
  final int offRouteFixes;

  NavState state = NavState.navigating;
  int _off = 0;
  int _end = 0;
  int? _lastSegment;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  /// Règle 1 : Démarrage refusé si le tracé a moins de 2 points ou moins de 50 m
  static String? canStart(RouteGeometry r) =>
      (r.pts.length < 2 || r.total < 50) ? 'Itinéraire invalide ou trop court' : null;

  /// Règle 2 : Départ loin du tracé (> 150 m) -> proposer « Recalculer depuis ma position »
  static bool isStartFarFromRoute(
    RouteGeometry r,
    LatLng pos, {
    double thresholdM = 150.0,
  }) {
    if (r.pts.length < 2) return false;
    return r.project(pos).off > thresholdM;
  }

  /// Traite un point GPS et retourne le nouvel état de progression
  NavUpdate onFix(LatLng pos, double accuracy, DateTime now) {
    final pr = route.project(pos, hintSegment: _lastSegment);
    _lastSegment = pr.segmentIndex;
    final remaining = math.max(0.0, route.total - pr.along);

    final msg =
        '[NAV] along=${pr.along.round()} remaining=${remaining.round()} off=${pr.off.round()} acc=${accuracy.round()}';
    AppLogger.i(msg);
    debugPrint(msg);

    // Règle 4 : Sortie de route comptabilisée uniquement si précision <= 30 m
    if (accuracy <= 30) {
      _off = pr.off > offRouteM ? _off + 1 : 0;
    }

    // Règle 5 : Arrivée seulement à <= 25 m ET après >= 90 % du parcours, sur 2 points de suite
    _end = (remaining <= arrivalM && pr.along >= 0.9 * route.total) ? _end + 1 : 0;
    if (_end >= 2) {
      state = NavState.arrived;
      return NavUpdate(
        state,
        along: pr.along,
        remaining: remaining,
        off: pr.off,
      );
    }

    // Règle 4 : Sortie de route (> 40 m pendant 3 points consécutifs, max 1 recalcul / 10 s)
    if (_off >= offRouteFixes &&
        now.difference(_lastReroute) > const Duration(seconds: 10)) {
      _lastReroute = now;
      _off = 0;
      state = NavState.rerouting;
      return NavUpdate(
        state,
        along: pr.along,
        remaining: remaining,
        off: pr.off,
        needsReroute: true,
      );
    }

    if (state == NavState.rerouting) {
      state = NavState.navigating;
    }

    return NavUpdate(
      state,
      along: pr.along,
      remaining: remaining,
      off: pr.off,
    );
  }

  /// En cas d'échec de recalcul réseau : retour à navigating sur l'ancien tracé (nouvel essai après 10 s)
  void onRerouteFailed() {
    state = NavState.navigating;
  }

  /// Arrête la course et ramène le moteur à l'état idle
  void stop() {
    state = NavState.idle;
    _off = 0;
    _end = 0;
    _lastSegment = null;
  }
}

