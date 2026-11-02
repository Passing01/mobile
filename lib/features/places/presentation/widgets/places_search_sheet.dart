import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/services/location_service.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_empty_state.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_error_state.dart';
import 'package:qvgestion_mobile/core/widgets/loaders/app_shimmer.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/save_place_modal.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Résultat d'une planification d'itinéraire multi-points (style Google Maps)
class RoutePlannerResult {
  final CoordinateModel origin;
  final CoordinateModel destination;
  final List<CoordinateModel> waypoints;
  final String mode;

  const RoutePlannerResult({
    required this.origin,
    required this.destination,
    this.waypoints = const [],
    this.mode = 'moto',
  });

  List<CoordinateModel> get allPoints => [origin, ...waypoints, destination];
}

/// Modal de recherche textuelle et de planification d'itinéraire multi-points (style Google Maps)
class PlacesSearchSheet extends ConsumerStatefulWidget {
  final ValueChanged<dynamic> onPlaceSelected;

  const PlacesSearchSheet({
    super.key,
    required this.onPlaceSelected,
  });

  static Future<dynamic> show(BuildContext context) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlacesSearchSheet(
        onPlaceSelected: (result) => Navigator.of(context).pop(result),
      ),
    );
  }

  @override
  ConsumerState<PlacesSearchSheet> createState() => _PlacesSearchSheetState();
}

