import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

class BroadcastGeoAlertModal extends ConsumerStatefulWidget {
  const BroadcastGeoAlertModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BroadcastGeoAlertModal(),
    );
  }

  @override
  ConsumerState<BroadcastGeoAlertModal> createState() =>
      _BroadcastGeoAlertModalState();
}

class _BroadcastGeoAlertModalState extends ConsumerState<BroadcastGeoAlertModal> {
  final _titleController =
      TextEditingController(text: 'Alerte Crue Voie Inondée');
  final _bodyController = TextEditingController(
      text:
          'Passage souterrain ou pont submersible impraticable. Prudence et déviation conseillées.');
  double _radiusKm = 5.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _broadcast() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      AppSnackbar.showError(context, message: 'Le titre et le message sont requis.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final loc = ref.read(currentLocationProvider);
      final repo = ref.read(notificationsRepositoryProvider);

      await repo.broadcastGeoAlert(
        latitude: loc.lat,
        longitude: loc.lon,
        radiusKm: _radiusKm,
        title: title,
        body: body,
      );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message:
              'Alerte de sécurité diffusée avec succès aux conducteurs dans un rayon de $_radiusKm km !',
        );
        ref.read(myNotificationsProvider.notifier).refreshNotifications();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Échec de la diffusion de l\'alerte : ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // En-tête
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Color(0xFFDC2626),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Diffuser une Géo-Alerte FCM',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Notification push urgente ciblée aux conducteurs d\'une zone',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Titre de l\'alerte',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Ex: Alerte Voie Coupée',
              prefixIcon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'Consignes et détails de l\'alerte',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ex: Voie submergée par les eaux de pluie, déviation recommandée...',
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rayon de diffusion',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${_radiusKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _radiusKm,
            min: 1.0,
            max: 20.0,
            divisions: 19,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _radiusKm = val),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isLoading ? null : _broadcast,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Diffuser l\'alerte immédiatement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
