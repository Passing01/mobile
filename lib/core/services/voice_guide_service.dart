import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/core/services/navigation_engine.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_route_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Étape ou virage associé à sa position curviligne sur le tracé réel (Étape 9)
class GuideStep {
  final int order;
  final double along; // Mètres cumulés depuis l'origine du tracé
  final String instruction;
  final String maneuverType; // 'turn_left', 'turn_right', 'slight_left', 'roundabout', 'straight', 'arrive', 'depart'
  final String? streetName;
  final double distanceMeters;
  final int confidence; // 3 = relevé terrain, 2 = source ouverte, 1 = consigne simple sans repère
  final String? anchorName;
  final String? anchorType; // 'traffic_signal', 'bridge', 'interchange', 'roundabout', 'place'
  final String? anchorSide; // 'left', 'right', 'ahead'
  final String? nameTts; // Correction phonétique pour synthèse vocale
  final String? localAudioFile; // Chemin fichier audio pour langues nationales

  const GuideStep({
    required this.order,
    required this.along,
    required this.instruction,
    required this.maneuverType,
    this.streetName,
    this.distanceMeters = 0.0,
    this.confidence = 1,
    this.anchorName,
    this.anchorType,
    this.anchorSide,
    this.nameTts,
    this.localAudioFile,
  });

  /// Formule la consigne à prononcer à [dist] mètres avant le virage
  String spoken({required double dist, String language = 'fr'}) {
    final lang = language.toLowerCase();
    if (lang == 'mos' || lang == 'moore') {
      return _spokenMoore(dist);
    } else if (lang == 'diu' || lang == 'dioula') {
      return _spokenDioula(dist);
    }
    return _spokenFr(dist);
  }

  /// Résout l'éventuel fichier audio pour cette distance et cette langue
  String? audioFor({required double dist, String language = 'fr'}) {
    if (localAudioFile != null && localAudioFile!.isNotEmpty) {
      return localAudioFile;
    }
    final lang = language.toLowerCase();
    if (lang == 'mos' || lang == 'moore') {
      return _nativeAudioPath('mos', maneuverType);
    } else if (lang == 'diu' || lang == 'dioula') {
      return _nativeAudioPath('diu', maneuverType);
    }
    return null;
  }

  static String? _nativeAudioPath(String lang, String type) {
    final t = type.toLowerCase();
    String file;
    if (t.contains('left')) {
      file = 'turn_left.ogg';
    } else if (t.contains('right')) {
      file = 'turn_right.ogg';
    } else if (t == 'arrive') {
      file = 'arrive.ogg';
    } else if (t == 'depart') {
      file = 'depart.ogg';
    } else {
      file = 'straight.ogg';
    }
    return 'assets/audio/$lang/$file';
  }

  /// Icône Material symbolisant le virage ou l'action
  IconData get iconData {
    switch (maneuverType.toLowerCase()) {
      case 'turn_left':
      case 'left':
      case 'sharp_left':
        return Icons.turn_left_rounded;
      case 'turn_right':
      case 'right':
      case 'sharp_right':
        return Icons.turn_right_rounded;
      case 'slight_left':
        return Icons.turn_slight_left_rounded;
      case 'slight_right':
        return Icons.turn_slight_right_rounded;
      case 'roundabout':
        return Icons.change_circle_rounded;
      case 'u_turn':
        return Icons.u_turn_left_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      case 'depart':
        return Icons.navigation_rounded;
      case 'straight':
      default:
        return Icons.straight_rounded;
    }
  }

  String _spokenFr(double dist) {
    final effectiveAnchor = nameTts ?? anchorName;
    final dInt = dist.toInt();
    final action = _actionFr(maneuverType);

    if (maneuverType == 'arrive') {
      return dist >= 100.0
          ? 'Dans $dInt mètres, vous arriverez à destination'
          : 'Vous arrivez à destination';
    }
    if (maneuverType == 'depart') {
      return 'Prenez la route';
    }

    // 9b · Narrateur local : repères réels (confiance >= 2)
    if (confidence >= 2 && effectiveAnchor != null && effectiveAnchor.isNotEmpty) {
      if (anchorType == 'traffic_signal' || anchorType == 'feu') {
        return dist >= 100.0
            ? 'Dans $dInt mètres, au feu, $action'
            : 'Au feu, $action';
      } else {
        return dist >= 100.0
            ? 'Dans $dInt mètres, après $effectiveAnchor, $action'
            : 'Après $effectiveAnchor, $action';
      }
    }

    // 9a · Consigne simple du moteur sans repère (confiance 1)
    if (streetName != null &&
        streetName!.isNotEmpty &&
        !streetName!.toLowerCase().startsWith('unnamed')) {
      return 'Dans $dInt mètres, $action sur $streetName';
    }
    return 'Dans $dInt mètres, $action';
  }

