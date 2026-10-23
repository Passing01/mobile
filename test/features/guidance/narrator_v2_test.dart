import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/anchor_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/narrator_v2.dart';

void main() {
  group('NarratorV2 Unit Tests', () {
    test('sideOf calcule correctement la position relative gauche/droite', () {
      // Sens de marche vers le Nord : P0=(0,0) -> P1=(0,1)
      final leftPoint = [-1.0, 0.5];
      final rightPoint = [1.0, 0.5];

      expect(NarratorV2.sideOf([0.0, 0.0], [0.0, 1.0], leftPoint), 'left');
      expect(NarratorV2.sideOf([0.0, 0.0], [0.0, 1.0], rightPoint), 'right');
    });

    test('scoreAnchor attribue 0 en dehors de la fenêtre 15m - 600m pour les repères', () {
      const anchorTooClose = AnchorModel(
        kind: 'place',
        id: '1',
        name: 'Boutique',
        s: 95.0, // distance = 100 - 95 = 5m (< 15m pour un lieu)
      );
      expect(NarratorV2.scoreAnchor(anchorTooClose, 100.0, 'right'), 0.0);

      const anchorTooFar = AnchorModel(
        kind: 'place',
        id: '2',
        name: 'Boutique',
        s: 100.0, // distance = 800 - 100 = 700m (> 600m)
      );
      expect(NarratorV2.scoreAnchor(anchorTooFar, 800.0, 'right'), 0.0);

      // Pour un feu tricolore à 5m avant le virage, le score est valide (> 0)
      const signalClose = AnchorModel(
        kind: 'traffic_signal',
        id: '3',
        name: 'Feu',
        s: 95.0,
      );
      expect(NarratorV2.scoreAnchor(signalClose, 100.0, 'right'), greaterThan(0.0));
    });

    test('scoreAnchor favorise les ancres du même côté avec un bonus de 15%', () {
      const anchorSameSide = AnchorModel(
        kind: 'place',
        id: '1',
        name: 'Station Total',
        s: 200.0,
        side: 'right',
        importance: 4,
        confidence: 3,
      );
      const anchorOppositeSide = AnchorModel(
        kind: 'place',
        id: '2',
        name: 'Pharmacie',
        s: 200.0,
        side: 'left',
        importance: 4,
        confidence: 3,
      );

      final scoreSame = NarratorV2.scoreAnchor(anchorSameSide, 300.0, 'right');
      final scoreOpposite = NarratorV2.scoreAnchor(anchorOppositeSide, 300.0, 'right');

      expect(scoreSame, greaterThan(scoreOpposite));
      expect(scoreSame / scoreOpposite, closeTo(1.15, 0.01));
    });

    test('pickAnchor choisit la meilleure ancre selon la pondération', () {
      final anchors = [
        const AnchorModel(kind: 'place', id: 'p1', name: 'Boutique', s: 200.0, side: 'right'),
        const AnchorModel(kind: 'traffic_signal', id: 's1', name: 'Feu', s: 250.0, side: 'right'),
        const AnchorModel(kind: 'interchange', id: 'i1', name: 'Échangeur du Nord', s: 260.0, side: 'right'),
      ];

      final best = NarratorV2.pickAnchor(anchors, 300.0, 'right');
      expect(best, isNotNull);
      // L'échangeur a le poids le plus élevé (5.0 vs 4.0 vs 3.0)
      expect(best!.kind, 'interchange');
      expect(best.name, 'Échangeur du Nord');
    });

    test('narrate génère at_signal_turn pour un virage situé au feu tricolore', () {
      final turns = [const NavigationTurn(s: 108.0, side: 'left')];
      final anchors = [
        const AnchorModel(kind: 'traffic_signal', id: 'ts1', s: 100.0, side: 'left', confidence: 3),
      ];

      final steps = NarratorV2.narrate(turns: turns, anchors: anchors, crossings: const []);
      expect(steps.length, 1);
      expect(steps.first.key, 'at_signal_turn');
      expect(steps.first.confidence, 3);
      expect(steps.first.render(language: 'fr'), 'Au feu, tournez à gauche');
      expect(steps.first.render(language: 'mos'), 'Feo zĩisẽ, gilli wĩndg-goabga');
      expect(steps.first.render(language: 'diu'), 'Fe la, kɛlɛbili numanya fɛ');
    });

    test('narrate génère after_anchor_turn avec rues comptées (six-mètres)', () {
      final turns = [const NavigationTurn(s: 400.0, side: 'right', cls: 'six_metres')];
      final anchors = [
        const AnchorModel(kind: 'place', id: 'p1', name: 'Station Total', s: 200.0, side: 'right', confidence: 3),
      ];
      final crossings = [
        const RouteCrossing(s: 260.0, side: 'right', cls: 'six_metres'),
        const RouteCrossing(s: 340.0, side: 'right', cls: 'six_metres'),
      ];

      final steps = NarratorV2.narrate(turns: turns, anchors: anchors, crossings: crossings);
      expect(steps.length, 1);
      expect(steps.first.key, 'after_anchor_turn');
      expect(steps.first.params['n'], 3); // 2 croisements intermédiaires + 1
      expect(steps.first.render(language: 'fr'), 'Après Station Total, prenez la 3e six-mètres à droite');
      expect(steps.first.render(language: 'mos'), contains('Station Total poore'));
    });

    test('narrate bascule sur turn_dist quand aucune ancre ni croisement n\'est identifié', () {
      final turns = [const NavigationTurn(s: 350.0, side: 'left')];

      final steps = NarratorV2.narrate(turns: turns, anchors: const [], crossings: const []);
      expect(steps.length, 1);
      expect(steps.first.key, 'turn_dist');
      expect(steps.first.confidence, 1);
      expect(steps.first.render(language: 'fr'), 'Continuez 350 m, puis tournez à gauche');
    });
  });
}
