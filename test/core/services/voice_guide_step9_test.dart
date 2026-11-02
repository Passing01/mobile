import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/services/voice_guide_service.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/anchor_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_maneuver_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_route_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Étape 9a · Consignes du moteur en français & Annonceur pas-à-pas', () {
    late VoiceGuide voiceGuide;
    late Announcer announcer;
    final spokenTexts = <String>[];

    setUp(() {
      spokenTexts.clear();
      voiceGuide = VoiceGuide();
      voiceGuide.banner.addListener(() {
        if (voiceGuide.banner.value.isNotEmpty) {
          spokenTexts.add(voiceGuide.banner.value);
        }
      });
      announcer = Announcer(voiceGuide);
    });

    test('1. Annonce à 200 m puis à 50 m avant chaque virage dans la fenêtre de 40 m', () {
      final steps = [
        const GuideStep(
          order: 1,
          along: 500.0, // Virage situé à 500 mètres de l'origine
          instruction: 'Tournez à droite sur Avenue Bassawarga',
          maneuverType: 'turn_right',
          streetName: 'Avenue Bassawarga',
          distanceMeters: 500.0,
          confidence: 1,
        ),
      ];

      // Progression à 250 m (d = 250 m) -> hors fenêtre [160, 200]
      announcer.onProgress(250.0, steps, language: 'fr');
      expect(announcer.spoken, isEmpty);
      expect(voiceGuide.banner.value, isEmpty);

      // Progression à 310 m (d = 190 m) -> dans la fenêtre de 200 m (160 < d <= 200)
      announcer.onProgress(310.0, steps, language: 'fr');
      expect(announcer.spoken, contains('0-200'));
      expect(voiceGuide.banner.value, 'Dans 200 mètres, tournez à droite sur Avenue Bassawarga');

      // Progression à 320 m (d = 180 m) -> encore dans la fenêtre, mais déjà annoncé !
      announcer.onProgress(320.0, steps, language: 'fr');
      expect(announcer.spoken.length, 1);
      expect(spokenTexts.length, 1); // Pas de doublon

      // Progression à 440 m (d = 60 m) -> hors fenêtre de 50 m (10 < d <= 50)
      announcer.onProgress(440.0, steps, language: 'fr');
      expect(announcer.spoken.length, 1);

      // Progression à 460 m (d = 40 m) -> dans la fenêtre de 50 m
      announcer.onProgress(460.0, steps, language: 'fr');
      expect(announcer.spoken, contains('0-50'));
      expect(voiceGuide.banner.value, 'Dans 50 mètres, tournez à droite sur Avenue Bassawarga');
      expect(spokenTexts.length, 2);

      // Progression à 470 m (d = 30 m) -> pas de répétition
      announcer.onProgress(470.0, steps, language: 'fr');
      expect(announcer.spoken.length, 2);
      expect(spokenTexts.length, 2);
    });

    test('2. Réinitialisation des annonces après recalcul (Announcer.reset)', () {
      final steps = [
        const GuideStep(
          order: 1,
          along: 500.0,
          instruction: 'Tournez à gauche',
          maneuverType: 'turn_left',
          distanceMeters: 500.0,
        ),
      ];

      announcer.onProgress(310.0, steps, language: 'fr');
      expect(announcer.spoken, contains('0-200'));
      expect(voiceGuide.banner.value, isNotEmpty);

      // Recalcul d'itinéraire intervenu -> reset
      announcer.reset();
      expect(announcer.spoken, isEmpty);
      expect(voiceGuide.banner.value, isEmpty);

      // Après reset, la consigne peut être redéclenchée sur un nouveau profil
      announcer.onProgress(315.0, steps, language: 'fr');
      expect(announcer.spoken, contains('0-200'));
    });

    test('3. Affichage du bandeau même si la voix fr-FR est indisponible', () async {
      final standaloneGuide = VoiceGuide();
      await standaloneGuide.init(); // En mode test ou hors ligne, _ok sera false

      await standaloneGuide.say('Prenez la 2ème sortie au rond-point');
      expect(standaloneGuide.banner.value, 'Prenez la 2ème sortie au rond-point');
    });
  });

  group('Étape 9b · Narrateur local : repères réels et phonétique name_tts', () {
    test('1. Intégration de la correction phonétique name_tts pour les noms locaux difficiles', () {
      final route = RouteModel(
        mode: 'motorcycle',
        distanceMeters: 1000.0,
        durationSeconds: 120,
        durationFormatted: '2 min',
        engine: 'valhalla',
        geometry: const [
          [12.3685, -1.5271],
          [12.3750, -1.5271],
        ],
        boundingBox: const [12.3685, -1.5271, 12.3750, -1.5271],
        maneuvers: const [
          ManeuverModel(
            order: 1,
            instruction: 'Tournez à droite',
            maneuverType: 'turn_right',
            distanceMeters: 500.0,
            durationSeconds: 60,
            location: CoordinateModel(lat: 12.3720, lon: -1.5271),
          ),
        ],
      );

      final enriched = const EnrichedRouteModel(
        mode: 'motorcycle',
        language: 'fr',
        totalDistanceMeters: 1000.0,
        totalDurationFormatted: '2 min',
        enrichedManeuvers: [
          EnrichedManeuverModel(
            order: 1,
            originalInstruction: 'Tournez à droite',
            localizedInstruction: 'Après Pont Kadiogo, tournez à droite',
            language: 'fr',
            maneuverType: 'turn_right',
            hasLandmark: true,
            landmarkName: 'Pont Kadiogo',
            distanceMeters: 500.0,
            durationSeconds: 60,
            confidence: 3,
            anchor: AnchorModel(
              id: 'bridge_1',
              name: 'Pont Kadiogo',
              kind: 'pont',
              s: 500.0,
              side: 'on',
              confidence: 3,
            ),
          ),
        ],
      );

      final places = [
        const PlaceModel(
          id: 10,
          nom: 'Pont Kadiogo',
          nameTts: 'Pont Kadjogo',
          categorieId: 1,
          latitude: 12.3720,
          longitude: -1.5271,
          categorie: CategoryModel(id: 1, nom: 'Pont', slug: 'pont', icone: 'bridge'),
        ),
      ];

      final steps = buildGuideSteps(
        route: route,
        enrichedRoute: enriched,
        places: places,
      );

      expect(steps.length, 1);
      final step = steps.first;
      expect(step.anchorName, 'Pont Kadiogo');
      expect(step.nameTts, 'Pont Kadjogo');

      // À 200 m, la synthèse utilise nameTts ('Pont Kadjogo')
      final spoken200 = step.spoken(dist: 200, language: 'fr');
      expect(spoken200, 'Dans 200 mètres, après Pont Kadjogo, tournez à droite');

      // À 50 m, consigne rapprochée
      final spoken50 = step.spoken(dist: 50, language: 'fr');
      expect(spoken50, 'Après Pont Kadjogo, tournez à droite');
    });

    test('2. Énoncés familiers aux feux tricolores (anchorType: traffic_signal)', () {
      const stepFeu = GuideStep(
        order: 1,
        along: 300.0,
        instruction: 'Tournez à gauche au feu',
        maneuverType: 'turn_left',
        distanceMeters: 300.0,
        confidence: 3,
        anchorType: 'traffic_signal',
        anchorName: 'Feu 1200 Logements',
      );

      expect(
        stepFeu.spoken(dist: 200, language: 'fr'),
        'Dans 200 mètres, au feu, tournez à gauche',
      );
      expect(
        stepFeu.spoken(dist: 50, language: 'fr'),
        'Au feu, tournez à gauche',
      );
    });

    test('3. Formulations multilingues en Mooré (mos) et Dioula (diu)', () {
      const stepTurn = GuideStep(
        order: 1,
        along: 400.0,
        instruction: 'Tournez à droite',
        maneuverType: 'turn_right',
        distanceMeters: 400.0,
        confidence: 3,
        anchorName: 'Rond-Point Patte d\'Oie',
      );

      // Mooré
      final spokenMoore200 = stepTurn.spoken(dist: 200, language: 'mos');
      expect(spokenMoore200, contains('Mɛtr 200 poore'));
      expect(spokenMoore200, contains('Rond-Point Patte d\'Oie poore'));
      expect(spokenMoore200, contains('gilli wĩndg-rɩtgo'));

      final spokenMoore50 = stepTurn.spoken(dist: 50, language: 'mos');
      expect(spokenMoore50, 'Rond-Point Patte d\'Oie poore, gilli wĩndg-rɩtgo');

      // Dioula
      final spokenDioula200 = stepTurn.spoken(dist: 200, language: 'diu');
      expect(spokenDioula200, contains('Mɛtɛrɛ 200 kɔfɛ'));
      expect(spokenDioula200, contains('Rond-Point Patte d\'Oie kɔfɛ'));
      expect(spokenDioula200, contains('kɛlɛbili kinin fɛ'));

      final spokenDioula50 = stepTurn.spoken(dist: 50, language: 'diu');
      expect(spokenDioula50, 'Rond-Point Patte d\'Oie kɔfɛ, kɛlɛbili kinin fɛ');
    });

    test('4. Prise en charge des fichiers audio locaux déclarés pour Mooré et Dioula', () {
      const stepWithAudio = GuideStep(
        order: 1,
        along: 200.0,
        instruction: 'Kẽng tao mɛtr 50, rabo gilli wĩndg-rɩtgo',
        maneuverType: 'turn_right',
        distanceMeters: 200.0,
        confidence: 3,
        localAudioFile: 'assets/audio/voice/WhatsApp Audio 2026-10-20 at 23.07.09.ogg',
      );

      final audioSource = stepWithAudio.audioFor(dist: 200, language: 'mos');
      expect(audioSource, 'assets/audio/voice/WhatsApp Audio 2026-10-20 at 23.07.09.ogg');
    });
  });
}
