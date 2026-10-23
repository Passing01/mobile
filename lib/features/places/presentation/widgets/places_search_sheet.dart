import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_empty_state.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_error_state.dart';
import 'package:qvgestion_mobile/core/widgets/loaders/app_shimmer.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

/// Modal de recherche textuelle connectée en direct aux endpoints réels du backend
class PlacesSearchSheet extends ConsumerStatefulWidget {
  final ValueChanged<PlaceModel> onPlaceSelected;

  const PlacesSearchSheet({
    super.key,
    required this.onPlaceSelected,
  });

  static Future<PlaceModel?> show(BuildContext context) {
    return showModalBottomSheet<PlaceModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlacesSearchSheet(
        onPlaceSelected: (place) => Navigator.of(context).pop(place),
      ),
    );
  }

  @override
  ConsumerState<PlacesSearchSheet> createState() => _PlacesSearchSheetState();
}

class _PlacesSearchSheetState extends ConsumerState<PlacesSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Synchroniser avec l'état existant si présent
    final currentQuery = ref.read(searchQueryProvider);
    if (currentQuery.isNotEmpty) {
      _searchController.text = currentQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(searchQueryProvider.notifier).setQuery(value);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final nearbyPlacesAsync = ref.watch(nearbyPlacesProvider);

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
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
            const SizedBox(height: 12),

          // Barre de saisie de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Rechercher une pharmacie, station, maquis...',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
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
                    'Annuler',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFF3F4F6)),

          // Contenu : Résultats de recherche ou Lieux à proximité par défaut
          Expanded(
            child: query.trim().isEmpty
                ? _buildDefaultNearbySection(nearbyPlacesAsync)
                : _buildSearchResultsSection(searchResultsAsync, query),
          ),
        ],
      ),
      ),
    );
  }

  /// Liste des lieux à proximité immédiate retournés par le backend quand aucun texte n'est saisi
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

  /// Résultats de la recherche en direct via GET /api/v1/places/search
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
            message: 'Aucun lieu ne correspond à "$query" dans notre base de données locale.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
          itemBuilder: (context, index) {
            final place = results[index];
            return _buildPlaceTile(place);
          },
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const PoiCardShimmer(),
      ),
      error: (err, _) => AppErrorState(
        title: 'Erreur de recherche',
        message: 'Impossible de contacter le serveur QvGestion ($err)',
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
    );
  }

  /// Élément graphique représentant un lieu réel du backend
  Widget _buildPlaceTile(PlaceModel place) {
    final catIcon = place.categorie?.iconData ?? Icons.place_rounded;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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
