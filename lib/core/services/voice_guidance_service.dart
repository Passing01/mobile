import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/services/voice_guide_service.dart';

/// Adaptateur de compatibilité vers le service officiel [VoiceGuide] (Étape 9)
class VoiceGuidanceService {
  VoiceGuidanceService(this._voiceGuide);

  final VoiceGuide _voiceGuide;

  Future<void> initialize() => _voiceGuide.init();

  Future<void> speak(String text, {String language = 'fr'}) =>
      _voiceGuide.say(text, language: language);

  Future<void> stop() => _voiceGuide.stop();
}

final voiceGuidanceServiceProvider = Provider<VoiceGuidanceService>((ref) {
  final voiceGuide = ref.watch(voiceGuideProvider);
  return VoiceGuidanceService(voiceGuide);
});
