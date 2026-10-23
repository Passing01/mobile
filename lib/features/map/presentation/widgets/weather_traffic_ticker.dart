import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/features/weather/presentation/providers/weather_providers.dart';

/// Bandeau météo & trafic déroulant de la maquette officielle
class WeatherTrafficTicker extends ConsumerWidget {
  const WeatherTrafficTicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(currentWeatherProvider);

    final String displayText = weatherAsync.when(
      data: (weather) {
        final temp = weather.temperatureCelsius.round();
        return 'Ouagadougou $temp°C • ${weather.drivingAdvisory}';
      },
      loading: () => 'Ouagadougou • Chargement météo & trafic...',
      error: (error, stack) =>
          'Ouagadougou 32°C • Trafic fluide sur l\'Avenue Kwame N\'Krumah',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône repère / académique
            const Icon(
              Icons.school_rounded,
              size: 16,
              color: Color(0xFF4B5563),
            ),
            const SizedBox(width: 6),
            // Pastille ambre
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFF59E0B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            // Icône météo
            const Text('🌤️', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            // Texte dynamique météo & trafic
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F2937),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
