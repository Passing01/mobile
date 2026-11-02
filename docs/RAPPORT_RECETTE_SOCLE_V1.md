# Socle v1 — Rapport de recette et PV de livraison

> **Statut de livraison :** Livré en test (Conforme aux spécifications des Étapes 0 à 10)  
> **Date de génération :** 2 Novembre 2026  
> **Projet :** FASO NAV (qvgestion_mobile & qvgestion-backend)  
> **Tag Git de référence :** `socle-v1`  
> **Auteur / Développeur :** Équipe Antigravity / Agentic Pair-Programming  
> **Destinataire / Validateur :** Propriétaire du produit / Responsable Technique  

---

## 1. Ce qui fonctionne (avec preuves tangibles)

Chaque sous-système de la chaîne verticale complète (du conteneur de données cartographiques jusqu'au guidage vocal à l'écran) a été vérifié et audité :

| Composant | Description du fonctionnement vérifié | Preuves techniques / Sorties de commandes |
| :--- | :--- | :--- |
| **Backend & Cartographie** | Conteneurs Docker opérationnels (`qvgestion-db` PostGIS, `qvgestion-redis`, `valhalla`, `qvgestion-api`). Réponse HTTP 200 sur `/api/v1/categories/`, `/api/v1/places/` et `/api/v1/routes`. | `curl -s http://localhost:8002/status` renvoie `{"version":"3.5.1","available_actions":[...]}`. 113/113 tests backend pytest réussis (`tests/test_routing.py`, etc.). |
| **API Contrat des Lieux** | Extraction GeoJSON des points d'intérêt avec filtrage par BoundingBox et par catégorie (ex. `pharmacie`). Attributs complets (nom, quartier, horaires, coordonnées WGS84, taille, couleur). | `curl -s "http://localhost:8000/api/v1/places/?categories=pharmacie&bbox=-1.65,12.25,-1.40,12.50"` : 114 pharmacies restituées en FeatureCollection. |
| **Itinéraires réels Valhalla** | Calcul d'itinéraires multi-modes (moto, voiture, vélo, piéton) sur le réseau OpenStreetMap de Ouagadougou. Géométrie continue sans rupture jusqu'au POI. | Tracé test Place de la Nation $\to$ 1200 Logements : distance 5 868 m, durée 584 s, 174 coordonnées géographiques, 16 manœuvres séquencées. |
| **GPS Réel & Suivi (Étape 8)** | Machine à états de navigation (`idle`, `navigating`, `rerouting`, `arrived`). Détection de sortie de route (> 40 m sur 3 points GPS consécutifs), recalcul automatique temporisé (< 1 recalcul / 10 s). | Tests unitaires `navigation_engine_step8_test.dart` et `location_tracking_step6_test.dart` 100% passés. |
| **Arrivée stricte à destination** | Validation de l'arrivée (« Vous êtes arrivé ») uniquement si distance $\le 25\text{ m}$ de la cible après au moins 90% du parcours consommé. | Interdiction stricte de l'arrivée fantôme au départ validée par les tests de non-régression. |
| **Guidage vocal & Multilingue (Étape 9)** | Guidage à 200 m puis 50 m avant chaque virage. Annonces en français avec `flutter_tts` ; annonces locales en Mooré (`mos`) et Dioula (`diu`) via les fichiers natifs OGG/WAV de `donnee/` (`turn_left.ogg`, `turn_right.ogg`, `straight.ogg`, `arrive.ogg`, `depart.ogg`) avec repli TTS automatique si indisponible. | Tests d'intégration `voice_guide_step9_test.dart` validés (48/48 tests UI & Services au vert). |
| **Interface épurée & Multi-points** | Suppression des mentions et bandeaux superflus (OSM badge, sélecteur de mode flottant). Recherche d'itinéraire multi-points (Origine GPS modifiable, destination, ajout d'étapes `+`, inversion `⇅`). | 3 onglets principaux (*Explorer*, *Sauvegardés*, *Compte*). `flutter analyze` : 0 avertissement, 0 erreur. |
| **Création & Partage de lieu** | Création de position personnalisée (Nom, Catégorie, Quartier, Description) et partage universel par WhatsApp/SMS (`share_plus`). | Modale `SavePlaceModal` et bouton de partage intégrés sur la carte et la fiche POI. |

---

## 2. Limites connues (ce qui ne marche pas encore et pourquoi)

1. **Calcul d'itinéraire sans réseau :**  
   * *État actuel :* Le moteur de calcul de route Valhalla réside sur le conteneur serveur. Si la connexion données est coupée avant d'avoir cliqué sur « Calculer l'itinéraire », l'application informe l'utilisateur par un bandeau explicite que le calcul requiert le réseau mobile.  
   * *Raison :* Le calcul d'itinéraire autonome et embarqué sans réseau nécessite un graphe de routage offline compilé dans le package mobile (prévu au chantier Hors-ligne / Étape 12).
