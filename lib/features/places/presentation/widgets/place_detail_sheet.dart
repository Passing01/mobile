import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/core/widgets/loaders/app_shimmer.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

/// Fiche détaillée d'un lieu sélectionné (Étape 5 FASO NAV)
/// Affiche nom, libellé catégorie avec couleur, adresse, horaires, téléphone
/// et 3 boutons d'action : « Itinéraire », « Appeler », « Signaler un problème ».
class PlaceDetailSheet extends ConsumerWidget {
  final String placeId;
  final PlaceModel? initialPlace;
  final VoidCallback onClose;
  final void Function(PlaceModel place, String source) onNavigate;
  final void Function(PlaceModel place, String mode, String source)? onNavigateWithMode;
  final VoidCallback? onReport;

  const PlaceDetailSheet({
    super.key,
    required this.placeId,
    this.initialPlace,
    required this.onClose,
    required this.onNavigate,
    this.onNavigateWithMode,
    this.onReport,
  });

  Color _parseColor(String? hexString, {Color fallback = const Color(0xFF0F766E)}) {
    if (hexString == null || hexString.isEmpty) return fallback;
    final clean = hexString.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    } else if (clean.length == 8) {
      return Color(int.parse('0x$clean'));
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(placeDetailProvider(placeId));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: detailAsync.when(
        loading: () => initialPlace != null
            ? _buildPlaceContent(context, initialPlace!)
            : _buildLoadingState(),
        error: (err, _) => initialPlace != null
            ? _buildPlaceContent(context, initialPlace!)
            : _buildErrorState(context, ref),
        data: (place) => _buildPlaceContent(context, place),
      ),
    );
  }

  Widget _buildLoadingState() {
    return AppShimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppShimmerBox(width: 44, height: 44, borderRadius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmerBox(width: 180, height: 18, borderRadius: 6),
                    SizedBox(height: 8),
                    AppShimmerBox(width: 100, height: 14, borderRadius: 6),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const AppShimmerBox(width: double.infinity, height: 16, borderRadius: 6),
          const SizedBox(height: 8),
          const AppShimmerBox(width: 220, height: 16, borderRadius: 6),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(child: AppShimmerBox(width: double.infinity, height: 44, borderRadius: 12)),
              SizedBox(width: 10),
              AppShimmerBox(width: 80, height: 44, borderRadius: 12),
              SizedBox(width: 10),
              AppShimmerBox(width: 80, height: 44, borderRadius: 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 8),
                Text(
                  'Lieu introuvable',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
              onPressed: onClose,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Impossible de charger les informations de ce lieu ou connexion perdue.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onClose,
              child: const Text('Fermer', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => ref.refresh(placeDetailProvider(placeId)),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceContent(BuildContext context, PlaceModel place) {
    final catColor = _parseColor(place.categorie?.color);
    final catName = place.categorie?.labels['fr'] ??
        place.categorie?.nom ??
        place.categorie?.slug ??
        'Lieu d\'intérêt';
    final hasPhone = place.telephone != null && place.telephone!.trim().isNotEmpty;
    final addressText = place.adresse ?? (place.quartier != null ? 'Quartier ${place.quartier}' : 'Ouagadougou');
    final hoursText = place.horaires ?? 'Horaires non renseignés';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. En-tête : Icône, Titre, Catégorie et bouton Fermer
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _getCategoryIcon(place.categorie?.slug),
                color: catColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.nom,
                    key: const Key('place_detail_title'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          catName,
                          key: const Key('place_detail_category'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('btn_close_place_sheet'),
              icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF6B7280)),
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2. Détails : Adresse, Horaires, Téléphone
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                iconColor: const Color(0xFF64748B),
                text: addressText,
                keyName: 'place_detail_address',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFF64748B),
                text: hoursText,
                keyName: 'place_detail_hours',
              ),
              if (hasPhone) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.phone_outlined,
                  iconColor: const Color(0xFF0F766E),
                  text: place.telephone!,
                  keyName: 'place_detail_phone',
                  isPhone: true,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2.5 Choix direct du mode de déplacement (Moto, Voiture, Vélo, À pied)
        Row(
          children: [
            _buildModeQuickButton(
              icon: Icons.two_wheeler_rounded,
              label: 'Moto',
              color: const Color(0xFF0F766E),
              onTap: () => onNavigateWithMode != null
                  ? onNavigateWithMode!(place, 'moto', 'lieu touché')
                  : onNavigate(place, 'lieu touché'),
            ),
            const SizedBox(width: 6),
            _buildModeQuickButton(
              icon: Icons.directions_car_rounded,
              label: 'Voiture',
              color: const Color(0xFF1D4ED8),
              onTap: () => onNavigateWithMode != null
                  ? onNavigateWithMode!(place, 'voiture', 'lieu touché')
                  : onNavigate(place, 'lieu touché'),
            ),
            const SizedBox(width: 6),
            _buildModeQuickButton(
              icon: Icons.pedal_bike_rounded,
              label: 'Vélo',
              color: const Color(0xFF16A34A),
              onTap: () => onNavigateWithMode != null
                  ? onNavigateWithMode!(place, 'velo', 'lieu touché')
                  : onNavigate(place, 'lieu touché'),
            ),
            const SizedBox(width: 6),
            _buildModeQuickButton(
              icon: Icons.directions_walk_rounded,
              label: 'À pied',
              color: const Color(0xFFEA580C),
              onTap: () => onNavigateWithMode != null
                  ? onNavigateWithMode!(place, 'pied', 'lieu touché')
                  : onNavigate(place, 'lieu touché'),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 3. Trois boutons d'action : « Itinéraire », « Appeler », « Signaler un problème »
        Row(
          children: [
            // Bouton 1 : Itinéraire (source: 'lieu touché')
            Expanded(
              flex: 5,
              child: ElevatedButton.icon(
                key: const Key('btn_place_route'),
                onPressed: () => onNavigate(place, 'lieu touché'),
                icon: const Icon(Icons.directions_rounded, size: 20),
                label: const Text(
                  'Itinéraire',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton 2 : Appeler
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                key: const Key('btn_place_call'),
                onPressed: () => _callPhone(context, place.telephone),
                icon: Icon(
                  Icons.phone_rounded,
                  size: 18,
                  color: hasPhone ? const Color(0xFF0F766E) : Colors.grey,
                ),
                label: Text(
                  'Appeler',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasPhone ? const Color(0xFF0F766E) : Colors.grey,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: hasPhone ? const Color(0xFF0F766E).withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton 3 : Partager la position
            IconButton.filledTonal(
              key: const Key('btn_place_share'),
              tooltip: 'Partager le lieu',
              onPressed: () {
                final latStr = place.latitude.toStringAsFixed(5);
                final lonStr = place.longitude.toStringAsFixed(5);
                final descPart = (place.description != null && place.description!.trim().isNotEmpty)
                    ? '${place.description!.trim()}\n'
                    : '';
                final quartPart = (place.quartier != null && place.quartier!.trim().isNotEmpty)
                    ? 'Quartier : ${place.quartier!.trim()}\n'
                    : '';
                final text = '📍 ${place.nom}\n'
                    '$descPart'
                    '$quartPart'
                    'Coordonnées GPS : $latStr, $lonStr\n'
                    'Partagé via FASO NAV • Carte et guidage du Burkina Faso\n'
                    'https://fasonav.bf/p?lat=$latStr&lon=$lonStr&name=${Uri.encodeComponent(place.nom)}';
                SharePlus.instance.share(
                  ShareParams(
                    text: text,
                    subject: 'FASO NAV : ${place.nom}',
                  ),
                );
              },
              icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF0F766E)),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF0FDFA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton 4 : Signaler un problème
            IconButton.filledTonal(
              key: const Key('btn_place_report'),
              tooltip: 'Signaler un problème',
              onPressed: onReport,
              icon: const Icon(Icons.flag_outlined, size: 18, color: Color(0xFFDC2626)),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeQuickButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String text,
    required String keyName,
    bool isPhone = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            key: Key(keyName),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isPhone ? FontWeight.w600 : FontWeight.normal,
              color: isPhone ? const Color(0xFF0F766E) : const Color(0xFF334155),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _callPhone(BuildContext context, String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun numéro de téléphone renseigné pour ce lieu.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = 'tel:$cleanPhone';
    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Numéro : $phone'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.w('Impossible de lancer l\'appel téléphonique: $e');
    }
  }

  IconData _getCategoryIcon(String? slug) {
    switch (slug) {
      case 'pharmacie':
        return Icons.local_pharmacy_rounded;
      case 'hopital-sante':
        return Icons.local_hospital_rounded;
      case 'station-service':
        return Icons.local_gas_station_rounded;
      case 'maquis-restaurant':
        return Icons.restaurant_rounded;
      case 'banque-distributeur':
        return Icons.account_balance_rounded;
      case 'administration':
        return Icons.account_balance_rounded;
      case 'ecole-universite':
        return Icons.school_rounded;
      case 'marche-commerce':
        return Icons.store_rounded;
      default:
        return Icons.place_rounded;
    }
  }
}