  String _spokenMoore(double dist) {
    final effectiveAnchor = nameTts ?? anchorName ?? '';
    final dInt = dist.toInt();
    final action = _actionMoore(maneuverType);

    if (maneuverType == 'arrive') {
      return 'Y taame y zĩigẽ';
    }
    if (maneuverType == 'depart') {
      return 'Rɩk sorã';
    }

    if (confidence >= 2 && effectiveAnchor.isNotEmpty) {
      if (anchorType == 'traffic_signal' || anchorType == 'feu') {
        return dist >= 100.0
            ? 'Mɛtr $dInt poore, feu wã nengẽ, $action'
            : 'Feu wã nengẽ, $action';
      } else {
        return dist >= 100.0
            ? 'Mɛtr $dInt poore, $effectiveAnchor poore, $action'
            : '$effectiveAnchor poore, $action';
      }
    }

    return dist >= 100.0
        ? 'Mɛtr $dInt poore, $action'
        : 'Kẽng tao mɛtr $dInt, rabo $action';
  }

  String _spokenDioula(double dist) {
    final effectiveAnchor = nameTts ?? anchorName ?? '';
    final dInt = dist.toInt();
    final action = _actionDioula(maneuverType);

    if (maneuverType == 'arrive') {
      return 'I sera i yɔrɔ la';
    }
    if (maneuverType == 'depart') {
      return 'Sira ta';
    }

    if (confidence >= 2 && effectiveAnchor.isNotEmpty) {
      if (anchorType == 'traffic_signal' || anchorType == 'feu') {
        return dist >= 100.0
            ? 'Mɛtɛrɛ $dInt kɔfɛ, feu yɔrɔ la, $action'
            : 'Feu yɔrɔ la, $action';
      } else {
        return dist >= 100.0
            ? 'Mɛtɛrɛ $dInt kɔfɛ, $effectiveAnchor kɔfɛ, $action'
            : '$effectiveAnchor kɔfɛ, $action';
      }
    }

    return dist >= 100.0
        ? 'Mɛtɛrɛ $dInt kɔfɛ, $action'
        : 'Ta ɲɛfɛ mɛtɛrɛ $dInt, ka $action';
  }

  static String _actionFr(String type) {
    switch (type.toLowerCase()) {
      case 'turn_left':
      case 'left':
        return 'tournez à gauche';
      case 'turn_right':
      case 'right':
        return 'tournez à droite';
      case 'slight_left':
        return 'serrez à gauche';
      case 'slight_right':
        return 'serrez à droite';
      case 'sharp_left':
        return 'tournez franchement à gauche';
      case 'sharp_right':
        return 'tournez franchement à droite';
      case 'u_turn':
        return 'faites demi-tour';
      case 'roundabout':
        return 'au rond-point, prenez la sortie';
      case 'straight':
        return 'continuez tout droit';
      default:
        return 'suivez la route';
    }
  }

  static String _actionMoore(String type) {
    switch (type.toLowerCase()) {
      case 'turn_left':
      case 'left':
      case 'slight_left':
      case 'sharp_left':
        return 'gilli wĩndg-goabga';
      case 'turn_right':
      case 'right':
      case 'slight_right':
      case 'sharp_right':
        return 'gilli wĩndg-rɩtgo';
      case 'roundabout':
        return 'rond-point wã zugu, rɩk sorã';
      case 'straight':
      default:
        return 'kẽng tɩrga';
    }
  }

  static String _actionDioula(String type) {
    switch (type.toLowerCase()) {
      case 'turn_left':
      case 'left':
      case 'slight_left':
      case 'sharp_left':
        return 'kɛlɛbili numanya fɛ';
      case 'turn_right':
      case 'right':
      case 'slight_right':
      case 'sharp_right':
        return 'kɛlɛbili kinin fɛ';
      case 'roundabout':
        return 'rond-point kan, sira ta';
      case 'straight':
      default:
        return 'taga ɲɛfɛ';
    }
  }
}

/// Service de synthèse vocale et d'affichage de bandeau conforme Étape 9
class VoiceGuide {
  VoiceGuide({FlutterTts? tts, AudioPlayer? player})
      : _customTts = tts,
        _customPlayer = player;