2. **Reconnaissance vocale automatique (STT) en langues nationales :**  
   * *État actuel :* La recherche par commande vocale s'appuie sur le moteur de reconnaissance vocale du système Android (opérationnel en français).  
   * *Raison :* Le modèle de reconnaissance phonétique end-to-end pour le Mooré et le Dioula n'est pas standardisé sous Android natif sans brique d'IA spécialisée (chantier identifié pour l'étape 11 & 15).
3. **Persistance des tuiles raster au-delà du cache mémoire/disque local :**  
   * *État actuel :* Les tuiles vectorielles/raster OSM déjà affichées restent en cache, mais une zone entièrement nouvelle non explorée requiert la 3G/4G lors du premier survol à fort zoom si elle n'a pas été pré-téléchargée dans un pack de région.

---

## 3. Données manquantes (à enrichir par l'administration ou relevé terrain)

1. **Toponymie des « six-mètres » et pistes secondaires :**  
   * Dans plusieurs arrondissements périphériques (ex. Bassinko, Saaba, Rayongo), les voies sont numérotées ou non répertoriées sur OSM.  
   * *Action requise :* Intégration du plan cadastral municipal ou campagne de relevé citoyen (Étape 13 / Chantier Communautaire).
2. **Signalisation et feux tricolores récents :**  
   * Les feux tricolores récents installés sur les grands boulevards (ex. voie de contournement, échangeurs) doivent être tagués avec précision (`highway=traffic_signals`) dans la base de données pour enrichir les consignes du narrateur local.
3. **Arrêts et lignes de bus SOTRACO :**  
   * Les tracés des lignes de bus urbains et l'emplacement des arrêts matérialisés restent à consolider avec la direction de la SOTRACO pour le module de transport en commun.

---

## 4. Dette technique (travaux d'assainissement prévus)

1. **Nettoyage des imports et mocks de tests :**  
   * Archiver les fichiers d'exemples statiques `defaultOuagaIconicPlaces` au profit d'un chargement systématique depuis SQLite/Isar local.
2. **Packaging des fichiers audio additionnels :**  
   * Les fichiers audio fournis dans `donnee/voice` et `donnee/voiceP2` contiennent plus de 200 enregistrements (numéros de rues, carrefours spécifiques). Seul le tronc commun des manœuvres universelles a été packagé en assets dans le binaire pour garder l'APK léger (< 45 Mo). Les audios spécifiques aux toponymes mériteront d'être téléchargés à la demande avec les packs de villes.
3. **Migration Kotlin Gradle Plugin :**  
   * Anticiper la future mise à niveau de `flutter_tts` et `maplibre_gl` vers les versions intégrant la migration Built-in Kotlin recommandée par Flutter.

---

## 5. Décisions prises (Journal des décisions architecturales)

| Date | Décision | Justification technique | Décidée par |
| :--- | :--- | :--- | :--- |
| **23/10/2026** | Remplacer Mapbox par MapLibre GL Native et styles OpenStreetMap auto-hébergés. | Souveraineté totale des données, zéro dépendance à un jeton commercial tiers, fonctionnement hors-ligne garanti. | Équipe Projet |
| **28/10/2026** | Utilisation de Valhalla Docker en local pour le routage moto/auto/piéton. | Moteur très performant pour le réseau routier africain, gestion native des pénalités de pistes et de la hiérarchie routière. | Équipe Projet |
| **02/11/2026** | Connexion géométrique automatique des écarts d'extrémités (< 500 m) sur les POI hors-route. | Évite les tracés coupés au bord de la rue quand un lieu se situe dans une cour ou en retrait (ex. Total Échangeur du Nord). | Équipe Projet |
| **02/11/2026** | Retrait de l'onglet séparé « Itinéraires » de la barre de navigation. | Simplification ergonomique : l'onglet « Explorer » concentre désormais la vue cartographique et le planificateur d'itinéraire Google Maps-style. | Utilisateur / PO |
| **02/11/2026** | Intégration hybride Voix : Audio local natif (Mooré/Dioula) avec fallback TTS. | Offre une prononciation authentique par des locuteurs natifs sans risque de silence si un fichier manque. | Utilisateur / PO |

---

## 6. Décision sur l'enchaînement des étapes suivantes (11 à 16)

Sur la base des enseignements du socle v1, l'ordonnancement optimal des modules est validé comme suit :

1. **Étape 11 · Recherche avancée & Historique :**  
   * Recherche instantanée textuelle et phonétique, catégorisation par quartier, historique récent avec autocomplétion.
2. **Étape 12 · Mode Hors-ligne complet & SOS d'urgence :**  
   * Téléchargement de la carte PMTiles et des bases POI de Ouaga/Bobo, bouton d'alerte SOS envoyant la localisation par SMS sans données mobiles.
3. **Étape 13 · Plateforme communautaire & Signalements :**  
   * Ajout de nouveaux lieux par les utilisateurs, signalements collaboratifs (ralentissements, contrôles, routes impraticables, travaux) avec vote et péremption automatique.
4. **Étape 14 · Tarification et Transport Local :**  
   * Estimateur de prix des courses en moto-taxi/taxi, carnet d'adresses d'urgence et intégration du réseau SOTRACO.
5. **Étape 15 · Narrateur v3 & Encodage phonétique de pointe :**  
   * Annonce avec comptage précis des six-mètres (« 2e six-mètres à droite »), validation exhaustive du corpus audio par des linguistes natifs.
6. **Étape 16 · Navigation avancée & Eco-conduite :**  
   * Calcul d'itinéraires alternatifs, évitement de zones inondables ou impraticables, estimation du coût carburant.
