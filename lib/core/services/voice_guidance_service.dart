import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Service gérant la synthèse vocale réelle (TTS) pour le guidage pas-à-pas
class VoiceGuidanceService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('fr-FR');
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      AppLogger.w('TTS non disponible sur cet environnement: $e');
    }
  }

  /// Énonce à haute voix une consigne de navigation
  Future<void> speak(String text, {String language = 'fr'}) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      await _flutterTts.setLanguage('fr-FR');
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      AppLogger.w('Consigne vocale ignorée (TTS indisponible ou erreur moteur): $e');
    }
  }

  /// Interrompt la lecture vocale
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}

final voiceGuidanceServiceProvider = Provider<VoiceGuidanceService>((ref) {
  final service = VoiceGuidanceService();
  service.initialize();
  return service;
});