  final FlutterTts? _customTts;
  final AudioPlayer? _customPlayer;
  FlutterTts? _ttsInstance;
  AudioPlayer? _playerInstance;

  FlutterTts get _tts => _customTts ?? (_ttsInstance ??= FlutterTts());
  AudioPlayer? get _player {
    if (_customPlayer != null) return _customPlayer;
    if (_playerInstance != null) return _playerInstance;
    try {
      _playerInstance = AudioPlayer();
      return _playerInstance;
    } catch (e) {
      AppLogger.w('Initialisation AudioPlayer impossible: $e');
      return null;
    }
  }

  bool _ok = false;
  bool get isOk => _ok;

  /// Bandeau de consigne toujours affiché en gros à l'écran
  final banner = ValueNotifier<String>('');

  void clearBanner() {
    banner.value = '';
  }

  Future<void> init() async {
    clearBanner();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest && _customTts == null) {
      _ok = false;
      return;
    }
    try {
      final res = await _tts
          .isLanguageAvailable('fr-FR')
          .timeout(const Duration(milliseconds: 400), onTimeout: () => false);
      _ok = res == true;
      if (_ok) {
        await _tts.setLanguage('fr-FR');
        await _tts.setSpeechRate(0.48);
        await _tts.awaitSpeakCompletion(true);
      } else {
        AppLogger.w('[VOIX] fr-FR indisponible : texte seul');
      }
    } catch (e) {
      _ok = false;
      AppLogger.w('[VOIX] fr-FR indisponible : texte seul ($e)');
    }
  }

  /// Énonce la consigne à voix haute et met à jour le bandeau textuel
  Future<void> say(
    String text, {
    String? audioSource,
    String language = 'fr',
    String? frenchFallbackText,
  }) async {
    AppLogger.i('[VOIX] $text');
    banner.value = text; // Le texte s'affiche toujours

    bool audioPlayed = false;
    // Si un fichier audio natif (Mooré/Dioula) est spécifié
    if (audioSource != null && audioSource.isNotEmpty) {
      try {
        await _tts.stop();
        final player = _player;
        if (player != null) {
          await player.stop();
          if (audioSource.startsWith('assets/')) {
            await player.play(AssetSource(audioSource.replaceFirst('assets/', '')));
            audioPlayed = true;
          } else if (audioSource.startsWith('http')) {
            await player.play(UrlSource(audioSource));
            audioPlayed = true;
          } else {
            await player.play(DeviceFileSource(audioSource));
            audioPlayed = true;
          }
        }
      } catch (e) {
        AppLogger.w('[VOIX] Échec lecture audio ($e), repli vocal');
        audioPlayed = false;
      }
    }

    // Synthèse vocale TTS :
    // RÈGLE ÉTAPE 10 : Si un audio mooré ou dioula manque, le repli sur la voix de synthèse française
    // lirait du texte mooré/dioula avec une prononciation française incompréhensible.
    // En cas de repli, énoncer la consigne équivalente EN FRANÇAIS tout en gardant l'affichage dans la langue sélectionnée !
    if (!audioPlayed && _ok) {
      try {
        await _player?.stop();
        await _tts.stop();
        final textToSpeak = (language != 'fr' && language != 'fr-FR')
            ? (frenchFallbackText != null && frenchFallbackText.isNotEmpty ? frenchFallbackText : text)
            : text;
        await _tts.speak(textToSpeak);
      } catch (e) {
        AppLogger.w('[VOIX] Erreur synthèse vocale: $e');
      }
    }
  }

  /// Énonce la manœuvre avec prise en compte des repères familiers
  Future<void> sayStep(dynamic step, {String language = 'fr'}) async {
    String text = '';
    String frenchFallbackText = '';
    String? audioUrl;
    String? landmarkName;

    if (step is GuideStep) {
      text = step.spoken(dist: 50.0, language: language);
      frenchFallbackText = step.spoken(dist: 50.0, language: 'fr');
      audioUrl = step.audioFor(dist: 50.0, language: language) ?? step.localAudioFile;
      landmarkName = step.anchorName;
    } else if (step is Map<String, dynamic>) {
      text = (step['localized_instruction'] as String?) ??
          (step['instruction'] as String?) ??
          (step['maneuver'] is Map ? step['maneuver']['instruction'] as String? : null) ??
          '';
      frenchFallbackText = (step['instruction'] as String?) ?? text;
      audioUrl = step['audio_url'] as String?;
      landmarkName = step['landmark_name'] as String?;
    } else {
      try {
        text = (step.localizedInstruction ?? step.originalInstruction ?? '').toString();
        frenchFallbackText = (step.originalInstruction ?? step.instruction ?? text).toString();
        audioUrl = step.audioUrl as String?;
        landmarkName = step.landmarkName as String?;
      } catch (_) {
        text = step.toString();
        frenchFallbackText = text;
      }
    }

    if (landmarkName != null && landmarkName.isNotEmpty && !text.contains(landmarkName)) {
      final lang = language.toLowerCase();
      if (lang == 'mos' || lang == 'moore') {
        text = '$landmarkName poore, $text';
      } else if (lang == 'diu' || lang == 'dioula') {
        text = '$landmarkName kɔfɛ, $text';
      } else {
        text = 'Après $landmarkName, $text';
      }
      frenchFallbackText = 'Après $landmarkName, $frenchFallbackText';
    }

    await say(
      text,
      audioSource: audioUrl,
      language: language,
      frenchFallbackText: frenchFallbackText,
    );
  }

  Future<void> stop() async {
    clearBanner();
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
    try {
      _playerInstance?.dispose();
    } catch (_) {}
  }
}

