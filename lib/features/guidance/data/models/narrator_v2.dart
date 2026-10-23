import 'package:equatable/equatable.dart';
import 'anchor_model.dart';

/// Poids des types d'ancres selon la spécification FASO NAV
const Map<String, double> kKindWeights = {
  'interchange': 5.0,
  'bridge': 4.5,
  'roundabout': 4.5,
  'traffic_signal': 4.0,
  'landmark': 3.5,
  'place': 3.0,
};

/// Représentation d'un virage ou d'une intersection
class NavigationTurn extends Equatable {
  final double s; // Position curviligne en mètres depuis l'origine
  final String side; // 'left' | 'right' | 'straight'
  final String cls; // 'six_metres' | 'dix_metres' | 'grande_voie' | 'piste' | 'rue'

  const NavigationTurn({
    required this.s,
    required this.side,
    this.cls = 'rue',
  });

  @override
  List<Object?> get props => [s, side, cls];
}

/// Rue ou voie croisant le tracé de navigation
class RouteCrossing extends Equatable {
  final double s;
  final String side; // 'left' | 'right'
  final String cls;

  const RouteCrossing({
    required this.s,
    required this.side,
    this.cls = 'six_metres',
  });

  @override
  List<Object?> get props => [s, side, cls];
}

/// Étape produite par le Narrateur v2
class NarrativeStep extends Equatable {
  final double s;
  final String key;
  final Map<String, dynamic> params;
  final int confidence; // 3 relevé terrain, 2 source ouverte, 1 incertain
  final AnchorModel? anchor;

  const NarrativeStep({
    required this.s,
    required this.key,
    this.params = const {},
    required this.confidence,
    this.anchor,
  });

  /// Traduction dynamique dans la langue demandée (fr, mos/moore, diu/dioula)
  String render({String language = 'fr'}) {
    final lang = language.toLowerCase();
    final side = (params['side'] as String?) ?? 'right';
    final n = (params['n'] as num?)?.toInt() ?? 1;
    final cls = (params['cls'] as String?) ?? 'rue';
    final dist = (params['dist'] as num?)?.toInt() ?? 100;
    final anchorName = anchor?.displayName ?? (params['anchor']?.toString() ?? 'le repère');

    final sideStr = _formatSide(side, lang);
    final clsStr = _formatCls(cls, lang);
    final ordStr = _formatOrdinal(n, lang);

    if (lang == 'mos' || lang == 'moore') {
      switch (key) {
        case 'at_signal_turn':
          return 'Feo zĩisẽ, gilli $sideStr';
        case 'after_anchor_turn':
          return '$anchorName poore, rɩk $clsStr $ordStr $sideStr';
        case 'after_anchor_plain':
          return '$anchorName poore, gilli $sideStr';
        case 'turn_count':
          return 'Rɩk $clsStr $ordStr $sideStr';
        case 'turn_dist':
          return 'Kẽng tao mɛtr $dist, rabo gilli $sideStr';
        case 'straight_to_anchor':
          return 'Kẽng tao hal tɩ tãag $anchorName, rabo lʋɩ tao';
        case 'roundabout_exit':
          return 'Rõ-pwɛ zĩisẽ, rɩk bʋlg $ordStr';
        default:
          return 'Gilli $sideStr';
      }
    } else if (lang == 'diu' || lang == 'dioula') {
      switch (key) {
        case 'at_signal_turn':
          return 'Fe la, kɛlɛbili $sideStr';
        case 'after_anchor_turn':
          return '$anchorName kɔfɛ, $clsStr $ordStr ta $sideStr';
        case 'after_anchor_plain':
          return '$anchorName kɔfɛ, kɛlɛbili $sideStr';
        case 'turn_count':
          return '$clsStr $ordStr ta $sideStr';
        case 'turn_dist':
          return 'Ta ɲɛfɛ mɛtɛrɛ $dist, ka kɛlɛbili $sideStr';
        case 'straight_to_anchor':
          return 'Ta teliya fo ka se $anchorName ma, o kɔ fɛ tɛmɛ';
        case 'roundabout_exit':
          return 'Rɔn-puwɛ la, bɔrɔ $ordStr ta';
        default:
          return 'Kɛlɛbili $sideStr';
      }
    } else {
      // Français par défaut
      switch (key) {
        case 'at_signal_turn':
          return 'Au feu, tournez à $sideStr';
        case 'after_anchor_turn':
          return 'Après $anchorName, prenez la $ordStr $clsStr à $sideStr';
        case 'after_anchor_plain':
          return 'Après $anchorName, tournez à $sideStr';
        case 'turn_count':
          return 'Prenez la $ordStr $clsStr à $sideStr';
        case 'turn_dist':
          return 'Continuez $dist m, puis tournez à $sideStr';
        case 'straight_to_anchor':
          return 'Allez tout droit jusqu\'à $anchorName, puis dépassez-le';
        case 'roundabout_exit':
          return 'Au rond-point, prenez la $ordStr sortie';
        default:
          return 'Tournez à $sideStr';
      }
    }
  }

  static String _formatSide(String side, String lang) {
    if (lang == 'mos' || lang == 'moore') {
      if (side == 'left') return 'wĩndg-goabga';
      if (side == 'right') return 'wĩndg-rɩtgo';
      return 'tao';
    }
    if (lang == 'diu' || lang == 'dioula') {
      if (side == 'left') return 'numanya fɛ';
      if (side == 'right') return 'kinin fɛ';
      return 'ɲɛfɛ';
    }
    if (side == 'left') return 'gauche';
    if (side == 'right') return 'droite';
    return 'tout droit';
  }

