import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/auth/presentation/widgets/auth_modal_sheet.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/reports/data/models/create_report_request.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_type_model.dart';
import 'package:qvgestion_mobile/features/reports/presentation/providers/reports_providers.dart';

/// Modal bottom sheet pour créer et soumettre un nouveau signalement d'obstacle routier
class ReportIncidentModal extends ConsumerStatefulWidget {
  const ReportIncidentModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReportIncidentModal(),
    );
  }

  @override
  ConsumerState<ReportIncidentModal> createState() => _ReportIncidentModalState();
}

class _ReportIncidentModalState extends ConsumerState<ReportIncidentModal> {
  String _selectedType = 'pothole';
  final _descriptionController = TextEditingController();
  final _quartierController = TextEditingController();
  final _adresseController = TextEditingController();
  bool _isSubmitting = false;

  // Typologie de secours au cas où le chargement réseau prend du temps
  static const _defaultTypes = [
    ReportTypeModel(
      typeIncident: 'pothole',
      label: 'Nid-de-poule',
      description: 'Trou béant ou chaussée défoncée risquant une chute à moto.',
      defaultDurationHours: 336.0,
    ),
    ReportTypeModel(
      typeIncident: 'flooding',
      label: 'Inondation / Caniveau',
      description: 'Voie submergée par les eaux de pluie.',
      defaultDurationHours: 8.0,
    ),
    ReportTypeModel(
      typeIncident: 'road_closed',
      label: 'Voie coupée / barrée',
      description: 'Route fermée pour travaux, marché ou manifestation.',
      defaultDurationHours: 24.0,
    ),
    ReportTypeModel(
      typeIncident: 'accident',
      label: 'Accident',
      description: 'Accident de circulation créant un goulot d\'étranglement.',
      defaultDurationHours: 2.0,
    ),
    ReportTypeModel(
      typeIncident: 'traffic_jam',
      label: 'Embouteillage',
      description: 'Ralentissement massif à un carrefour ou grand axe.',
      defaultDurationHours: 1.0,
    ),
    ReportTypeModel(
      typeIncident: 'map_error',
      label: 'Erreur carto',
      description: 'Sens interdit non répertorié ou route inexistante.',
      defaultDurationHours: 720.0,
    ),
  ];

  static const _quickPills = [
    'Passage moto impossible',
    'Trou très profond',
    'Caniveau débordé',
    'Déviation en terre',
    'Feux tricolores éteints',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _quartierController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated) {
      AppSnackbar.showWarning(
        context,
        title: 'Connexion requise',
        message: 'Vous devez être connecté pour publier un signalement citoyen.',
      );
      AuthModalSheet.show(context);
      return;
    }

    final location = ref.read(currentLocationProvider);

    setState(() => _isSubmitting = true);

    final request = CreateReportRequest(
      typeIncident: _selectedType,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      latitude: location.lat,
      longitude: location.lon,
      quartier: _quartierController.text.trim().isNotEmpty
          ? _quartierController.text.trim()
          : null,
      adresse: _adresseController.text.trim().isNotEmpty
          ? _adresseController.text.trim()
          : null,
      ville: 'Ouagadougou',
    );

    try {
      final createdReport = await ref
          .read(createReportNotifierProvider.notifier)
          .submitReport(request);

      if (mounted) {
        if (createdReport != null) {
          Navigator.of(context).pop();
          AppSnackbar.showSuccess(
            context,
            title: 'Signalement publié !',
            message: 'Merci citoyen ! Votre alerte est visible sur la carte des conducteurs.',
          );
        } else {
          AppSnackbar.showError(
            context,
            title: 'Échec de transmission',
            message: 'Impossible de publier le signalement. Réessayez.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Erreur réseau',
          message: 'Vérifiez votre connexion internet.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(reportTypesProvider);
    final types = typesAsync.value ?? _defaultTypes;
    final location = ref.watch(currentLocationProvider);
    final isAuth = ref.watch(authNotifierProvider).isAuthenticated;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barre de préhension
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Titre et bannière Faso Nav
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Signaler un obstacle routier',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Alertez la communauté Faso Nav en direct',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Avertissement si non connecté
              if (!isAuth)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: Color(0xFFB45309), size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Connexion requise pour valider le signalement citoyen.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => AuthModalSheet.show(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Se connecter',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // Position GPS actuelle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Position : ${location.label}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 1. Sélection du type d'obstacle
              const Text(
                'Type d\'incident :',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types.map((t) {
                  final isSelected = _selectedType == t.typeIncident;
                  return ChoiceChip(
                    avatar: Icon(
                      t.iconData,
                      size: 16,
                      color: isSelected ? Colors.white : t.color,
                    ),
                    label: Text(t.label),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF374151),
                    ),
                    selected: isSelected,
                    selectedColor: t.color,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? t.color : const Color(0xFFE5E7EB),
                    ),
                    onSelected: (_) {
                      setState(() => _selectedType = t.typeIncident);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // 2. Quartier / Repère familier
              TextField(
                controller: _quartierController,
                decoration: InputDecoration(
                  labelText: 'Quartier / Repère (optionnel)',
                  hintText: 'Ex: Koulouba, 1200 Logements, Gounghin...',
                  prefixIcon: const Icon(Icons.place_outlined, size: 18),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. Description
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Précisions pour les deux-roues',
                  hintText: 'Ex: Caniveau débordé sur 50m, contourner par la gauche',
                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Suggestions rapides de description
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPills.map((pill) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(pill),
                        labelStyle: const TextStyle(fontSize: 11),
                        backgroundColor: const Color(0xFFF9FAFB),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        onPressed: () {
                          if (_descriptionController.text.isEmpty) {
                            _descriptionController.text = pill;
                          } else {
                            _descriptionController.text += ' • $pill';
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Bouton de soumission
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmitting
                      ? 'Transmission en cours...'
                      : 'Publier le signalement',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