/// Annonceur pas-à-pas le long du tracé réel (Étape 9a)
/// Annonce chaque virage à 200 m, puis à 50 m avant le virage, une seule fois chacun.
/// Fenêtre de déclenchement : 40 m.
class Announcer {
  Announcer(this.voice);

  final VoiceGuide voice;
  final _spoken = <String>{};

  /// Clés d'annonces déjà prononcées (pour assertions et tests)
  Set<String> get spoken => Set.unmodifiable(_spoken);

  void onProgress(
    double along,
    List<GuideStep> steps, {
    String language = 'fr',
  }) {
    for (var i = 0; i < steps.length; i++) {
      final d = steps[i].along - along; // mètres avant le virage
      for (final t in const [200.0, 50.0]) {
        final key = '$i-${t.toInt()}';
        if (d <= t && d > t - 40 && _spoken.add(key)) {
          voice.say(
            steps[i].spoken(dist: t, language: language),
            audioSource: steps[i].audioFor(dist: t, language: language),
            language: language,
          );
        }
      }
    }
  }

  /// Réinitialise les annonces après un recalcul d'itinéraire
  void reset() {
    _spoken.clear();
    voice.clearBanner();
  }
}

/// Transforme un itinéraire et sa géométrie en une séquence de [GuideStep] projetés
List<GuideStep> buildGuideSteps({
  required RouteModel route,
  EnrichedRouteModel? enrichedRoute,
  List<PlaceModel>? places,
}) {
  final geom = RouteGeometry.fromRoute(route);
  final steps = <GuideStep>[];

  for (var i = 0; i < route.maneuvers.length; i++) {
    final m = route.maneuvers[i];
    final proj = geom.project(LatLng(m.location.lat, m.location.lon));

    final enriched = (enrichedRoute != null && i < enrichedRoute.enrichedManeuvers.length)
        ? enrichedRoute.enrichedManeuvers[i]
        : null;

    // Correction phonétique name_tts pour les noms difficiles
    String? nameTts;
    if (enriched?.landmarkName != null && places != null) {
      for (final p in places) {
        if (p.nom.trim().toLowerCase() == enriched!.landmarkName!.trim().toLowerCase()) {
          nameTts = p.nameTts;
          break;
        }
      }
    }

    steps.add(GuideStep(
      order: m.order,
      along: proj.along,
      instruction: enriched?.localizedInstruction ?? m.instruction,
      maneuverType: m.maneuverType,
      streetName: m.streetName,
      distanceMeters: m.distanceMeters,
      confidence: enriched?.confidence ?? 1,
      anchorName: enriched?.landmarkName,
      anchorType: enriched?.anchor?.kind,
      anchorSide: enriched?.anchor?.side,
      nameTts: nameTts,
      localAudioFile: enriched?.audioUrl,
    ));
  }

  return steps;
}

final voiceGuideProvider = Provider<VoiceGuide>((ref) {
  final guide = VoiceGuide();
  guide.init();
  ref.onDispose(() => guide.dispose());
  return guide;
});

final announcerProvider = Provider<Announcer>((ref) {
  final voice = ref.watch(voiceGuideProvider);
  return Announcer(voice);
});
