import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/landmark_model.dart';
import 'package:qvgestion_mobile/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/reports/presentation/providers/reports_providers.dart';
import 'package:qvgestion_mobile/features/reports/presentation/widgets/report_map_marker.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'custom_map_callout_marker.dart';

/// Carte interactive réelle propulsée par FlutterMap et OpenStreetMap
/// avec tuiles réelles, géolocalisation et marqueurs dynamiques conformes à la maquette
class InteractiveFasoMap extends ConsumerStatefulWidget {
  final ValueChanged<PlaceModel> onPlaceSelected;
  final ValueChanged<ReportModel>? onReportSelected;
  final VoidCallback? onReportTap;
  final VoidCallback? onToggleLayers;
  final LatLng? navigationPosition;
  final String navigationMode;
  final bool isNavigating;
  final double vehicleHeading;

  const InteractiveFasoMap({
    super.key,
    required this.onPlaceSelected,
    this.onReportSelected,
    this.onReportTap,
    this.onToggleLayers,
    this.navigationPosition,
    this.navigationMode = 'motorcycle',
    this.isNavigating = false,
    this.vehicleHeading = 0.0,
  });

  @override
  ConsumerState<InteractiveFasoMap> createState() => _InteractiveFasoMapState();
}

class _InteractiveFasoMapState extends ConsumerState<InteractiveFasoMap> {
  late final MapController _mapController;
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant InteractiveFasoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNavigating && widget.navigationPosition != null) {
      if (oldWidget.navigationPosition != widget.navigationPosition) {
        _mapController.move(widget.navigationPosition!, 16.0);
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterOnUser(double lat, double lon) {
    ref.read(currentLocationProvider.notifier).fetchRealDeviceLocation();
    _mapController.move(LatLng(lat, lon), 15.0);
  }

  @override
  Widget build(BuildContext context) {
    // Écoute l'obtention de la position GPS pour rediriger automatiquement la caméra
    ref.listen(currentLocationProvider, (prev, next) {
      if (next.lat != AppConstants.ouagaCenterLatitude ||
          next.lon != AppConstants.ouagaCenterLongitude) {
        _mapController.move(LatLng(next.lat, next.lon), 16.0);
      }
    });

    // Écoute la sélection d'un lieu pour centrer immédiatement la caméra
    ref.listen(selectedPlaceProvider, (prev, next) {
      if (next != null) {
        _mapController.move(LatLng(next.latitude, next.longitude), 16.0);
      }
    });

    final currentLocation = ref.watch(currentLocationProvider);
    final nearbyPlacesAsync = ref.watch(nearbyPlacesProvider);
    final activeReportsAsync = ref.watch(activeReportsProvider);
    final landmarksAsync = ref.watch(landmarksProvider);
    final activeLang = ref.watch(guidanceLanguageProvider);
    final activeRouteState = ref.watch(activeRouteProvider);
    final activeRoute = activeRouteState.value;

    final places = nearbyPlacesAsync.when(
      data: (list) => list,
      loading: () => <PlaceModel>[],
      error: (error, stack) => <PlaceModel>[],
    );

    final reports = activeReportsAsync.when(
      data: (list) => list,
      loading: () => <ReportModel>[],
      error: (error, stack) => <ReportModel>[],
    );

    final landmarks = landmarksAsync.value ?? <LandmarkModel>[];

    // Points géographiques pour le tracé d'itinéraire réel s'il y en a un
    final polylinePoints = <LatLng>[];
    if (activeRoute != null && activeRoute.geometry.isNotEmpty) {
      for (final pt in activeRoute.geometry) {
        if (pt.length >= 2) {
          polylinePoints.add(LatLng(pt[0], pt[1]));
        }
      }
    }

    return Stack(
      children: [
        // 1. CARTE OPENSTREETMAP INTERACTIVE EN PLEIN ÉCRAN
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(currentLocation.lat, currentLocation.lon),
            initialZoom: 13.8,
            minZoom: 6.0,
            maxZoom: 18.0,
          ),
          children: [
            // Couche de tuiles OpenStreetMap
            TileLayer(
              urlTemplate: _isSatellite
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'bf.faso.nav',
              maxZoom: 19,
              errorTileCallback: (tile, error, stackTrace) {
                // Gestion silencieuse des erreurs de tuiles en mode hors-ligne
              },
            ),

            // Tracé d'itinéraire réel s'il y a un calcul actif
            if (polylinePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    strokeWidth: 6.0,
                    color: const Color(0xFF2563EB),
                    borderStrokeWidth: 2.0,
                    borderColor: Colors.white,
                  ),
                ],
              ),

            // Couche de Marqueurs interactifs réels
            MarkerLayer(
              markers: [
                // Marqueur véhicule (Navigation active) ou Radar de position
                if (widget.isNavigating && widget.navigationPosition != null)
                  Marker(
                    point: widget.navigationPosition!,
                    width: 64,
                    height: 64,
                    child: NavigationVehicleMarker(
                      mode: widget.navigationMode,
                      heading: widget.vehicleHeading,
                    ),
                  )
                else
                  Marker(
                    point: LatLng(currentLocation.lat, currentLocation.lon),
                    width: 60,
                    height: 60,
                    child: const UserLocationRadarMarker(),
                  ),

                // Marqueurs des obstacles et signalements citoyens (nids-de-poule, inondations, etc.)
                ...reports.map((report) {
                  return ReportMapMarker.build(
                    report: report,
                    onTap: () {
                      widget.onReportSelected?.call(report);
                      _mapController.move(
                        LatLng(report.latitude, report.longitude),
                        15.0,
                      );
                    },
                  );
                }),

                // Repères familiers de Ouagadougou (Landmarks culturels)
                ...landmarks.map((landmark) {
                  return Marker(
                    point: LatLng(landmark.latitude, landmark.longitude),
                    width: 38,
                    height: 38,
                    child: Tooltip(
                      message: landmark.localizedName(activeLang),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D28D9), // Violet repère emblématique
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          landmark.iconData,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }),

                // Marqueurs POI réels chargés depuis le backend
                ...places.map((place) {
                  final isPharmacy = place.categorie?.slug == 'pharmacie';
                  final isGas = place.categorie?.slug == 'station-service';
                  final isFood = place.categorie?.slug == 'maquis-restaurant';

                  final iconData = isPharmacy
                      ? Icons.local_pharmacy_rounded
                      : isGas
                          ? Icons.local_gas_station_rounded
                          : isFood
                              ? Icons.restaurant_rounded
                              : Icons.place_rounded;

                  final iconBg = isPharmacy
                      ? const Color(0xFF22C55E)
                      : isGas
                          ? const Color(0xFF2563EB)
                          : isFood
                              ? const Color(0xFFD97706)
                              : AppColors.primary;

                  return Marker(
                    point: LatLng(place.latitude, place.longitude),
                    width: 175,
                    height: 58,
                    child: CustomMapCalloutMarker(
                      title: place.nom,
                      subtitle: place.horaires ?? place.quartier,
                      icon: iconData,
                      iconBackgroundColor: iconBg,
                      hasActiveDot: isPharmacy,
                      onTap: () {
                        widget.onPlaceSelected(place);
                        _mapController.move(
                          LatLng(place.latitude, place.longitude),
                          14.5,
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // 2. BADGE FLOTTANT "✅ Hors-ligne prêt"
        Positioned(
          left: 20,
          bottom: 300,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF22C55E),
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Hors-ligne prêt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. CONTRÔLES FLOTTANTS DE CARTE (Calques & Recentrage GPS)
        Positioned(
          right: 16,
          bottom: 270,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bouton Signaler un obstacle routier (Alert / Campaign)
              if (widget.onReportTap != null) ...[
                GestureDetector(
                  onTap: widget.onReportTap,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Bouton Calques (Layers)
              GestureDetector(
                onTap: () {
                  setState(() => _isSatellite = !_isSatellite);
                  if (widget.onToggleLayers != null) {
                    widget.onToggleLayers!();
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.layers_rounded,
                    color: _isSatellite ? AppColors.primary : const Color(0xFF374151),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Bouton Recentrage GPS (Target / Crosshair)
              GestureDetector(
                onTap: () {
                  _recenterOnUser(currentLocation.lat, currentLocation.lon);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Marqueur de véhicule animé pour la navigation active (Moto, Voiture, Vélo, Piéton)
class NavigationVehicleMarker extends StatelessWidget {
  final String mode;
  final double heading;

  const NavigationVehicleMarker({
    super.key,
    required this.mode,
    this.heading = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color bgColor;

    switch (mode.toLowerCase()) {
      case 'motorcycle':
      case 'moto':
        icon = Icons.two_wheeler_rounded;
        bgColor = const Color(0xFF16A34A); // Vert motard
        break;
      case 'auto':
      case 'car':
        icon = Icons.directions_car_rounded;
        bgColor = const Color(0xFF2563EB); // Bleu voiture
        break;
      case 'bicycle':
      case 'velo':
        icon = Icons.pedal_bike_rounded;
        bgColor = const Color(0xFFD97706); // Orange vélo
        break;
      case 'pedestrian':
      case 'pieton':
        icon = Icons.directions_walk_rounded;
        bgColor = const Color(0xFF7C3AED); // Violet piéton
        break;
      default:
        icon = Icons.two_wheeler_rounded;
        bgColor = const Color(0xFF16A34A);
    }

    return Transform.rotate(
      angle: heading * 3.141592653589793 / 180.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo d'onde radar pulsant
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor.withValues(alpha: 0.22),
            ),
          ),
          // Flèche de cap directionnelle
          Positioned(
            top: 2,
            child: Icon(
              Icons.navigation_rounded,
              size: 16,
              color: bgColor,
            ),
          ),
          // Badge du véhicule
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}
