import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';

/// Marqueur interactif représentant un obstacle routier sur la carte FlutterMap
class ReportMapMarker {
  static Marker build({
    required ReportModel report,
    required VoidCallback onTap,
  }) {
    return Marker(
      point: LatLng(report.latitude, report.longitude),
      width: 46,
      height: 46,
      child: GestureDetector(
        onTap: onTap,
        child: _ReportMarkerIcon(report: report),
      ),
    );
  }
}

class _ReportMarkerIcon extends StatelessWidget {
  final ReportModel report;

  const _ReportMarkerIcon({required this.report});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Cercle d'onde extérieure
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: report.color.withValues(alpha: 0.22),
          ),
        ),
        // Cercle central avec icône
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: report.color,
            border: Border.all(color: Colors.white, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            report.iconData,
            size: 18,
            color: Colors.white,
          ),
        ),
        // Badge de score de confiance s'il y a des votes
        if (report.upvotes > 1)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: report.color, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '+${report.upvotes}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: report.color,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
