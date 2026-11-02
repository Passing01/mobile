# Fiche de Test Terrain — Étape 9c : Test du Conducteur Inconnu (Guidage Vocal et Narrateur Local)

> **Règle absolue de sécurité routière :** Le conducteur ne manipule **jamais** son téléphone pendant qu'il roule. Le téléphone est solidement clipsé sur un support guidon (moto) ou support tableau de bord (voiture). Volume réglé à 100 %. L'observateur / évaluateur est assis à l'arrière en passager ou suit à proximité sécurisée.

---

## 1. Informations de la session d'essai

| Champ | Valeur relevée |
| :--- | :--- |
| **Date et heure du test** | `____ / ____ / 2026 — ____h____` |
| **Trajet de test** | `[ ] T1 (Gounghin)   [ ] T2 (Axe Nelson Mandela)   [ ] T3 (Échangeur Est)   [ ] T4 (Grande Traversée)` |
| **Moyen de transport** | `[ ] Moto / Deux-Roues   [ ] Voiture   [ ] À pied (T5)` |
| **Conducteur testeur** | `________________________________________` |
| **Profil de familiarité du conducteur** | `[x] Ne connaît PAS le quartier de destination` |
| **Langue sélectionnée** | `[ ] Français (fr)   [ ] Mooré (mos)   [ ] Dioula (diu)` |
| **Support de fixation utilisé** | `[ ] Support guidon moto   [ ] Support ventouse pare-brise` |

---

## 2. Consigne impérative remise au conducteur avant le départ

> *« Ne regarde jamais l'écran du téléphone pendant que tu roules. Écoute uniquement les indications vocales de FASO NAV. L'application t'annonce les virages à l'avance et utilise les repères réels que tu vois devant toi (feux tricolores, ponts, échangeurs, stations, monuments). Si tu hésites, continue tout droit, l'application recalculera automatiquement si tu sors du tracé. Tu ne dois appeler personne au téléphone pour demander la route. »*

---

## 3. Déroulement du Test et Chronologie

1. **Vérification audio préalable :**
   - Volume multimédia du téléphone monté à 100 %.
   - Dans l'écran de sélection du mode, tester le bouton audio (haut-parleur). Vérifier la clarté et l'audibilité du son dans l'environnement sonore urbain de Ouaga.
2. **Démarrage de la course :**
   - Appui sur *« Démarrer la navigation vocale »*.
   - Consigne de départ énoncée vocalement (`[VOIX] Prenez la route...` / `[VOIX] Rɩk sorã...`).
3. **Pendant le trajet :**
   - Observer à quel moment le conducteur engage son clignotant ou prépare son virage après l'annonce à **200 mètres**.
   - Observer la confirmation du virage à l'annonce rapprochée à **50 mètres** avec le repère visuel immédiat (*« Au feu... »*, *« Après Pont Kadiogo... »*).
4. **En cas d'erreur de trajectoire volontaire ou involontaire :**
   - Chronométrer le temps de détection de sortie de route ($> 40\text{ m}$ sur 3 points GPS consécutifs).
   - Constater l'annonce de recalcul automatique (*« Recalcul de l'itinéraire »*) et la reprise immédiate du guidage depuis la position actuelle.
5. **Arrivée à destination :**
   - Constater l'annonce d'arrivée effective dans les 25 derniers mètres (*« Vous êtes arrivé à destination ! »* / *« Y taame y zĩigẽ ! »*).

---

## 4. Grille d'Évaluation des 6 Critères de Succès de l'Étape 9c

| # | Critère de succès | Résultat attendu | Constat terrain | Statut |
| :-: | :--- | :--- | :--- | :-: |
| **1** | **Arrivée sans hésitation majeure** | Le conducteur parvient à destination du premier coup sans faire demi-tour erratique | `[ ] Réussi   [ ] Échec` | `[ ] OK` |
| **2** | **Zéro manipulation du téléphone** | Le conducteur n'a pas touché l'écran du téléphone une seule fois pendant la course | `[ ] Zéro toucher   [ ] Manipulé` | `[ ] OK` |
| **3** | **Zéro appel d'assistance** | Le conducteur n'a pas appelé un ami ou un habitant pour demander son chemin | `[ ] Aucun appel   [ ] A appelé` | `[ ] OK` |
| **4** | **Compréhension immédiate des repères** | Les repères locaux (feux, ponts, monuments) sont reconnus sans ambiguïté | `[ ] Compris direct  [ ] Confusion` | `[ ] OK` |
| **5** | **Timing des annonces (200m / 50m)** | Déclenchement audible avant le carrefour, permettant d'anticiper la manœuvre | `[ ] Parfait timing  [ ] Trop tard` | `[ ] OK` |
| **6** | **Journalisation `[VOIX]` complète** | Chaque consigne apparaît dans le journal d'exécution avec le préfixe `[VOIX]` | `[ ] Conforme logs   [ ] Absent` | `[ ] OK` |

---

## 5. Dépouillement des Virages et Retours du Conducteur

- **Nombre total de manœuvres sur le parcours :** `____`
- **Nombre de manœuvres réussies du 1er coup :** `____`
- **Taux de réussite manœuvres :** `____ %` (Objectif $\ge 90\,\%$)

### Verbatims et commentaires du conducteur à l'arrivée :
- *Clarté de la voix et du volume sonore :*
  `__________________________________________________________________________________`
- *Utilité des repères locaux familiers par rapport aux mètres :*
  `__________________________________________________________________________________`
- *Compréhension de la langue (Français / Mooré / Dioula) :*
  `__________________________________________________________________________________`

---

## 6. Extrait du Journal `[VOIX]` Relevé sur l'Appareil

Copier ci-dessous les lignes `[VOIX]` extraites depuis la Console de Debug (*8. Exporter le journal*) :

```text
[VOIX] Dans 200 mètres, au feu, tournez à droite
[VOIX] Au feu, tournez à droite
[VOIX] Dans 200 mètres, après Pont Kadjogo, tournez à droite
[VOIX] Après Pont Kadjogo, tournez à droite
[VOIX] Vous êtes arrivé à destination !
```

---

**Signature de l'évaluateur (passager) :** `___________________________`  
**Signature du conducteur testeur :** `___________________________`

