# Socle v1 — Rapport de recette et PV de livraison (Candidat)

> **Statut de livraison :** Livré en test — Version candidate (En attente des essais 4G sur route et de la signature du propriétaire)  
> **Date du rapport :** 2 Novembre 2026  
> **Projet :** FASO NAV (`qvgestion_mobile` & `qvgestion-backend`)  
> **Tag Git :** `socle-v1-candidat`  
> **Auteur / Développeur :** Équipe Antigravity / Agentic Pair-Programming  
> **Destinataire / Validateur :** Propriétaire du produit / Responsable Technique  

---

## 1. Tableau des Trajets de Référence T1 à T5 (Attendu contre Obtenu)

Conformément à l'Annexe C des spécifications, les cinq trajets types ont été calculés via le moteur réel Valhalla local (`/api/v1/routes`) :

| N° | Trajet & Itinéraire | Distance attendue | Obtenu Valhalla | Durée estimée | Géométrie & Manœuvres | Particularité testée | Trois points de passage clés vérifiés |
| :---: | :--- | :---: | :---: | :---: | :---: | :--- | :--- |
| **T1** | Somgandé : Phcie de la Paix `[12.3850, -1.5020]` $\to$ Rond-point `[12.3920, -1.4980]` | ~1 km | **2 531 m** | 7 min 56 s (476 s) | 70 points, 7 manœuvres | Quartier connu, voirie secondaire | 1. Rue 14.12<br>2. Église de Somgandé<br>3. Giratoire Somgandé |
| **T2** | Axe Central : Place de la Nation `[12.3685, -1.5271]` $\to$ Rond-Point Nations Unies `[12.3650, -1.5170]` | ~1.5 - 3 km | **1 575 m** | 3 min 11 s (191 s) | 32 points, 6 manœuvres | Axe régulé avec feux tricolores | 1. Av. Kadiogo<br>2. Feu Av. Houari Boumédiène<br>3. RP Nations Unies |
| **T3** | Échangeur : Mairie de Tampouy `[12.4166, -1.5657]` $\to$ Total Échangeur Nord `[12.4105, -1.5585]` | ~1.5 - 3 km | **1 339 m** (1 202 m route + 137 m accès) | 2 min 36 s (156 s) | 19 points, 5 manœuvres | Franchissement d'un pont/échangeur | 1. Av. Mogho Naba<br>2. Bretelle Échangeur Nord<br>3. Dernier tronçon à pied (137 m pointillé) |
| **T4** | Grande Traversée : Héros Nationaux (Ouaga 2000) `[12.3160, -1.5030]` $\to$ CHU Yalgado `[12.3780, -1.5120]` | ~8 km | **10 603 m** | 15 min 12 s (912 s) | 191 points, 13 manœuvres | Traverse 4 arrondissements (Sud $\to$ Nord) | 1. Bd Muammar Kadhafi<br>2. Échangeur Ouaga 2000<br>3. Av. Babanguida |
| **T5** | Suivi Piéton : Grand Marché Rood-Woko `[12.3685, -1.5222]` $\to$ Cathédrale `[12.3645, -1.5245]` | ~500 m | **842 m** | 9 min 25 s (565 s) | 11 points, 5 manœuvres | Marche à pied / sensibilité GPS | 1. Rue du Grand Marché<br>2. Rue de la Chance<br>3. Parvis Cathédrale |

*Note T3 :* Conformément aux règles d'intégrité, le raccordement de 136,7 m entre l'extrémité du réseau bitumé Valhalla et la station en cour est rendu sous forme de **segment d'accès piéton en pointillé vert**, et n'est pas confondu avec le tracé routier.

---

## 2. Résultats des trois recherches d'audit par Grep (Étape 0)

1. **Recherche Mapbox :** `grep -rni "mapbox" lib pubspec.yaml android ios`
   * **Résultat : 0 occurrence.**  
   * **Constat :** Mapbox est totalement absent du code source, des dépendances Flutter et des configurations Android/iOS. L'application utilise exclusivement MapLibre GL Native.
2. **Recherche des blocs Catch silencieux :** `grep -rn "catch" lib | grep -v rethrow`
   * **Résultat : 157 blocs catch répertoriés.**  
   * **Constat :** Chaque bloc catch est instrumenté avec `AppLogger.w` ou `AppErrorReporter.reportError` et met à jour l'état UI (bandeau d'erreur visible, dialogue ou désactivation du bouton). Aucun catch ne retourne de résultat fictif inventé en dehors du mode test.
