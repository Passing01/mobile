import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/admin/data/models/api_key_model.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/add_traffic_signal_dialog.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/admin_map_point_picker_dialog.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/admin_reset_password_dialog.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/admin_user_detail_dialog.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/broadcast_geo_alert_modal.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/create_api_key_dialog.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/declare_maintenance_dialog.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/trace_road_dialog.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/reports/presentation/providers/reports_providers.dart';

/// Console d'Administration, Éditeur Carto Pro (GrabMaps) & API B2B FASO NAV
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(adminDashboardStatsProvider);
    ref.invalidate(pendingPlacesProvider);
    ref.invalidate(activeReportsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(adminRoadFeaturesProvider);
    ref.invalidate(adminApiKeysProvider);
    ref.invalidate(adminUsersProvider);
    AppSnackbar.showInfo(context, message: 'Données actualisées');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Console d\'Administration',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'FASO NAV • Back-Office & Modération',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Actualiser',
          ),
          IconButton(
            onPressed: () => BroadcastGeoAlertModal.show(context),
            icon: const Icon(Icons.campaign_rounded, color: Color(0xFFDC2626)),
            tooltip: 'Diffuser une Géo-Alerte FCM',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Vue Globale'),
            Tab(icon: Icon(Icons.verified_user_rounded, size: 18), text: 'Modération'),
            Tab(icon: Icon(Icons.edit_location_alt_rounded, size: 18), text: 'Éditeur Carto'),
            Tab(icon: Icon(Icons.vpn_key_rounded, size: 18), text: 'API B2B'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Équipe & Admins'),
            Tab(icon: Icon(Icons.category_rounded, size: 18), text: 'Catégories'),
            Tab(icon: Icon(Icons.traffic_rounded, size: 18), text: 'Ancres Routières'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildModerationTab(),
          _buildMapEditorTab(),
          _buildApiKeysTab(),
          _buildUsersTab(),
          _buildCategoriesTab(),
          _buildRoadFeaturesTab(),
        ],
      ),
    );
  }

  // ====================================================
  // ---- Onglet 1 : Vue Globale & Statistiques (KPIs) ----
  // ====================================================
  Widget _buildDashboardTab() {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bandeau Espace Admin
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF38BDF8),
                    size: 36,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Système Opérationnel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Surveillance cartographique nationale & Hub B2B/B2G',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Grille KPI
            const Text(
              'Indicateurs Clés de Performance',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Lieux Indexés',
                    value: '${stats.totalPlaces}',
                    subtitle: '${stats.pendingPlacesCount} en attente',
                    icon: Icons.place_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Signalements Actifs',
                    value: '${stats.activeReportsCount}',
                    subtitle: 'Total : ${stats.totalReports}',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'Utilisateurs',
                    value: '${stats.totalUsers}',
                    subtitle: '${stats.activeDevicesCount} terminaux FCM',
                    icon: Icons.people_rounded,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    title: 'Trajets Deux-Roues',
                    value: '${stats.totalRoutesCalculated}',
                    subtitle: 'Guidage Narrateur v2',
                    icon: Icons.two_wheeler_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action rapide Géo-Alerte
            OutlinedButton.icon(
              onPressed: () => BroadcastGeoAlertModal.show(context),
              icon: const Icon(Icons.campaign_rounded, color: Color(0xFFDC2626)),
              label: const Text(
                'Diffuser une Géo-Alerte FCM aux Usagers',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFECACA)),
                backgroundColor: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Impossible de charger les métriques : $e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(adminDashboardStatsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================
  // ---- Onglet 2 : Modération des Lieux & Incidents ----
  // ====================================================
  Widget _buildModerationTab() {
    final pendingPlacesAsync = ref.watch(pendingPlacesProvider);
    final activeReportsAsync = ref.watch(activeReportsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section POI en attente
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lieux Soumis en Attente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => ref.invalidate(pendingPlacesProvider),
            ),
          ],
        ),
        const SizedBox(height: 8),

        pendingPlacesAsync.when(
          data: (places) {
            if (places.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'Aucun lieu en attente de validation.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
              );
            }

            return Column(
              children: places.map((place) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              place.nom,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              place.categorie?.nom ?? 'Lieu',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${place.quartier ?? 'Burkina Faso'} • ${place.adresse ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref
                                    .read(pendingPlacesProvider.notifier)
                                    .moderate(placeId: place.id, approve: false);
                                if (mounted) {
                                  AppSnackbar.showInfo(context, message: 'Lieu rejeté');
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Rejeter'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await ref
                                    .read(pendingPlacesProvider.notifier)
                                    .moderate(placeId: place.id, approve: true);
                                if (mounted) {
                                  AppSnackbar.showSuccess(context,
                                      message: 'Lieu approuvé et publié sur la carte !');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Approuver'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Impossible de charger les ancres routières',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                '$e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(adminRoadFeaturesProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
        ),

        const SizedBox(height: 24),

        // Section Signalements d'incidents
        const Text(
          'Signalements Collaboratifs en Cours',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        activeReportsAsync.when(
          data: (reports) {
            if (reports.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'Aucun incident actif signalé.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
              );
            }

            return Column(
              children: reports.map((r) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(r.iconData, color: r.color, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              r.description ?? (r.quartier ?? 'Burkina Faso'),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${r.scoreConfiance}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: r.color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Impossible de charger les ancres routières',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                '$e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(adminRoadFeaturesProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ],
    );
  }

  // =========================================================================
  // ---- Onglet 3 : Éditeur Carto Pro (GrabMaps style FASO NAV) ----
  // =========================================================================
  Widget _buildMapEditorTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'introduction
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_road_rounded, color: Color(0xFFA5B4FC), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Éditeur Carto Pro • Type GrabMaps',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Créez et mettez à jour la voirie locale, les feux tricolores et les coupures en temps réel sans attendre de mise à jour externe.',
                style: TextStyle(fontSize: 12, color: Color(0xFFC7D2FE)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Carte d'accès direct au pointeur cartographique visuel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Pointage Direct sur la Carte',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pas besoin de saisir de coordonnées : touchez la carte pour positionner vos feux, travaux ou voies partout au Burkina Faso.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.traffic_rounded, size: 16, color: Color(0xFFD97706)),
                    label: const Text('Pointer un Feu 📍', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFFFEF3C7),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    onPressed: () async {
                      final point = await AdminMapPointPickerDialog.pickPoint(
                        context,
                        title: 'Pointer l\'emplacement du Feu',
                        subtitle: 'Touchez l\'intersection exacte sur la carte',
                        confirmLabel: 'Placer le feu ici',
                        confirmIcon: Icons.traffic_rounded,
                        themeColor: const Color(0xFFD97706),
                      );
                      if (point != null && mounted) {
                        AddTrafficSignalDialog.show(
                          context,
                          initialLat: point.latitude,
                          initialLon: point.longitude,
                        );
                      }
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.construction_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Pointer des Travaux 📍', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFFFEE2E2),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    onPressed: () async {
                      final point = await AdminMapPointPickerDialog.pickPoint(
                        context,
                        title: 'Pointer la Coupure / Travaux',
                        subtitle: 'Touchez la voie à couper ou sécuriser',
                        confirmLabel: 'Bloquer cette voie ici',
                        confirmIcon: Icons.block_rounded,
                        themeColor: const Color(0xFFDC2626),
                      );
                      if (point != null && mounted) {
                        DeclareMaintenanceDialog.show(
                          context,
                          initialLat: point.latitude,
                          initialLon: point.longitude,
                        );
                      }
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add_road_rounded, size: 16, color: Color(0xFF4338CA)),
                    label: const Text('Tracer une Voie 📍', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFFE0E7FF),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    onPressed: () async {
                      final point = await AdminMapPointPickerDialog.pickPoint(
                        context,
                        title: 'Point de Départ de la Voie',
                        subtitle: 'Touchez le début du 6-mètres ou de la piste',
                        confirmLabel: 'Définir le début du tracé',
                        confirmIcon: Icons.play_arrow_rounded,
                        themeColor: const Color(0xFF4338CA),
                      );
                      if (point != null && mounted) {
                        TraceRoadDialog.show(
                          context,
                          initialLat: point.latitude,
                          initialLon: point.longitude,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Actions Cartographiques Administrateur',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),

        // Action 1: Déposer un feu tricolore
        _buildEditorActionCard(
          title: 'Déposer un Feu Tricolore',
          subtitle: 'Ancre vocale pour les voix Moore, Dioula & FR (« Au prochain feu... »)',
          buttonText: 'Ajouter un Feu',
          icon: Icons.traffic_rounded,
          iconColor: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          onTap: () => AddTrafficSignalDialog.show(context),
        ),
        const SizedBox(height: 12),

        // Action 2: Déclarer des travaux / voie coupée
        _buildEditorActionCard(
          title: 'Déclarer Travaux / Voie Coupée',
          subtitle: 'Blocage immédiat d\'un axe avec recalcul automatique du tracé Valhalla',
          buttonText: 'Bloquer une Voie',
          icon: Icons.construction_rounded,
          iconColor: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEE2E2),
          onTap: () => DeclareMaintenanceDialog.show(context),
        ),
        const SizedBox(height: 12),

        // Action 3: Tracer une voie / 6-mètres / piste
        _buildEditorActionCard(
          title: 'Tracer une Nouvelle Voie (6-Mètres / Piste)',
          subtitle: 'Numérisation souveraine de nouveaux lotissements et pistes rurales',
          buttonText: 'Tracer la Voie',
          icon: Icons.add_road_rounded,
          iconColor: const Color(0xFF4338CA),
          bgColor: const Color(0xFFE0E7FF),
          onTap: () => TraceRoadDialog.show(context),
        ),
        const SizedBox(height: 20),

        // Aperçu des ancres existantes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Feux & Éléments Récemment Ajoutés',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            TextButton.icon(
              onPressed: () => _tabController.animateTo(5),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Tout voir'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditorActionCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ---- Onglet 4 : API B2B & Partenaires (Commercialisation & Quotas) ----
  // =========================================================================
  Widget _buildApiKeysTab() {
    final apiKeysAsync = ref.watch(adminApiKeysProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'introduction B2B
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Color(0xFF5EEAD4), size: 28),
                  SizedBox(width: 10),
                  Text(
                    'FASO NAV Maps API • Hub B2B & B2G',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Plateforme souveraine d\'itinéraires, Distance Matrix et géolocalisation pour le SAMU, les Sapeurs-Pompiers, livreurs et VTC.',
                style: TextStyle(fontSize: 12, color: Color(0xFFCCFBF1)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => CreateApiKeyDialog.show(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Générer une Clé Partenaire'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: const Color(0xFF134E4A),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Carte documentation endpoints
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.code_rounded, size: 18, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Endpoints Commerciaux Actifs',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildEndpointRow('POST /api/v1/matrix', 'Distance Matrix & Dispatch multi-points'),
              const Divider(height: 12),
              _buildEndpointRow('POST /api/v1/routes/calculate', 'Calcul d\'itinéraires d\'urgence & motos'),
              const Divider(height: 12),
              _buildEndpointRow('GET /api/v1/search', 'Recherche floue & géocodage Burkina'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Liste des clés API
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Partenaires B2B / B2G Enregistrés',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => ref.invalidate(adminApiKeysProvider),
            ),
          ],
        ),
        const SizedBox(height: 8),

        apiKeysAsync.when(
          data: (keys) {
            if (keys.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'Aucune clé API active. Cliquez ci-dessus pour en générer une.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
              );
            }

            return Column(
              children: keys.map((keyModel) => _buildApiKeyCard(keyModel)).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Impossible de charger les ancres routières',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                '$e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(adminRoadFeaturesProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ],
    );
  }

  Widget _buildEndpointRow(String method, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            method,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            desc,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyCard(ApiKeyModel key) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: key.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  key.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: key.isActive ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: key.clientType == ApiClientType.emergency
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  key.clientType.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: key.clientType == ApiClientType.emergency
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Clé masquée avec bouton copier
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${key.key.substring(0, (key.key.length > 18 ? 18 : key.key.length))}••••••••',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: key.key));
                    AppSnackbar.showSuccess(context, message: 'Clé ${key.name} copiée !');
                  },
                  tooltip: 'Copier la clé',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Jauge de quota
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quota : ${key.currentUsage} / ${key.monthlyQuota <= 0 ? 'Illimité' : key.monthlyQuota}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              Text(
                key.tier.label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: key.monthlyQuota <= 0 ? 0.05 : key.usagePercentage,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                key.usagePercentage > 0.9 ? Colors.red : AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),

          // Actions toggle et supprimer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch(
                    value: key.isActive,
                    onChanged: (val) async {
                      await ref.read(adminApiKeysProvider.notifier).toggleKey(key.id);
                      if (mounted) {
                        AppSnackbar.showInfo(
                          context,
                          message: val ? 'Clé activée' : 'Clé suspendue',
                        );
                      }
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                  Text(
                    key.isActive ? 'Active' : 'Suspendue',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: key.isActive ? const Color(0xFF10B981) : Colors.red,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Révoquer la clé API ?'),
                      content: Text('Voulez-vous supprimer définitivement la clé pour "${key.name}" ?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Révoquer'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(adminApiKeysProvider.notifier).deleteKey(key.id);
                    if (mounted) {
                      AppSnackbar.showSuccess(context, message: 'Clé révoquée');
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ---- Onglet 5 : Gestion des Administrateurs & Utilisateurs ----
  // =========================================================================
  Widget _buildUsersTab() {
    final usersAsync = ref.watch(adminUsersProvider);
    final activeRole = ref.watch(adminUsersFilterRoleProvider);

    return Column(
      children: [
        // Zone de recherche & Filtres
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un admin ou usager (nom, email, tél)...',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  ref.read(adminUsersSearchProvider.notifier).setSearch(val);
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRoleFilterChip('Tous', null, activeRole == null),
                    const SizedBox(width: 6),
                    _buildRoleFilterChip('Admins', 'admin', activeRole == 'admin'),
                    const SizedBox(width: 6),
                    _buildRoleFilterChip('Modérateurs', 'moderator', activeRole == 'moderator'),
                    const SizedBox(width: 6),
                    _buildRoleFilterChip('Usagers', 'user', activeRole == 'user'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Liste des utilisateurs
        Expanded(
          child: usersAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Aucun utilisateur ne correspond aux critères.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (ctx, i) => _buildUserCard(users[i]),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Erreur de chargement : $e', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(adminUsersProvider),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleFilterChip(String label, String? roleSlug, bool isSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (_) {
        ref.read(adminUsersFilterRoleProvider.notifier).setRole(roleSlug);
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    final isAdmin = user.role.toLowerCase() == 'admin';
    final isMod = user.role.toLowerCase() == 'moderator';

    final Color badgeColor = isAdmin
        ? const Color(0xFFDC2626)
        : (isMod ? const Color(0xFF2563EB) : const Color(0xFF64748B));

    final Color badgeBg = isAdmin
        ? const Color(0xFFFEE2E2)
        : (isMod ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: badgeColor,
                child: Text(
                  user.initiales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nom,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: user.isActive ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      user.email ?? (user.telephone.isNotEmpty ? user.telephone : 'ID #${user.id}'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch(
                    value: user.isActive,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      await ref.read(adminUsersProvider.notifier).toggleStatus(user.id, val);
                      if (mounted) {
                        AppSnackbar.showInfo(
                          context,
                          message: val ? 'Compte de ${user.nom} activé' : 'Compte de ${user.nom} suspendu',
                        );
                      }
                    },
                  ),
                  Text(
                    user.isActive ? 'Actif' : 'Suspendu',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: user.isActive ? const Color(0xFF10B981) : Colors.red,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => AdminResetPasswordDialog.show(context, user: user),
                    icon: const Icon(Icons.lock_reset_rounded, size: 14, color: Color(0xFFDC2626)),
                    label: const Text('MDP', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () => AdminUserDetailDialog.show(context, user: user),
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: const Text('Détails', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ---- Onglet 6 : Catégories & Taxonomie Cartographique ----
  // =========================================================================
  Widget _buildCategoriesTab() {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Taxonomie FASO NAV (Catégories Officielles)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chaque catégorie pilote la couleur des repères, la taille des points et les filtres.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            ...categories.map((cat) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cat.displayColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat.iconData, color: cat.displayColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.labelIn('fr'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Slug : ${cat.slug} • Taille marker : ${cat.markerSize}/5',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cat.displayColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cat.color,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Impossible de charger les ancres routières',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                '$e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(adminRoadFeaturesProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ---- Onglet 6 : Éléments Routiers & Ancres Narrateur v2 ----
  // =========================================================================
  Widget _buildRoadFeaturesTab() {
    final roadFeaturesAsync = ref.watch(adminRoadFeaturesProvider);

    return roadFeaturesAsync.when(
      data: (features) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Éléments Routiers Remarquables',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Feux tricolores, ponts, échangeurs pour le guidage vocal.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => AddTrafficSignalDialog.show(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouveau Feu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (features.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'Aucun élément routier cartographié.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ...features.map((feat) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: feat.isTrafficSignal
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFE0E7FF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          feat.isTrafficSignal
                              ? Icons.traffic_rounded
                              : Icons.alt_route_rounded,
                          color: feat.isTrafficSignal
                              ? const Color(0xFFD97706)
                              : const Color(0xFF4338CA),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feat.name ?? 'Élément sans nom',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Type : ${feat.kind.label} • GPS : ${feat.latitude.toStringAsFixed(4)}, ${feat.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Confiance ${feat.confidence}/3',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Impossible de charger les ancres routières',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                '$e',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(adminRoadFeaturesProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
