import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/traffic/data/models/live_tracking_model.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/providers/traffic_providers.dart';

class ShareTripSheet extends ConsumerStatefulWidget {
  final double currentLat;
  final double currentLon;
  final String? initialDestination;

  const ShareTripSheet({
    super.key,
    required this.currentLat,
    required this.currentLon,
    this.initialDestination,
  });

  static Future<void> show(
    BuildContext context, {
    required double currentLat,
    required double currentLon,
    String? initialDestination,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareTripSheet(
        currentLat: currentLat,
        currentLon: currentLon,
        initialDestination: initialDestination,
      ),
    );
  }

  @override
  ConsumerState<ShareTripSheet> createState() => _ShareTripSheetState();
}

class _ShareTripSheetState extends ConsumerState<ShareTripSheet> {
  late final TextEditingController _destinationController;
  int _selectedDurationMinutes = 120;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _destinationController =
        TextEditingController(text: widget.initialDestination ?? '');
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _startSharing() async {
    setState(() => _isLoading = true);
    try {
      final destination = _destinationController.text.trim().isEmpty
          ? null
          : _destinationController.text.trim();

      final session = await ref.read(activeTrackingProvider.notifier).startTracking(
            lat: widget.currentLat,
            lon: widget.currentLon,
            destination: destination,
            durationMinutes: _selectedDurationMinutes,
          );

      if (mounted) {
        final shareUrl = session.shareUrl(EnvConfig.apiBaseUrl);
        await Clipboard.setData(ClipboardData(text: shareUrl));
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            message: 'Lien de suivi copié ! Partagez-le avec vos proches sur WhatsApp ou SMS.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Échec de l\'activation du partage : ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopSharing() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(activeTrackingProvider.notifier).stopTracking();
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Partage de trajet arrêté avec succès.',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Impossible d\'arrêter le partage : ${e.toString()}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeTrackingProvider);
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
          // Drag handle
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
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.share_location_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partage de trajet en direct',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeSession != null
                          ? 'Session active • Vos proches peuvent voir votre position'
                          : 'Rassurez vos proches pendant votre parcours à Ouaga',
                      style: TextStyle(
                        fontSize: 12,
                        color: activeSession != null
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B),
                        fontWeight: activeSession != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (activeSession != null) ...[
            // Vue de session active
            _buildActiveSessionCard(activeSession),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _stopSharing,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.stop_circle_outlined),
              label: const Text('Arrêter le partage de trajet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            // Formulaire de configuration
            const Text(
              'Destination (Optionnel)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                hintText: 'Ex: Maison Ouaga 2000, 1200 Logements...',
                prefixIcon: const Icon(Icons.flag_rounded, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Durée de validité du lien',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDurationChip(30, '30 min'),
                const SizedBox(width: 8),
                _buildDurationChip(60, '1 heure'),
                const SizedBox(width: 8),
                _buildDurationChip(120, '2 heures'),
                const SizedBox(width: 8),
                _buildDurationChip(240, '4 heures'),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _startSharing,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Générer & Copier le lien de suivi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected = _selectedDurationMinutes == minutes;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDurationMinutes = minutes),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(LiveTrackingModel session) {
    final shareUrl = session.shareUrl(EnvConfig.apiBaseUrl);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Session : ${session.userName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF166534),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'EN COURS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          if (session.destinationName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Destination : ${session.destinationName}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shareUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                  tooltip: 'Copier',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    AppSnackbar.showSuccess(
                      context,
                      message: 'Lien copié dans le presse-papiers !',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
