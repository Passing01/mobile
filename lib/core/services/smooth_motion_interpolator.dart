import 'dart:math' as math;

/// État cinématique interpolé à 60 FPS (position, cap, vitesse)
class MotionSample {
  final double latitude;
  final double longitude;
  final double bearingDeg;
  final double speedKmh;

  const MotionSample({
    required this.latitude,
    required this.longitude,
    required this.bearingDeg,
    required this.speedKmh,
  });
}

/// Interpolateur cinématique haute fréquence (60 Hz) entre les fixes GPS 1 Hz.
/// Garantit un déplacement et une rotation caméra sans saccades en mode Faso 3D et Vue Radar.
class SmoothMotionInterpolator {
  MotionSample? _from;
  MotionSample? _to;
  DateTime _transitionStart = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _transitionDuration = const Duration(milliseconds: 900);

  /// Enregistre un nouveau point cible GPS/simulation et amorce une transition douce.
  void pushTarget({
    required double latitude,
    required double longitude,
    required double bearingDeg,
    required double speedKmh,
    Duration duration = const Duration(milliseconds: 900),
  }) {
    final now = DateTime.now();
    final current = sampleAt(now) ??
        MotionSample(
          latitude: latitude,
          longitude: longitude,
          bearingDeg: _normalizeDeg(bearingDeg),
          speedKmh: speedKmh,
        );

    _from = current;
    _to = MotionSample(
      latitude: latitude,
      longitude: longitude,
      bearingDeg: _normalizeDeg(bearingDeg),
      speedKmh: speedKmh,
    );
    _transitionStart = now;
    _transitionDuration = duration;
  }

  /// Retourne l'état interpolé à l'instant [now] (avec courbe ease-out douce).
  MotionSample? sampleAt([DateTime? now]) {
    final target = _to;
    final start = _from;
    if (target == null) return null;
    if (start == null || _transitionDuration.inMicroseconds <= 0) {
      return target;
    }

    final tNow = now ?? DateTime.now();
    final elapsedUs = tNow.difference(_transitionStart).inMicroseconds;
    final rawT = (elapsedUs / _transitionDuration.inMicroseconds).clamp(0.0, 1.0);
    // Courbe linéaire-douce pour maintenir une vitesse visuelle constante sur la chaussée
    final t = rawT < 0.85 ? rawT : (0.85 + (rawT - 0.85) * 0.9);
    final clampedT = t.clamp(0.0, 1.0);

    final lat = start.latitude + (target.latitude - start.latitude) * clampedT;
    final lon = start.longitude + (target.longitude - start.longitude) * clampedT;
    final deltaAngle = shortestAngleDelta(start.bearingDeg, target.bearingDeg);
    final bearing = _normalizeDeg(start.bearingDeg + deltaAngle * clampedT);
    final speed = start.speedKmh + (target.speedKmh - start.speedKmh) * clampedT;

    return MotionSample(
      latitude: lat,
      longitude: lon,
      bearingDeg: bearing,
      speedKmh: speed,
    );
  }

  void reset() {
    _from = null;
    _to = null;
  }

  /// Calcule la plus petite différence angulaire signée dans [-180, 180].
  static double shortestAngleDelta(double fromDeg, double toDeg) {
    final diff = (_normalizeDeg(toDeg) - _normalizeDeg(fromDeg) + 540.0) % 360.0 - 180.0;
    return diff;
  }

  static double _normalizeDeg(double deg) {
    if (!deg.isFinite) return 0.0;
    return ((deg % 360.0) + 360.0) % 360.0;
  }

  /// Calcule la distance approximative en mètres entre deux points WGS84.
  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    final dLat = (lat2 - lat1) * 111320.0;
    final dLon = (lon2 - lon1) * 111320.0 * math.cos(lat1 * math.pi / 180.0);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }
}