  static String _formatCls(String cls, String lang) {
    if (cls == 'six_metres') {
      if (lang.startsWith('mo')) return 'six-mètres';
      if (lang.startsWith('di')) return 'six-mètres';
      return 'six-mètres';
    }
    if (cls == 'dix_metres') return 'dix-mètres';
    if (cls == 'grande_voie') return 'grande voie';
    if (cls == 'piste') return 'piste';
    return 'rue';
  }

  static String _formatOrdinal(int n, String lang) {
    if (lang == 'mos' || lang == 'moore') {
      if (n == 1) return 'pipa';
      if (n == 2) return 'yiib soaba';
      if (n == 3) return 'tãab soaba';
      return '$n soaba';
    }
    if (lang == 'diu' || lang == 'dioula') {
      if (n == 1) return 'fɔlɔ';
      if (n == 2) return 'filanan';
      if (n == 3) return 'sabanan';
      return '${n}nan';
    }
    if (n == 1) return '1ère';
    return '${n}e';
  }

  @override
  List<Object?> get props => [s, key, params, confidence, anchor];
}

/// Moteur de narration v2 FASO NAV
/// Implémente fidèlement l'algorithme probabiliste de sélection d'ancres et de gabarits
class NarratorV2 {
  /// Détermine si un point Q se trouve à gauche ou à droite du segment orienté P0 -> P1
  static String sideOf(List<double> p0, List<double> p1, List<double> q) {
    final cross = (p1[0] - p0[0]) * (q[1] - p0[1]) - (p1[1] - p0[1]) * (q[0] - p0[0]);
    return cross > 0 ? 'left' : 'right';
  }

  /// Score d'adéquation d'une ancre pour un virage donné
  /// Fenêtre admissible : entre 15 m et 600 m avant le virage
  static double scoreAnchor(AnchorModel a, double turnS, String turnSide) {
    final d = turnS - a.s;
    final minDistance = a.kind == 'traffic_signal' ? 0.0 : 15.0;
    if (d < minDistance || d > 600.0) {
      return 0.0;
    }
    final kindWeight = kKindWeights[a.kind] ?? 2.0;
    final importanceFactor = 0.5 + 0.5 * (a.importance / 5.0);
    final confidenceFactor = 0.7 + 0.1 * a.confidence;
    final distanceDecay = (1.0 - (d / 700.0)).clamp(0.0, 1.0);

    double sc = kindWeight * importanceFactor * confidenceFactor * distanceDecay;

    // Bonus de 15% si l'ancre est du même côté que le virage
    if (a.side == turnSide) {
      sc *= 1.15;
    }
    return sc;
  }

  /// Sélectionne la meilleure ancre le long du tracé avant le virage
  static AnchorModel? pickAnchor(List<AnchorModel> anchors, double turnS, String turnSide) {
    AnchorModel? best;
    double bestScore = 0.0;

    for (final a in anchors) {
      final sc = scoreAnchor(a, turnS, turnSide);
      if (sc > bestScore) {
        bestScore = sc;
        best = a;
      }
    }
    return bestScore > 0 ? best : null;
  }

  /// Génère les étapes de navigation enrichies avec ancres ou comptage de rues
  static List<NarrativeStep> narrate({
    required List<NavigationTurn> turns,
    required List<AnchorModel> anchors,
    required List<RouteCrossing> crossings,
  }) {
    final steps = <NarrativeStep>[];
    double prevS = 0.0;

    for (final t in turns) {
      final a = pickAnchor(anchors, t.s, t.side);
      final since = a != null ? a.s : prevS;

      // Comptage des intersections intermédiaires du même type et même côté
      int intermediateCrossings = 0;
      for (final c in crossings) {
        if (c.s > since && c.s < (t.s - 5.0) && c.side == t.side && c.cls == t.cls) {
          intermediateCrossings++;
        }
      }
      final int n = 1 + intermediateCrossings;
      final bool knownCount = crossings.any((c) => c.side == t.side);

      if (a != null && a.kind == 'traffic_signal' && (t.s - a.s) < 15.0) {
        // Virage précisément au feu tricolore (Confiance 3)
        steps.add(NarrativeStep(
          s: t.s,
          key: 'at_signal_turn',
          params: {'side': t.side},
          confidence: 3,
          anchor: a,
        ));
      } else if (a != null && knownCount) {
        // Ancre + rues intermédiaires comptées (ex: 2e six-mètres après la station)
        steps.add(NarrativeStep(
          s: t.s,
          key: 'after_anchor_turn',
          params: {'n': n, 'cls': t.cls, 'side': t.side},
          confidence: a.confidence,
          anchor: a,
        ));
      } else if (a != null) {
        // Ancre sans comptage intermédiaire fiable
        steps.add(NarrativeStep(
          s: t.s,
          key: 'after_anchor_plain',
          params: {'side': t.side},
          confidence: a.confidence,
          anchor: a,
        ));
      } else if (knownCount) {
        // Comptage pur de rues sans ancre visible
        steps.add(NarrativeStep(
          s: t.s,
          key: 'turn_count',
          params: {'n': n, 'cls': t.cls, 'side': t.side},
          confidence: 2,
        ));
      } else {
        // Dernier recours : distance métrique arrondie
        final rawDist = (t.s - prevS).clamp(0.0, 50000.0);
        final roundedDist = (rawDist / 50.0).round() * 50;
        steps.add(NarrativeStep(
          s: t.s,
          key: 'turn_dist',
          params: {'dist': roundedDist > 0 ? roundedDist : 50, 'side': t.side},
          confidence: 1,
        ));
      }

      prevS = t.s;
    }

    return steps;
  }
}
