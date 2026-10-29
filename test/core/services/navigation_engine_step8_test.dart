import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/core/services/navigation_engine.dart';

/// Crée un tracé droit nord-sud à partir du centre de Ouagadougou d'une longueur exacte [lengthMeters]
RouteGeometry straightRoute(double lengthMeters, {int segments = 10}) {
  const startLat = 12.3714;
  const startLon = -1.5197;
  // 1 degré de latitude = 110540 m dans RouteGeometry._dist
  final dLatTotal = lengthMeters / 110540.0;
  final pts = <LatLng>[];
  for (var i = 0; i <= segments; i++) {
    final frac = i / segments;
    pts.add(LatLng(startLat + dLatTotal * frac, startLon));
  }
  return RouteGeometry(pts);
}

/// Retourne un point situé à [alongM] le long du tracé nord-sud et décalé de [offEastM] vers l'est
LatLng pointAlongAndOff(double alongM, double offEastM) {
  const startLat = 12.3714;
  const startLon = -1.5197;
  final lat = startLat + (alongM / 110540.0);
  final lonScale = math.cos(startLat * math.pi / 180.0) * 111320.0;
  final lon = startLon + (offEastM / lonScale);
  return LatLng(lat, lon);
}

void main() {
  final t0 = DateTime(2026, 10, 29, 9, 0, 0);

  group('Étape 8 · Tests unitaires obligatoires NavigationEngine & RouteGeometry', () {
    test('1. pas d\'arrivée au départ', () {
      final route = straightRoute(1000); // tracé droit de 1 km
      final e = NavigationEngine(route);
      final u = e.onFix(route.pts.first, 5, t0);

      expect(u.state, NavState.navigating);
      expect(u.along, closeTo(0, 1.0));
      expect(u.remaining, closeTo(1000, 1.0));
      expect(u.needsReroute, isFalse);
    });

    test('2. arrivée seulement à 25 m, sur 2 points', () {
      final route = straightRoute(1000);
      final e = NavigationEngine(route);

      // Fix 1 : à 100 m de l'arrivée (900 m parcourus) -> navigating
      final u1 = e.onFix(pointAlongAndOff(900, 0), 5, t0);
      expect(u1.state, NavState.navigating);
      expect(u1.remaining, closeTo(100, 1.0));

      // Fix 2 : à 40 m de l'arrivée (960 m parcourus) -> navigating
      final u2 = e.onFix(pointAlongAndOff(960, 0), 5, t0.add(const Duration(seconds: 1)));
      expect(u2.state, NavState.navigating);
      expect(u2.remaining, closeTo(40, 1.0));

      // Fix 3 : à 20 m de l'arrivée (980 m parcourus, 1er point <= 25 m) -> encore navigating
      final u3 = e.onFix(pointAlongAndOff(980, 0), 5, t0.add(const Duration(seconds: 2)));
      expect(u3.state, NavState.navigating);
      expect(u3.remaining, closeTo(20, 1.0));

      // Fix 4 : à 18 m de l'arrivée (982 m parcourus, 2e point consécutif <= 25 m et >= 90%) -> arrived
      final u4 = e.onFix(pointAlongAndOff(982, 0), 5, t0.add(const Duration(seconds: 3)));
      expect(u4.state, NavState.arrived);
      expect(u4.remaining, closeTo(18, 1.0));
    });

    test('3. sortie de route : un seul recalcul sur 5 s', () {
      final route = straightRoute(1000);
      final e = NavigationEngine(route);

      int rerouteCount = 0;
      // 6 points à 60 m du tracé sur 5 secondes (t = 0s, 1s, 2s, 3s, 4s, 5s)
      for (var i = 0; i < 6; i++) {
        final pos = pointAlongAndOff(200.0 + i * 10, 60.0);
        final u = e.onFix(pos, 10.0, t0.add(Duration(seconds: i)));
        if (u.needsReroute) {
          rerouteCount++;
        }
      }

      // 3 points consécutifs déclenchent le 1er recalcul à i=2, et le délai de 10 s bloque le 2e à i=5
      expect(rerouteCount, 1);

      // Après plus de 10 s (ex: t = 15s), un nouveau recalcul est autorisé si toujours hors tracé
      e.onRerouteFailed();
      final uRetry = e.onFix(pointAlongAndOff(300, 60.0), 10.0, t0.add(const Duration(seconds: 15)));
      expect(uRetry.needsReroute, isTrue);
      expect(uRetry.state, NavState.rerouting);
    });

    test('4. bruit GPS de ±15 m : aucun recalcul', () {
      final route = straightRoute(1000);
      final e = NavigationEngine(route);
      final rng = math.Random(42);

      // 60 points aléatoires autour du tracé avec bruit dans [-15 m, +15 m]
      for (var i = 0; i < 60; i++) {
        final along = (i / 60.0) * 850.0; // progresse de 0 à 850 m
        final noiseM = (rng.nextDouble() * 30.0) - 15.0; // [-15, +15]
        final pos = pointAlongAndOff(along, noiseM);
        final u = e.onFix(pos, 12.0, t0.add(Duration(seconds: i)));

        expect(u.needsReroute, isFalse);
        expect(u.state, NavState.navigating);
        expect(u.off, lessThanOrEqualTo(15.5));
      }
    });

    test('5. tracé de 30 m refusé', () {
      expect(NavigationEngine.canStart(straightRoute(30)), isNotNull);
      expect(NavigationEngine.canStart(RouteGeometry(const [])), isNotNull);
      expect(NavigationEngine.canStart(straightRoute(100)), isNull);
    });

    test('6. départ à plus de 150 m du tracé est détecté (Règle 2)', () {
      final route = straightRoute(1000);
      final farStart = pointAlongAndOff(0, 180.0);
      final nearStart = pointAlongAndOff(0, 25.0);

      expect(NavigationEngine.isStartFarFromRoute(route, farStart), isTrue);
      expect(NavigationEngine.isStartFarFromRoute(route, nearStart), isFalse);
    });
  });
}
