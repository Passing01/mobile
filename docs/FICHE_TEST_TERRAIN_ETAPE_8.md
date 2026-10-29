# Fiche de Test Terrain — Étape 8 : Navigation sur le GPS réel (Progression, Sortie de route, Arrivée)

> **Règle absolue de sécurité :** Ne jamais manipuler le téléphone en conduisant. Les essais sur route se font obligatoirement **en passager** (trajet T2) ou **à pied** sur trottoir sécurisé (trajet T5).

---

## 1. Informations de la session d'essai

| Champ | Valeur relevée |
| :--- | :--- |
| **Date et heure** | `____ / ____ / 2026 — ____h____` |
| **Appareil physique testé** | `TECNO KM4 (Android)` |
| **Version de l'application** | `FASO NAV — Étape 8 (AppConfig.testMode = false)` |
| **Opérateur / Passager testeur** | `________________________________________` |
| **Conditions météo / Ciel** | `[ ] Dégagé   [ ] Nuageux   [ ] Pluie` |

---

## 2. Protocole des 4 Essais Terrain (en passager ou à pied)

### Essai A · Marche complète jusqu'à l'arrivée sur T5 (~350 m à pied)
1. Se placer au point de départ de **T5** à ciel ouvert et attendre une précision GPS `<= 20 m`.
2. Choisir la destination de **T5**, calculer l'itinéraire **À pied**, puis appuyer sur **« Démarrer la navigation vocale »**.
3. Vérifier qu'aucun message « Vous êtes arrivé » n'apparaît au départ (`state = navigating`).
4. Marcher le long du tracé jusqu'au bout :
   - Observer la **distance restante** décroître régulièrement (`remaining` diminue à chaque fix `[NAV]`).
   - Observer la **durée restante estimée** et la **vitesse (`km/h`)** se mettre à jour.
5. Vérifier que **« Vous êtes arrivé à destination »** s'affiche et s'annonce vocalement **uniquement dans les 25 derniers mètres** (après `>= 90 %` du parcours, sur 2 points GPS consécutifs).

### Essai B · Sortie de route volontaire sur T2 ou T5 (> 50 m hors tracé)
1. Démarrer la navigation sur **T2** (en passager) ou **T5** (à pied).
2. Prendre volontairement une rue parallèle ou perpendiculaire jusqu'à s'éloigner de **plus de 50 m** du tracé initial pendant au moins 3 secondes (`3 points GPS consécutifs` avec `off > 40 m` et `acc <= 30 m`).
3. Vérifier que :
   - L'état passe à `rerouting` (bandeau *« Sortie de route détectée · Recalcul en cours… »*),
   - Un **nouveau tracé** est calculé depuis la position GPS réelle et remplace l'ancien sur la carte,
   - Aucun recalcul en boucle ne se produit dans les 10 secondes suivantes.

### Essai C · Sortie de route avec données mobiles coupées (Mode hors-ligne)
1. En cours de navigation, **couper les données mobiles / Wi-Fi**.
2. S'écarter de plus de 50 m du tracé sur 3 points consécutifs.
3. Vérifier que :
   - L'application **ne plante pas**,
   - L'ancien tracé reste affiché sur la carte (`onRerouteFailed()` -> retour à `navigating`),
   - Le bandeau d'avertissement *« Recalcul impossible (réseau coupé). Maintien du tracé actuel, nouvel essai dans 10 s. »* est affiché clairement.
4. Réactiver les données mobiles : après 10 s, le nouveau tracé est recalculé automatiquement.

### Essai D · Course avec écran verrouillé pendant 2 minutes (Foreground Service + WakeLock)
1. Démarrer une course sur **T2** ou **T5**, puis **verrouiller l'écran du téléphone** tout en continuant d'avancer pendant **2 minutes**.
2. Vérifier la présence de la notification Android **`FASO NAV — Navigation en cours`**.
3. Déverrouiller l'écran après 2 minutes :
   - La position et la distance restante sont immédiatement à jour,
   - L'export du journal (Console de Debug -> *8. Exporter le journal*) montre des lignes `[GPS]` et `[NAV] along=... remaining=... off=... acc=...` continues pendant les 2 minutes où l'écran était éteint.

---

## 3. Grille des 10 Critères de Validation (Étape 8)

| # | Critère de validation | Attendu | Résultat |
| :-: | :--- | :--- | :-: |
| **1** | **5 tests unitaires obligatoires** | `flutter test test/core/services/navigation_engine_step8_test.dart` -> 100 % PASS | `[x] OK` |
| **2** | **Démarrage refusé si GPS absent ou tracé < 50 m** | Message explicite, refus d'entrer en `activeNavigation` | `[ ] OK  [ ] KO` |
| **3** | **Aucun « Vous êtes arrivé » au départ ni en milieu de parcours** | `NavState.navigating` maintenu tant que `along < 90%` ou `remaining > 25 m` | `[ ] OK  [ ] KO` |
| **4** | **Distance restante décroît régulièrement quand on avance** | Logs `[NAV] along=... remaining=...` et carte UI mis à jour à chaque point GPS | `[ ] OK  [ ] KO` |
| **5** | **Sortie de route (> 40 m sur 3 points) déclenche un recalcul** | Un seul recalcul déclenché, nouveau tracé affiché depuis la position réelle | `[ ] OK  [ ] KO` |
| **6** | **Recalcul hors-ligne échoue proprement** | Ancien tracé conservé + bandeau d'erreur visible + nouvel essai après 10 s | `[ ] OK  [ ] KO` |
| **7** | **Arrivée déclarée uniquement dans les 25 derniers mètres** | `remaining <= 25 m` ET `along >= 90%` sur 2 points consécutifs | `[ ] OK  [ ] KO` |
| **8** | **Navigation active écran verrouillé (2 minutes)** | Notification `FASO NAV` active + WakeLock + logs `[NAV]` continus | `[ ] OK  [ ] KO` |
| **9** | **Bouton « Terminer » ramène proprement à `idle`** | Dialogue de confirmation -> arrêt du moteur et retour à l'exploration | `[ ] OK  [ ] KO` |
| **10** | **Fiche de test terrain remplie et signée** | Présente fiche complétée avec extrait du journal `[NAV]` | `[ ] OK  [ ] KO` |

---

## 4. Extrait du journal `[NAV]` relevé sur téléphone réel

Coller ci-dessous 5 à 10 lignes issues du bouton **« 8. Exporter le journal d'exécution »** de la Console de Debug :

```text
[NAV] along=... remaining=... off=... acc=...
```

**Signature du testeur (passager / piéton) :** `___________________________`