3. **Recherche des données codées en dur :** `grep -rn "defaultOuagaIconicPlaces\|_destLat\|_destLon\|Simulation" lib`
   * **Résultat :** `_destLat` et `_destLon` = **0 occurrence**.
   * Les méthodes `Simulation` sont strictement verrouillées par `if (!kDebugMode || !_isTestModeActive) return;`.
   * Le catalogue `defaultOuagaIconicPlaces` a été **strictement bridé par `AppConfig.testMode`** : en mode normal (production), aucune donnée simulée n'est retournée ; l'application consomme exclusivement l'API ou le cache SQLite hors-ligne.

---

## 3. Réponses aux quatre points de correction exigés

| Point soulevé | Correction apportée dans le code | Fichiers modifiés |
| :--- | :--- | :--- |
| **1. Tracé complété de force (500 m)** | Le tracé routier de Valhalla n'est plus artificiellement étendu. Si le lieu est situé en retrait de la voirie (5 à 500 m), le backend renvoie un `walking_segment` distinct. L'application mobile trace ce tronçon en **pointillé vert** (`lineDasharray: [2, 2]`), affiche « + X m à pied » sur la fiche, et ne compte pas ce segment pour l'arrivée du véhicule. | `qvgestion-backend/app/services/routing.py`, `route_model.dart`, `map_service.dart`, `home_map_screen.dart` |
| **2. Repli de voix absurde** | Si un fichier audio natif Mooré ou Dioula fait défaut, l'application **ne lit jamais de texte africain avec la synthèse vocale française**. Le bandeau textuel reste affiché dans la langue choisie (Mooré/Dioula), mais le moteur TTS prononce **la consigne équivalente en français clair** (*« Tournez à droite »*). | `voice_guide_service.dart` |
| **3. Audios Mooré et Dioula** | Création d'une fiche officielle de validation linguistique ([`FICHE_VALIDATION_LINGUISTIQUE_MOORE_DIOULA.md`](file:///home/ouedraogo/Bureau/qvgestion_mobile/docs/FICHE_VALIDATION_LINGUISTIQUE_MOORE_DIOULA.md)). Les enregistrements sont identifiés comme « livrés en test » et devront faire l'objet d'une signature formelle par deux locuteurs natifs avant diffusion grand public. | `docs/FICHE_VALIDATION_LINGUISTIQUE_MOORE_DIOULA.md` |
| **4. Source réelle des tuiles & Attribution OSM** | **Source réelle :** Les tuiles sont des tuiles vectorielles servies par **OpenFreeMap** (`https://tiles.openfreemap.org/planet`) au format vectoriel OpenMapTiles. Aucun appel n'est fait à `tile.openstreetmap.org`.<br>**Attribution :** Réactivation permanente du badge interactif **« © OpenStreetMap contributors »** sur la carte et lien direct vers la modale des crédits souverains. | `assets/map/styles/*.json`, `faso_map.dart`, `about_credits_modal.dart` |

---

## 4. Statut honnête des Étapes 9b (Ancres) et 9c (Conducteur Inconnu)

Conformément à l'exigence de vérité technique :

* **Étape 9a (Consignes moteur & Annonceur 200 m / 50 m) :** **FAITE ET VALIDÉE.** L'annonceur pas-à-pas est codé, testé unitairement et réinitialise ses annonces au recalcul.
* **Étape 9b (Narrateur local avec ancres réelles) :** **LIVRÉE EN TEST (Données incomplètes).** Les algorithmes de sélection d'ancres et de scoring (`pickAnchor`, `sideOf`, etc.) sont opérationnels. Cependant, **la base d'ancres réelles OSM de Ouagadougou est encore lacunaire** : les feux tricolores récents et toponymes de plusieurs arrondissements périphériques doivent être cartographiés par l'administration municipale pour atteindre les 80 % de couverture visés.
* **Étape 9c (Test du conducteur inconnu) :** **NON FAITE SUR ROUTE.** La fiche de protocole ([`FICHE_TEST_CONDUCTEUR_ETAPE_9C.md`](file:///home/ouedraogo/Bureau/qvgestion_mobile/docs/FICHE_TEST_CONDUCTEUR_ETAPE_9C.md)) est rédigée, mais **aucun essai physique avec un conducteur inconnu n'a encore été réalisé sur le terrain**. Ce test doit être passé en condition réelle avant toute validation de cette sous-étape.

---

## 5. Synthèse des tests automatiques à date

* **Backend :** **113 tests pytest passés avec succès** (100% de réussite).
* **Mobile :** **186 tests Flutter passés avec succès** (`flutter test` au vert).
* **Analyse statique :** `flutter analyze` : **0 erreur, 0 avertissement**.
* **Tag Git actuel :** `socle-v1-candidat` (remplaçant `socle-v1`).
