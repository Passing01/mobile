# Étude de Faisabilité & Plan Directeur d'Architecture
# Carte 3D Ultra-Réaliste du Burkina Faso & Navigation « Vue Radar Live »

> **Projet** : QVGestion / FASO NAV (`qvgestion_mobile` + `qvgestion-backend`)  
> **Date** : 20 novembre 2026  
> **Statut** : Étude technique de faisabilité & feuille de route d'implémentation  
> **Objectif** : Évaluer la faisabilité, les prérequis techniques, la fluidité réelle sur mobile et dresser un plan par phases pour proposer un nouveau mode de carte 3D réaliste du Burkina Faso (style Apple Maps DCE) couplé à une vue de guidage immersif « façon radar de voiture autonome » (style Tesla FSD).

---

## 1. Verdict Exécutif : Est-ce possible ?

**Oui, c'est techniquement réalisable dans votre application Flutter actuelle**, à condition d'adopter une **architecture hybride intelligente** et de distinguer clairement **ce qui doit être vrai 3D / données géospatiales** de **ce qui relève d'une reconstruction synthétique (jumeau numérique)** plutôt que de la vidéo caméra ou de la photogrammétrie lourde.

### Les deux réalités techniques à bien cadrer

| Volet visé | Ce qui serait irréaliste (à éviter) | L'approche gagnante & 100 % faisable |
|---|---|---|
| **1. Carte 3D ultra-réaliste de tout le Burkina Faso** *(bâtiments, monuments, échangeurs)* | Modéliser ou scanner en photogrammétrie haute résolution les 274 200 km² du pays (poids de plusieurs téraoctets, besoin de survols aériens complets, impossible à faire tourner sur un smartphone standard). | **Rendu 3D Hybride (Procédural + Modèles Héros)** :<br>• **Tout le pays** : relief terrain (DEM 30 m) + empreintes et hauteurs réelles de tous les bâtiments (Overture Maps + Google Open Buildings + OSM) extrudés en 3D avec ombrage.<br>• **Lieux emblématiques & échangeurs** : modèles 3D détaillés sur mesure (`.glb` PBR optimisés) pour les monuments, ronds-points majeurs, ponts et échangeurs du Burkina. |
| **2. Itinéraire « comme ses yeux voient / radar de voiture autonome »** | Utiliser la caméra du smartphone pour détecter par IA temps réel toutes les voitures, piétons et lignes de la route à 360° (le téléphone n'a pas de vue 360°, surchauffe rapidement au soleil à 40 °C, vide la batterie et échoue la nuit ou sous l'harmattan). | **Jumeau Numérique Temps Réel (« Vue Radar / Cockpit Live »)** :<br>Une scène 3D à 60 FPS centrée sur le véhicule (moto, voiture, vélo ou piéton) qui reconstruit **la route, les voies, les bâtiments proches, les obstacles (`RoadFeature`), les repères (`RepereLocal`), la trajectoire lumineuse, les ondes radar et le trafic des autres usagers en temps réel via WebSocket**. |

---

## 2. État de l'Existant dans QVGestion / FASO NAV (Vos Atouts Déjà en Place)

L'audit du dépôt actuel montre que vous partez avec une **très bonne longueur d'avance**. Plusieurs briques critiques existent déjà :

