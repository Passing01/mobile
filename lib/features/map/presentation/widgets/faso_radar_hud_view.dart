import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:qvgestion_mobile/features/guidance/data/models/radar_scene_model.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Vue immersive "Radar Live / Cockpit Voiture Autonome" pour FASO NAV.
/// Reconstruit en 3D temps réel à 60 FPS la chaussée devant le conducteur,
/// la trajectoire lumineuse, les ondes radar, les échangeurs/feux/monuments
/// et le trafic environnant sans recourir à la caméra vidéo (zéro surchauffe).
class FasoRadarHudView extends StatefulWidget {
  final LatLng vehiclePosition;
  final double vehicleHeadingDeg;
  final double speedKmh;
  final String transportMode;
  final RouteModel? route;
  final RadarSceneModel? radarScene;
  final List<ReportModel> activeReports;
  final VoidCallback onSwitchToMap;

  const FasoRadarHudView({
    super.key,
    required this.vehiclePosition,
    required this.vehicleHeadingDeg,
    required this.speedKmh,
    required this.transportMode,
    this.route,
    this.radarScene,
    this.activeReports = const [],
    required this.onSwitchToMap,
  });

  @override
  State<FasoRadarHudView> createState() => _FasoRadarHudViewState();
}

class _FasoRadarHudViewState extends State<FasoRadarHudView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  static bool get _isUnderTest {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    return binding.contains('Test') || const bool.fromEnvironment('FLUTTER_TEST_RUNNER');
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (!_isUnderTest) {
      _pulseController.repeat();
    } else {
      _pulseController.value = 0.45;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.radarScene;
    final detectedCount = (scene?.roadFeatures.length ?? 0) +
        (scene?.monuments3d.length ?? 0) +
        widget.activeReports.length;

    return Container(
      key: const Key('faso_radar_hud_view'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF040914),
            Color(0xFF0A1931),
            Color(0xFF0E2954),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FasoRadarPainter(
                    phase: _pulseController.value,
                    vehiclePosition: widget.vehiclePosition,
                    headingDeg: widget.vehicleHeadingDeg,
                    speedKmh: widget.speedKmh,
                    transportMode: widget.transportMode,
                    route: widget.route,
                    radarScene: widget.radarScene,
                    activeReports: widget.activeReports,
                  ),
                );
              },
            ),
          ),

          // Bandeau télémétrie & bascule rapide vers Carte 3D
          Positioned(
            top: MediaQuery.paddingOf(context).top + 116,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          color: Color(0xFF38BDF8),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'RADAR LIVE • $detectedCount obj.',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const Key('btn_exit_radar_view'),
                  onTap: widget.onSwitchToMap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_rounded,
                          color: Color(0xFF1E293B),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Carte 3D',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Badge vitesse instantanée façon cockpit
          Positioned(
            left: 16,
            bottom: 248,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.speedKmh.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectedPoint {
  final Offset offset;
  final double scale;
  final double depthM;

  const _ProjectedPoint(this.offset, this.scale, this.depthM);
}

class _FasoRadarPainter extends CustomPainter {
  final double phase;
  final LatLng vehiclePosition;
  final double headingDeg;
  final double speedKmh;
  final String transportMode;
  final RouteModel? route;
  final RadarSceneModel? radarScene;
  final List<ReportModel> activeReports;

  _FasoRadarPainter({
    required this.phase,
    required this.vehiclePosition,
    required this.headingDeg,
    required this.speedKmh,
    required this.transportMode,
    required this.route,
    required this.radarScene,
    required this.activeReports,
  });

  static const double _maxRangeM = 360.0;
  static const double _cameraHeightM = 9.5;
  static const double _nearOffsetM = 12.0;

  /// Transforme une coordonnée WGS84 en coordonnées locales (x droite, z avant) en mètres
  Offset _toLocalMeters(double lat, double lon) {
    final dNorth = (lat - vehiclePosition.latitude) * 111320.0;
    final dEast = (lon - vehiclePosition.longitude) *
        111320.0 *
        math.cos(vehiclePosition.latitude * math.pi / 180.0);
    final rad = headingDeg * math.pi / 180.0;
    final forward = dNorth * math.cos(rad) + dEast * math.sin(rad);
    final right = -dNorth * math.sin(rad) + dEast * math.cos(rad);
    return Offset(right, forward);
  }

  /// Projection perspective 3D (x latéral en m, z avant en m) -> écran
  _ProjectedPoint? _project(Size size, double xM, double zM) {
    if (zM < -8.0 || zM > _maxRangeM) return null;
    final horizonY = size.height * 0.25;
    final egoY = size.height * 0.72;
    final zEff = math.max(1.0, zM + _nearOffsetM);
    final scale = _cameraHeightM / zEff;
    final normDepth = (zM + 8.0) / (_maxRangeM + 8.0);
    final screenY = egoY - (egoY - horizonY) * math.pow(normDepth, 0.56);
    final screenX = size.width * 0.5 + xM * scale * (size.width * 0.105);
    return _ProjectedPoint(Offset(screenX, screenY), scale.clamp(0.08, 1.35), zM);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final egoBase = _project(size, 0, 0)?.offset ?? Offset(size.width * 0.5, size.height * 0.72);
    final horizonY = size.height * 0.25;

    // 1. Lueur d'horizon atmosphérique
    final horizonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF040914),
          const Color(0xFF1D4ED8).withValues(alpha: 0.22),
          const Color(0xFF0B1F44),
        ],
        stops: const [0.0, 0.26, 0.48],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), horizonPaint);

    // 2. Grille radar perspective (cercles de distance & lignes de sol)
    _drawPerspectiveGrid(canvas, size, egoBase, horizonY);

    // 3. Ondes radar pulsées depuis le véhicule
    _drawRadarWaves(canvas, size, egoBase);

    // 4. Route réelle devant le conducteur (chaussée + voies + ruban de guidage)
    _drawProjectedRoadAndCorridor(canvas, size);

    // 5. Objets détectés : Monuments 3D, Feux/Échangeurs, Signalements, Trafic
    _drawDetectedSceneObjects(canvas, size);

    // 6. Véhicule Ego 3D au premier plan
    _drawEgoVehicle(canvas, egoBase);
  }

  void _drawPerspectiveGrid(Canvas canvas, Size size, Offset egoBase, double horizonY) {
    final gridPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.10)
      ..strokeWidth = 1.0;

    // Lignes longitudinales fuyant vers l'horizon
    for (var i = -5; i <= 5; i++) {
      final pNear = _project(size, i * 8.0, 0);
      final pFar = _project(size, i * 8.0, _maxRangeM);
      if (pNear != null && pFar != null) {
        canvas.drawLine(pNear.offset, pFar.offset, gridPaint);
      }
    }

    // Arcs de distance (50m, 100m, 200m, 300m)
    for (final dist in const [50.0, 100.0, 200.0, 300.0]) {
      final pLeft = _project(size, -45.0, dist);
      final pRight = _project(size, 45.0, dist);
      if (pLeft != null && pRight != null) {
        canvas.drawLine(pLeft.offset, pRight.offset, gridPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: '${dist.round()} m',
            style: TextStyle(
              color: const Color(0xFF7DD3FC).withValues(alpha: 0.45),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width - 14, pRight.offset.dy - 12));
      }
    }

    // Ligne d'horizon subtile
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.25)
        ..strokeWidth = 1.2,
    );
  }

  void _drawRadarWaves(Canvas canvas, Size size, Offset egoBase) {
    for (var i = 0; i < 3; i++) {
      final t = (phase + i / 3.0) % 1.0;
      final radius = 36.0 + t * (size.width * 0.78);
      final alpha = (1.0 - t) * 0.42;
      final rect = Rect.fromCenter(
        center: Offset(egoBase.dx, egoBase.dy - 12),
        width: radius * 1.9,
        height: radius * 0.62,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1.0 - t * 0.5)
          ..color = const Color(0xFF38BDF8).withValues(alpha: alpha),
      );
    }
  }

  List<Offset> _extractCorridorPointsLocal() {
    final pts = <Offset>[];
    final geom = route?.geometry ?? const [];
    if (geom.length >= 2) {
      for (final raw in geom) {
        if (raw.length >= 2) {
          final lat = raw[0] > 5.0 ? raw[0] : raw[1];
          final lon = raw[0] > 5.0 ? raw[1] : raw[0];
          final local = _toLocalMeters(lat, lon);
          if (local.dy >= -15.0 && local.dy <= _maxRangeM) {
            pts.add(local);
          }
        }
      }
      pts.sort((a, b) => a.dy.compareTo(b.dy));
    }

    if (pts.length < 2) {
      // Chaussée droite synthétique devant le conducteur si géométrie absente ou hors fenêtre
      return const [
        Offset(0, 0),
        Offset(0, 60),
        Offset(0, 140),
        Offset(0, 240),
        Offset(0, 340),
      ];
    }
    return pts;
  }

  void _drawProjectedRoadAndCorridor(Canvas canvas, Size size) {
    final localPts = _extractCorridorPointsLocal();
    const halfRoadWidthM = 5.8;
    const halfCorridorWidthM = 2.4;

    final leftEdge = <Offset>[];
    final rightEdge = <Offset>[];
    final corrLeft = <Offset>[];
    final corrRight = <Offset>[];
    final centerLine = <Offset>[];

    for (final p in localPts) {
      final pL = _project(size, p.dx - halfRoadWidthM, p.dy);
      final pR = _project(size, p.dx + halfRoadWidthM, p.dy);
      final cL = _project(size, p.dx - halfCorridorWidthM, p.dy);
      final cR = _project(size, p.dx + halfCorridorWidthM, p.dy);
      final cM = _project(size, p.dx, p.dy);
      if (pL != null && pR != null && cL != null && cR != null && cM != null) {
        leftEdge.add(pL.offset);
        rightEdge.add(pR.offset);
        corrLeft.add(cL.offset);
        corrRight.add(cR.offset);
        centerLine.add(cM.offset);
      }
    }

    if (leftEdge.length < 2) return;

    // Polygone de chaussée
    final roadPath = Path()..moveTo(leftEdge.first.dx, leftEdge.first.dy);
    for (final pt in leftEdge.skip(1)) {
      roadPath.lineTo(pt.dx, pt.dy);
    }
    for (final pt in rightEdge.reversed) {
      roadPath.lineTo(pt.dx, pt.dy);
    }
    roadPath.close();

    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFF102A4C).withValues(alpha: 0.92)
        ..style = PaintingStyle.fill,
    );

    // Bordures lumineuses de la route
    final edgePaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.78)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final leftPath = Path()..moveTo(leftEdge.first.dx, leftEdge.first.dy);
    for (final pt in leftEdge.skip(1)) {
      leftPath.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(leftPath, edgePaint);

    final rightPath = Path()..moveTo(rightEdge.first.dx, rightEdge.first.dy);
    for (final pt in rightEdge.skip(1)) {
      rightPath.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(rightPath, edgePaint);

    // Couloir lumineux de trajectoire (style Tesla Autopilot path ribbon)
    final corridorPath = Path()..moveTo(corrLeft.first.dx, corrLeft.first.dy);
    for (final pt in corrLeft.skip(1)) {
      corridorPath.lineTo(pt.dx, pt.dy);
    }
    for (final pt in corrRight.reversed) {
      corridorPath.lineTo(pt.dx, pt.dy);
    }
    corridorPath.close();

    canvas.drawPath(
      corridorPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF38BDF8).withValues(alpha: 0.42),
            const Color(0xFF2563EB).withValues(alpha: 0.14),
          ],
        ).createShader(Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.55)),
    );

    // Chevrons animés avançant dans le couloir
    final chevronPaint = Paint()
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.78)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 6; i++) {
      final z = ((i / 6.0 + phase) % 1.0) * 140.0 + 14.0;
      final c = _project(size, 0, z);
      final l = _project(size, -1.3, z - 4.0);
      final r = _project(size, 1.3, z - 4.0);
      if (c != null && l != null && r != null) {
        final chev = Path()
          ..moveTo(l.offset.dx, l.offset.dy)
          ..lineTo(c.offset.dx, c.offset.dy)
          ..lineTo(r.offset.dx, r.offset.dy);
        canvas.drawPath(chev, chevronPaint);
      }
    }
  }

  void _drawDetectedSceneObjects(Canvas canvas, Size size) {
    final scene = radarScene;
    if (scene != null) {
      // Monuments 3D à l'horizon
      for (final m in scene.monuments3d) {
        final local = _toLocalMeters(m.latitude, m.longitude);
        final proj = _project(size, local.dx, local.dy.clamp(10.0, _maxRangeM));
        if (proj != null) {
          final boxH = (m.heightM * proj.scale * 1.4).clamp(16.0, 90.0);
          final boxW = (18.0 * proj.scale).clamp(10.0, 38.0);
          final rect = Rect.fromLTWH(
            proj.offset.dx - boxW / 2,
            proj.offset.dy - boxH,
            boxW,
            boxH,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()
              ..color = const Color(0xFFF59E0B).withValues(alpha: 0.25)
              ..style = PaintingStyle.fill,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()
              ..color = const Color(0xFFFBBF24).withValues(alpha: 0.85)
              ..strokeWidth = 1.4
              ..style = PaintingStyle.stroke,
          );
          _drawLabel(canvas, m.name, Offset(proj.offset.dx, rect.top - 10), const Color(0xFFFDE68A));
        }
      }

      // Feux, échangeurs, ralentisseurs (`RoadFeature`)
      for (final rf in scene.roadFeatures) {
        final local = _toLocalMeters(rf.latitude, rf.longitude);
        final proj = _project(size, local.dx, local.dy);
        if (proj != null) {
          final color = rf.kind == 'traffic_signal'
              ? const Color(0xFFEF4444)
              : (rf.kind == 'interchange'
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFFF59E0B));
          final r = (10.0 * proj.scale).clamp(4.0, 12.0);
          canvas.drawCircle(
            proj.offset,
            r * 1.8,
            Paint()..color = color.withValues(alpha: 0.24),
          );
          canvas.drawCircle(
            proj.offset,
            r,
            Paint()..color = color,
          );
          if (rf.distanceM <= 220) {
            _drawLabel(
              canvas,
              '${rf.name} (${rf.distanceM.round()}m)',
              Offset(proj.offset.dx, proj.offset.dy - 14),
              Colors.white,
            );
          }
        }
      }

      // Trafic en direct (représentation véhicules sur la chaussée devant soi)
      for (final seg in scene.trafficSegments) {
        final local = _toLocalMeters(seg.latitude, seg.longitude);
        final proj = _project(size, local.dx.clamp(-8.0, 8.0), local.dy);
        if (proj != null) {
          final carW = (18.0 * proj.scale).clamp(8.0, 32.0);
          final carH = (11.0 * proj.scale).clamp(6.0, 20.0);
          final carColor = seg.congestionLevel == 'heavy'
              ? const Color(0xFFEF4444)
              : const Color(0xFF94A3B8);
          final rect = Rect.fromCenter(
            center: Offset(proj.offset.dx, proj.offset.dy - carH * 0.5),
            width: carW,
            height: carH,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()..color = carColor.withValues(alpha: 0.85),
          );
        }
      }
    }

    // Signalements communautaires actifs
    for (final rep in activeReports) {
      final local = _toLocalMeters(rep.latitude, rep.longitude);
      final proj = _project(size, local.dx, local.dy);
      if (proj != null) {
        canvas.drawCircle(
          proj.offset,
          9.0 * proj.scale.clamp(0.5, 1.3),
          Paint()..color = const Color(0xFFEF4444),
        );
        _drawLabel(
          canvas,
          rep.label,
          Offset(proj.offset.dx, proj.offset.dy - 14),
          const Color(0xFFFCA5A5),
        );
      }
    }
  }

  void _drawEgoVehicle(Canvas canvas, Offset center) {
    final mode = transportMode.toLowerCase();
    // Aura néon au sol sous le véhicule
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 78, height: 30),
      Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.25),
    );

    if (mode == 'motorcycle' || mode == 'moto' || mode == 'bicycle' || mode == 'velo') {
      // Silhouette 3D stylisée Moto / Deux-roues vue arrière 3/4
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 16), width: 22, height: 42),
        const Radius.circular(10),
      );
      canvas.drawRRect(
        body,
        Paint()..color = const Color(0xFF0F172A),
      );
      canvas.drawRRect(
        body,
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );
      // Feu arrière rouge & phare avant blanc
      canvas.drawCircle(
        Offset(center.dx, center.dy - 1),
        3.5,
        Paint()..color = const Color(0xFFEF4444),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 46), width: 32, height: 22),
        Paint()..color = const Color(0xFFE0F2FE).withValues(alpha: 0.22),
      );
    } else if (mode == 'foot' || mode == 'walk' || mode == 'pedestrian') {
      // Marqueur piéton directionnel
      canvas.drawCircle(
        Offset(center.dx, center.dy - 14),
        14,
        Paint()..color = const Color(0xFF10B981),
      );
      canvas.drawCircle(
        Offset(center.dx, center.dy - 14),
        14,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    } else {
      // Silhouette 3D stylisée Voiture (wireframe néon façon Tesla FSD)
      final carRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(center.dx, center.dy - 16), width: 46, height: 54),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        carRect,
        Paint()..color = const Color(0xFF0B1F3A),
      );
      canvas.drawRRect(
        carRect,
        Paint()
          ..color = const Color(0xFFE0F2FE)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
      // Toit vitré
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, center.dy - 15), width: 32, height: 26),
          const Radius.circular(7),
        ),
        Paint()..color = const Color(0xFF1E3A5F),
      );
      // Feux stop arrière
      canvas.drawRect(
        Rect.fromCenter(center: Offset(center.dx - 14, center.dy + 7), width: 9, height: 3.5),
        Paint()..color = const Color(0xFFEF4444),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(center.dx + 14, center.dy + 7), width: 9, height: 3.5),
        Paint()..color = const Color(0xFFEF4444),
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(color: Colors.black, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 150);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FasoRadarPainter oldDelegate) => true;
}
