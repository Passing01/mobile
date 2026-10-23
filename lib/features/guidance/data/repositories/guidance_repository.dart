import 'package:qvgestion_mobile/core/config/app_config.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/anchor_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_maneuver_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_route_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/landmark_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/narrator_v2.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Repository pour interagir avec le moteur de consignes locales et guidage vocal FASO NAV
/// Implémente le Narrateur v2 (ancres routières, hiérarchie de confiance et gabarits multilingues)
class GuidanceRepository {
  final ApiClient apiClient;

  GuidanceRepository({required this.apiClient});

  /// Récupère la liste des repères locaux enregistrés (GET /api/v1/guidance/landmarks)
  Future<List<LandmarkModel>> getLandmarks({
    String? typeRepere,
    String? ville,
    String? quartier,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (typeRepere != null) queryParams['type_repere'] = typeRepere;
      if (ville != null) queryParams['ville'] = ville;
      if (quartier != null) queryParams['quartier'] = quartier;

      final response = await apiClient.get<dynamic>(
        ApiEndpoints.guidanceLandmarks,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final list = response.data as List<dynamic>? ?? [];
      final landmarks = list
          .map((item) => LandmarkModel.fromJson(item as Map<String, dynamic>))
          .toList();
      if (landmarks.isNotEmpty) return landmarks;
      return AppConfig.testMode ? defaultOuagaLandmarks : const [];
    } catch (e) {
      AppLogger.w('Repères distants inaccessibles ($e).');
      AppErrorReporter.reportWarning('Repères distants inaccessibles: $e', tag: 'Guidance');
      return AppConfig.testMode ? defaultOuagaLandmarks : const [];
    }
  }

  /// Récupère les ancres de guidage situées le long du corridor d'un tracé WKT
  Future<List<AnchorModel>> getCorridorAnchors(String lineWkt) async {
    try {
      final response = await apiClient.get<dynamic>(
        '/guidance/anchors',
        queryParameters: {'wkt': lineWkt},
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((item) => AnchorModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.w('Ancres de corridor inaccessibles ($e).');
      AppErrorReporter.reportWarning('Ancres de corridor inaccessibles: $e', tag: 'Guidance');
      if (!AppConfig.testMode) return const [];
      return defaultOuagaLandmarks.map((l) {
        return AnchorModel(
          kind: l.typeRepere == 'echangeur' ? 'interchange' : 'landmark',
          id: l.id.toString(),
          name: l.nom,
          s: 300.0,
          side: 'right',
          importance: l.importance,
          confidence: 3,
          latitude: l.latitude,
          longitude: l.longitude,
        );
      }).toList();
    }
  }

  /// Enrichit un itinéraire avec les repères familiers de Ouagadougou et les consignes vocales
  /// (POST /api/v1/guidance/enrich-route)
  Future<EnrichedRouteModel> enrichRoute({
    required RouteModel route,
    required String language,
  }) async {
    try {
      final payload = {
        'route': route.toJson(),
        'language': language,
      };

      final response = await apiClient.post<dynamic>(
        ApiEndpoints.guidanceEnrichRoute,
        data: payload,
      );

      return EnrichedRouteModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.w('Serveur de guidage indisponible ($e). Activation du Narrateur v2 local.');
      AppErrorReporter.reportWarning('Serveur de guidage indisponible ($e). Activation du guidage local.', tag: 'Guidance');
      return _buildOfflineEnrichedRoute(route, language);
    }
  }

  /// Moteur de narration local v2 avec ancres familières de Ouaga et gabarits de phrases
  EnrichedRouteModel _buildOfflineEnrichedRoute(RouteModel route, String language) {
    final lang = language.toLowerCase();
    final enrichedList = <EnrichedManeuverModel>[];

    // Conversion des landmarks en ancres pour le Narrateur v2 (uniquement en testMode)
    final fallbackLandmarks = AppConfig.testMode ? defaultOuagaLandmarks : const <LandmarkModel>[];
    final defaultAnchors = fallbackLandmarks.map((l) {
      String kind = 'landmark';
      if (l.typeRepere == 'echangeur') kind = 'interchange';
      if (l.typeRepere == 'rond-point') kind = 'roundabout';
      return AnchorModel(
        kind: kind,
        id: l.id.toString(),
        name: l.nom,
        s: 250.0,
        side: 'right',
        importance: l.importance,
        confidence: 3,
        latitude: l.latitude,
        longitude: l.longitude,
      );
    }).toList();

    double accumulatedDistance = 0.0;
    for (int i = 0; i < route.maneuvers.length; i++) {
      final m = route.maneuvers[i];
      accumulatedDistance += m.distanceMeters;

      String turnSide = 'right';
      if (m.maneuverType.contains('left')) {
        turnSide = 'left';
      } else if (m.maneuverType == 'straight' || m.maneuverType == 'depart') {
        turnSide = 'straight';
      }

      // Simulation de sélection d'ancre via NarratorV2
      final turn = NavigationTurn(s: accumulatedDistance, side: turnSide, cls: 'rue');
      final steps = NarratorV2.narrate(
        turns: [turn],
        anchors: defaultAnchors,
        crossings: const [],
      );

      final narrativeStep = steps.isNotEmpty
          ? steps.first
          : NarrativeStep(
              s: accumulatedDistance,
              key: 'turn_dist',
              params: {'dist': m.distanceMeters.round(), 'side': turnSide},
              confidence: 2,
            );

      String localized;
      if (m.maneuverType == 'arrive') {
        if (lang == 'mos') {
          localized = 'Y taame ! Barka wusgo';
        } else if (lang == 'diu') {
          localized = 'I sera yɔrɔ la ! I ni ce';
        } else {
          localized = 'Vous êtes arrivé à destination !';
        }
      } else if (m.maneuverType == 'depart') {
        if (lang == 'mos') {
          localized = 'Rɩk sorã n kẽng ${m.streetName ?? "tao"}';
        } else if (lang == 'diu') {
          localized = 'Sira ta ka ta ${m.streetName ?? "ɲɛfɛ"}';
        } else {
          localized = 'Prenez la route sur ${m.streetName ?? "la voie principale"}';
        }
      } else {
        localized = narrativeStep.render(language: lang);
      }

      enrichedList.add(
        EnrichedManeuverModel(
          order: m.order,
          originalInstruction: m.instruction,
          localizedInstruction: localized,
          language: lang,
          maneuverType: m.maneuverType,
          hasLandmark: narrativeStep.anchor != null || i == 1,
          landmarkName: narrativeStep.anchor?.displayName ?? (i == 1 ? 'Près de l\'Axe National' : null),
          distanceMeters: m.distanceMeters,
          durationSeconds: m.durationSeconds,
          audioSoundId: 'snd_${m.maneuverType}',
          audioUrl: getAudioUrl('snd_${m.maneuverType}'),
          confidence: narrativeStep.confidence,
          templateKey: narrativeStep.key,
          anchor: narrativeStep.anchor,
        ),
      );
    }

    return EnrichedRouteModel(
      mode: route.mode,
      totalDistanceMeters: route.distanceMeters,
      totalDurationFormatted: route.durationFormatted,
      language: lang,
      enrichedManeuvers: enrichedList.isNotEmpty
          ? enrichedList
          : [
              EnrichedManeuverModel(
                order: 1,
                originalInstruction: 'Suivre l\'itinéraire',
                localizedInstruction: lang == 'mos'
                    ? 'Rɩk sorã n tɩ ta'
                    : lang == 'diu'
                        ? 'Sira ta ka ta'
                        : 'Suivre l\'itinéraire',
                language: lang,
                maneuverType: 'depart',
                hasLandmark: false,
                distanceMeters: route.distanceMeters,
                durationSeconds: route.durationSeconds,
                confidence: 2,
              ),
            ],
    );
  }

  /// Récupère l'URL complète du flux audio WAV pour une consigne donnée
  String getAudioUrl(String soundId) {
    return '${EnvConfig.apiBaseUrl}/guidance/audio/$soundId.wav';
  }
}

/// Catalogue des repères clés de Ouagadougou en secours hors-ligne
const List<LandmarkModel> defaultOuagaLandmarks = [
  LandmarkModel(
    id: 1,
    nom: 'Monument des Héros Nationaux',
    nomMoore: 'Kamba tẽng-n-biisi monument',
    nomDioula: 'Héros kɛrɛbila monument',
    latitude: 12.3160,
    longitude: -1.5030,
    importance: 5,
    visibiliteMetres: 200.0,
    typeRepere: 'monument',
    description: 'Grand monument rond-point Ouaga 2000',
  ),
  LandmarkModel(
    id: 2,
    nom: 'Place de la Nation (Révolution)',
    nomMoore: 'Nation yaado',
    nomDioula: 'Jamana kɛnɛ',
    latitude: 12.3680,
    longitude: -1.5270,
    importance: 5,
    visibiliteMetres: 150.0,
    typeRepere: 'place',
    description: 'Place centrale en face de la mairie',
  ),
  LandmarkModel(
    id: 3,
    nom: 'Rond-Point des Nations Unies',
    nomMoore: 'Nations Unies rond-point',
    latitude: 12.3700,
    longitude: -1.5180,
    importance: 4,
    visibiliteMetres: 120.0,
    typeRepere: 'rond-point',
    description: 'Carrefour central Avenue Nelson Mandela',
  ),
  LandmarkModel(
    id: 4,
    nom: 'Échangeur du Nord',
    nomMoore: 'Nord échangeur',
    latitude: 12.3950,
    longitude: -1.5350,
    importance: 5,
    visibiliteMetres: 250.0,
    typeRepere: 'echangeur',
    description: 'Grand échangeur moderne sortie Nord',
  ),
  LandmarkModel(
    id: 5,
    nom: 'Échangeur de l\'Est',
    nomMoore: 'Est échangeur',
    latitude: 12.3710,
    longitude: -1.4850,
    importance: 5,
    visibiliteMetres: 250.0,
    typeRepere: 'echangeur',
    description: 'Échangeur route de Fada',
  ),
];