class _PlacesSearchSheetState extends ConsumerState<PlacesSearchSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Contrôleurs pour recherche simple
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Contrôleurs pour itinéraire multi-points
  final TextEditingController _originController =
      TextEditingController(text: 'Ma position GPS');
  final TextEditingController _destController = TextEditingController();
  final List<TextEditingController> _waypointControllers = [];
  final List<CoordinateModel?> _waypointCoords = [];

  CoordinateModel? _originCoord;
  CoordinateModel? _destCoord;
  String _selectedMode = 'moto';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final currentQuery = ref.read(searchQueryProvider);
    if (currentQuery.isNotEmpty) {
      _searchController.text = currentQuery;
    }

    // Initialiser l'origine avec la position GPS réelle
    final lastGps = ref.read(locationServiceProvider).last;
    final loc = ref.read(currentLocationProvider);
    final lat = lastGps?.latitude ?? loc.lat;
    final lon = lastGps?.longitude ?? loc.lon;
    _originCoord = CoordinateModel(lat: lat, lon: lon, name: 'Ma position GPS');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _originController.dispose();
    _destController.dispose();
    for (final c in _waypointControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(searchQueryProvider.notifier).setQuery(value);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).clear();
  }

  void _swapOriginAndDestination() {
    setState(() {
      final tmpText = _originController.text;
      _originController.text = _destController.text;
      _destController.text = tmpText;

      final tmpCoord = _originCoord;
      _originCoord = _destCoord;
      _destCoord = tmpCoord;
    });
  }

  void _addWaypoint() {
    if (_waypointControllers.length >= 4) return; // Max 4 arrêts intermédiaires
    setState(() {
      _waypointControllers.add(TextEditingController());
      _waypointCoords.add(null);
    });
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypointControllers[index].dispose();
      _waypointControllers.removeAt(index);
      _waypointCoords.removeAt(index);
    });
  }

  void _calculateMultiPointRoute() {
    final orig = _originCoord;
    final dest = _destCoord;

    if (orig == null || dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez définir un départ et une destination'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final validWaypoints = <CoordinateModel>[];
    for (final wp in _waypointCoords) {
      if (wp != null) validWaypoints.add(wp);
    }

    final result = RoutePlannerResult(
      origin: orig,
      destination: dest,
      waypoints: validWaypoints,
      mode: _selectedMode,
    );

    widget.onPlaceSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          children: [
            // Poignée supérieure (Drag Handle)
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Onglets de navigation : Recherche simple vs Itinéraire Google Maps
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.search_rounded, size: 20), text: 'Rechercher un lieu'),
                Tab(icon: Icon(Icons.alt_route_rounded, size: 20), text: 'Itinéraire (Multi-points)'),
              ],
            ),
            const SizedBox(height: 8),

            // Vues d'onglets
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSingleSearchTab(),
                  _buildMultiPointItineraryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Onglet 1 : Recherche simple d'un lieu
  Widget _buildSingleSearchTab() {
    final query = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final nearbyPlacesAsync = ref.watch(nearbyPlacesProvider);

    return Column(
      children: [
        // Barre de saisie
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une pharmacie, station, maquis...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Fermer',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Action rapide : Enregistrer ma position
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            onTap: () {
              final lastGps = ref.read(locationServiceProvider).last;
              final loc = ref.read(currentLocationProvider);
              final lat = lastGps?.latitude ?? loc.lat;
              final lon = lastGps?.longitude ?? loc.lon;
              Navigator.of(context).pop();
              SavePlaceModal.show(
                context,
                latitude: lat,
                longitude: lon,
                initialName: 'Ma position',
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCFBF1)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add_location_alt_rounded, color: Color(0xFF0F766E), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enregistrer ma position actuelle (Nom, repères, partage)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Color(0xFF0F766E), size: 20),
                ],
              ),
            ),
          ),
        ),

        const Divider(height: 16, thickness: 1, color: Color(0xFFF3F4F6)),

        // Résultats
        Expanded(
          child: query.trim().isEmpty
              ? _buildDefaultNearbySection(nearbyPlacesAsync)
              : _buildSearchResultsSection(searchResultsAsync, query),
        ),
      ],
    );
  }

  /// Onglet 2 : Planificateur d'itinéraire multi-points (style Google Maps)
  Widget _buildMultiPointItineraryTab() {
    final searchResults = ref.watch(searchResultsProvider).value ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Cadre des champs Départ / Arrivée / Étapes
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // 1. Champ Départ
              Row(
                children: [
                  const Icon(Icons.trip_origin_rounded, color: Color(0xFF0F766E), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _originController,
                      decoration: const InputDecoration(
                        hintText: 'Point de départ (par défaut: Ma position)',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) {
                        ref.read(searchQueryProvider.notifier).setQuery(v);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_vert_rounded, color: Color(0xFF0F766E)),
                    tooltip: 'Inverser départ et arrivée',
                    onPressed: _swapOriginAndDestination,
                  ),
                ],
              ),
              const Divider(height: 16, thickness: 1, color: Color(0xFFE2E8F0)),

              // Étapes intermédiaires éventuelles
              ...List.generate(_waypointControllers.length, (idx) {
                return Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked_rounded,
                            color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _waypointControllers[idx],
                            decoration: InputDecoration(
                              hintText: 'Étape ${idx + 1}...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (v) {
                              ref.read(searchQueryProvider.notifier).setQuery(v);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                          onPressed: () => _removeWaypoint(idx),
                        ),
                      ],
                    ),
                    const Divider(height: 12, thickness: 1, color: Color(0xFFE2E8F0)),
                  ],
                );
              }),

              // 2. Champ Destination
              Row(
                children: [
                  const Icon(Icons.place_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _destController,
                      decoration: const InputDecoration(
                        hintText: 'Destination finale...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) {
                        ref.read(searchQueryProvider.notifier).setQuery(v);
                      },
                    ),
                  ),
                  if (_destController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                      onPressed: () {
                        _destController.clear();
                        _destCoord = null;
                        setState(() {});
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Bouton Ajouter une étape
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addWaypoint,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF0F766E)),
            label: const Text(
              'Ajouter une étape',
              style: TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Sélecteur de mode de déplacement
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildModeChoice('moto', Icons.two_wheeler_rounded, 'Moto'),
            _buildModeChoice('voiture', Icons.directions_car_rounded, 'Voiture'),
            _buildModeChoice('velo', Icons.pedal_bike_rounded, 'Vélo'),
            _buildModeChoice('pied', Icons.directions_walk_rounded, 'À pied'),
          ],
        ),
        const SizedBox(height: 16),

        // Bouton de calcul
        ElevatedButton.icon(
          onPressed: _calculateMultiPointRoute,
          icon: const Icon(Icons.navigation_rounded, size: 20),
          label: const Text(
            'Tracer l\'itinéraire directement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),

        // Suggestions rapides de lieux
        const Text(
          'Sélectionner rapidement un lieu pour la destination :',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 8),

        if (searchResults.isNotEmpty)
          ...searchResults.take(5).map((place) => _buildQuickPickTile(place))
        else
          ...ref.watch(nearbyPlacesProvider).maybeWhen(
                data: (places) => places.take(5).map((p) => _buildQuickPickTile(p)),
                orElse: () => [const SizedBox.shrink()],
              ),
      ],
    );
  }

  Widget _buildModeChoice(String mode, IconData icon, String label) {
    final isSel = _selectedMode == mode;
    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSel ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSel ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPickTile(PlaceModel place) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place_rounded, color: Color(0xFF0F766E), size: 20),
      title: Text(place.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(place.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF0F766E)),
      onTap: () {
        setState(() {
          _destController.text = place.nom;
          _destCoord = CoordinateModel(
            lat: place.latitude,
            lon: place.longitude,
            name: place.nom,
          );
        });
      },
    );
  }

  /// Liste des lieux à proximité immédiate
  Widget _buildDefaultNearbySection(AsyncValue<List<PlaceModel>> nearbyAsync) {
    return nearbyAsync.when(
      data: (places) {
        if (places.isEmpty) {
          return const AppEmptyState(
            icon: Icons.place_outlined,
            title: 'Aucun lieu à proximité',
            message: 'Aucun point d\'intérêt répertorié dans ce rayon géographique.',
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.near_me_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Lieux à proximité à Ouagadougou',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            ...places.map((place) => _buildPlaceTile(place)),
          ],
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const PoiCardShimmer(),
      ),
      error: (err, _) => AppErrorState(
        title: 'Erreur de chargement',
        message: 'Impossible de contacter l\'API des lieux ($err)',
        onRetry: () => ref.invalidate(nearbyPlacesProvider),
      ),
    );
  }

  /// Résultats de la recherche en direct
  Widget _buildSearchResultsSection(
    AsyncValue<List<PlaceModel>> searchAsync,
    String query,
  ) {
    return searchAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return AppEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Aucun résultat trouvé',
            message: 'Aucun lieu ne correspond à "$query" dans notre base locale.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            color: Color(0xFFF3F4F6),
          ),
          itemBuilder: (context, index) {
            final place = results[index];
            return _buildPlaceTile(place);
          },
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const PoiCardShimmer(),
      ),
      error: (err, _) => AppErrorState(
        title: 'Erreur de recherche',
        message: 'Échec de la recherche en ligne ($err)',
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
    );
  }

  Widget _buildPlaceTile(PlaceModel place) {
    final catIcon = place.categorie?.iconData ?? Icons.place_rounded;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(catIcon, color: AppColors.primary, size: 24),
      ),
      title: Text(
        place.nom,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.textPrimaryLight,
        ),
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              '${place.subtitle} • ${place.categorie?.nom ?? "POI"}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (place.formattedDistance != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                place.formattedDistance!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.directions_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'Itinéraire',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
      onTap: () {
        widget.onPlaceSelected(place);
      },
    );
  }
}
