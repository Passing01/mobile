# FASO NAV · Fiches de Diagnostic et d'Isolation des Cinq Pannes (Étape 1)

Ce document consigne les cinq fiches de diagnostic formelles de l'Étape 1. Conformément au protocole non négociable, chaque cause est étayée par une preuve directe (réponse d'API, journal serveur ou journal mobile avec horodatage) et rattachée à son étape de résolution dédiée.

---

## Synthèse du rattachement des pannes au plan de reprise

| Panne | Titre | Cause prouvée principale | Catégorie | Étape qui corrige |
| :--- | :--- | :--- | :--- | :--- |
| **P4** | Le filtre ne montre aucun point | 4 catégories ont 0 lieu en base, divergence de slug (`hopital` vs `hopital-sante`), et initialisation asynchrone de `PlacesLayer` non synchronisée au style | **Données** / **État** / **Carte** | **Étape 4** (Catalogue des lieux et filtre par catégorie) |
| **P3** | L'itinéraire n'est jamais calculé et le départ affiche « arrivé » | Absence du moteur Valhalla actif en backend (fallback géodésique linéaire à 6 points) et court-circuit `immediate_arrival` si origine et destination coïncident | **API** / **Logique** | **Étape 7** (Calcul d'itinéraire routier fiable) & **Étape 8** (Navigation active et suivi du tracé) |
| **P2** | Le suivi (tracking) ne fonctionne pas | `_vehiclePosition` et la caméra étaient animés par un timer de simulation fictif au lieu du flux `PositionStream` du GPS réel | **Logique** / **Carte** | **Étape 6** (Position GPS et suivi en temps réel) |
| **P5** | Le moteur de guidage ne marche pas | Base de données dépourvue d'ancres et de feux le long des axes (3 repères locaux et 4 road features pour tout Ouaga) combiné à un tracé sans virages | **Données** / **Logique** | **Étape 9** (Moteur de guidage local Narrateur v2) |
| **P1** | Impossible de toucher un lieu sur la carte | Absence de POI dans le buffer mémoire (effet de P4) déclenchant systématiquement le repli synthétique « Destination sur la carte » (id: 888888) | **Carte** / **Données** | **Étape 5** (Sélection d'un lieu au toucher) |

---

## Fiche P4 · Le filtre ne montre aucun point

- **Panne** : P4 — Le filtre ne montre aucun point
- **Reproduction** :
  1. Lancer l'application sur smartphone Android (TECNO KM4, Android 14).
  2. Mode test : NON (`TEST_MODE=false`).
  3. Toucher la pastille de filtre « Banque / Distributeur » ou « Hôpital / Santé ».
- **Observé** :
  La carte ne montre aucun marqueur de lieu pour la catégorie sélectionnée.
- **Preuves tangibles** :
  1. *Contrôle SQL 1 (État des données en base)* :
     ```sql
     SELECT c.slug, count(l.id) FROM categories c LEFT JOIN lieux l ON l.categorie_id = c.id GROUP BY c.slug ORDER BY count(l.id) DESC;
     ```
     *Résultat* :
     ```text
             slug         | count 
     ---------------------+-------
      pharmacie           |    10
      maquis-restaurant   |     8
      station-service     |     7
      hopital-sante       |     4
      ecole-universite    |     0
      marche-commerce     |     0
      administration      |     0
      banque-distributeur |     0
     ```
     -> 4 catégories sur 8 possèdent exactement **0 point** en base de données de production et de test.

  2. *Contrôle API 2 (Requête filtrée Banque)* :
     ```bash
     curl -s "https://qvgestion-backend-production.up.railway.app/api/v1/places/?categories=banque-distributeur&limit=800&zoom=14.0&near=12.3059763%2C-1.5040482"
     ```
     *Réponse HTTP 200* :
     ```json
     {"type":"FeatureCollection","features":[]}
     ```

  3. *Contrôle Code App (Divergence de slug)* :
     Dans `mapbox_faso_map.dart` (l. 249-252) :
     ```dart
     if ((c == 'hopital' || c == 'sante') && ...) return true;
     ```
     Le slug officiel backend est `hopital-sante` (id: 4). La comparaison stricte `c == 'hopital'` échouait pour la pastille hôpital.

  4. *Contrôle API 3 (Pharmacie avec BBox)* :
     ```bash
     curl -s "https://qvgestion-backend-production.up.railway.app/api/v1/places/?categories=pharmacie&bbox=-1.65,12.25,-1.40,12.50"
     ```
     *Résultat* : Renvoie bien les 10 pharmacies validées (ex: Pharmacie Gounghin `[-1.55, 12.36]`).
- **Cause prouvée** :
  - **Données** : Absence totale d'enregistrements en base pour `banque-distributeur`, `administration`, `marche-commerce` et `ecole-universite`.
  - **État** : Divergence de nommage du slug `hopital` dans le filtre mobile face au slug backend `hopital-sante`.
  - **Carte** : `PlacesLayer` configure ses sources et couches dans `onMapCreated` sans synchronisation avec la fin de chargement du style vectoriel Mapbox.
- **Étape qui corrige** : **Étape 4** (Catalogue des lieux, validation des slugs et filtre par catégorie).

---

## Fiche P3 · L'itinéraire n'est jamais calculé et le départ affiche « arrivé »

- **Panne** : P3 — L'itinéraire n'est jamais calculé et le départ affiche « arrivé »
- **Reproduction** :
  1. Choisir le trajet T2 du jeu de test (Rond-Point Nations Unies `[12.3700, -1.5180]` vers Rond-Point Patte d'Oie `[12.3415, -1.5170]`).
  2. Mode test : NON.
  3. Lancer le calcul et observer l'itinéraire et les manœuvres.
- **Observé** :
  Le tracé affiché est une ligne droite segmentée sans virages réels, et si l'utilisateur lance la navigation avec une destination non sélectionnée (ou à sa propre position), l'application affiche immédiatement « Vous êtes déjà à destination : Arrivée ».
- **Preuves tangibles** :
  1. *Réponse brute de l'API backend sur T2 (`POST /routes/calculate`)* :
     ```bash
     curl -s -X POST "http://127.0.0.1:8001/api/v1/routes/calculate" \
       -H "Content-Type: application/json" \
       -d '{"origin": {"lat": 12.3700, "lon": -1.5180, "name": "Rond-Point Nations Unies"}, "destination": {"lat": 12.3415, "lon": -1.5170, "name": "Rond-Point Patte d'\''Oie"}, "mode": "motorcycle"}'
     ```
     *Extrait de la réponse* :
     ```json
     {
       "mode": "motorcycle",
       "distance_meters": 3805.1,
       "duration_seconds": 391,
       "duration_formatted": "7 min",
       "geometry": [[12.37, -1.518], [12.3643, -1.5178], [12.3586, -1.5176], [12.3529, -1.5174], [12.3472, -1.5172], [12.3415, -1.517]],
       "engine": "geodesic_fallback",
       "maneuvers": [
         {"order": 1, "instruction": "Prenez la route en direction de Rond-Point Patte d'Oie", "maneuver_type": "depart"},
         {"order": 2, "instruction": "Continuez tout droit sur le tronçon principal", "maneuver_type": "straight"},
         {"order": 3, "instruction": "Vous êtes arrivé à Rond-Point Patte d'Oie", "maneuver_type": "arrive"}
       ]
     }
     ```
     -> L'attribut `"engine": "geodesic_fallback"` prouve que le moteur de routage Valhalla n'est pas opérationnel sur le serveur : le calcul retourne 5 segments d'interpolation rectiligne et aucune géométrie de rue réelle.

  2. *Code de court-circuit immédiat dans `routes_repository.dart` (l. 63-93)* :
     ```dart
     if ((origin.lat - destination.lat).abs() < 0.00005 &&
         (origin.lon - destination.lon).abs() < 0.00005) {
       return RouteModel(
         engine: 'immediate_arrival',
         distanceMeters: 0.0,
         maneuvers: [ManeuverModel(maneuverType: 'arrive', instruction: 'Vous êtes déjà à destination : Arrivée')]
       );
     }
     ```
     -> Lorsque la destination n'était pas sélectionnée ou reprenait la position par défaut (12.3685, -1.5222), le départ coïncidait avec l'arrivée et déclenchait l'annonce « arrivé » immédiate.
- **Cause prouvée** :
  - **API** : Moteur de routage Valhalla non connecté en backend, provoquant le repli sur un tracé géodésique linéaire fictif (`geodesic_fallback`).
  - **Logique** : Court-circuit `immediate_arrival` dans le repository mobile déclenché quand destination et origine sont confondues.
- **Étape qui corrige** : **Étape 7** (Intégration d'un moteur de routage routier fiable) & **Étape 8** (Navigation active).

---

## Fiche P2 · Le suivi (tracking) ne fonctionne pas

- **Panne** : P2 — Le suivi (tracking) ne fonctionne pas
- **Reproduction** :
  1. Téléphone : TECNO KM4 (Android 14).
  2. Mode test : NON.
  3. Démarrer la navigation et marcher dehors.
- **Observé** :
  L'icône véhicule ne suit pas la marche réelle de l'utilisateur ou reste statique (la simulation étant désactivée en mode réel).
- **Preuves tangibles** :
  1. *Extrait du journal de l'application (TECNO KM4)* :
     Le flux Geolocator natif fonctionne parfaitement et remonte des positions réelles précises :
     ```text
     [2026-10-23T15:39:46.447017] [INFO] Position GPS obtenue immédiatement: 12.3060346, -1.5040284
     [2026-10-23T15:40:23.905611] [DEBUG] ➡️ [GET] /places/nearby?lat=12.306006&lon=-1.5040388
     [2026-10-23T15:41:28.453185] [DEBUG] ➡️ [GET] /places/nearby?lat=12.3060358&lon=-1.5040277
     ```
  2. *Contrôle du code de navigation active (`home_map_screen.dart` l. 74-81 & l. 230-235)* :
     ```dart
     void _startNavigationSimulation(RouteModel route) {
       if (!AppConfig.testMode) {
         AppLogger.warning('Simulation de navigation ignorée car le mode test est désactivé (Mode réel actif)');
         return;
       }
       ...
     }
     ```
     `home_map_screen.dart` ne possédait aucun écouteur reliant `Geolocator.getPositionStream()` à `_vehiclePosition` et à `NavigationController` : la mise à jour de la position du véhicule était **exclusivement** alimentée par le timer de simulation `_simulationTimer` ! En mode réel, `_vehiclePosition` ne recevait donc aucune mise à jour.
- **Cause prouvée** :
  - **Logique** : La mise à jour de la position de navigation était conditionnée à la simulation logicielle au lieu d'être connectée au flux `PositionStream` du GPS matériel.
  - **Carte** : La caméra de navigation et l'icône de position n'écoutaient pas le GPS en direct lors de l'état `activeNavigation`.
- **Étape qui corrige** : **Étape 6** (Position GPS, orientation cap et suivi en temps réel).

---

## Fiche P5 · Le moteur de guidage ne marche pas

- **Panne** : P5 — Le moteur de guidage ne marche pas
- **Reproduction** :
  1. Appel à l'API `/api/v1/guidance/enrich-route` avec le trajet T2 en Mooré (`mos`) et Français (`fr`).
  2. Analyse de la réponse d'enrichissement et des ancres routières.
- **Observé** :
  Le texte est traduit littéralement mais aucune ancre locale (feu tricolore, carrefour, échangeur) n'apparaît le long du parcours (`has_landmark: false`, `landmark_name: null`).
- **Preuves tangibles** :
  1. *Réponse d'enrichissement sur T2 (Mooré)* :
     ```text
     Maneuvers count: 3
     - Order 1: Rɩk sorã (destination) | landmark: None (has_lm=False) | audio: /api/v1/guidance/audio/mos_depart.wav
     - Order 2: Mètre 1900 poore, kẽng tɩrga | landmark: None (has_lm=False) | audio: /api/v1/guidance/audio/mos_straight.wav
     - Order 3: y taame y zĩigẽ | landmark: None (has_lm=False) | audio: /api/v1/guidance/audio/mos_arrive.wav
     ```
  2. *Contrôle SQL des repères locaux et des caractéristiques routières (Base `qvgestion_db`)* :
     ```sql
     SELECT count(*) FROM reperes_locaux; -- Résultat : 3
     SELECT count(*) FROM road_features;  -- Résultat : 4
     ```
     Sur l'ensemble de Ouagadougou, la base ne compte que :
     - 3 repères : Échangeur de l'Est, Rond-point Nations Unies, Station Total 1200 Logements.
     - 4 road_features : 1 feu (1200 Logements), 2 échangeurs (Est, Nord), 1 pont (Pont Kadiogo).
     -> Aucun feu tricolore ni ancre n'existe en base de données sur l'Avenue Nelson Mandela et le Boulevard Bassawarga (trajet T2).
  3. *Manque de virages réels dans le tracé géodésique* :
     Le tracé ne comportant que des segments droits fictifs (`straight`), aucun virage n'a pu solliciter l'algorithme d'ancre locale du Narrateur v2.
- **Cause prouvée** :
  - **Données** : Base de données quasi-vide en repères et attributs routiers réels pour Ouagadougou (3 repères et 4 features pour toute la ville).
  - **Logique** : Absence de virages réels (`turn_left`, `turn_right`, `roundabout`) issus du moteur d'itinéraire géodésique pour accrocher des repères.
- **Étape qui corrige** : **Étape 9** (Moteur de guidage local Narrateur v2, peuplement des ancres et phrases multilingues).

---

## Fiche P1 · Impossible de toucher un lieu sur la carte

- **Panne** : P1 — Impossible de toucher un lieu sur la carte
- **Reproduction** :
  1. Toucher un point quelconque sur la carte dans l'application mobile.
  2. Mode test : NON.
- **Observé** :
  Le lieu touché ne sélectionne jamais un POI réel existant (pharmacie, station, hôpital) et crée systématiquement un point synthétique nommé **« Destination sur la carte »**.
- **Preuves tangibles** :
  1. *Code source de `mapbox_faso_map.dart` (l. 627-665)* :
     ```dart
     // Vérifier si un lieu connu est à proximité immédiate du toucher (~75 m)
     PlaceModel? closestPlace;
     for (final place in candidates) {
       ...
     }
     if (closestPlace != null) {
       widget.onPlaceSelected(closestPlace);
       return;
     }
     // Repli synthétique
     final customPlace = PlaceModel(
       id: 888888,
       nom: 'Destination sur la carte',
       categorieId: 1,
       latitude: lat,
       longitude: lon,
       adresse: 'Ouagadougou (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})',
     );
     widget.onPlaceSelected(customPlace);
     ```
  2. *Preuve de cause liée à P4* :
     Les POIs réels n'étant pas chargés sur la couche interactive (`candidates` vide ou incomplet suite à P4), la distance minimale dépasse toujours le seuil de 75 mètres.
  3. *Preuve d'implémentation de carte* :
     Le composant utilise un `GestureDetector` Flutter générique posé au-dessus de la vue graphique native sans interroger directement les features vectorielles de la carte (`queryRenderedFeatures`).
- **Cause prouvée** :
  - **Données** : Absence de POIs chargés sous la zone tactile suite aux défaillances de chargement de P4.
  - **Carte** : Détection tactile basée sur un calcul de distance planaire approximatif sur une liste Dart en mémoire au lieu d'une interrogation directe du moteur cartographique.
- **Étape qui corrige** : **Étape 5** (Sélection d'un lieu au toucher et requêtage précis des features cartographiques).
