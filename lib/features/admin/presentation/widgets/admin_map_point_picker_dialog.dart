import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/core/config/map_config.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_map.dart';

/// Ville repère pour navigation rapide à l'échelle du Burkina Faso
class BurkinaCityPreset {
  final String name;
  final LatLng position;

  const BurkinaCityPreset(this.name, this.position);
}

const List<BurkinaCityPreset> kBurkinaPresets = [
  BurkinaCityPreset('Ouagadougou', LatLng(12.3714, -1.5197)),
  BurkinaCityPreset('Bobo-Dioulasso', LatLng(11.1771, -4.2974)),
  BurkinaCityPreset('Koudougou', LatLng(12.2526, -2.3627)),
  BurkinaCityPreset('Ouahigouya', LatLng(13.5828, -2.4216)),
  BurkinaCityPreset('Fada N\'Gourma', LatLng(12.0616, 0.3584)),
  BurkinaCityPreset('Banfora', LatLng(10.6333, -4.7500)),
  BurkinaCityPreset('Dédougou', LatLng(12.4633, -3.4607)),
  BurkinaCityPreset('Kaya', LatLng(13.0913, -1.0844)),
  BurkinaCityPreset('Dori', LatLng(14.0354, -0.0345)),
];

/// Dialogue / Écran de sélection cartographique interactive (Pointeur GPS précis)
class AdminMapPointPickerDialog extends StatefulWidget {
  final LatLng initialPoint;
  final String title;
  final String subtitle;
  final String confirmLabel;
  final IconData confirmIcon;
  final Color themeColor;

  const AdminMapPointPickerDialog({
    super.key,
    required this.initialPoint,
    this.title = 'Sélectionner un point sur la carte',
    this.subtitle = 'Touchez un emplacement ou déplacez le repère',
    this.confirmLabel = 'Valider cette position',
    this.confirmIcon = Icons.check_circle_rounded,
    this.themeColor = AppColors.primary,
  });

  /// Ouvre le sélecteur cartographique en plein écran et renvoie les coordonnées sélectionnées
  static Future<LatLng?> pickPoint(
    BuildContext context, {
    LatLng? initialPoint,
    String? title,
    String? subtitle,
    String? confirmLabel,
    IconData? confirmIcon,
    Color? themeColor,
  }) {
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => AdminMapPointPickerDialog(
          initialPoint: initialPoint ?? const LatLng(12.3714, -1.5197),
          title: title ?? 'Sélectionner un point sur la carte',
          subtitle: subtitle ?? 'Touchez un emplacement ou déplacez le repère',
          confirmLabel: confirmLabel ?? 'Valider cette position',
          confirmIcon: confirmIcon ?? Icons.check_circle_rounded,
          themeColor: themeColor ?? AppColors.primary,
        ),
      ),
    );
  }

  @override
  State<AdminMapPointPickerDialog> createState() =>
      _AdminMapPointPickerDialogState();
}

class _AdminMapPointPickerDialogState extends State<AdminMapPointPickerDialog> {
  late LatLng _selectedPoint;
  MapLibreMapController? _controller;
  double _currentZoom = 14.0;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  void _onMapTap(Point<double> mathPoint, LatLng latLng) {
    setState(() {
      _selectedPoint = latLng;
    });
    _controller?.animateCamera(
      CameraUpdate.newLatLng(latLng),
    );
  }

  void _flyToCity(BurkinaCityPreset city) {
    setState(() {
      _selectedPoint = city.position;
    });
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: city.position, zoom: 13.5),
      ),
    );
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(3.0, 19.0);
    _controller?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(3.0, 19.0);
    _controller?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. CARTE INTERACTIVE SOUVERAINE FASO NAV
          Positioned.fill(
            child: FasoMap(
              styleUrl: MapConfig.defaultFasoLight,
              onStyleReady: (controller) async {
                _controller = controller;
                await controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _selectedPoint, zoom: _currentZoom),
                  ),
                );
              },
              onTap: _onMapTap,
            ),
          ),

          // 2. PIN CENTRAL / POINTEUR RÉTICULE VISUEL
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.themeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.themeColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.place_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. BARRE SUPÉRIEURE (EN-TÊTE + BOUTON FERMER)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Retour',
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.confirmIcon, size: 14, color: widget.themeColor),
                              const SizedBox(width: 4),
                              Text(
                                'Éditeur Pro',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.themeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Raccourcis de villes du Burkina Faso
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: kBurkinaPresets.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final city = kBurkinaPresets[index];
                          return ActionChip(
                            label: Text(
                              city.name,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () => _flyToCity(city),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. BOUTONS DE ZOOM ET CONTRÔLE
          Positioned(
            right: 16,
            bottom: 140,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_picker_zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'map_picker_zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove_rounded),
                ),
              ],
            ),
          ),

          // 5. BANDEAU INFÉRIEUR DE VALIDATION DE POSITION
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.my_location_rounded, color: widget.themeColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Coordonnées GPS Sélectionnées :',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('admin_map_point_picker_confirm'),
                        onPressed: () {
                          Navigator.of(context).pop(_selectedPoint);
                        },
                        icon: Icon(widget.confirmIcon, size: 18),
                        label: Text(widget.confirmLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
