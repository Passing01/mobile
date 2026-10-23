import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/providers/traffic_providers.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/widgets/share_trip_sheet.dart';

class ActiveTrackingBanner extends ConsumerWidget {
  const ActiveTrackingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeTrackingProvider);
    if (activeSession == null) return const SizedBox.shrink();

    final shareUrl = activeSession.shareUrl(EnvConfig.apiBaseUrl);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF15803D),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.share_location_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Partage de trajet en direct actif',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  activeSession.destinationName != null
                      ? 'Cap sur : ${activeSession.destinationName}'
                      : 'Position transmise en temps réel',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            tooltip: 'Copier le lien',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: shareUrl));
              AppSnackbar.showSuccess(
                context,
                message: 'Lien de suivi copié dans le presse-papiers !',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
            tooltip: 'Gérer',
            onPressed: () {
              ShareTripSheet.show(
                context,
                currentLat: activeSession.latitude,
                currentLon: activeSession.longitude,
                initialDestination: activeSession.destinationName,
              );
            },
          ),
        ],
      ),
    );
  }
}
