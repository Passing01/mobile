import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Service de guidage vocal multilingue :
/// - Synthèse vocale locale (TTS) pour le Français
/// - Lecture audio streaming (AudioPlayer) pour les consignes natives Mooré & Dioula
class VoiceGuide {
  final FlutterTts? _customTts;
  final AudioPlayer? _customAudioPlayer;
  FlutterTts? _flutterTts;
  AudioPlayer? _audioPlayer;
  bool _isTtsInitialized = false;

  VoiceGuide({FlutterTts? flutterTts, AudioPlayer? audioPlayer})
      : _customTts = flutterTts,
        _customAudioPlayer = audioPlayer;

  FlutterTts get _tts => _customTts ?? (_flutterTts ??= FlutterTts());

  AudioPlayer? get _player {
    if (_customAudioPlayer != null) return _customAudioPlayer;
    if (_audioPlayer != null) return _audioPlayer;
    try {
      _audioPlayer = AudioPlayer();
      return _audioPlayer;
    } catch (e) {
      AppLogger.w('Initialisation AudioPlayer impossible: $e');
      return null;
    }
  }

  Future<void> initialize() async {
    if (_isTtsInitialized) return;
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (e) {
      AppLogger.w('TTS non disponible: $e');
    }
  }

  /// Énonce un message court (ex: "Recalcul de l'itinéraire", "Vous êtes arrivé")
  Future<void> say(String text, {String language = 'fr'}) async {
    try {
      await initialize();
      try {
        await _player?.stop();
      } catch (e) {
        AppLogger.d('Arrêt lecteur audio ignoré: $e');
      }
      try {
        await _tts.stop();
      } catch (e) {
        AppLogger.d('Arrêt TTS ignoré: $e');
      }

      final lang = language.toLowerCase();
      if (lang == 'mos' || lang == 'diu') {
        try {
          await _tts.setLanguage('fr-FR');
        } catch (e) {
          AppLogger.d('Langue TTS non supportée: $e');
        }
      } else {
        try {
          await _tts.setLanguage('fr-FR');
        } catch (e) {
          AppLogger.d('Langue TTS non supportée: $e');
        }
      }
      await _tts.speak(text);
    } catch (e) {
      AppLogger.w('Impossible de lire le message vocal: $e');
    }
  }

  /// Énonce la manœuvre suivante avec prise en compte des repères visuels familiers
  Future<void> sayStep(dynamic step, {String language = 'fr'}) async {
    try {
      final lang = language.toLowerCase();

      String text = '';
      String? audioUrl;
      String? landmarkName;

      if (step is Map<String, dynamic>) {
        text = step['localized_instruction'] as String? ??
            step['instruction'] as String? ??
            (step['maneuver'] is Map ? step['maneuver']['instruction'] as String? : null) ??
            '';
        audioUrl = step['audio_url'] as String?;
        landmarkName = step['landmark_name'] as String?;
      } else {
        try {
          text = (step.localizedInstruction ?? step.originalInstruction ?? '').toString();
          audioUrl = step.audioUrl as String?;
          landmarkName = step.landmarkName as String?;
        } catch (e) {
          AppLogger.d('Parsing step non standard: $e');
          text = step.toString();
        }
      }

      // 1. Si consigne en Mooré ou Dioula avec fichier audio serveur disponible
      if ((lang == 'mos' || lang == 'diu') && audioUrl != null && audioUrl.isNotEmpty) {
        try {
          await _tts.stop();
          final player = _player;
          if (player != null) {
            await player.stop();
            await player.play(UrlSource(audioUrl));
            return;
          }
        } catch (e) {
          AppLogger.w('Échec lecture audio distant ($e), bascule sur la voix TTS');
        }
      }

      // 2. Annonce enrichie avec repère familier
      if (landmarkName != null && landmarkName.isNotEmpty && !text.contains(landmarkName)) {
        if (lang == 'mos') {
          text = '$landmarkName yaado, $text';
        } else if (lang == 'diu') {
          text = '$landmarkName kɛrɛfɛ, $text';
        } else {
          text = 'Près de $landmarkName, $text';
        }
      }

      await say(text, language: language);
    } catch (e) {
      AppLogger.w('Erreur sayStep: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      AppLogger.d('Arrêt TTS ignoré: $e');
    }
    try {
      await _player?.stop();
    } catch (e) {
      AppLogger.d('Arrêt AudioPlayer ignoré: $e');
    }
  }

  void dispose() {
    try {
      _tts.stop();
    } catch (e) {
      AppLogger.d('Arrêt TTS ignoré: $e');
    }
    try {
      _audioPlayer?.dispose();
    } catch (e) {
      AppLogger.d('Dispose AudioPlayer ignoré: $e');
    }
  }
}

final voiceGuideProvider = Provider<VoiceGuide>((ref) {
  final guide = VoiceGuide();
  guide.initialize();
  ref.onDispose(() => guide.dispose());
  return guide;
});