### Côté Mobile (`qvgestion_mobile`)
- **Moteur cartographique isolé** : l'interface abstraite [`MapService`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/services/map_service.dart#L15-L56) et son implémentation [`MapLibreMapService`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/services/map_service.dart#L59) utilisent `maplibre_gl: 0.26.2` ([pubspec.yaml](file:///home/ouedraogo/Bureau/qvgestion_mobile/pubspec.yaml#L49)). Cette abstraction permet d'ajouter un nouveau moteur ou un nouveau mode de vue sans casser les écrans métier.
- **Sélection multi-styles déjà active** : [`MapConfig`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/config/map_config.dart#L6-L64) et [`HomeMapScreen`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/features/map/presentation/screens/home_map_screen.dart#L1433-L1466) gèrent déjà le basculement entre **Clair**, **Sombre** et **Satellite**.
- **Caméra inclinée amorcée** : [`NavigationController`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/features/navigation/controllers/navigation_controller.dart#L156-L158) anime déjà la caméra avec `bearing` et `tilt: 50.0`.
- **Moteur de projection locale précis** : [`RouteGeometry`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/services/navigation_engine.dart#L18-L108) et [`NavigationEngine`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/services/navigation_engine.dart#L133) projettent déjà le GPS sur le tracé en mètres avec détection de sortie de route.
- **Styles actuellement en 2D plate** : dans [faso-light.json](file:///home/ouedraogo/Bureau/qvgestion_mobile/assets/map/styles/faso-light.json#L277-L287) et [faso-dark.json](file:///home/ouedraogo/Bureau/qvgestion_mobile/assets/map/styles/faso-dark.json#L277-L285), la couche `building` est configurée en `"type": "fill"` (plat), et en `"type": "line"` dans [faso-satellite.json](file:///home/ouedraogo/Bureau/qvgestion_mobile/assets/map/styles/faso-satellite.json#L216-L224). Le terrain DEM et les modèles 3D `.glb` ne sont pas encore activés.

### Côté Backend (`qvgestion-backend`)
- **Import Overture Maps amorcé** : [`overture_import.py`](file:///home/ouedraogo/Bureau/qvgestion-backend/app/services/overture_import.py) montre une capacité d'ingestion des jeux de données **Overture Maps** (qui incluent précisément les empreintes et hauteurs de bâtiments).
- **Objets routiers structurés** : [`RoadFeature`](file:///home/ouedraogo/Bureau/qvgestion-backend/app/models/road_feature.py#L18-L47) modélise déjà exactement ce dont la vue « Radar » a besoin : `traffic_signal` (feux), `interchange` (échangeurs), `bridge` (ponts), `roundabout` (ronds-points), `level_crossing`, `speed_bump` (ralentisseurs), `toll` (péages), `checkpoint`, ainsi que [`RoadLocalAttr`](file:///home/ouedraogo/Bureau/qvgestion-backend/app/models/road_feature.py#L77-L89) (`local_class`, `surface`: goudron, pavé, latérite, sable).
- **Repères locaux multilingues** : [`RepereLocal`](file:///home/ouedraogo/Bureau/qvgestion-backend/app/models/guidance.py#L8-L58) contient les monuments et repères de quartier (français, mooré, dioula) avec rayon de visibilité et importance (`1..5`).
- **Télémétrie trafic temps réel** : [`TrafficService`](file:///home/ouedraogo/Bureau/qvgestion-backend/app/services/traffic_service.py#L14-L101) gère déjà les pings GPS, le calcul de congestion et un `ConnectionManager` WebSocket.

---

## 3. Tous les Éléments qui Entrent en Jeu

Pour passer de la carte actuelle à l'expérience 3D + Radar Live, **5 couches techniques** travaillent ensemble :

### 3.1. Couche Données Géospatiales 3D (Couverture nationale Burkina Faso)
1. **Empreintes et hauteurs de bâtiments (tout le pays)** :
   - Fusion de **OpenStreetMap** + **Overture Maps Buildings** + **Google Open Buildings** (excellente couverture en Afrique de l'Ouest, y compris zones non cartographiées sur OSM : périphéries de Ouaga, Bobo, Koudougou, Kaya, Ouahigouya, Banfora, etc.).
   - Estimation automatique des hauteurs lorsqu'elles manquent (`num_floors`, superficie au sol, type de zone : résidentiel 3–4 m, commercial 6–12 m, administratif/immeuble 15–45 m).
2. **Modèle Numérique de Terrain (DEM — Relief)** :
   - Tuiles d'élévation **Copernicus DEM 30 m** ou **SRTM** encodées en *Terrain-RGB* / *Terrarium* pour restituer le relief réel (ex. falaises de Banfora, pics de Sindou, collines de Bobo-Dioulasso, vallées et barrages).
3. **Réseau routier enrichi pour la vue « Radar »** :
   - Nombre de voies (`lanes`), sens de circulation (`oneway`), largeur estimée, type de revêtement (`RoadLocalAttr.surface` : goudron, latérite, pavé), ponts/tunnels (`layer`, `bridge`, `tunnel`) indispensables pour dessiner correctement les **échangeurs sur plusieurs niveaux**.
4. **Catalogue de Monuments & Échangeurs « Héros » (Modèles 3D `.glb`)** :
   - Modèles low-poly texturés PBR (Physically Based Rendering), avec niveaux de détail (LOD), géoréférencés (lat, lon, altitude, orientation/azimut, échelle) :
     - **Ouagadougou** : Échangeur du Nord, Échangeur de l'Est, Échangeur de Ouaga 2000, Monument des Martyrs, Place de la Nation, Mémorial Thomas Sankara, Grande Mosquée, Cathédrale, Palais des Sports, SIAO, BCEAO / Immeubles du Centre-ville, Aéroport, Barrage n°1–3.
     - **Bobo-Dioulasso** : Vieille Mosquée de Dioulassoba, Place Tiéfo Amoro, Gare Sitarail, Cathédrale Notre-Dame de Lourdes, Rond-point du Cinquantenaire.
     - **Autres villes & sites majeurs** : Cathédrale / Place de Koudougou, Cascades & Dômes de Fabédougou / Banfora, Grande Mosquée de Dori, etc.
5. **Bibliothèque de Mobilier Urbain 3D générique** :
   - Feux tricolores, dos-d'âne, barrières de péage, poteaux/pylônes, stations-service, arbres locaux (manguiers, karités, baobabs, neems) instanciés automatiquement à partir de `RoadFeature` et OSM.

### 3.2. Couche Moteur de Rendu Mobile (Comparatif d'Architecture)

Le plugin Flutter actuel `maplibre_gl: 0.26.2` permet l'extrusion `fill-extrusion` des bâtiments, **mais** il ne permet pas facilement côté Dart d'injecter des dizaines de modèles `.glb` PBR, des ombres dynamiques, ni des shaders « radar/néon Tesla » fluides.

Voici les **4 options d'architecture** comparées objectivement :

| Option | Principe | Fidélité « Apple Maps 3D » | Fidélité « Radar Tesla » | Fluidité sur mobile local (3–4 Go RAM) | Coût & Souveraineté | Verdict |
|---|---|---|---|---|---|---|
| **A. MapLibre seul (`fill-extrusion`)** | Juste activer l'extrusion 3D dans les JSON MapLibre actuels. | Moyenne (blocs gris/beiges, pas de monuments `.glb` ni échangeurs 3D complexes). | Faible (tracé ligne 2D sur carte inclinée). | Excellente (60 FPS). | 100 % gratuit & souverain. | **Bon pour Phase 0 (immédiat), insuffisant pour la cible finale.** |
| **B. Mapbox Maps SDK v11 (Standard Style)** | Utiliser le SDK Mapbox commercial 3D. | Très bonne (Standard 3D + éclairage dynamique). | Moyenne (pas de vue radar véhicules/voies type Tesla). | Très bonne (60 FPS). | **Payant** à l'usage (MAU / tuiles), dépendance propriétaire. | Déconseillé pour la souveraineté et les coûts à grande échelle. |
| **C. WebView (`MapLibre GL JS` + `Three.js`)** | Embarquer une carte WebGL dans `flutter_inappwebview`. | Très bonne (monuments `.glb`, ciel, brouillard, DEM). | Bonne (shaders radar faciles en Three.js). | **Moyenne à faible** sur Tecno/Infinix/Redmi 3 Go RAM (surconsommation RAM WebView + chauffe GPU). | 100 % gratuit & souverain. | Utile en **prototype rapide (PoC)**, risqué en production nationale. |
| **D. Architecture Hybride Native : MapLibre Native + Scène 3D Google Filament (`thermion_flutter` / Natif C++)** | **Vue Explore 3D** : MapLibre Native (tuiles vectorielles + DEM + `fill-extrusion` + Custom Native Layer pour monuments `.glb`).<br>**Vue Radar Live** : Moteur 3D natif PBR **Google Filament** (ou Flutter GPU / Custom OpenGL/Metal) rendu sur un rayon local de 500 m. | **Excellente** (bâtiments + relief + monuments `.glb` PBR). | **Excellente** (exactement l'effet Tesla : ego-véhicule, voies, ruban lumineux, ondes radar, trafic live). | **Optimale (60 FPS natifs)**, faible empreinte RAM, conçu par Google pour Android/iOS. | **100 % gratuit, open-source & souverain.** | **Architecture Recommandée.** |

> **Pourquoi Google Filament (exposé en Flutter via `thermion_flutter` ou bridge natif Android/iOS) excelle pour la « Vue Radar » ?**  
> Pendant le guidage actif façon Tesla, l'utilisateur ne regarde pas tout le Burkina Faso : il regarde **les 400 à 600 mètres devant lui**. En alimentant un moteur 3D PBR ultra-léger (Filament) uniquement avec les routes, voies, bâtiments extrudés, monuments et incidents de cette fenêtre locale, le GPU dessine moins de 150 000 triangles en quelques *draw calls* — garantissant un rendu type jeu vidéo / voiture autonome à **60 FPS stables**.

### 3.3. Couche Capteurs & Fusion de Localisation (Le Secret de la Fluidité perçue)
Un GPS smartphone standard délivre une position **1 fois par seconde (1 Hz)** avec une imprécision de 5 à 15 mètres. Si la vue 3D ne bouge qu'à chaque point GPS, **elle saccadera à 1 FPS** même si l'écran tourne à 60 Hz.

Il faut donc un **Pipeline d'Interpolation & Dead Reckoning à 60 Hz** :
1. **Entrées capteurs** : GPS (`geolocator`) + **IMU** (`sensors_plus` : gyroscope, accéléromètre, magnétomètre / boussole).
2. **Filtre de Kalman + Map-Matching** : lissage de la position, de la vitesse et du cap (`heading`), et aimantation douce sur la géométrie de la voie (`RouteGeometry`).
3. **Prédiction entre deux ticks GPS (16 ms par frame)** : projection continue de l'avance selon la vitesse instantanée + rotation fluide via le gyroscope.
4. **Caméra cinématique amortie (Spring-Damper)** : la caméra suit derrière le véhicule avec une inertie douce (zoom dynamique selon la vitesse : plus proche à l'arrêt/carrefour, légèrement plus large et incliné à 50–70 km/h).

### 3.4. Couche Backend & Diffusion Temps Réel
1. **Serveur de tuiles vectorielles auto-hébergé** :
   - Génération d'une archive **PMTiles** unique couvrant le Burkina Faso (routes + bâtiments Overture/OSM avec hauteurs + hydrographie + occupation du sol) + **PMTiles DEM** (relief).
   - Servie via un service léger (ex. **Martin** ou **PMTiles sur CDN / Nginx** avec *HTTP Range Requests*).
2. **Service de Scène 3D Locale (`/api/v1/map3d/corridor` ou tuiles locales)** :
   - Renvoie les monuments `.glb` à précharger dans la zone, les géométries multi-niveaux des échangeurs et les `RoadFeature` / `RepereLocal` enrichis.
3. **Diffusion Trafic & Incidents Live (WebSocket)** :
   - Extension de [`TrafficService`](file:///home/ouedraogo/Bureau/qvgestion-backend/app/services/traffic_service.py#L41) : abonnement WebSocket par cellule spatiale (ex. rayon 1 km autour du conducteur) pour recevoir les positions anonymisées (position, cap, vitesse, type véhicule `moto`/`voiture`) des autres usagers actifs toutes les 1 à 2 secondes, plus les signalements (`reports`) en direct.

---

## 4. Est-ce que ça peut être ULTRA FLUIDE ? (Analyse Performance & Contraintes Burkina)

**Oui, à 60 FPS constants**, à condition de respecter des budgets matériels stricts adaptés au parc de smartphones réel au Burkina Faso (Tecno Spark/Camon, Infinix Hot/Note, Samsung Galaxy A-series, Xiaomi Redmi avec 3 à 6 Go de RAM, GPU Mali-G52 / G57 / Adreno 610, températures ambiantes élevées) :

### Les 7 Règles d'Or pour garantir les 60 FPS sans chauffe ni crash

| Pilier | Problème évité | Solution technique précise |
|---|---|---|
| **1. Interpolation 60 Hz (GPS + IMU)** | Mouvement saccadé « téléporté » toutes les secondes. | Boucle `Ticker` Flutter à 60 Hz pilotant un filtre Kalman + Dead Reckoning entre les fixes GPS 1 Hz. |
| **2. GPU Instancing & Fusion de maillages** | Chute à 15 FPS causée par trop d'appels GPU (*draw calls*). | Fusionner les bâtiments d'une même tuile en un maillage unique ; instancier arbres, feux et véhicules de trafic (< **80 draw calls/frame**, < **150 000 triangles visibles**). |
| **3. Compression Draco + KTX2** | Saturation RAM et téléchargement lent en 3G/4G. | Compresser tous les `.glb` avec **Draco** (maillage -80 %) et **KTX2 / Basis Universal** (textures compressées directement en VRAM GPU sans décompression PNG lourde). Poids cible : **< 800 Ko par monument**. |
| **4. LOD (Level of Detail) & Brouillard d'horizon** | Rendu inutile des bâtiments à 5 km. | • **0–150 m** : détails complets (voies, marquages, véhicules, feux, ego 3D).<br>• **150–600 m** : bâtiments extrudés simples + monuments.<br>• **> 600 m** : fondu progressif dans le brouillard atmosphérique / ciel. |
| **5. Packs Offline Vectoriels (PMTiles)** | Blanc sur la carte en zone périurbaine ou coupure 4G. | Pré-téléchargement optionnel par ville/région (ex. Ouagadougou ~100–150 Mo, Bobo ~50 Mo, Burkina complet ~450 Mo) stocké dans le cache local avec [`offline_repository`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/features/offline/data/repositories/offline_repository.dart). |
| **6. Profils de Qualité Adaptatifs** | Surchauffe en plein soleil / batterie qui fond. | 3 modes réglables (ou auto selon température/batterie) :<br>• **Ultra** : 60 FPS, ombres douces, effet bloom radar, portée 800 m.<br>• **Équilibré (Défaut)** : 60 FPS, éclairage simplifié, portée 500 m.<br>• **Éco / Plein Soleil** : 30–45 FPS, contraste renforcé anti-reflet, zéro post-processing lourd. |
| **7. Choix libre dans l'UI** | Forcer la 3D lourde sur un téléphone très ancien (2 Go RAM). | L'utilisateur choisit son fond de carte dans un sélecteur clair : **Standard (Clair)** · **Sombre** · **Satellite** · **Faso 3D** (+ option **Vue Radar Live** pendant la navigation). |

---

## 5. Expérience Utilisateur Cible dans l'Application

### A. Sélecteur de Carte (Écran d'exploration `HomeMapScreen`)
Un sélecteur de calques permet de basculer à tout moment vers **« Faso 3D Immersif »** :
- Vue inclinable et rotative librement à deux doigts (pitch `0°` à `68°`).
- Bâtiments en volume avec hauteur réaliste et ombrage solaire (adapté jour/nuit selon l'heure à Ouagadougou).
- Monuments et échangeurs du Burkina reconnaissables immédiatement (et cliquables comme POI).
- Labels flottants nets avec halo anti-éblouissement, conservant les couleurs de catégories FASO NAV ([`MapTheme`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/theme/map_theme.dart#L61-L97)).

### B. Pendant la Navigation : « Vue Radar / Cockpit Live »
Lorsqu'un itinéraire est lancé, un bouton bascule instantanément entre :
1. **Vue Carte 3D Classique** (vue d'ensemble 3D inclinée, idéale pour anticiper loin).
2. **Vue Radar Live (Cockpit)** — inspirée des écrans de conduite autonome :
   - **Votre véhicule en 3D** au premier plan (moto, voiture, vélo ou piéton selon le mode sélectionné).
   - **Chaussée modélisée avec voies, bordures et zébras**, courbée dynamiquement selon la géométrie réelle de la route et du prochain virage / échangeur.
   - **Tapis lumineux de trajectoire** + flèches animées indiquant quelle bretelle ou voie prendre.
   - **Impulsions radar circulaires** émanant du véhicule : lorsqu'une onde traverse un élément à moins de 250 m (feu tricolore, dos-d'âne, rond-point, accident signalé, repère vocal en mooré/dioula), l'objet **s'illumine en 3D** avec son icône et sa distance !
   - **Autres véhicules en quasi-live** : représentation 3D fluide des usagers connectés à proximité et visualisation visuelle de la densité du trafic devant soi.

---

## 6. Plan d'Action & Feuille de Route par Phases

### Phase 0 — Fondations & « Quick Win 3D » dans l'App Actuelle *(2 à 3 semaines)*
**Objectif** : Donner un premier rendu 3D impressionnant immédiatement testable sans refonte lourde.
1. **Activer la 3D dans MapLibre** :
   - Créer un 4e style `faso-3d.json` (et sa variante nuit) dérivé de [`faso-light.json`](file:///home/ouedraogo/Bureau/qvgestion_mobile/assets/map/styles/faso-light.json) en remplaçant la couche `building` `"type": "fill"` par `"type": "fill-extrusion"` avec hauteur interpolée (`render_height` / `render_min_height`), couleur contrastée et `fill-extrusion-vertical-gradient: true`.
   - Ajouter la source de relief terrain DEM (`raster-dem`) pour les falaises, collines et barrages.
2. **Sélecteur de mode de carte** :
   - Étendre [`MapConfig`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/config/map_config.dart) et remplacer le simple booléen `isSatelliteModeProvider` ([`theme_provider.dart`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/theme/theme_provider.dart#L28)) par un `enum MapVisualStyle { light, dark, satellite, faso3d }` + sélecteur UI dans [`HomeMapScreen`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/features/map/presentation/screens/home_map_screen.dart).
3. **Interpolation caméra 60 Hz** :
   - Ajouter `sensors_plus` dans `pubspec.yaml`.
   - Implémenter un interpolateur GPS + cap IMU pour que la caméra et le marqueur véhicule avancent à 60 FPS au lieu de sauter à 1 Hz.

---

### Phase 1 — Pipeline Data 3D National Burkina Faso & Modèles Monuments *(4 à 6 semaines)*
**Objectif** : Disposer de données 3D complètes et fidèles pour tout le Burkina (pas seulement les zones déjà denses sur OSM).
1. **Pipeline Géospatial Backend (ETL)** :
   - Étendre [`overture_import.py`](file:///home/ouedraogo/Bureau/qvgestion-backend/app/services/overture_import.py) pour fusionner **Overture Maps Buildings + Google Open Buildings + OSM** sur la boîte englobante du Burkina Faso (`[9.0..15.5, -5.5..2.5]`).
   - Générer les tuiles vectorielles nationales compressées au format **PMTiles** (`burkina-3d.pmtiles` + `burkina-dem.pmtiles`) et les servir depuis l'infrastructure backend/CDN.
   - Enrichir l'extraction routière avec le nombre de voies, les ponts/niveaux (`layer` / `z_order` pour les échangeurs) et les types de revêtement (`RoadLocalAttr`).
2. **Production des 15 à 25 premiers modèles 3D « Héros » (`.glb`)** :
   - Modélisation low-poly PBR (Blender) des échangeurs et monuments majeurs de **Ouagadougou** et **Bobo-Dioulasso** (puis extension progressive à Koudougou, Banfora, Kaya, Ouahigouya, Tenkodogo, Dédougou, Fada).
   - Export optimisé **glTF / GLB + Draco + KTX2** (< 800 Ko/modèle) avec 2 niveaux de détail (LOD0 proche, LOD1 lointain).
   - Création d'une table/registre backend `landmarks_3d` (liée à `RepereLocal` et `RoadFeature`) exposant la liste et les métadonnées de placement (lat, lon, azimut, échelle, URL CDN versionnée avec hash).

---

### Phase 2 — Rendu des Monuments & Échangeurs 3D dans « Faso 3D » *(4 à 5 semaines)*
**Objectif** : Afficher les modèles `.glb` fidèles intégrés à la carte 3D nationale à 60 FPS.
1. **Intégration Native 3D sur MapLibre** :
   - Sur Android (OpenGL ES / Vulkan) et iOS (Metal), implémenter un **Custom Style Layer** (ou coupler la matrice caméra de MapLibre à un overlay Filament transparent synchronisé au pixel près).
   - Charger et cacher localement les `.glb` dans la zone visible (frustum culling + cache LRU en RAM/disque).
2. **Gestion multi-niveaux des échangeurs** :
   - Rendre les bretelles supérieures avec piles de pont, ombres portées au sol et séparation claire des niveaux (fini les routes qui se coupent à plat).
3. **Éclairage solaire dynamique** :
   - Adapter automatiquement l'angle du soleil, l'ombre des bâtiments et le ciel selon l'heure locale (aube, plein soleil, crépuscule sahélien, nuit).

---

### Phase 3 — Mode Navigation « Vue Radar / Cockpit Live » (Style Voiture Autonome) *(6 à 8 semaines)*
**Objectif** : Construire le mode de guidage immersif 3D temps réel inspiré des véhicules autonomes.
1. **Moteur de Scène Locale 3D (`FasoRadar3DEngine` sous Google Filament / `thermion_flutter`)** :
   - Widget Flutter dédié branché derrière [`MapService`](file:///home/ouedraogo/Bureau/qvgestion_mobile/lib/core/services/map_service.dart) ou comme vue alternative dans `HomeMapScreen` lorsque `MapScreenState.activeNavigation` est actif.
   - Fenêtre glissante de **500 m** autour du conducteur : extraction instantanée depuis les tuiles vectorielles locales/cache des polygones de routes, voies, bordures et bâtiments extrudés.
2. **Modèles Ego & Mobilier Dynamique** :
   - Modèles 3D articulés pour les 4 modes FASO NAV : **Moto** (avec inclinaison dynamique dans les virages !), **Voiture**, **Vélo**, **Piéton**.
   - Modèles 3D génériques pour `RoadFeature` (feux tricolores animés, dos-d'âne texturés, barrières, ronds-points).
3. **Shaders & Effets « Radar / Vision »** :
   - Ruban de trajectoire 3D lumineux posé sur la voie avec chevrons animés en fonction de la vitesse.
   - Shader d'onde radar circulaire/conique balayant la chaussée toutes les 2 secondes et déclenchant un halo/mise en avant sur les dangers, dos-d'âne, incidents signalés et repères vocaux (`RepereLocal`).
4. **Flux Trafic Temps Réel via WebSocket** :
   - Étendre [`TrafficService`](file:///home/ouedraogo/Bureau/qvgestion-backend/app/services/traffic_service.py) pour diffuser les véhicules anonymisés dans la zone de 500 m (position, cap, vitesse, type).
   - Côté mobile : interpolation fluide des autres véhicules sur la chaussée + génération procédurale cohérente de densité trafic là où les données agrégées indiquent une congestion (`HEAVY` / `MODERATE`).

---

### Phase 4 — Optimisation Terrain, Mode Offline & Évolutions Futures *(3 à 4 semaines)*
1. **Tests terrain réels au Burkina Faso** :
   - Campagne de tests à Ouagadougou (traversée des échangeurs du Nord / Est / Ouaga 2000, zones denses de Zogona/Dapoya, zones en latérite) sur au moins 3 classes d'appareils (entrée de gamme 3 Go RAM, milieu de gamme 4–6 Go, haut de gamme).
   - Mesure des métriques cibles : **>= 55–60 FPS**, RAM < **350 Mo** pour la vue 3D, dérive thermique acceptable après 45 min de guidage en plein soleil, consommation data < **5 Mo / heure** en navigation.
2. **Gestionnaire de Packs 3D Hors-Ligne** :
   - Téléchargement Wi-Fi recommandé par ville (Ouaga, Bobo, Koudougou, etc.) incluant PMTiles + modèles `.glb` locaux.
3. **Option Future (Phase 5 — Bonus AR)** :
   - Couche optionnelle *Réalité Augmentée Piéton / Derniers 100 mètres* via ARCore/ARKit pour retrouver une boutique ou un maquis précis à pied.

---

## 7. Synthèse des Risques & Contre-Mesures

| Risque | Impact | Probabilité | Contre-mesure prévue |
|---|---|---|---|
| **Données OSM incomplètes hors grands axes** (hauteurs, nombre de voies, revêtements) | Bâtiments manquants ou routes génériques en quartiers périphériques | Élevée | Fusion **Overture Maps + Google Open Buildings** + valeurs par défaut intelligentes issues de `RoadLocalAttr` + contribution admin déjà existante dans l'app. |
| **Surchauffe et baisse de FPS sur smartphones d'entrée de gamme** | Saccades ou fermeture OS | Élevée | Profil **Éco / Équilibré** automatique selon FPS mesuré/température + possibilité de basculer d'un tap vers la carte 2D légère. |
| **Précision GPS dégradée sous les échangeurs ou rues étroites** | Le véhicule 3D sort de sa voie | Moyenne | Map-matching strict sur le tracé + prédiction IMU (gyroscope/accéléromètre) pour maintenir la trajectoire pendant les pertes GPS de 2–5 s. |
| **Coût et délai de modélisation des monuments** | Retard sur la couverture de tout le pays | Moyenne | Prioriser les **20 carrefours/monuments à plus fort trafic** (Ouaga + Bobo) en V1, puis enrichissement continu par mises à jour OTA des `.glb` sans republier l'app. |

---

## 8. Recommandation Immédiate (Prochaine Étape Concrète)

Pour valider la faisabilité **visuellement et techniquement dès cette semaine** avant d'investir dans le pipeline complet :
1. **Lancer un mini-sprint Phase 0 (3–5 jours)** : activer `fill-extrusion` + relief sur un style `faso-3d.json`, ajouter le choix **« Faso 3D »** dans le sélecteur de carte, et brancher une **interpolation caméra 60 Hz** sur la navigation simulée déjà présente dans `HomeMapScreen`.
2. **Lancer en parallèle un PoC `thermion_flutter` (Google Filament)** sur un tronçon test de Ouagadougou (par exemple *Place des Martyrs → Échangeur de Ouaga 2000*) afin de mesurer les FPS réels, la RAM et la température sur un smartphone Android courant au Burkina Faso.

